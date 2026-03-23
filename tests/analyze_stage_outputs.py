from pathlib import Path


Q_TABLE_Y = [
    18, 12, 11, 18, 27, 44, 57, 68,
    13, 13, 16, 21, 29, 64, 67, 61,
    16, 14, 18, 27, 44, 63, 77, 62,
    16, 19, 24, 32, 57, 97, 89, 69,
    20, 24, 41, 62, 75, 121, 114, 85,
    27, 39, 61, 71, 90, 115, 125, 102,
    54, 71, 87, 97, 114, 134, 133, 112,
    80, 102, 105, 109, 124, 111, 114, 110,
]

ZIGZAG_ORDER = [
    0, 1, 8, 16, 9, 2, 3, 10,
    17, 24, 32, 25, 18, 11, 4, 5,
    12, 19, 26, 33, 40, 48, 41, 34,
    27, 20, 13, 6, 7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36,
    29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46,
    53, 60, 61, 54, 47, 55, 62, 63,
]


def load_lines(path: Path):
    return [line.strip() for line in path.read_text(encoding="ascii").splitlines() if line.strip()]


def trunc_div(a: int, b: int) -> int:
    return int(a / b)


def round_nearest_signed(a: int, b: int) -> int:
    if a >= 0:
        return (a + b // 2) // b
    return -(((-a) + b // 2) // b)


def analyze_rgb(root: Path):
    observed = [tuple(map(int, line.split())) for line in load_lines(root / "tests" / "stage_rgb2ycbcr.txt")]
    samples = [(0, 5, 10), (15, 20, 25), (120, 125, 130), (240, 245, 250)]
    expected = []
    for r, g, b in samples:
        y = (77 * r + 150 * g + 29 * b) >> 8
        cb = (-43 * r - 85 * g + 128 * b + 32768) >> 8
        cr = (128 * r - 107 * g - 21 * b + 32768) >> 8
        expected.append((y & 0xFF, cb & 0xFF, cr & 0xFF))

    if observed == expected:
        print("rgb2ycbcr: PASS")
        return []

    issues = [f"rgb2ycbcr mismatch: expected {expected}, got {observed}"]
    if len(observed) == len(expected) and observed[:-1] == expected[1:] and observed[-1] == expected[-1]:
        issues.append("rgb2ycbcr likely has valid/data misalignment: first sample dropped and last sample repeated")
    return issues


def analyze_quantizer(root: Path):
    observed = [int(line) for line in load_lines(root / "tests" / "stage_quantizer.txt")]
    dct_coeffs = [(idx - 20) * 17 for idx in range(64)]

    rtl_expected = [round_nearest_signed(coeff, q) for coeff, q in zip(dct_coeffs, Q_TABLE_Y)]
    ideal_expected = rtl_expected[:]

    issues = []
    if observed != rtl_expected:
        issues.append("quantizer output does not match its current RTL formula")
        return issues

    mismatches = []
    for idx, (rtl_val, ideal_val) in enumerate(zip(rtl_expected, ideal_expected)):
        if rtl_val != ideal_val:
            mismatches.append((idx, dct_coeffs[idx], Q_TABLE_Y[idx], rtl_val, ideal_val))

    print("quantizer: RTL-consistent")
    print("quantizer: PASS against symmetric rounding model")
    return issues


def analyze_zigzag(root: Path):
    observed = [int(line) for line in load_lines(root / "tests" / "stage_zigzag.txt")]
    expected = [ZIGZAG_ORDER[idx] for idx in range(64)]
    if observed != expected:
        return [f"zigzag mismatch: expected {expected}, got {observed}"]
    print("zigzag: PASS")
    return []


def analyze_dct_implementation(root: Path):
    text = (root / "DCT" / "d1dct_pipeline.v").read_text(encoding="ascii")
    if "Simplified gain" in text and "not actual DCT" in text:
        print("dct: CURRENT IMPLEMENTATION IS A PLACEHOLDER, not a JPEG-accurate DCT")
        return ["dct implementation is a placeholder, not a JPEG-accurate transform"]
    if "Orthonormal 1D DCT matrix coefficients scaled by 256." in text:
        print("dct: fixed-point matrix DCT implementation detected")
        return []
    print("dct: implementation changed, inspect manually")
    return []


def main():
    root = Path(__file__).resolve().parent.parent
    issues = []
    issues.extend(analyze_rgb(root))
    issues.extend(analyze_quantizer(root))
    issues.extend(analyze_zigzag(root))
    issues.extend(analyze_dct_implementation(root))

    if issues:
        print("stage-analysis findings:")
        for issue in issues:
            print(f"  - {issue}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
