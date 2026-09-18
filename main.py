from __future__ import annotations

import os
import shutil
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_INPUT = ROOT / "frames"
DEFAULT_OUTPUT = ROOT / "exports"
DEFAULT_MODEL = ROOT / "models" / "RMBG-2.0-F16.gguf"
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
JOBS: dict[str, dict] = {}
JOBS_LOCK = threading.Lock()


def find_executable() -> str | None:
    candidates = [
        os.environ.get("VISION_CLI", ""),
        str(ROOT / "vision.cpp" / "build" / "bin" / "vision-cli"),
        str(ROOT / "vision-cli"),
        shutil.which("vision-cli") or "",
    ]
    return next((candidate for candidate in candidates if candidate and Path(candidate).exists()), None)


def discover_frames(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    return sorted(
        (item for item in folder.iterdir() if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS),
        key=lambda item: item.name.lower(),
    )


def update_job(job_id: str, **values) -> None:
    with JOBS_LOCK:
        JOBS[job_id].update(values)


def run_job(job_id: str, input_dir: Path, output_dir: Path, model: Path, overwrite: bool) -> None:
    executable = find_executable()
    frames = discover_frames(input_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    for item in output_dir.iterdir():
        if item.is_dir() and not item.is_symlink():
            shutil.rmtree(item)
        else:
            item.unlink()
    if not executable:
        update_job(job_id, status="error", error="vision-cli was not found. Build vision.cpp or set VISION_CLI to its executable path.")
        return
    if not model.is_file():
        update_job(job_id, status="error", error=f"Model not found: {model}. Download RMBG-2.0-F16.gguf into models/.")
        return
    if not frames:
        update_job(job_id, status="error", error=f"No supported images found in {input_dir}. Run export_frames.sh first or put PNG/JPG images in frames/.")
        return

    update_job(job_id, status="running", total=len(frames), completed=0, current=frames[0].name)
    failures: list[dict[str, str]] = []
    environment = os.environ.copy()
    library_dir = ROOT / "vision.cpp" / "build" / "lib"
    if library_dir.is_dir():
        environment["LD_LIBRARY_PATH"] = ":".join(
            part for part in (str(library_dir), environment.get("LD_LIBRARY_PATH", "")) if part
        )
    for index, frame in enumerate(frames, start=1):
        destination = output_dir / f"{frame.stem}.png"
        remaining = len(frames) - index
        print(f"Processing {index}/{len(frames)} ({remaining} left): {frame.name}", flush=True)
        update_job(job_id, current=frame.name, completed=index - 1)
        if destination.exists() and not overwrite:
            update_job(job_id, completed=index)
            continue
        command = [
            executable,
            "birefnet",
            "-m",
            str(model),
            "-i",
            str(frame),
            "-o",
            str(output_dir / f"{frame.stem}.mask.png"),
            "--composite",
            str(destination),
        ]
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=False, env=environment)
        except OSError as exc:
            failures.append({"file": frame.name, "message": str(exc)})
            continue
        if result.returncode != 0:
            message = (result.stderr or result.stdout or "vision-cli failed").strip().splitlines()[-1]
            failures.append({"file": frame.name, "message": message})
        else:
            mask = output_dir / f"{frame.stem}.mask.png"
            mask.unlink(missing_ok=True)
        update_job(job_id, completed=index)

    update_job(job_id, status="complete", current="", failures=failures)


def main() -> None:
    DEFAULT_INPUT.mkdir(exist_ok=True)
    DEFAULT_OUTPUT.mkdir(exist_ok=True)
    DEFAULT_MODEL.parent.mkdir(exist_ok=True)
    job_id = "batch"
    with JOBS_LOCK:
        JOBS[job_id] = {"id": job_id, "status": "queued", "total": 0, "completed": 0, "current": "", "failures": []}
    run_job(job_id, DEFAULT_INPUT, DEFAULT_OUTPUT, DEFAULT_MODEL, overwrite=True)
    with JOBS_LOCK:
        job = JOBS[job_id]
    if job["status"] == "error":
        print(job["error"], file=sys.stderr)
        raise SystemExit(1)
    print(f"Processed {job['completed']}/{job['total']} frames into {DEFAULT_OUTPUT}")
    if job["failures"]:
        print(f"{len(job['failures'])} frame(s) failed.", file=sys.stderr)
        for failure in job["failures"][:5]:
            print(f"  {failure['file']}: {failure['message']}", file=sys.stderr)
        if len(job["failures"]) > 5:
            print(f"  ... and {len(job['failures']) - 5} more", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()