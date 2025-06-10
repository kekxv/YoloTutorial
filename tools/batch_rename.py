import os
import argparse
from datetime import datetime
from tqdm import tqdm

def batch_rename_by_time(directory, dry_run=False):
    """
    按修改时间对目录中的文件进行批量重命名。
    新名称格式: YYYYMMDDHHMMSSNNN.ext

    Args:
        directory (str): 要处理的目录。
        dry_run (bool): 如果为 True，则只打印将要执行的操作，不实际重命名。
    """
    print(f"Scanning directory: {directory}")

    # 1. 获取所有文件及其修改时间
    files_to_rename = []
    supported_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp']

    for filename in os.listdir(directory):
        filepath = os.path.join(directory, filename)
        ext = os.path.splitext(filename)[1].lower()

        if os.path.isfile(filepath) and ext in supported_extensions:
            try:
                mtime = os.path.getmtime(filepath)
                files_to_rename.append((mtime, filepath))
            except OSError as e:
                print(f"Warning: Could not access {filepath}: {e}")

    if not files_to_rename:
        print("No supported image files found to rename.")
        return

    # 2. 按修改时间排序
    files_to_rename.sort()

    print(f"Found {len(files_to_rename)} files to rename. Starting process...")

    # 3. 执行重命名
    rename_plan = []
    last_timestamp_str = ""
    sequence = 1

    for mtime, old_path in files_to_rename:
        dt_object = datetime.fromtimestamp(mtime)
        timestamp_str = dt_object.strftime("%Y%m%d%H%M%S")

        # 处理时间戳冲突
        if timestamp_str == last_timestamp_str:
            sequence += 1
        else:
            sequence = 1

        last_timestamp_str = timestamp_str

        ext = os.path.splitext(old_path)[1]
        new_name = f"{timestamp_str}{sequence:03d}{ext}"
        new_path = os.path.join(directory, new_name)

        # 确保新文件名不与现有文件冲突（除了它自己）
        counter = 1
        final_new_path = new_path
        while os.path.exists(final_new_path) and final_new_path != old_path:
            counter += 1
            new_name = f"{timestamp_str}{sequence:03d}_{counter}{ext}"
            final_new_path = os.path.join(directory, new_name)

        rename_plan.append((old_path, final_new_path))

    # 4. 应用重命名计划
    if dry_run:
        print("\n--- Dry Run Mode ---")
        print("The following renames would be performed:")
        for old, new in rename_plan:
            if old != new:
                print(f"'{os.path.basename(old)}' -> '{os.path.basename(new)}'")
            else:
                print(f"'{os.path.basename(old)}' -> (no change)")
    else:
        print("\nApplying renames...")
        for old, new in tqdm(rename_plan, desc="Renaming"):
            if old != new:
                try:
                    os.rename(old, new)
                except OSError as e:
                    print(f"Error renaming '{old}' to '{new}': {e}")
        print("Batch rename completed.")


def main():
    parser = argparse.ArgumentParser(description="Batch rename files in a directory based on their modification time.")
    parser.add_argument("directory", help="The directory containing files to rename.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be renamed without actually performing the rename."
    )
    args = parser.parse_args()

    if not os.path.isdir(args.directory):
        print(f"Error: Directory not found at '{args.directory}'")
        return

    batch_rename_by_time(args.directory, args.dry_run)

if __name__ == "__main__":
    main()