import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image


def extract_frames(video_path: Path, output_dir: Path) -> list[Path]:
    subprocess.run(
        [
            "ffmpeg", "-i", str(video_path),
            "-vsync", "0",
            str(output_dir / "frame_%04d.png"),
        ],
        check=True,
        capture_output=True,
    )
    frames = sorted(output_dir.glob("frame_*.png"))
    return frames


def remove_black_background(img: Image.Image, threshold: int = 30) -> Image.Image:
    rgba = img.convert("RGBA")
    data = np.array(rgba)
    r, g, b = data[:, :, 0], data[:, :, 1], data[:, :, 2]
    brightness = r.astype(int) + g.astype(int) + b.astype(int)
    mask = brightness < threshold * 3
    data[mask, 3] = 0
    return Image.fromarray(data)


def stitch_grid(frames: list[Path], output_path: Path) -> tuple[int, int, int, int]:
    images = [remove_black_background(Image.open(f)) for f in frames]
    frame_w = images[0].width
    frame_h = images[0].height
    frame_count = len(images)
    columns = math.ceil(math.sqrt(frame_count))
    rows = math.ceil(frame_count / columns)

    sheet = Image.new("RGBA", (frame_w * columns, frame_h * rows), (0, 0, 0, 0))
    for i, img in enumerate(images):
        col = i % columns
        row = i // columns
        sheet.paste(img, (col * frame_w, row * frame_h))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, "PNG")
    return frame_count, columns, frame_w, frame_h


def main() -> None:
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <video.mp4> <output_sheet.png>")
        sys.exit(1)

    video_path = Path(sys.argv[1]).expanduser().resolve()
    output_path = Path(sys.argv[2]).expanduser().resolve()

    if not video_path.exists():
        print(f"Video not found: {video_path}")
        sys.exit(1)

    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        frames = extract_frames(video_path, tmp_dir)
        if not frames:
            print("No frames extracted")
            sys.exit(1)

        frame_count, columns, frame_w, frame_h = stitch_grid(frames, output_path)
        rows = math.ceil(frame_count / columns)
        print(f"Created {output_path.name}: {frame_count} frames in {columns}x{rows} grid, {frame_w}x{frame_h} each")


if __name__ == "__main__":
    main()
