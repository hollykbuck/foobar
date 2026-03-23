from __future__ import annotations

from pathlib import Path

import numpy as np


WIDTH = 16
HEIGHT = 16


def build_ramp() -> np.ndarray:
    image = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    for row in range(HEIGHT):
        for col in range(WIDTH):
            base = row * 8 + col
            image[row, col, 0] = base
            image[row, col, 1] = base + 5
            image[row, col, 2] = base + 10
    return image


def build_checkerboard() -> np.ndarray:
    image = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    for row in range(HEIGHT):
        for col in range(WIDTH):
            if ((row // 2) + (col // 2)) % 2 == 0:
                image[row, col] = (230, 40, 40)
            else:
                image[row, col] = (30, 210, 220)
    return image


def build_stripes() -> np.ndarray:
    image = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    for row in range(HEIGHT):
        for col in range(WIDTH):
            if col < WIDTH // 4:
                image[row, col] = (240, 60, 50)
            elif col < WIDTH // 2:
                image[row, col] = (250, 220, 60)
            elif col < (WIDTH * 3) // 4:
                image[row, col] = (70, 190, 80)
            else:
                image[row, col] = (40, 90, 230)
    return image


def build_crossfade() -> np.ndarray:
    image = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    for row in range(HEIGHT):
        for col in range(WIDTH):
            image[row, col, 0] = row * 16
            image[row, col, 1] = col * 16
            image[row, col, 2] = min(255, row * 8 + col * 8)
    return image


TEST_PATTERN_BUILDERS = {
    "ramp": build_ramp,
    "checkerboard": build_checkerboard,
    "stripes": build_stripes,
    "crossfade": build_crossfade,
}


def build_pattern(name: str) -> np.ndarray:
    try:
        return TEST_PATTERN_BUILDERS[name]()
    except KeyError as exc:
        available = ", ".join(sorted(TEST_PATTERN_BUILDERS))
        raise ValueError(f"Unknown test pattern '{name}'. Available: {available}") from exc


def generated_dir(root: Path) -> Path:
    return root / "tests" / "generated"
