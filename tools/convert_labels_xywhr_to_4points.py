import os
import argparse
import numpy as np
from tqdm import tqdm
import shutil
import tempfile

def xywhr_to_4points_clamped(x_center, y_center, width, height, angle_rad):
    """
    将 (xc, yc, w, h, angle) 格式转换为四个角点坐标，并进行边界裁剪。
    angle_rad: 旋转角度（弧度）。
    """
    half_w, half_h = width / 2, height / 2
    corners = np.array([
        [-half_w, -half_h], [ half_w, -half_h],
        [ half_w,  half_h], [-half_w,  half_h]
    ])
    cos_a, sin_a = np.cos(angle_rad), np.sin(angle_rad)
    rotation_matrix = np.array([[cos_a, -sin_a], [sin_a, cos_a]])
    rotated_corners = corners @ rotation_matrix.T
    final_corners = rotated_corners + np.array([x_center, y_center])

    # ❗️❗️❗️ 核心修正：裁剪坐标到 [0.0, 1.0] 范围 ❗️❗️❗️
    # np.clip(array, min_value, max_value)
    clamped_corners = np.clip(final_corners, 0.0, 1.0)

    return clamped_corners.flatten()

def convert_file(input_path, output_path, is_overwrite):
    """转换单个标签文件"""
    converted_lines = []

    temp_fd, temp_path = tempfile.mkstemp(dir=os.path.dirname(input_path))

    try:
        with open(input_path, 'r') as infile:
            lines = infile.readlines()
            if not lines:
                os.close(temp_fd)
                os.remove(temp_path)
                return

            for i, line in enumerate(lines):
                line = line.strip()
                if not line:
                    continue

                parts = line.split()
                if len(parts) != 6:
                    print(f"\n[!] WARNING: Skipping malformed line #{i+1} in '{os.path.basename(input_path)}'. Expected 6 columns, got {len(parts)}. Line: '{line}'")
                    continue

                try:
                    class_id = int(parts[0])
                    xc, yc, w, h, angle = map(float, parts[1:])
                    angle_rad = angle # 假设 roLabelImg 输出的是弧度

                    four_points = xywhr_to_4points_clamped(xc, yc, w, h, angle_rad)
                    points_str = " ".join([f"{p:.6f}" for p in four_points])
                    converted_lines.append(f"{class_id} {points_str}")

                except ValueError as e:
                    print(f"\n[!] WARNING: Skipping line with non-numeric data #{i+1} in '{os.path.basename(input_path)}'. Error: {e}. Line: '{line}'")
                    continue

        if converted_lines:
            with os.fdopen(temp_fd, 'w') as temp_file:
                temp_file.write("\n".join(converted_lines))
            shutil.move(temp_path, output_path)
        else:
            os.close(temp_fd)
            os.remove(temp_path)
            if not is_overwrite:
                open(output_path, 'w').close()
            print(f"\n[!] INFO: No valid lines to convert in '{os.path.basename(input_path)}'.")

    except Exception as e:
        print(f"\n[X] ERROR: An unexpected error occurred while processing {input_path}: {e}")
        if os.path.exists(temp_path):
            try:
                os.close(temp_fd)
                os.remove(temp_path)
            except OSError:
                pass

# --- main 函数部分保持不变 ---
def main():
    parser = argparse.ArgumentParser(description="Convert OBB labels to 4-point format with coordinate clamping.")
    parser.add_argument("--input-dir", required=True, help="Input directory with 6-column OBB labels.")
    parser.add_argument("--output-dir", help="Output directory for 9-column OBB labels. If not provided, will overwrite.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite original files instead of saving to a new directory.")
    args = parser.parse_args()

    if not args.output_dir and not args.overwrite:
        parser.error("Either --output-dir must be specified, or --overwrite must be used.")

    input_dir = args.input_dir
    output_dir = args.output_dir if not args.overwrite else input_dir

    if args.overwrite:
        print(f"🚨 WARNING: Overwriting files in-place in '{input_dir}'")

    all_files = []
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.endswith('.txt'):
                all_files.append((root, file))

    if not all_files:
        print("No .txt files found to process.")
        return

    for root, file in tqdm(all_files, desc="Converting labels"):
        src_path = os.path.join(root, file)

        if args.overwrite:
            dest_path = src_path
        else:
            relative_path = os.path.relpath(root, input_dir)
            dest_root = os.path.join(output_dir, relative_path)
            os.makedirs(dest_root, exist_ok=True)
            dest_path = os.path.join(dest_root, file)

        convert_file(src_path, dest_path, args.overwrite)

    print("\n✅ Label conversion process finished.")

if __name__ == "__main__":
    main()