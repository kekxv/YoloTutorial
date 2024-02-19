mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(dir $(mkfile_path))

ifeq ($(OS),Windows_NT)
 PLATFORM=win
 env_activate= .\env\Scripts\activate.bat
else
 env_activate= . env/bin/activate
 ifeq ($(shell uname),Darwin)
  #PLATFORM=MacOS
  PLATFORM=unix
 else
  PLATFORM=unix
 endif
endif

# https://docs.ultralytics.com/zh/tasks/
# YOLOv8 是一个支持多种计算机视觉任务的人工智能框架。该框架可用于执行detection, segmentation, obb, classification, and pose estimation。每种任务都有不同的目标和用例。
# detect,segment,classify,pose,obb
task=detect
# 基础模型文件 yolov8n.pt 是最快的
model=yolov8n.pt
# 配置文件，里面包含了 class
config_file=$(current_dir)config.yaml
# 图片大小
imgsz=640
# 训练的epochs，一般来说训练的越大，效果越好，但是也有例外的
epochs=100
# 训练的结果文件夹，多次训练的文件夹不一样
train_dir=train

# batch
batch=-1
cos_lr=True
weight_decay=0.001
# 识别的阈值
predict_conf=0.50
box=5.0

weights_dir=$(current_dir)weights
datasets_dir=$(current_dir)datasets
runs_dir=$(current_dir)runs


all:
	@echo $(PLATFORM)

# 清理缓存
clean: clean-$(PLATFORM)

# 清理所有缓存
clean-all: clean-all-$(PLATFORM)

clean-unix:
	rm -rf ./runs/$(task)/predict*
	rm -rf ./runs/$(task)/val*

clean-all-unix: clean-unix
	rm -rf ./runs/$(task)/train*

clean-win:
	for /d %%i in (./runs/$(task)/predict*) do rd /S /Q "./runs/$(task)/%%i"
	for /d %%i in (./runs/$(task)/val*) do rd /S /Q "./runs/$(task)/%%i"
clean-all-win: clean-win
	for /d %%i in (./runs/$(task)/train*) do rd /S /Q "./runs/$(task)/%%i"

# 安装依赖
install-dev: env
	$(env_activate) && python -m pip install setuptools
	$(env_activate) && python -m pip install labelimg
	$(env_activate) && python -m pip install ultralytics
	$(env_activate) && python -m pip install -U ultralytics
	$(env_activate) && python -m pip install onnx

# 开始训练
train: update-config clean-all
	$(env_activate) && yolo task=$(task) mode=train cos_lr=$(cos_lr) weight_decay=$(weight_decay) box=$(box) model=$(model) data=$(config_file) batch=$(batch) imgsz=$(imgsz) epochs=$(epochs)

# 继续训练
resume: update-config
	$(env_activate) && yolo task=$(task) mode=train resume=True cos_lr=$(cos_lr) weight_decay=$(weight_decay) box=$(box) model=runs/$(task)/$(train_dir)/weights/last.pt data=$(config_file) batch=$(batch) imgsz=$(imgsz) epochs=$(epochs)

# 开始训练 epochs
train-10: update-config
	$(env_activate) &&  yolo task=$(task) mode=train cos_lr=$(cos_lr) weight_decay=$(weight_decay) box=$(box) model=$(model) data=$(config_file) batch=$(batch) imgsz=$(imgsz) epochs=10

# 测试训练出来的模型
test: update-config
	$(env_activate) && yolo $(task) predict conf=$(predict_conf) model=runs/$(task)/$(train_dir)/weights/best.pt source=./datasets/images/test

# 验证训练内容
val: update-config
	$(env_activate) && yolo $(task) val data=$(config_file) model=runs/$(task)/$(train_dir)/weights/best.pt imgsz=$(imgsz)

# 导出 onnx 模型
onnx: update-config
	$(env_activate) && yolo export model=runs/$(task)/$(train_dir)/weights/best.pt format=onnx
# 导出 ncnn 模型
ncnn: update-config
	$(env_activate) && yolo export model=runs/$(task)/$(train_dir)/weights/best.pt format=ncnn


update-config:
	$(env_activate) && yolo settings weights_dir=$(weights_dir) datasets_dir=$(datasets_dir) runs_dir=$(runs_dir)


# 创建虚拟环境
env:
	python3.9 -m venv env || python -m venv env

# 启动分类标注工具
labelImg: datasets/labels/train/classes.txt
	$(env_activate) && labelImg datasets/images/train datasets/labels/train/classes.txt datasets/labels/train/
# 启动分类标注工具
labelImg-val: datasets/labels/train/classes.txt
	$(env_activate) && labelImg datasets/images/val datasets/labels/train/classes.txt datasets/labels/val/
# 启动分类标注工具
labelImg-test: datasets/labels/train/classes.txt
	$(env_activate) && labelImg datasets/images/test datasets/labels/train/classes.txt datasets/labels/test/

# 分类的文件
datasets/labels/train/classes.txt:
	echo "" > datasets/labels/train/classes.txt
