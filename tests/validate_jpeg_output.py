import argparse
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image

from jpeg_test_patterns import HEIGHT, WIDTH, build_pattern


MAX_MEAN_ABS_ERROR = 110.0


def load_sim_bytes(path: Path) -> bytes:
    values = []
    with path.open("r", encoding="ascii") as handle:
        for line in handle:
            token = line.strip()
            if not token:
                continue
            values.append(int(token, 16))
    return bytes(values)

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-name", default="ramp")
    parser.add_argument("--sim-path")
    parser.add_argument("--output-jpeg-path")
    return parser.parse_args()


def main():
    args = parse_args()
    root = Path(__file__).resolve().parent.parent
    sim_path = Path(args.sim_path) if args.sim_path else root / "tests" / "sim_output.txt"
    jpeg_path = Path(args.output_jpeg_path) if args.output_jpeg_path else root / "tests" / "sim_output.jpg"

    if not sim_path.exists():
        raise FileNotFoundError(f"Missing simulation output: {sim_path}")

    jpeg_bytes = load_sim_bytes(sim_path)
    if len(jpeg_bytes) < 4:
        raise ValueError("JPEG output is too short")
    if jpeg_bytes[:2] != b"\xFF\xD8":
        raise ValueError("Missing SOI marker")
    if jpeg_bytes[-2:] != b"\xFF\xD9":
        raise ValueError("Missing EOI marker")

    jpeg_path.write_bytes(jpeg_bytes)

    with Image.open(BytesIO(jpeg_bytes)) as decoded:
        decoded.load()
        if decoded.size != (WIDTH, HEIGHT):
            raise ValueError(f"Unexpected decoded size: {decoded.size}")
        rgb = np.array(decoded.convert("RGB"), dtype=np.int16)

    expected = build_pattern(args.test_name).astype(np.int16)
    mae = np.abs(rgb - expected).mean()
    max_err = np.abs(rgb - expected).max()
    value_span = int(rgb.max() - rgb.min())

    print(f"Test pattern: {args.test_name}")
    print(f"Decoded JPEG size: {WIDTH}x{HEIGHT}")
    print(f"Mean absolute error: {mae:.2f}")
    print(f"Max absolute error: {max_err}")
    print(f"Decoded value span: {value_span}")
    print(f"Wrote decoded bitstream to: {jpeg_path}")

    if value_span == 0:
        raise ValueError("Decoded JPEG is a flat image")

    if mae > MAX_MEAN_ABS_ERROR:
        raise ValueError(
            f"Decoded JPEG differs too much from source pattern: mae={mae:.2f} threshold={MAX_MEAN_ABS_ERROR:.2f}"
        )


if __name__ == "__main__":
    main()
