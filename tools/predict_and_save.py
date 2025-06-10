import os
import argparse
from ultralytics import YOLO
from tqdm import tqdm

def run_inference(model_path, image_dir, label_dir, conf_threshold, task_type='detect'):
    """
    使用 YOLO 模型对图片进行推理，并将结果以 YOLO 格式保存到标签文件中。
    支持 'detect' (标准) 和 'obb' (旋转) 任务。

    输出格式:
    - 'detect' 任务: class_id x_center y_center width height
    - 'obb' 任务: class_id x1 y1 x2 y2 x3 y3 x4 y4 (归一化的四个角点)

    Args:
        model_path (str): 预训练的 YOLO 模型文件路径 (.pt 文件)。
        image_dir (str): 包含输入图片的文件夹路径。
        label_dir (str): 用于保存输出标签文件 (.txt) 的文件夹路径。
        conf_threshold (float): 用于过滤检测结果的置信度阈值。
        task_type (str): 任务类型, 'detect' 或 'obb'。
    """
    # 1. 加载 YOLO 模型
    print(f"正在加载模型: {model_path} (任务类型: {task_type})")
    try:
        model = YOLO(model_path)
    except Exception as e:
        print(f"错误: 无法加载模型。请确保路径正确且文件未损坏。")
        print(e)
        return

    # 2. 确保输出目录存在
    os.makedirs(label_dir, exist_ok=True)
    print(f"标签将保存至: {label_dir}")

    # 3. 获取所有支持的图片文件
    supported_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.tiff']
    image_files = [f for f in os.listdir(image_dir) if os.path.splitext(f)[1].lower() in supported_extensions]

    if not image_files:
        print(f"警告: 在目录 '{image_dir}' 中没有找到支持的图片文件。")
        return

    print(f"找到 {len(image_files)} 张图片，开始处理...")

    # 4. 遍历所有图片并进行推理
    for image_name in tqdm(image_files, desc="Processing images"):
        image_path = os.path.join(image_dir, image_name)
        results = model.predict(image_path, conf=conf_threshold, verbose=False)
        result = results[0]

        yolo_lines = []

        # 根据任务类型选择不同的处理逻辑
        if task_type == 'obb' and result.obb is not None:
            # --- OBB 任务处理逻辑 (已修改为输出四个点位) ---
            for obb in result.obb:
                class_id = int(obb.cls[0])
                # 使用 .xyxyxyn 属性直接获取归一化后的四个角点坐标
                # 格式为 [x1, y1, x2, y2, x3, y3, x4, y4]
                points = obb.xyxyxyn[0].tolist()

                # 将所有点位坐标格式化为字符串，保留6位小数
                points_str = " ".join([f"{p:.6f}" for p in points])

                # 组合成最终的行: class_id x1 y1 x2 y2 x3 y3 x4 y4
                line = f"{class_id} {points_str}"
                yolo_lines.append(line)

        elif task_type == 'detect' and result.boxes is not None:
            # --- 标准检测任务处理逻辑 (已修复classid重复的bug) ---
            # result.boxes.xywhn 直接提供了归一化的 [x_center, y_center, width, height]
            for box in result.boxes:
                class_id = int(box.cls[0])
                x_center, y_center, width, height = box.xywhn[0].tolist()
                # 修正: 原脚本中 class_id 写了两次，这里修复为正确的格式
                line = f"{class_id} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}"
                yolo_lines.append(line)

        # 如果检测到了物体，则生成标签文件
        if yolo_lines:
            base_name = os.path.splitext(image_name)[0]
            label_path = os.path.join(label_dir, f"{base_name}.txt")
            with open(label_path, 'w') as f:
                f.write("\n".join(yolo_lines))

    print("处理完成！")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="使用YOLO模型进行推理并以YOLO格式保存标签")
    parser.add_argument('--model', type=str, required=True, help="YOLO 模型文件的路径")
    parser.add_argument('--image-dir', type=str, required=True, help="包含输入图片的文件夹路径")
    parser.add_argument('--label-dir', type=str, required=True, help="用于保存输出标签文件的文件夹路径")
    parser.add_argument('--conf', type=float, default=0.25, help="目标检测的置信度阈值")
    # 新增 task 参数
    parser.add_argument(
        '--task',
        type=str,
        default='detect',
        choices=['detect', 'obb'],
        help="任务类型: 'detect' 用于标准边界框, 'obb' 用于旋转边界框。"
    )
    args = parser.parse_args()

    run_inference(args.model, args.image_dir, args.label_dir, args.conf, args.task)