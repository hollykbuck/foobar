from pathlib import Path


BLOCKS = [
    [[0 for _ in range(8)] for _ in range(8)],
    [[12 for _ in range(8)] for _ in range(8)],
    [[row * 8 + col - 32 for col in range(8)] for row in range(8)],
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


def d1_dct(samples: list[int]) -> list[int]:
    outputs = []
    for row in COEFFS:
        acc = sum(sample * coeff for sample, coeff in zip(samples, row))
        outputs.append(round_shift_10(acc))
    return outputs


def transpose(block: list[list[int]]) -> list[list[int]]:
    return [[block[row][col] for row in range(8)] for col in range(8)]


def d2_standard(block: list[list[int]]) -> list[int]:
    stage1 = [d1_dct(row) for row in block]
    stage2 = [d1_dct(row) for row in transpose(stage1)]
    flattened = []
    for row in transpose(stage2):
        flattened.extend(row)
    return flattened


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
    observed = parse_lines(root / "tests" / "d2dct_output.txt")
    expected = [d2_standard(block) for block in BLOCKS]

    if len(observed) != len(expected):
        raise SystemExit(f"d2dct: expected {len(expected)} outputs, got {len(observed)}")

    issues = []
    for idx, (obs, exp) in enumerate(zip(observed, expected)):
        if obs != exp:
            issues.append(f"block {idx}: mismatch at first differing coefficient")
            for coeff_idx, (obs_coeff, exp_coeff) in enumerate(zip(obs, exp)):
                if obs_coeff != exp_coeff:
                    issues.append(
                        f"block {idx} coeff {coeff_idx}: expected {exp_coeff}, got {obs_coeff}"
                    )
                    break

    if issues:
        print("d2dct: FAIL")
        for issue in issues:
            print(f"  - {issue}")
        raise SystemExit(1)

    print("d2dct: PASS against standard row-major fixed-point DCT model")


if __name__ == "__main__":
    main()
