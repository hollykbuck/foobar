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

Q_TABLE_C = [
    19, 20, 27, 52, 110, 110, 110, 110,
    20, 23, 29, 73, 110, 110, 110, 110,
    27, 29, 62, 110, 110, 110, 110, 110,
    52, 73, 110, 110, 110, 110, 110, 110,
    110, 110, 110, 110, 110, 110, 110, 110,
    110, 110, 110, 110, 110, 110, 110, 110,
    110, 110, 110, 110, 110, 110, 110, 110,
    110, 110, 110, 110, 110, 110, 110, 110,
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
    return [round_shift_10(sum(sample * coeff for sample, coeff in zip(samples, row))) for row in COEFFS]


def transpose(block: list[list[int]]) -> list[list[int]]:
    return [[block[row][col] for row in range(8)] for col in range(8)]


def d2_dct(block: list[list[int]]) -> list[list[int]]:
    stage1 = [d1_dct(row) for row in block]
    stage2 = [d1_dct(row) for row in transpose(stage1)]
    return transpose(stage2)


def quantize(coeffs: list[list[int]], q_table: list[int]) -> list[int]:
    out = []
    for idx, coeff in enumerate(value for row in coeffs for value in row):
        q = q_table[idx]
        if coeff >= 0:
            rounded = coeff + q // 2
        else:
            rounded = coeff - q // 2
        out.append(int(rounded / q))
    return out


def rgb_to_ycbcr_block() -> dict[str, list[list[int]]]:
    y_block = []
    cb_block = []
    cr_block = []
    for row in range(8):
        y_row = []
        cb_row = []
        cr_row = []
        for col in range(8):
            r = row * 8 + col
            g = row * 8 + col + 5
            b = row * 8 + col + 10
            y = (77 * r + 150 * g + 29 * b) >> 8
            cb = (-43 * r - 85 * g + 128 * b + 32768) >> 8
            cr = (128 * r - 107 * g - 21 * b + 32768) >> 8
            y_row.append(y - 128)
            cb_row.append(cb - 128)
            cr_row.append(cr - 128)
        y_block.append(y_row)
        cb_block.append(cb_row)
        cr_block.append(cr_row)
    return {"Y": y_block, "Cb": cb_block, "Cr": cr_block}


def zigzag(values: list[int]) -> list[int]:
    return [values[idx] for idx in ZIGZAG_ORDER]


def expected_components() -> dict[str, list[int]]:
    blocks = rgb_to_ycbcr_block()
    result = {}
    for name, block in blocks.items():
        dct = d2_dct(block)
        q_table = Q_TABLE_Y if name == "Y" else Q_TABLE_C
        quant = quantize(dct, q_table)
        result[name] = zigzag(quant)
    return result


def load_observed(path: Path) -> dict[str, list[int]]:
    observed = {}
    for line in path.read_text(encoding="ascii").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        observed[parts[0]] = [int(token) for token in parts[1:]]
    return observed


def main():
    root = Path(__file__).resolve().parent.parent
    observed = load_observed(root / "tests" / "dct_chain_output.txt")
    expected = expected_components()

    issues = []
    for name in ("Y", "Cb", "Cr"):
        if name not in observed:
            issues.append(f"missing component dump: {name}")
            continue
        if observed[name] != expected[name]:
            for idx, (obs, exp) in enumerate(zip(observed[name], expected[name])):
                if obs != exp:
                    issues.append(f"{name} coeff {idx}: expected {exp}, got {obs}")
                    break

    if issues:
        print("dct-chain: FAIL")
        for issue in issues:
            print(f"  - {issue}")
        raise SystemExit(1)

    print("dct-chain: PASS against software block model")


if __name__ == "__main__":
    main()
