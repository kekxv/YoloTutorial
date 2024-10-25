mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(dir $(mkfile_path))

GPU_CONFIG=
ifeq ($(OS),Windows_NT)
 PLATFORM=win
 env_activate= .\env\Scripts\activate.bat
else
 env_activate= . env/bin/activate
 ifeq ($(shell uname),Darwin)
  #PLATFORM=MacOS
  GPU_CONFIG=device=mps
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
model=yolo11n.pt
# 配置文件，里面包含了 class
config_file=$(current_dir)datasets/data.yaml
# 图片大小
imgsz=320
# 训练的epochs，一般来说训练的越大，效果越好，但是也有例外的
epochs=1000
# 训练的结果文件夹，多次训练的文件夹不一样
train_dir=train

# batch
batch=-1
cos_lr=True
close_mosaic=10
crop_fraction=1.0
weight_decay=0.0005
# 识别的阈值
predict_conf=0.50
box=7.5 # 7.5
degrees=180 #180
flipud=1 # 0.0

weights_dir=$(current_dir)weights
datasets_dir=$(current_dir)datasets
runs_dir=$(current_dir)runs

TASK_ARGS=$(GPU_CONFIG) mode=train degrees=$(degrees) flipud=$(flipud) cos_lr=$(cos_lr) crop_fraction=$(crop_fraction) close_mosaic=$(close_mosaic) weight_decay=$(weight_decay) box=$(box) batch=$(batch) imgsz=$(imgsz)

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
	$(env_activate) && yolo task=$(task) $(TASK_ARGS) model=$(model) data=$(config_file) epochs=$(epochs)

# 继续训练
resume: update-config
	$(env_activate) && yolo task=$(task) $(TASK_ARGS) resume=True model=runs/$(task)/$(train_dir)/weights/last.pt data=$(config_file) epochs=$(epochs)

# 开始训练 epochs
train-10: update-config
	$(env_activate) &&  yolo task=$(task) $(TASK_ARGS) model=$(model) data=$(config_file) epochs=10

# 测试训练出来的模型
test: update-config
	$(env_activate) && yolo $(task) predict conf=$(predict_conf) crop_fraction=$(crop_fraction) close_mosaic=$(close_mosaic) model=runs/$(task)/$(train_dir)/weights/best.pt source=./datasets/test/images

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
	python3.9 -m venv env || python -m venv env || python3 -m venv env

# 启动分类标注工具
labelImg: datasets/train/labels/classes.txt
	$(env_activate) && labelImg datasets/train/images datasets/classes.txt datasets/train/labels/
# 启动分类标注工具
labelImg-val: datasets/val/labels/classes.txt
	$(env_activate) && labelImg datasets/val/images datasets/classes.txt datasets/val/labels/
# 启动分类标注工具
labelImg-test: datasets/test/labels/classes.txt
	$(env_activate) && labelImg datasets/test/images datasets/classes.txt datasets/test/labels/

datasets/test/labels/classes.txt: datasets/classes.txt
	cp datasets/classes.txt datasets/test/labels/classes.txt
datasets/train/labels/classes.txt: datasets/classes.txt
	cp datasets/classes.txt datasets/train/labels/classes.txt
datasets/val/labels/classes.txt: datasets/classes.txt
	cp datasets/classes.txt datasets/val/labels/classes.txt
# 分类的文件
datasets/classes.txt:
	echo "" > datasets/classes.txt
