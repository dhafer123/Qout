"""Custom pages of the admin panel: the moderation queue, the review page of one
contribution (photos next to the fields, edit, preview the score, approve or reject), and
the error reports (resolve or dismiss).

They call the same `ModerationService` as the `/v1/admin` endpoints. Forms post back to the
same page; after a change the browser is redirected (no resubmission on reload).
"""

import uuid
from typing import Any

from pydantic import ValidationError
from sqladmin import BaseView, expose
from sqladmin.flash import Flash
from starlette import status
from starlette.exceptions import HTTPException
from starlette.requests import Request
from starlette.responses import RedirectResponse, Response

from app.admin.context import moderation_service, sessions_of, settings_of, signed_in_admin
from app.admin.forms import NUTRIENTS, changes, form_values, read_form
from app.core.storage import StorageError
from app.modules.contributions.models import Contribution, ContributionStatus, ReportStatus
from app.modules.contributions.moderation import (
    ContributionNotPendingError,
    ModerationService,
    ReportNotFoundError,
    ReportNotOpenError,
)
from app.modules.contributions.nutrition import score_preview
from app.modules.contributions.schemas import ContributionEdit, ReviewDecision
from app.modules.contributions.service import ContributionNotFoundError
from app.modules.products.models import NutritionBasis
from app.modules.scoring import Category

LIST_LIMIT = 200
ALREADY_DECIDED = "This contribution was already decided."
_REPORT_DECISIONS = {"resolve": ReportStatus.RESOLVED, "dismiss": ReportStatus.DISMISSED}


def _status_param[E: (ContributionStatus, ReportStatus)](
    request: Request, enum: type[E], default: E
) -> E:
    try:
        return enum(request.query_params.get("status", default.value))
    except ValueError:
        return default


def _uuid_param(request: Request, name: str) -> uuid.UUID:
    try:
        return uuid.UUID(request.path_params[name])
    except ValueError as error:
        raise HTTPException(status.HTTP_404_NOT_FOUND) from error


def _review_url(request: Request, contribution: Contribution) -> Any:
    return request.url_for("admin:view-review", contribution_id=str(contribution.id))


def _redirect(url: Any) -> RedirectResponse:
    return RedirectResponse(str(url), status_code=status.HTTP_303_SEE_OTHER)


