cos_lr=True
weight_decay=0.001
box=5.0
# 基础模型文件 yolov8n.pt 是最快的
model=yolov8n.pt
# 配置文件，里面包含了 class
config_file=config.yaml
# batch
batch=-1
# 图片大小
imgsz=640
# 训练的epochs，一般来说训练的越大，效果越好，但是也有例外的
epochs=100
# 训练的结果文件夹，多次训练的文件夹不一样
train_dir=train

all:

# 清理缓存
clean:
	rm -rf ./runs/detect/predict*
	rm -rf ./runs/detect/val*

# 清理所有缓存
clean-all: clean
	rm -rf ./runs/detect/train*

# 安装依赖
install-dev: env
	. env/bin/activate
	python -m pip install labelimg
	python -m pip install ultralytics
	python -m pip install onnx

# 开始训练
train:
	. env/bin/activate
	#rm -rf ./runs/detect/train*
    # 根据自己的情况修改对应的参数
	yolo task=detect mode=train cos_lr=$(cos_lr) weight_decay=$(weight_decay) box=$(box) model=$(model) data=$(config_file) batch=$(batch) imgsz=$(imgsz) epochs=$(epochs)

# 开始训练 epochs
train-10:
	. env/bin/activate
    # 根据自己的情况修改对应的参数
	yolo task=detect mode=train cos_lr=$(cos_lr) weight_decay=$(weight_decay) box=$(box) model=$(model) data=$(config_file) batch=$(batch) imgsz=$(imgsz) epochs=10

# 测试训练出来的模型
test:
	. env/bin/activate
	yolo detect predict model=runs/detect/$(train_dir)/weights/best.pt source=./datasets/images/test

# 验证训练内容
val:
	. env/bin/activate
	yolo detect val data=config.yaml model=runs/detect/$(train_dir)/weights/best.pt imgsz=$(imgsz)  # val custom model

# 导出 onnx 模型
onnx:
	. env/bin/activate
	yolo export model=runs/detect/$(train_dir)/weights/best.pt format=onnx

# 创建虚拟环境
env:
	python3.9 -m venv env || python -m venv env

# 启动分类标注工具
labelImg: datasets/labels/train/classes.txt
	labelImg datasets/images/train datasets/labels/train/classes.txt datasets/labels/train/
# 启动分类标注工具
labelImg-val: datasets/labels/train/classes.txt
	labelImg datasets/images/val datasets/labels/train/classes.txt datasets/labels/val/
# 启动分类标注工具
labelImg-test: datasets/labels/train/classes.txt
	labelImg datasets/images/test datasets/labels/train/classes.txt datasets/labels/test/

# 分类的文件
datasets/labels/train/classes.txt:
	touch datasets/labels/train/classes.txt
