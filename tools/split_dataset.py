import os
import random
import shutil
import argparse
from tqdm import tqdm

def split_dataset(source_dir, dest_dir, ratios=(0.8, 0.1, 0.1), copy_files=False):
    """
    将源数据集（图片和标签）按比例划分到训练、验证和测试集。

    Args:
        source_dir (str): 源数据目录，应包含 'images' 和 'labels' 子目录。
        dest_dir (str): 目标数据集目录，将在此创建 'train', 'val', 'test'。
        ratios (tuple): (train, val, test) 的比例，总和应为 1.0。
        copy_files (bool): 如果为 True，则复制文件；否则，移动文件。
    """
    if sum(ratios) != 1.0:
        raise ValueError("Ratios must sum to 1.0")

    train_ratio, val_ratio, test_ratio = ratios
    print(f"Splitting dataset with ratios: Train={train_ratio*100}%, Val={val_ratio*100}%, Test={test_ratio*100}%")
    action = "Copying" if copy_files else "Moving"
    print(f"Action: {action} files.")

    # 1. 定义源路径
    source_images_dir = os.path.join(source_dir, 'images')
    source_labels_dir = os.path.join(source_dir, 'labels')

    if not os.path.isdir(source_images_dir):
        print(f"Error: Source images directory not found at '{source_images_dir}'")
        return
    if not os.path.isdir(source_labels_dir):
        print(f"Warning: Source labels directory not found at '{source_labels_dir}'. Proceeding with images only.")

    # 2. 获取所有图片文件的基础名（不带扩展名）
    image_files = [os.path.splitext(f)[0] for f in os.listdir(source_images_dir) if os.path.splitext(f)[1].lower() in ['.jpg', '.jpeg', '.png']]
    if not image_files:
        print("No image files found in the source directory.")
        return

    # 打乱文件列表以确保随机分配
    random.shuffle(image_files)

    # 3. 计算每个集合的大小
    total_files = len(image_files)
    train_count = int(total_files * train_ratio)
    val_count = int(total_files * val_ratio)
    # 剩下的都给 test，避免因取整导致总数不匹配
    test_count = total_files - train_count - val_count

    # 4. 分配文件列表
    train_files = image_files[:train_count]
    val_files = image_files[train_count : train_count + val_count]
    test_files = image_files[train_count + val_count:]

    splits = {
        'train': train_files,
        'val': val_files,
        'test': test_files,
    }

    print(f"\nDataset split summary:")
    print(f"  Total files: {total_files}")
    print(f"  Training set: {len(train_files)} files")
    print(f"  Validation set: {len(val_files)} files")
    print(f"  Test set: {len(test_files)} files")

    # 5. 创建目标目录并移动/复制文件
    os.makedirs(dest_dir, exist_ok=True)

    file_op = shutil.copy2 if copy_files else shutil.move

    for split_name, file_list in splits.items():
        print(f"\nProcessing '{split_name}' set...")

        # 创建目标子目录
        dest_split_images_dir = os.path.join(dest_dir, split_name, 'images')
        dest_split_labels_dir = os.path.join(dest_dir, split_name, 'labels')
        os.makedirs(dest_split_images_dir, exist_ok=True)
        os.makedirs(dest_split_labels_dir, exist_ok=True)

        for base_name in tqdm(file_list, desc=f" {action} {split_name} files"):
            # 查找图片文件（可能后缀是.jpg, .png等）
            image_ext = None
            for ext in ['.jpg', '.jpeg', '.png']:
                if os.path.exists(os.path.join(source_images_dir, base_name + ext)):
                    image_ext = ext
                    break

            if image_ext:
                # 处理图片
                src_image_path = os.path.join(source_images_dir, base_name + image_ext)
                dest_image_path = os.path.join(dest_split_images_dir, base_name + image_ext)
                try:
                    file_op(src_image_path, dest_image_path)
                except Exception as e:
                    print(f"Error {action.lower()}ing {src_image_path} to {dest_image_path}: {e}")

                # 处理对应的标签文件
                src_label_path = os.path.join(source_labels_dir, base_name + '.txt')
                if os.path.exists(src_label_path):
                    dest_label_path = os.path.join(dest_split_labels_dir, base_name + '.txt')
                    try:
                        file_op(src_label_path, dest_label_path)
                    except Exception as e:
                        print(f"Error {action.lower()}ing {src_label_path} to {dest_label_path}: {e}")

    print("\n✅ Dataset splitting process completed successfully.")

def main():
    parser = argparse.ArgumentParser(description="Split a dataset into training, validation, and test sets.")
    parser.add_argument(
        "--source-dir",
        default="datas",
        help="Path to the source data directory (containing 'images' and 'labels'). Default: 'datas'"
    )
    parser.add_argument(
        "--dest-dir",
        default="datasets",
        help="Path to the destination directory where 'train', 'val', 'test' will be created. Default: 'datasets'"
    )
    parser.add_argument(
        "--ratios",
        type=float,
        nargs=3,
        metavar=('TRAIN', 'VAL', 'TEST'),
        default=[0.8, 0.1, 0.1],
        help="A tuple of ratios for train, val, test sets. Must sum to 1.0. Default: 0.8 0.1 0.1"
    )
    parser.add_argument(
        "--copy",
        action="store_true",
        help="Copy files instead of moving them. Leaves the source directory intact."
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducibility. Default: 42"
    )
    args = parser.parse_args()

    # 设置随机种子以保证每次划分结果一致
    random.seed(args.seed)

    split_dataset(args.source_dir, args.dest_dir, tuple(args.ratios), args.copy)

if __name__ == "__main__":
    main()