class ModerationView(BaseView):
    name = "Contributions"
    category = "Moderation"
    icon = "fa-solid fa-inbox"

    @expose("/moderation", identity="moderation")
    async def queue(self, request: Request) -> Response:
        """Contributions by status, oldest first (pending: the queue)."""
        shown = _status_param(request, ContributionStatus, ContributionStatus.PENDING)
        async with sessions_of(request)() as session:
            items = await moderation_service(request, session).contributions(
                shown, limit=LIST_LIMIT
            )
        context = {
            "title": "Contributions",
            "items": items,
            "shown": shown,
            "statuses": list(ContributionStatus),
            "limit": LIST_LIMIT,
        }
        response: Response = await self.templates.TemplateResponse(
            request, "qout/moderation_queue.html", context
        )
        return response

    @expose("/moderation/{contribution_id}", methods=["GET", "POST"], identity="review")
    async def review(self, request: Request) -> Response:
        contribution_id = _uuid_param(request, "contribution_id")
        async with sessions_of(request)() as session:
            service = moderation_service(request, session)
            try:
                contribution = await service.get(contribution_id)
            except ContributionNotFoundError as error:
                raise HTTPException(status.HTTP_404_NOT_FOUND) from error
            if request.method == "GET":
                return await self._render(request, service, contribution)
            return await self._post(request, service, contribution)

    async def _post(
        self, request: Request, service: ModerationService, contribution: Contribution
    ) -> Response:
        form = await request.form()
        action = str(form.get("action", ""))
        values = {key: str(value) for key, value in form.items()}
        try:
            note = ReviewDecision.model_validate({"note": form.get("note")}).note
        except ValidationError:
            return await self._render(
                request, service, contribution, status.HTTP_400_BAD_REQUEST,
                values=values, errors={"note": "At most 500 characters"},
            )  # fmt: skip
        if action == "reject":
            return await self._reject(request, service, contribution, note)
        if action not in ("preview", "save", "approve"):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown action")

        result = read_form(form)
        if result.edit is None:
            return await self._render(
                request, service, contribution, status.HTTP_400_BAD_REQUEST,
                values=values, errors=result.errors,
            )  # fmt: skip
        edit = result.edit
        if action == "preview":
            # The schema refuses null category and nutrition: both are set here.
            preview = score_preview(edit.category, edit.nutrition)  # type: ignore[arg-type]
            return await self._render(
                request, service, contribution, values=values, preview=preview
            )
        try:
            return await self._save(
                request, service, contribution, edit, note, approve=action == "approve"
            )
        except StorageError:
            return await self._render(
                request, service, contribution, status.HTTP_503_SERVICE_UNAVAILABLE, values=values,
                error="Photo storage is unavailable: nothing was approved. Try again later.",
            )  # fmt: skip

    async def _reject(
        self,
        request: Request,
        service: ModerationService,
        contribution: Contribution,
        note: str | None,
    ) -> Response:
        # A refused decision rolls back, which expires `contribution`: read it first.
        review, ean = _review_url(request, contribution), contribution.ean
        try:
            await service.reject(contribution.id, signed_in_admin(request), note)
        except ContributionNotPendingError:
            Flash.error(request, ALREADY_DECIDED)
            return _redirect(review)
        Flash.success(request, f"Rejected {ean}.")
        return _redirect(request.url_for("admin:view-moderation"))

    async def _save(  # noqa: PLR0913 - the request's parts
        self,
        request: Request,
        service: ModerationService,
        contribution: Contribution,
        edit: ContributionEdit,
        note: str | None,
        *,
        approve: bool,
    ) -> Response:
        """Save what changed, then approve if asked. Raises StorageError (approval)."""
        # A refused change rolls back, which expires `contribution`: read it first.
        review, ean, contribution_id = (
            _review_url(request, contribution),
            contribution.ean,
            contribution.id,
        )
        try:
            changed = changes(contribution, edit)
            if changed is not None:
                await service.edit(contribution_id, changed)
            if not approve:
                Flash.success(request, "Saved." if changed else "Nothing changed.")
                return _redirect(review)
            await service.approve(contribution_id, signed_in_admin(request), note)
        except ContributionNotPendingError:
            Flash.error(request, ALREADY_DECIDED)
            return _redirect(review)
        Flash.success(request, f"Approved {ean}: the product is verified.")
        return _redirect(request.url_for("admin:view-moderation"))

    async def _render(
        self,
        request: Request,
        service: ModerationService,
        contribution: Contribution,
        status_code: int = status.HTTP_200_OK,
        **extra: Any,
    ) -> Response:
        """The review page; `extra`: values (as typed), errors, preview, error.

        While pending, it says whether approving updates an existing product (e.g. one
        from Open Food Facts without nutrition values) or creates one."""
        settings = settings_of(request)
        context = {
            "title": f"Contribution {contribution.ean}",
            "contribution": contribution,
            "pending": contribution.status == ContributionStatus.PENDING,
            "existing": await service.existing_product(contribution),
            "photo_urls": await service.photo_urls(
                contribution, expires_in=settings.admin_photo_url_ttl_seconds
            ),
            "values": form_values(contribution),
            "errors": {},
            "preview": None,
            "error": None,
            "nutrients": NUTRIENTS,
            "categories": list(Category),
            "bases": list(NutritionBasis),
        } | extra
        response: Response = await self.templates.TemplateResponse(
            request, "qout/moderation_review.html", context, status_code=status_code
        )
        return response


class ReportsView(BaseView):
    name = "Error reports"
    category = "Moderation"
    icon = "fa-solid fa-flag"

    @expose("/error-reports", identity="error-reports")
    async def reports(self, request: Request) -> Response:
        shown = _status_param(request, ReportStatus, ReportStatus.OPEN)
        async with sessions_of(request)() as session:
            items = await moderation_service(request, session).reports(shown, limit=LIST_LIMIT)
        context = {
            "title": "Error reports",
            "items": items,
            "shown": shown,
            "statuses": list(ReportStatus),
            "limit": LIST_LIMIT,
        }
        response: Response = await self.templates.TemplateResponse(
            request, "qout/reports.html", context
        )
        return response

    @expose("/error-reports/{report_id}/{decision}", methods=["POST"], identity="report-decision")
    async def decide(self, request: Request) -> Response:
        report_id = _uuid_param(request, "report_id")
        decision = _REPORT_DECISIONS.get(request.path_params["decision"])
        if decision is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND)
        async with sessions_of(request)() as session:
            service = moderation_service(request, session)
            try:
                await service.decide_report(report_id, signed_in_admin(request), decision)
            except ReportNotFoundError as error:
                raise HTTPException(status.HTTP_404_NOT_FOUND) from error
            except ReportNotOpenError:
                Flash.error(request, "This report was already handled.")
            else:
                Flash.success(request, f"Report {decision.value}.")
        return _redirect(request.url_for("admin:view-error-reports"))
