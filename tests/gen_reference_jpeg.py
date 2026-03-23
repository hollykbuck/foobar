from pathlib import Path

from PIL import Image

from jpeg_test_patterns import TEST_PATTERN_BUILDERS, build_pattern, generated_dir


def write_pixel_hex(output_path: Path, rgb_image) -> None:
    with output_path.open("w", encoding="ascii") as handle:
        for row in rgb_image:
            for pixel in row:
                handle.write(f"{int(pixel[0]):02x}{int(pixel[1]):02x}{int(pixel[2]):02x}\n")


def main():
    root = Path(__file__).resolve().parent.parent
    output_dir = generated_dir(root)
    output_dir.mkdir(parents=True, exist_ok=True)

    for name in TEST_PATTERN_BUILDERS:
        rgb = build_pattern(name)
        input_png_path = output_dir / f"{name}_input.png"
        reference_jpg_path = output_dir / f"{name}_reference.jpg"
        pixel_hex_path = output_dir / f"{name}_pixels.hex"

        Image.fromarray(rgb, mode="RGB").save(input_png_path, format="PNG")
        Image.fromarray(rgb, mode="RGB").save(reference_jpg_path, format="JPEG", quality=95, subsampling=0)
        write_pixel_hex(pixel_hex_path, rgb)
        print(f"[{name}] input: {input_png_path}")
        print(f"[{name}] reference jpeg: {reference_jpg_path}")
        print(f"[{name}] pixel hex: {pixel_hex_path}")


if __name__ == "__main__":
    main()
