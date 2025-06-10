import os
import hashlib
import argparse
import json
from collections import defaultdict
from tqdm import tqdm

def format_bytes(size):
    """将字节数格式化为可读的字符串 (KB, MB, GB)"""
    power = 1024
    n = 0
    power_labels = {0: '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
    while size > power and n < len(power_labels) -1 :
        size /= power
        n += 1
    return f"{size:.2f} {power_labels[n]}B"

def get_hashes(filepath, hash_algorithms=('md5', 'sha256')):
    """计算文件的哈希值"""
    hashes = {alg: hashlib.new(alg) for alg in hash_algorithms}
    try:
        with open(filepath, 'rb') as f:
            while chunk := f.read(8192):
                for h in hashes.values():
                    h.update(chunk)
        return {alg: h.hexdigest() for alg, h in hashes.items()}
    except (IOError, OSError) as e:
        print(f"Warning: Could not read file {filepath}: {e}")
        return None

def find_duplicate_files(directory):
    """在指定目录中查找重复文件。"""
    print(f"Scanning directory: {directory}")
    hashes_by_size = defaultdict(list)
    all_files = [os.path.join(root, f) for root, _, files in os.walk(directory) for f in files]

    print("Step 1/2: Grouping files by size...")
    for path in tqdm(all_files, desc="Sizing files"):
        try:
            size = os.path.getsize(path)
            hashes_by_size[size].append(path)
        except OSError as e:
            print(f"Warning: Could not access {path}: {e}")

    print("\nStep 2/2: Calculating hashes for potential duplicates...")
    hashes_map = defaultdict(list)
    potential_duplicates_paths = [path for paths in hashes_by_size.values() if len(paths) > 1 for path in paths]

    for path in tqdm(potential_duplicates_paths, desc="Hashing files"):
        file_hashes = get_hashes(path, ('md5',))
        if file_hashes:
            hashes_map[file_hashes['md5']].append(path)

    # 筛选出真正的重复文件
    duplicates = []
    for md5_hash, paths in hashes_map.items():
        if len(paths) > 1:
            # 按路径字母顺序排序，确保保留策略的一致性
            sorted_paths = sorted(paths)
            first_file_path = sorted_paths[0]

            # 为报告计算完整的哈希
            full_hashes = get_hashes(first_file_path, ('md5', 'sha256'))
            if full_hashes:
                duplicates.append({
                    "files_to_keep": [first_file_path],
                    "files_to_delete": sorted_paths[1:],
                    "hashes": full_hashes,
                    "size_bytes": os.path.getsize(first_file_path)
                })

    return duplicates

def main():
    parser = argparse.ArgumentParser(description="Find and optionally delete duplicate files in a directory.")
    parser.add_argument("directory", help="The directory to scan for duplicates.")
    parser.add_argument(
        "--delete",
        action="store_true",
        help="Enable deletion mode. Without this flag, the script only reports duplicates."
    )
    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        help="Skip interactive confirmation before deleting. Use with caution."
    )
    parser.add_argument(
        "--output",
        default="duplicates.json",
        help="Path to save the JSON report of duplicates found *before* deletion."
    )
    args = parser.parse_args()

    if not os.path.isdir(args.directory):
        print(f"Error: Directory not found at '{args.directory}'")
        return

    duplicate_sets = find_duplicate_files(args.directory)

    if not duplicate_sets:
        print("\n🎉 No duplicate files found.")
        return

    print(f"\nFound {len(duplicate_sets)} sets of duplicate files.")

    # 将找到的重复项写入报告文件
    with open(args.output, 'w') as f:
        json.dump(duplicate_sets, f, indent=4)
    print(f"A detailed report of duplicates has been saved to '{args.output}'.")

    if not args.delete:
        print("Run with the --delete flag to enable deletion.")
        return

    # --- DELETION LOGIC ---
    print("\n" + "="*50)
    print("🚨 WARNING: DELETION MODE ENABLED 🚨")
    print("="*50)

    total_files_to_delete = 0
    total_space_to_free = 0

    print("The following actions will be performed:")
    for item in duplicate_sets:
        print(f"\n  For set with hash (md5: {item['hashes']['md5'][:12]}...):")
        print(f"    [KEEP]   : {item['files_to_keep'][0]}")
        for f in item['files_to_delete']:
            print(f"    [DELETE] : {f}")
            total_files_to_delete += 1
            total_space_to_free += item['size_bytes']

    print("-" * 50)
    print(f"Summary: About to delete {total_files_to_delete} files and free up {format_bytes(total_space_to_free)}.")

    if not args.yes:
        try:
            confirm = input("Are you sure you want to proceed? (y/n): ")
        except (EOFError, KeyboardInterrupt):
            print("\nOperation cancelled by user.")
            return

        if confirm.lower() != 'y':
            print("Operation cancelled.")
            return

    print("\nProceeding with deletion...")
    deleted_count = 0
    for item in tqdm(duplicate_sets, desc="Deleting files"):
        for filepath in item['files_to_delete']:
            try:
                os.remove(filepath)
                deleted_count += 1
            except OSError as e:
                print(f"\nError deleting {filepath}: {e}")

    print(f"\n✅ Deletion complete. Successfully deleted {deleted_count} files.")


if __name__ == "__main__":
    main()