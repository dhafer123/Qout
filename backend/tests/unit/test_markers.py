import pytest


def test_unit_tests_are_not_marked_integration(request: pytest.FixtureRequest) -> None:
    # Regression: the integration conftest hook used to mark every collected test.
    assert request.node.get_closest_marker("integration") is None
