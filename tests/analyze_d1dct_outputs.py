from pathlib import Path


INPUT_VECTORS = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [5, 5, 5, 5, 5, 5, 5, 5],
    [32, 0, 0, 0, 0, 0, 0, 0],
    [-28, -20, -12, -4, 4, 12, 20, 28],
    [11, -7, 3, -19, 23, -5, 2, -13],
]

COEFFS = [
    [362, 362, 362, 362, 362, 362, 362, 362],
    [502, 426, 284, 100, -100, -284, -426, -502],
    [473, 196, -196, -473, -473, -196, 196, 473],
    [426, -100, -502, -284, 284, 502, 100, -426],
    [362, -362, -362, 362, 362, -362, -362, 362],
    [284, -502, 100, 426, -426, -100, 502, -284],
    [196, -473, 473, -196, -196, 473, -473, 196],
    [100, -284, 426, -502, 502, -426, 284, -100],
]


def round_shift_10(value: int) -> int:
    if value >= 0:
        return (value + 512) >> 10
    return (value - 512) >> 10


def rtl_dct_model(samples: list[int]) -> list[int]:
    outputs = []
    for row in COEFFS:
        acc = sum(sample * coeff for sample, coeff in zip(samples, row))
        outputs.append(round_shift_10(acc))
    return outputs


def parse_lines(path: Path) -> list[list[int]]:
    lines = []
    for raw in path.read_text(encoding="ascii").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        lines.append([int(token) for token in raw.split()])
    return lines


def main():
    root = Path(__file__).resolve().parent.parent
    observed = parse_lines(root / "tests" / "d1dct_pipeline_output.txt")
    expected = [rtl_dct_model(samples) for samples in INPUT_VECTORS]

    if len(observed) != len(expected):
        raise SystemExit(f"d1dct: expected {len(expected)} outputs, got {len(observed)}")

    issues = []
    for idx, (obs, exp) in enumerate(zip(observed, expected)):
        if obs != exp:
            issues.append(f"vector {idx}: expected {exp}, got {obs}")

    if issues:
        print("d1dct: FAIL")
        for issue in issues:
            print(f"  - {issue}")
        raise SystemExit(1)

    print("d1dct: PASS against current fixed-point DCT model")


if __name__ == "__main__":
    main()
