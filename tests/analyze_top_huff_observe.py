import argparse
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected-path", required=True)
    parser.add_argument("--observed-path", required=True)
    return parser.parse_args()


def load_dump(path: Path):
    observed = {}
    for line in path.read_text(encoding="ascii").splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        observed[(parts[0], int(parts[1]))] = [int(token) for token in parts[2:]]
    return observed


def main():
    args = parse_args()
    root = Path(__file__).resolve().parent.parent
    expected = load_dump(root / args.expected_path)
    observed = load_dump(root / args.observed_path)

    issues = []
    for key, expected_coeffs in expected.items():
        actual_coeffs = observed.get(key)
        if actual_coeffs is None:
            issues.append(f"missing block {key[0]} {key[1]}")
            continue
        for idx, (obs, exp) in enumerate(zip(actual_coeffs, expected_coeffs)):
            if obs != exp:
                issues.append(f"{key[0]} block {key[1]} coeff {idx}: expected {exp}, got {obs}")
                break

    extra = sorted(set(observed) - set(expected))
    for key in extra:
        issues.append(f"unexpected block {key[0]} {key[1]}")

    if issues:
        print("top-huff-observe: FAIL")
        for issue in issues:
            print(f"  - {issue}")
        raise SystemExit(1)

    print("top-huff-observe: PASS")


if __name__ == "__main__":
    main()
