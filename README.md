# YOLOv8 训练自己的数据

## YOLO:简史

`YOLO(You Only Look Once）`是一种流行的物体检测和图像分割模型，由`华盛顿大学`的`约瑟夫-雷德蒙（Joseph Redmon）`
和`阿里-法哈迪（Ali Farhadi）`开发。`YOLO` 于 `2015` 年推出，因其高速度和高精确度而迅速受到欢迎。

- `2016` 年发布的`YOLOv2` 通过纳入`批量归一化`、`锚框`和`维度集群`改进了原始模型。
- `2018` 年推出的`YOLOv3` 使用`更高效的骨干网络`、`多锚和空间金字塔池`进一步增强了模型的性能。
- `YOLOv4`于 `2020` 年发布，引入了 `Mosaic` 数据增强、新的`无锚检测头`和新的`损失函数`等创新技术。
- `YOLOv5`进一步提高了模型的性能，并增加了超参数优化、集成实验跟踪和自动导出为常用导出格式等新功能。
- `YOLOv6`于 `2022` 年由`美团`开源，目前已用于该公司的许多自主配送机器人。
- `YOLOv7`增加了额外的任务，如 `COCO` 关键点数据集的姿势估计。
- `YOLOv8`是`YOLO` 的最新`(20240206)`版本，由`Ultralytics` 提供。`YOLOv8` 支持全方位的视觉 AI
  任务，包括`检测`、`分割`、`姿态估计`、`跟踪`和`分类`。这种多功能性使用户能够在各种应用和领域中利用`YOLOv8`的功能。

更多的资料可以查看：[https://docs.ultralytics.com/zh/](https://docs.ultralytics.com/zh/)

## 关于 Makefile

`Makefile` 一般用于`c`的编译辅助，但是它不只是可以用于编译，它的目标规则特性，可以让用来做一些其他的事情：

- `make clean` 清理缓存
- `make clean-all` 清理所有缓存，包括训练数据
- `make install-dev` 安装依赖
- `make train` 开始训练
- `make test` 测试 `image/test` 文件夹的识别结果
- `make val` 验证
- `make onnx` 导出 `onnx` 模型，其他的 `ncnn`以及`mnn`可以通过`onnx`模型转换
- `make env` 创建虚拟环境
- `make labelImg` 启动分类标注工具

可以查看 `Makefile`文件以及官方文档，手动使用 `cli` 进行训练等操作

## 开始准备


## 额外说明

### 关于 `labelImg`

`labelImg` 需要使用 `python3.9` 的版本，其他版本会有`bug`，无法保存

### 关于安装：

```shell
make install-dev
```

### 激活虚拟环境

```shell
. env/bin/activate
```

### 退出虚拟环境

```shell
deactivate
```

### 训练：

```shell
yolo task=detect mode=train model=yolov8n.pt data=config.yaml batch=-1 imgsz=640 epochs=100
```

## 相关文档

`yolov8` 文档
https://docs.ultralytics.com/zh/quickstart/

在线转换模型类型：
https://convertmodel.com
