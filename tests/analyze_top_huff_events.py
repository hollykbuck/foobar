import argparse
from pathlib import Path

from gen_huffman_hex import (
    BITS_AC_CHROMA,
    BITS_AC_LUMA,
    BITS_DC_CHROMA,
    BITS_DC_LUMA,
    VALS_AC_CHROMA,
    VALS_AC_LUMA,
    VALS_DC_CHROMA,
    VALS_DC_LUMA,
    build_canonical_codes,
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blocks-path", required=True)
    parser.add_argument("--events-path", required=True)
    return parser.parse_args()


def load_blocks(path: Path):
    blocks = []
    grouped = {}
    for line in path.read_text(encoding="ascii").splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        comp = parts[0]
        block_idx = int(parts[1])
        coeffs = [int(token) for token in parts[2:]]
        grouped.setdefault(block_idx, {})[comp] = coeffs

    for block_idx in sorted(grouped):
        entry = grouped[block_idx]
        blocks.append((block_idx, 0, entry["Y"]))
        blocks.append((block_idx, 1, entry["Cb"]))
        blocks.append((block_idx, 2, entry["Cr"]))
    return blocks


def load_events(path: Path):
    events = []
    for line in path.read_text(encoding="ascii").splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        kind = parts[0]
        if kind == "START":
            events.append(("START", int(parts[1]), int(parts[2])))
        elif kind == "BITS":
            events.append(("BITS", int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4], 16)))
        elif kind == "DONE":
            events.append(("DONE", int(parts[1]), int(parts[2])))
        else:
            raise ValueError(f"Unknown event line: {line}")
    return events


DC_CODES = {
    0: build_canonical_codes(BITS_DC_LUMA, VALS_DC_LUMA),
    1: build_canonical_codes(BITS_DC_CHROMA, VALS_DC_CHROMA),
    2: build_canonical_codes(BITS_DC_CHROMA, VALS_DC_CHROMA),
}
AC_CODES = {
    0: build_canonical_codes(BITS_AC_LUMA, VALS_AC_LUMA),
    1: build_canonical_codes(BITS_AC_CHROMA, VALS_AC_CHROMA),
    2: build_canonical_codes(BITS_AC_CHROMA, VALS_AC_CHROMA),
}


def get_category(value: int) -> int:
    abs_val = abs(value)
    if abs_val == 0:
        return 0
    category = 0
    while abs_val:
        category += 1
        abs_val >>= 1
    return category


def get_value_bits(value: int) -> int:
    if value > 0:
        return value
    return value - 1


def expected_events(blocks):
    events = []
    last_dc = {0: 0, 1: 0, 2: 0}

    for block_idx, comp, coeffs in blocks:
        events.append(("START", block_idx, comp))

        dc = coeffs[0]
        dc_diff = dc - last_dc[comp]
        last_dc[comp] = dc
        dc_cat = get_category(dc_diff)
        dc_code, dc_len = DC_CODES[comp][dc_cat]
        events.append(("BITS", block_idx, comp, dc_len, dc_code))
        if dc_cat != 0:
            events.append(("BITS", block_idx, comp, dc_cat, get_value_bits(dc_diff) & 0xFFFF))

        ac_idx = 1
        run_count = 0
        while ac_idx < 64:
            current = coeffs[ac_idx]
            if current == 0:
                if all(value == 0 for value in coeffs[ac_idx:]):
                    ac_code, ac_len = AC_CODES[comp][0x00]
                    events.append(("BITS", block_idx, comp, ac_len, ac_code))
                    events.append(("DONE", block_idx, comp))
                    break
                run_count += 1
                ac_idx += 1
                if run_count == 16:
                    ac_code, ac_len = AC_CODES[comp][0xF0]
                    events.append(("BITS", block_idx, comp, ac_len, ac_code))
                    run_count = 0
                continue

            ac_cat = get_category(current)
            rs = (run_count << 4) | ac_cat
            ac_code, ac_len = AC_CODES[comp][rs]
            events.append(("BITS", block_idx, comp, ac_len, ac_code))
            events.append(("BITS", block_idx, comp, ac_cat, get_value_bits(current) & 0xFFFF))
            run_count = 0
            if ac_idx == 63:
                events.append(("DONE", block_idx, comp))
                break
            ac_idx += 1

    return events


def main():
    args = parse_args()
    root = Path(__file__).resolve().parent.parent
    blocks = load_blocks(root / args.blocks_path)
    observed = load_events(root / args.events_path)
    expected = expected_events(blocks)

    issues = []
    if len(expected) != len(observed):
        issues.append(f"event count mismatch: expected {len(expected)}, got {len(observed)}")

    for idx, (exp, obs) in enumerate(zip(expected, observed)):
        if exp != obs:
            issues.append(f"event {idx}: expected {exp}, got {obs}")
            break

    if issues:
        print("top-huff-events: FAIL")
        for issue in issues:
            print(f"  - {issue}")
        raise SystemExit(1)

    print("top-huff-events: PASS")


if __name__ == "__main__":
    main()
