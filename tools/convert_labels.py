import os
import argparse
import tempfile
import shutil
from tqdm import tqdm

def convert_detect_to_obb(line, default_angle=0.0):
    """将单行 detect 格式转换为 obb 格式"""
    parts = line.strip().split()
    if len(parts) == 5:
        parts.append(f"{default_angle:.6f}") # 保证格式一致性
        return " ".join(parts)
    elif len(parts) == 6:
        return line.strip()
    else:
        return None

def convert_obb_to_detect(line):
    """将单行 obb 格式转换为 detect 格式"""
    parts = line.strip().split()
    if len(parts) == 6:
        return " ".join(parts[:5])
    elif len(parts) == 5:
        return line.strip()
    else:
        return None

def process_directory(input_dir, output_dir, conversion_mode, default_angle, overwrite, non_interactive):
    """递归处理目录中的所有 .txt 标签文件，进行格式转换。"""

    # 确定转换函数
    if conversion_mode == 'detect2obb':
        converter = lambda line: convert_detect_to_obb(line, default_angle)
        print(f"Mode: Detect -> OBB. Default angle: {default_angle}")
    elif conversion_mode == 'obb2detect':
        converter = convert_obb_to_detect
        print("Mode: OBB -> Detect.")
    else:
        raise ValueError("Invalid conversion mode.")

    if overwrite:
        if not non_interactive:
            print("\n" + "🚨"*10)
            print("WARNING: --overwrite is enabled. This will modify files in-place.")
            print(f"The directory to be modified is: '{os.path.abspath(input_dir)}'")
            try:
                confirm = input("Are you absolutely sure? (y/n): ")
                if confirm.lower() != 'y':
                    print("Operation cancelled.")
                    return
            except (EOFError, KeyboardInterrupt):
                print("\nOperation cancelled by user.")
                return
        output_dir = input_dir # 直接在输入目录操作
        print(f"Overwriting files in '{input_dir}'...")
    else:
        print(f"Saving converted files to '{output_dir}'...")

    # 收集所有 .txt 文件
    txt_files = [os.path.join(root, file) for root, _, files in os.walk(input_dir) for file in files if file.endswith('.txt')]

    if not txt_files:
        print(f"No .txt files found in '{input_dir}'.")
        return

    print(f"Found {len(txt_files)} label files to process.")

    for src_path in tqdm(txt_files, desc="Converting labels"):
        # 使用临时文件确保操作的原子性（避免写一半失败导致文件损坏）
        temp_fd, temp_path = tempfile.mkstemp(dir=os.path.dirname(src_path))

        try:
            with os.fdopen(temp_fd, 'w') as temp_file:
                with open(src_path, 'r') as src_file:
                    converted_lines = []
                    for line in src_file:
                        converted_line = converter(line)
                        if converted_line:
                            converted_lines.append(converted_line)
                    temp_file.write("\n".join(converted_lines))

            # 确定最终目标路径
            if overwrite:
                dest_path = src_path
            else:
                relative_path = os.path.relpath(os.path.dirname(src_path), input_dir)
                dest_subdir = os.path.join(output_dir, relative_path)
                os.makedirs(dest_subdir, exist_ok=True)
                dest_path = os.path.join(dest_subdir, os.path.basename(src_path))

            # 将临时文件替换/移动到最终位置
            shutil.move(temp_path, dest_path)

        except Exception as e:
            print(f"\nError processing {src_path}: {e}")
            # 如果出错，删除临时文件
            os.remove(temp_path)

    print(f"\n✅ Conversion complete.")

def main():
    parser = argparse.ArgumentParser(description="Convert YOLO label formats between 'detect' and 'obb'.")
    parser.add_argument("mode", choices=['detect2obb', 'obb2detect'], help="Conversion mode.")
    parser.add_argument("--input-dir", required=True, help="Input directory containing label files.")
    parser.add_argument("--output-dir", help="Output directory. Required unless --overwrite is used.")
    parser.add_argument("--overwrite", action="store_true", help="Modify files in-place in the input directory.")
    parser.add_argument("-y", "--yes", action="store_true", help="Skip confirmation when using --overwrite.")
    parser.add_argument("--angle", type=float, default=0.0, help="Default angle for detect2obb conversion.")

    args = parser.parse_args()

    if args.overwrite and args.output_dir:
        parser.error("--output-dir cannot be used with --overwrite.")
    if not args.overwrite and not args.output_dir:
        parser.error("--output-dir is required unless --overwrite is used.")

    if not os.path.isdir(args.input_dir):
        print(f"Error: Input directory '{args.input_dir}' not found.")
        return

    process_directory(args.input_dir, args.output_dir, args.mode, args.angle, args.overwrite, args.yes)

if __name__ == "__main__":
    main()