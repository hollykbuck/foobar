import numpy as np
from scipy.fftpack import dct
import os

def rgb_to_ycbcr(r, g, b):
    y = 0.299 * r + 0.587 * g + 0.114 * b
    cb = -0.1687 * r - 0.3313 * g + 0.5 * b + 128
    cr = 0.5 * r - 0.4187 * g - 0.0813 * b + 128
    return y, cb, cr

def dct_2d(block):
    return dct(dct(block.T, norm='ortho').T, norm='ortho')

def quantize(block, q_table):
    return np.round(block / q_table).astype(int)

# Standard JPEG Luminance Quantization Table (Quality 50)
Q_TABLE_Y = np.array([
    [16, 11, 10, 16, 24, 40, 51, 61],
    [12, 12, 14, 19, 26, 58, 60, 55],
    [14, 13, 16, 24, 40, 57, 69, 56],
    [14, 17, 22, 29, 51, 87, 80, 62],
    [18, 22, 37, 56, 68, 109, 103, 77],
    [24, 35, 55, 64, 81, 104, 113, 92],
    [49, 64, 78, 87, 103, 121, 120, 101],
    [72, 92, 95, 98, 112, 100, 103, 99]
])

def generate_test_vectors():
    print("Generating test vectors for 8x8 block...")
    
    # Create an 8x8 RGB image (simple gradient)
    r = np.arange(64).reshape(8, 8)
    g = np.arange(64, 128).reshape(8, 8)
    b = np.arange(128, 192).reshape(8, 8)
    
    # 1. CSC
    y, cb, cr = rgb_to_ycbcr(r, g, b)
    print("\nSample Y (after CSC):")
    print(y[0, :8])
    
    # 2. Level Shift (-128)
    y_shifted = y - 128
    
    # 3. 2D DCT
    # Note: Our Verilog implementation uses Loeffler which is an un-normalized Fast DCT.
    # SciPy's 'ortho' norm is slightly different in scaling.
    y_dct = dct_2d(y_shifted)
    
    # 4. Quantization
    y_quant = quantize(y_dct, Q_TABLE_Y)
    print("\nQuantized Y coefficients (First few):")
    print(y_quant[0, :4])

    # Save to file
    with open("tests/expected_output.txt", "w") as f:
        f.write("# Expected Quantized Y Block\n")
        np.savetxt(f, y_quant, fmt="%d")

if __name__ == "__main__":
    generate_test_vectors()
