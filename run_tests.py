import os
import subprocess
import sys

# Script for running JPEG Encoder FPGA IP Core automated tests
# Dependencies are managed via `uv run`.

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "tests"))

from jpeg_test_patterns import TEST_PATTERN_BUILDERS

def run_command(command, description):
    print(f"\n--- {description} ---")
    print(f"Executing: {command}")
    process = subprocess.Popen(command, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate(input=b'finish\n')
    
    if stdout:
        print(stdout.decode())
    if stderr:
        print(stderr.decode(), file=sys.stderr)
        
    if process.returncode != 0 and "vvp" not in command:
        return False
    return True

def main():
    output_dir = os.path.join("tests", "generated")
    # 1. Generate lookup tables and test vectors
    if not run_command("uv run tests/gen_huffman_hex.py", "Generating Standard JPEG Huffman/Header Assets"):
        return
    if not run_command("uv run tests/gen_reference_jpeg.py", "Generating Software Reference JPEG"):
        return
    if not run_command("uv run tests/gen_test_vectors.py", "Generating Golden Model Data"):
        return
    if not run_command(
        "iverilog -o simv_d1dct DCT/d1dct_pipeline.v tests/tb_d1dct_pipeline.v",
        "Compiling D1DCT Testbench"
    ):
        return
    if not run_command("vvp simv_d1dct", "Running D1DCT Testbench"):
        return
    if not run_command("uv run tests/analyze_d1dct_outputs.py", "Analyzing D1DCT Outputs"):
        return
    if not run_command(
        "iverilog -o simv_d2dct DCT/D2DCT.v DCT/D1DCT.v DCT/d1dct_pipeline.v DCT/transpose_buffer.v DCT/line_buffer.v DCT/fifo.v tests/tb_d2dct.v",
        "Compiling D2DCT Testbench"
    ):
        return
    if not run_command("vvp simv_d2dct", "Running D2DCT Testbench"):
        return
    if not run_command("uv run tests/analyze_d2dct_outputs.py", "Analyzing D2DCT Outputs"):
        return
    if not run_command(
        "iverilog -o simv_chain rgb2ycbcr.v DCT/D2DCT.v DCT/D1DCT.v DCT/d1dct_pipeline.v DCT/transpose_buffer.v DCT/line_buffer.v DCT/fifo.v quantizer.v zigzag.v tests/tb_dct_chain.v",
        "Compiling DCT Chain Testbench"
    ):
        return
    if not run_command("vvp simv_chain", "Running DCT Chain Testbench"):
        return
    if not run_command("uv run tests/analyze_dct_chain.py", "Analyzing DCT Chain Outputs"):
        return
    if not run_command(
        "iverilog -o simv_stage rgb2ycbcr.v quantizer.v zigzag.v tests/tb_stage_analysis.v",
        "Compiling Stage Analysis Testbench"
    ):
        return
    if not run_command("vvp simv_stage", "Running Stage Analysis Testbench"):
        return
    if not run_command("uv run tests/analyze_stage_outputs.py", "Analyzing Stage Outputs"):
        return

    # 2. Collect ALL Verilog source files
    v_files = [
        "jpeg_top.v",
        "rgb2ycbcr.v",
        "DCT/D2DCT.v",
        "DCT/D1DCT.v",
        "DCT/d1dct_pipeline.v",
        "DCT/transpose_buffer.v",
        "DCT/line_buffer.v",
        "DCT/fifo.v",
        "quantizer.v",
        "zigzag.v",
        "huffman_encoder.v",
        "huffman_lut.v",
        "bitstream_packer.v",
        "jpeg_header.v",
        "tests/tb_jpeg_top.v"
    ]
    
    for f in v_files:
        if not os.path.exists(f):
            print(f"Error: Missing source file: {f}")
            return

    # 3. Compile
    compile_cmd = f"iverilog -o simv " + " ".join(v_files)
    if not run_command(compile_cmd, "Compiling Verilog Source"):
        return

    # 4. Run Simulation
    if not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    passed = []
    for test_name in TEST_PATTERN_BUILDERS:
        pixel_path = f"tests/generated/{test_name}_pixels.hex"
        sim_output_path = f"tests/generated/{test_name}_sim_output.txt"
        sim_jpeg_path = f"tests/generated/{test_name}_sim_output.jpg"

        if not run_command(
            f"vvp simv +PIXELS={pixel_path} +OUTPUT={sim_output_path}",
            f"Running Simulation [{test_name}]"
        ):
            return

        if not run_command(
            f"uv run tests/validate_jpeg_output.py --test-name {test_name} --sim-path {sim_output_path} --output-jpeg-path {sim_jpeg_path}",
            f"Validating JPEG Bitstream [{test_name}]"
        ):
            return
        passed.append(test_name)

    # 6. Verification Result
    print("\n--- Verification Result ---")
    print(f"Generated outputs in: {os.path.join('tests', 'generated')}")
    print(f"Validated test images: {', '.join(passed)}")

if __name__ == "__main__":
    main()
