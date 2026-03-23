import argparse
from pathlib import Path

import numpy as np

from jpeg_test_patterns import build_pattern


Q_TABLE_Y = np.array([
    [18, 12, 11, 18, 27, 44, 57, 68],
    [13, 13, 16, 21, 29, 64, 67, 61],
    [16, 14, 18, 27, 44, 63, 77, 62],
    [16, 19, 24, 32, 57, 97, 89, 69],
    [20, 24, 41, 62, 75, 121, 114, 85],
    [27, 39, 61, 71, 90, 115, 125, 102],
    [54, 71, 87, 97, 114, 134, 133, 112],
    [80, 102, 105, 109, 124, 111, 114, 110],
], dtype=np.int32)

Q_TABLE_C = np.array([
    [19, 20, 27, 52, 110, 110, 110, 110],
    [20, 23, 29, 73, 110, 110, 110, 110],
    [27, 29, 62, 110, 110, 110, 110, 110],
    [52, 73, 110, 110, 110, 110, 110, 110],
    [110, 110, 110, 110, 110, 110, 110, 110],
    [110, 110, 110, 110, 110, 110, 110, 110],
    [110, 110, 110, 110, 110, 110, 110, 110],
    [110, 110, 110, 110, 110, 110, 110, 110],
], dtype=np.int32)

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

COEFFS = np.array([
    [362, 362, 362, 362, 362, 362, 362, 362],
    [502, 426, 284, 100, -100, -284, -426, -502],
    [473, 196, -196, -473, -473, -196, 196, 473],
    [426, -100, -502, -284, 284, 502, 100, -426],
    [362, -362, -362, 362, 362, -362, -362, 362],
    [284, -502, 100, 426, -426, -100, 502, -284],
    [196, -473, 473, -196, -196, 473, -473, 196],
    [100, -284, 426, -502, 502, -426, 284, -100],
], dtype=np.int32)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-name", required=True)
    parser.add_argument("--observed-path", required=True)
    return parser.parse_args()


def round_shift_10(values: np.ndarray) -> np.ndarray:
    return np.where(values >= 0, (values + 512) >> 10, (values - 512) >> 10)


def d1_dct(block: np.ndarray) -> np.ndarray:
    out = np.zeros((8, 8), dtype=np.int32)
    for row in range(8):
        products = block[row][None, :] * COEFFS
        out[row] = round_shift_10(products.sum(axis=1))
    return out


def d2_dct(block: np.ndarray) -> np.ndarray:
    stage1 = d1_dct(block)
    stage2 = d1_dct(stage1.T)
    return stage2.T


def quantize(block: np.ndarray, table: np.ndarray) -> np.ndarray:
    rounded = np.where(block >= 0, block + (table // 2), block - (table // 2))
    return np.trunc(rounded / table).astype(np.int32)


def rgb_to_ycbcr(rgb: np.ndarray):
    r = rgb[:, :, 0].astype(np.int32)
    g = rgb[:, :, 1].astype(np.int32)
    b = rgb[:, :, 2].astype(np.int32)
    y = ((77 * r + 150 * g + 29 * b) >> 8) - 128
    cb = ((-43 * r - 85 * g + 128 * b + 32768) >> 8) - 128
    cr = ((128 * r - 107 * g - 21 * b + 32768) >> 8) - 128
    return {"Y": y, "Cb": cb, "Cr": cr}


def expected_blocks(test_name: str):
    rgb = build_pattern(test_name)
    components = rgb_to_ycbcr(rgb)
    expected = {}
    for comp_name, plane in components.items():
        q_table = Q_TABLE_Y if comp_name == "Y" else Q_TABLE_C
        blocks = []
        for block_row in range(0, 16, 8):
            for block_col in range(0, 16, 8):
                block = plane[block_row:block_row + 8, block_col:block_col + 8]
                dct = d2_dct(block)
                quant = quantize(dct, q_table).reshape(-1)
                blocks.append([int(quant[idx]) for idx in ZIGZAG_ORDER])
        expected[comp_name] = blocks
    return expected


def load_observed(path: Path):
    observed = {"Y": {}, "Cb": {}, "Cr": {}}
    for line in path.read_text(encoding="ascii").splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        comp_name = parts[0]
        block_idx = int(parts[1])
        coeffs = [int(token) for token in parts[2:]]
        observed[comp_name][block_idx] = coeffs
    return observed


def summarize_block_diff(observed: list[int], expected: list[int]):
    diffs = [(idx, exp, obs) for idx, (obs, exp) in enumerate(zip(observed, expected)) if obs != exp]
    if not diffs:
        return None
    first = diffs[0]
    count = len(diffs)
    return count, first


def main():
    args = parse_args()
    root = Path(__file__).resolve().parent.parent
    observed = load_observed(root / args.observed_path)
    expected = expected_blocks(args.test_name)

    issues = []
    for comp_name in ("Y", "Cb", "Cr"):
        for block_idx, expected_coeffs in enumerate(expected[comp_name]):
            actual_coeffs = observed.get(comp_name, {}).get(block_idx)
            if actual_coeffs is None:
                issues.append(f"{comp_name} block {block_idx}: missing dump")
                continue
            summary = summarize_block_diff(actual_coeffs, expected_coeffs)
            if summary is None:
                continue
            diff_count, first = summary
            coeff_idx, expected_val, actual_val = first
            issues.append(
                f"{comp_name} block {block_idx}: {diff_count} coeff mismatches, first at coeff {coeff_idx} expected {expected_val} got {actual_val}"
            )

    if issues:
        print(f"block-grid-chain: FAIL [{args.test_name}]")
        for issue in issues:
            print(f"  - {issue}")
        raise SystemExit(1)

    print(f"block-grid-chain: PASS [{args.test_name}]")


if __name__ == "__main__":
    main()
