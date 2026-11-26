"""Command line: `python -m qout_ml <command>`.

fetch foodseg103 [--keep-parquet]   download and convert FoodSeg103 (~1.3 GB)
fetch nutrition5k                   download the pinned Nutrition5k sample (~200 MB)
nutrition5k-sample [--count N]      (maintainer) pick a new sample and write the manifest
"""

import argparse
import logging
import sys
from collections.abc import Sequence
from pathlib import Path

import httpx

from qout_ml.data import foodseg103, nutrition5k
from qout_ml.data.download import download_all
from qout_ml.paths import data_dir

logger = logging.getLogger("qout_ml")

USER_AGENT = "qout-ml (dataset fetch)"
TIMEOUT = httpx.Timeout(60.0, connect=20.0)


def _client() -> httpx.Client:
    return httpx.Client(headers={"User-Agent": USER_AGENT}, timeout=TIMEOUT, follow_redirects=True)


def fetch_foodseg103(client: httpx.Client, root: Path, *, keep_parquet: bool) -> None:
    for split, files in foodseg103.PARQUET_FILES.items():
        split_dir = root / "foodseg103" / split
        expected = foodseg103.SPLIT_SIZES[split]
        if foodseg103.is_converted(split_dir, expected):
            logger.info("foodseg103/%s: ready (%d samples)", split, expected)
            continue
        parquet = download_all(client, list(files), root / "downloads")
        foodseg103.convert_parquet(parquet, split_dir, expected)
        logger.info("foodseg103/%s: %d samples written", split, expected)
        if not keep_parquet:
            for path in parquet:
                path.unlink()


def fetch_nutrition5k(client: httpx.Client, root: Path, manifest: nutrition5k.Manifest) -> None:
    files = nutrition5k.remote_files(manifest)
    download_all(client, files, root)
    logger.info("nutrition5k: %d dishes ready", len(manifest.dishes))


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m qout_ml")
    commands = parser.add_subparsers(dest="command", required=True)
    fetch = commands.add_parser("fetch", help="download a dataset into the data folder")
    fetch.add_argument("dataset", choices=["foodseg103", "nutrition5k"])
    fetch.add_argument(
        "--keep-parquet", action="store_true", help="keep FoodSeg103's Parquet files"
    )
    sample = commands.add_parser("nutrition5k-sample", help="pick a new Nutrition5k sample")
    sample.add_argument("--count", type=int, default=500)
    sample.add_argument("--seed", type=int, default=0)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)
    with _client() as client:
        if args.command == "fetch" and args.dataset == "foodseg103":
            fetch_foodseg103(client, data_dir(), keep_parquet=args.keep_parquet)
        elif args.command == "fetch":
            fetch_nutrition5k(client, data_dir(), nutrition5k.load_manifest())
        else:
            manifest = nutrition5k.build_manifest(client, args.count, args.seed)
            nutrition5k.MANIFEST_FILE.write_text(
                nutrition5k.manifest_to_json(manifest), encoding="utf-8", newline="\n"
            )
            logger.info("wrote %s (%d dishes)", nutrition5k.MANIFEST_FILE, len(manifest.dishes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
