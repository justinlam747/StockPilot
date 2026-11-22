"""Install a verified, project-local queue server for Windows without registering a service."""

import hashlib
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path


VERSION = "8.10.3"
BUNDLE = f"Redis-{VERSION}-Windows-x64-msys2"
URL = f"https://github.com/redis-windows/redis-windows/releases/download/{VERSION}/{BUNDLE}.zip"
DIGEST = "af16df340525b431e9ec8dabfd625d5e7a233f82805b5418819904ea909c447f"
DESTINATION = Path(__file__).resolve().parents[1] / ".venv" / "stockpilot-redis" / VERSION


def install(archive=None):
    if os.name != "nt" or os.environ.get("STOCKPILOT_REDIS_URL") or os.environ.get("STOCKPILOT_REDIS_SERVER"):
        return
    if (DESTINATION / "redis-server.exe").is_file():
        return
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=DESTINATION.parent) as staging:
        folder = Path(staging)
        if archive is None:
            archive = folder / "redis.zip"
            with urllib.request.urlopen(URL, timeout=90) as response, archive.open("wb") as output:
                shutil.copyfileobj(response, output)
        with Path(archive).open("rb") as source:
            if hashlib.file_digest(source, "sha256").hexdigest() != DIGEST:
                raise ValueError("The Windows Redis download failed checksum verification.")
        binaries = folder / "bin"
        binaries.mkdir()
        with zipfile.ZipFile(archive) as bundle:
            for name in bundle.namelist():
                member = Path(name)
                if member.parent.as_posix() == BUNDLE and (
                    member.name == "redis-server.exe" or member.suffix == ".dll"
                ):
                    (binaries / member.name).write_bytes(bundle.read(name))
        if not (binaries / "redis-server.exe").is_file():
            raise ValueError("The Redis download did not contain redis-server.exe.")
        binaries.rename(DESTINATION)


if __name__ == "__main__":
    install(Path(sys.argv[1]) if len(sys.argv) > 1 else None)
