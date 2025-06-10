# ==============================================================================
#  YOLO MLOps Makefile
#  Author: kekxv
#  Description: A comprehensive Makefile for managing the YOLO training,
#               prediction, and deployment lifecycle.
# ==============================================================================

# ------------------------------------------------------------------------------
# I. CORE CONFIGURATION & ENVIRONMENT DETECTION
# ------------------------------------------------------------------------------
# Get the absolute path of the current directory
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(dir $(mkfile_path))

# Auto-detect Operating System and set environment activation command
GPU_CONFIG := device=cpu # Default to CPU
ifeq ($(OS),Windows_NT)
	PLATFORM       := win
	ENV_ACTIVATE   := .\env\Scripts\activate.bat
	PYTHON         := python
	ROLABELIMG_BIN := roLabelImg
	# On Windows, check for nvidia-smi in path
	ifneq (,$(shell where nvidia-smi 2>NUL))
		GPU_CONFIG := device=0
	endif
else
	PLATFORM       := unix
	ENV_ACTIVATE   := . env/bin/activate
	PYTHON         := python3
	ROLABELIMG_BIN := roLabelImg
	# Check for macOS and enable MPS device if available
	ifneq (,$(shell which nvidia-smi 2>/dev/null))
		# NVIDIA GPU detected
		GPU_CONFIG := device=0
	else ifeq ($(shell uname),Darwin)
		# No NVIDIA GPU, check for Apple Silicon (MPS)
		GPU_CONFIG := device=mps
	endif
endif

# ------------------------------------------------------------------------------
# II. PROJECT & MODEL PARAMETERS (Editable)
# ------------------------------------------------------------------------------
# --- Task and Model Settings ---
# Task type: detect, segment, classify, pose, obb
TASK          ?= detect
# --- 根据 TASK 自动选择基础模型 ---
# Base model for training. yolov8n.pt is the smallest and fastest.
ifeq ($(TASK),obb)
	BASE_MODEL ?= yolo11n-obb.pt
else
	BASE_MODEL ?= yolo11n.pt
endif
# Dataset configuration file
CONFIG_FILE   ?= $(CURRENT_DIR)config.yaml

# --- Training Hyperparameters ---
IMGSZ         ?= 320
EPOCHS        ?= 1000
BATCH         ?= -1  # -1 for auto-batch
COS_LR        ?= True
CLOSE_MOSAIC  ?= 10
CROP_FRACTION ?= 1.0
WEIGHT_DECAY  ?= 0.0005
DEGREES       ?= 180
FLIPUD        ?= 1.0
BOX           ?= 7.5

# --- Prediction & Export Settings ---
# Default model to use for prediction/validation/export is the best one from training
BEST_MODEL    ?= $(CURRENT_DIR)runs/$(TASK)/train/weights/best.pt
LAST_MODEL    ?= $(CURRENT_DIR)runs/$(TASK)/train/weights/last.pt
# Confidence threshold for CLI prediction
PREDICT_CONF  ?= 0.50
# --- Model Export Specific Settings (New & Improved) ---
EXPORT_MODEL  ?= $(BEST_MODEL)
EXPORT_IMGSZ  ?= $(IMGSZ)
EXPORT_ARGS   ?= half=False simplify=True  # Common export flags (e.g., half, int8, simplify)


# --- Prediction-to-File Script Settings (Your New Feature) ---
PREDICT_SCRIPT   ?= tools/predict_and_save.py
PREDICT_IMG_DIR  ?= $(CURRENT_DIR)datasets/test/images
PREDICT_LABEL_DIR?= $(CURRENT_DIR)datasets/test/labels
PREDICT_MODEL    ?= $(BEST_MODEL)
PREDICT_FILE_CONF?= 0.25 # Can use a different confidence for file generation

# ------------------------------------------------------------------------------
# III. DERIVED VARIABLES (Do not edit)
# ------------------------------------------------------------------------------
# Directories for Ultralytics settings
WEIGHTS_DIR  := $(CURRENT_DIR)weights
DATASETS_DIR := $(CURRENT_DIR)datasets
RUNS_DIR     := $(CURRENT_DIR)runs

# Combined arguments for training
TRAIN_ARGS = $(GPU_CONFIG) mode=train degrees=$(DEGREES) flipud=$(FLIPUD) cos_lr=$(COS_LR) \
             crop_fraction=$(CROP_FRACTION) close_mosaic=$(CLOSE_MOSAIC) \
             weight_decay=$(WEIGHT_DECAY) box=$(BOX) batch=$(BATCH) imgsz=$(IMGSZ)

# ==============================================================================
# IV. TARGETS
# ==============================================================================
.PHONY: all help default \
        install-dev env update-config \
        train resume train-10 \
        val predict-cli predict-to-file \
        export-onnx export-ncnn export-mnn \
        labelImg labelImg-val labelImg-test labelImg-datas \
        find-duplicates clean-duplicates clean-duplicates-dry-run rename-by-time rename-by-time-dry-run  \
        split-dataset split-dataset-copy \
        convert-labels-to-obb convert-labels-to-obb-overwrite \
        convert-labels-to-detect convert-labels-to-detect-overwrite \
        debug \
        clean clean-all

# Default target: Show help message
default: help

help:
	@echo "===================== YOLO Makefile Help ====================="
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "---------------------- Setup & Environment ---------------------"
	@echo "  help                      Show this help message."
	@echo "  env                       Create a Python virtual environment in './env'."
	@echo "  install-dev               Install all required Python dependencies."
	@echo "  update-config             Update Ultralytics settings (dirs)."
	@echo ""
	@echo "---------------------- Core Settings ---------------------------"
	@echo "  TASK              The main task type. Either 'detect' or 'obb'."
	@echo "                    (default: $(TASK))"
	@echo ""
	@echo "---------------------- Example Overrides -----------------------"
	@echo "  make train TASK=obb"
	@echo "  make predict-to-file TASK=obb PREDICT_IMG_DIR=./my_obb_images/"
	@echo ""
	@echo "---------------------- Training & Validation -------------------"
	@echo "  train                     Start a new training session."
	@echo "  resume                    Resume the last training session."
	@echo "  train-10                  Run a short training session for 10 epochs."
	@echo "  val                       Validate the best trained model."
	@echo ""
	@echo "---------------------- Prediction & Inference ------------------"
	@echo "  predict-cli               Run prediction on test images using YOLO CLI."
	@echo "  predict-to-file           Run prediction and save results as YOLO label files."
	@echo "                            (Uses predict_and_save.py script)"
	@echo ""
	@echo "---------------------- Model Export ----------------------------"
	@echo "  export-onnx               Export the model to ONNX format."
	@echo "  export-ncnn               Export the model to NCNN format."
	@echo "  export-mnn                Export the model to MNN format."
	@echo "    > Override with: EXPORT_MODEL=\$$$(LAST_MODEL) EXPORT_IMGSZ=640 half=True"
	@echo ""
	@echo "---------------------- Data Labeling ---------------------------"
	@echo "  labelImg                  Launch labelImg for the training set."
	@echo "  labelImg-val              Launch labelImg for the validation set."
	@echo "  labelImg-test             Launch labelImg for the test set."
	@echo "  labelImg-datas            Launch labelImg for the datas set."
	@echo ""
	@echo "---------------------- Cleanup ---------------------------------"
	@echo "  clean                     Remove prediction and validation run artifacts."
	@echo "  clean-all                 Remove all run artifacts, including training."
	@echo ""
	@echo "---------------------- Example Overrides -----------------------"
	@echo "  make train EPOCHS=50"
	@echo "  make predict-to-file 	   PREDICT_IMG_DIR=./new_images/ PREDICT_LABEL_DIR=./new_labels/"
	@echo "=================================================================="
	@echo ""
	@echo "---------------------- Data Utilities --------------------------"
	@echo "  split-dataset             Split data from 'datas' to 'datasets' (MOVE files)."
	@echo "  split-dataset-copy        Split data by COPYING files (safer)."
	@echo "                            > Ratios: SPLIT_RATIOS=$(subst_and_space,$(SPLIT_RATIOS))"
	@echo "  convert-labels-to-obb     Convert standard labels to OBB (saves to new dir)."
	@echo "  convert-labels-to-detect  Convert OBB labels to standard (saves to new dir)."
	@echo "  convert-labels-to-obb-overwrite    (DESTRUCTIVE!) Convert to OBB in-place."
	@echo "  convert-labels-to-detect-overwrite (DESTRUCTIVE!) Convert to standard in-place."
	@echo "                              > Target Dir: CONVERT_DIR=$(CONVERT_DIR)"
	@echo "  find-duplicates           Scan a directory for duplicate files (safe)."
	@echo "  clean-duplicates-dry-run  Show which duplicates would be deleted and ask for confirmation."
	@echo "  clean-duplicates          (DESTRUCTIVE!) Automatically find and delete duplicate files."
	@echo "                            > Uses --yes to run non-interactively."
	@echo "  rename-by-time            Batch rename files in a directory by modification time."
	@echo "  rename-by-time-dry-run    Show what rename-by-time would do without changing files."
	@echo "  > All utilities default to: UTIL_DIR=$(UTIL_DIR)"
	@echo ""
	@echo "---------------------- Example Overrides -----------------------"
	@echo "  make train EPOCHS=50"
	@echo "  make predict-to-file PREDICT_IMG_DIR=./new_images/ PREDICT_LABEL_DIR=./new_labels/"
	@echo "  make find-duplicates UTIL_DIR=./my_downloads/"
	@echo "=================================================================="


debug:
	@echo "Detected Platform: $(PLATFORM)"
	@echo "GPU Configuration: $(GPU_CONFIG)"

# ------------------------------------------------------------------------------
# Environment and Setup
# ------------------------------------------------------------------------------
env:
	$(PYTHON) -m venv env

install-dev: env
	$(ENV_ACTIVATE) &&  python3 --version
	$(ENV_ACTIVATE) && pip install --upgrade pip
	$(ENV_ACTIVATE) && pip install labelimg ultralytics onnx "tqdm>=4.66.1"
	# ❗️修改为从 GitHub 安装 roLabelImg
	@echo "Installing roLabelImg from GitHub..."
	$(ENV_ACTIVATE) && $(PYTHON) -m pip install --no-cache-dir git+https://github.com/kekxv/roLabelImg.git

update-config: env
	$(ENV_ACTIVATE) && yolo settings weights_dir=$(WEIGHTS_DIR) datasets_dir=$(DATASETS_DIR) runs_dir=$(RUNS_DIR)

# ------------------------------------------------------------------------------
# Training and Validation
# ------------------------------------------------------------------------------
train: update-config
	@echo "yolo task=$(TASK) $(TRAIN_ARGS) model=$(BASE_MODEL) data=$(CONFIG_FILE) epochs=$(EPOCHS)"
	$(ENV_ACTIVATE) && yolo task=$(TASK) $(TRAIN_ARGS) model=$(BASE_MODEL) data=$(CONFIG_FILE) epochs=$(EPOCHS)

resume: update-config
	$(ENV_ACTIVATE) && yolo task=$(TASK) $(TRAIN_ARGS) resume=True model=$(LAST_MODEL) data=$(CONFIG_FILE) epochs=$(EPOCHS)

train-10:
	make train EPOCHS=10

val: update-config
	@echo "Validating model: $(BEST_MODEL)"
	$(ENV_ACTIVATE) && yolo $(TASK) val data=$(CONFIG_FILE) model=$(BEST_MODEL) imgsz=$(IMGSZ)

# ------------------------------------------------------------------------------
# Prediction (renamed 'test' to 'predict-cli' for clarity)
# ------------------------------------------------------------------------------
predict-cli: update-config
	@echo "Running CLI prediction with model: $(BEST_MODEL)"
	$(ENV_ACTIVATE) && yolo $(TASK) predict conf=$(PREDICT_CONF) model=$(BEST_MODEL) source=$(DATASETS_DIR)

# --- YOUR NEW TARGET ---
predict-to-file: update-config
	@echo "Running prediction script to generate label files..."
	@echo "  > Task:     $(TASK)"
	@echo "  > Model:    $(PREDICT_MODEL)"
	@echo "  > Images:   $(PREDICT_IMG_DIR)"
	@echo "  > Labels:   $(PREDICT_LABEL_DIR)"
	@echo "  > Conf:     $(PREDICT_FILE_CONF)"
	# ❗️给脚本传递 --task 参数
	$(ENV_ACTIVATE) && $(PYTHON) $(PREDICT_SCRIPT) \
		--model "$(PREDICT_MODEL)" \
		--image-dir "$(PREDICT_IMG_DIR)" \
		--label-dir "$(PREDICT_LABEL_DIR)" \
		--conf $(PREDICT_FILE_CONF) \
		--task $(TASK)

# ==============================================================================
# V. DATA UTILITY TARGETS (新添加的部分)
# ==============================================================================
# --- Data Utility Parameters ---
# Directory for data utility tasks like finding duplicates or renaming
UTIL_DIR ?= $(DATASETS_DIR)/train/images
# Source directory for raw data
RAW_DATA_DIR ?= datas
# Destination for processed datasets
PROCESSED_DATA_DIR ?= datasets
# Ratios for splitting
SPLIT_RATIOS ?= 0.8 0.1 0.1
# Random seed for splitting
SPLIT_SEED ?= 42
# --- Label Conversion Parameters ---
CONVERT_DIR ?= datasets
CONVERT_DEST_DIR ?= datasets-converted


# --- Label Format Conversion ---
# --- 安全的、非覆盖的转换 ---
convert-labels-to-obb:
	@echo "🔄 Converting labels from Detect -> OBB (to new directory)"
	@echo "  Source:      $(CONVERT_DIR)"
	@echo "  Destination: $(CONVERT_DEST_DIR)"
	$(ENV_ACTIVATE) && $(PYTHON) tools/convert_labels.py detect2obb \
		--input-dir "$(CONVERT_DIR)" \
		--output-dir "$(CONVERT_DEST_DIR)"

convert-labels-to-detect:
	@echo "🔄 Converting labels from OBB -> Detect (to new directory)"
	@echo "  Source:      $(CONVERT_DIR)"
	@echo "  Destination: $(CONVERT_DEST_DIR)"
	$(ENV_ACTIVATE) && $(PYTHON) tools/convert_labels.py obb2detect \
		--input-dir "$(CONVERT_DIR)" \
		--output-dir "$(CONVERT_DEST_DIR)"

# --- 破坏性的、覆盖的转换 ---
convert-labels-to-obb-overwrite:
	@echo "🚨 WARNING: Overwriting labels in-place: Detect -> OBB"
	@echo "  Target Directory: $(CONVERT_DIR)"
	@echo "  This action is IRREVERSIBLE. It will run automatically in 5 seconds."
	@sleep 5
	$(ENV_ACTIVATE) && $(PYTHON) tools/convert_labels.py detect2obb \
		--input-dir "$(CONVERT_DIR)" \
		--overwrite --yes

convert-labels-to-detect-overwrite:
	@echo "🚨 WARNING: Overwriting labels in-place: OBB -> Detect"
	@echo "  Target Directory: $(CONVERT_DIR)"
	@echo "  This action is IRREVERSIBLE. It will run automatically in 5 seconds."
	@sleep 5
	$(ENV_ACTIVATE) && $(PYTHON) tools/convert_labels.py obb2detect \
		--input-dir "$(CONVERT_DIR)" \
		--overwrite --yes

convert-labels-xywhr-to-4points-overwrite:
	@echo "  Target Directory: $(CONVERT_DIR)"
	@echo "  This action is IRREVERSIBLE. It will run automatically in 5 seconds."
	@sleep 5
	$(ENV_ACTIVATE) && $(PYTHON) tools/convert_labels_xywhr_to_4points.py \
		--input-dir "$(CONVERT_DIR)" \
		--overwrite


# --- Dataset Splitting ---
split-dataset:
	@echo "🔀 Splitting dataset from '$(RAW_DATA_DIR)' to '$(PROCESSED_DATA_DIR)'..."
	@echo "⚠️  This will MOVE files from the source directory."
	@echo "To keep original files, use 'make split-dataset-copy'."
	$(ENV_ACTIVATE) && $(PYTHON) tools/split_dataset.py \
		--source-dir "$(RAW_DATA_DIR)" \
		--dest-dir "$(PROCESSED_DATA_DIR)" \
		--ratios $(SPLIT_RATIOS) \
		--seed $(SPLIT_SEED)

split-dataset-copy:
	@echo "📋 Splitting dataset by COPYING from '$(RAW_DATA_DIR)' to '$(PROCESSED_DATA_DIR)'..."
	@echo "Original files in '$(RAW_DATA_DIR)' will be preserved."
	$(ENV_ACTIVATE) && $(PYTHON) tools/split_dataset.py \
		--source-dir "$(RAW_DATA_DIR)" \
		--dest-dir "$(PROCESSED_DATA_DIR)" \
		--ratios $(SPLIT_RATIOS) \
		--seed $(SPLIT_SEED) \
		--copy

# --- Find Duplicates ---
find-duplicates: env
	@echo "🔍 Finding duplicate files in: $(UTIL_DIR)"
	@echo "Report will be saved to 'duplicates.json'"
	$(ENV_ACTIVATE) && $(PYTHON) tools/find_duplicates.py "$(UTIL_DIR)"

clean-duplicates-dry-run:
	@echo "🧪 [Dry Run] Simulating duplicate file deletion in: $(UTIL_DIR)"
	@echo "The script will list files to be deleted and ask for confirmation."
	@echo "You can safely answer 'n' to cancel."
	$(ENV_ACTIVATE) && $(PYTHON) tools/find_duplicates.py --delete "$(UTIL_DIR)"

clean-duplicates:
	@echo ""
	@echo "❗️❗️❗️ WARNING: DESTRUCTIVE ACTION ❗️❗️❗️"
	@echo "This command will PERMANENTLY DELETE duplicate files in: $(UTIL_DIR)"
	@echo "It is highly recommended to run 'make clean-duplicates-dry-run' first."
	@echo "Proceeding automatically in 5 seconds... (Press Ctrl+C to cancel)"
	@sleep 5
	$(ENV_ACTIVATE) && $(PYTHON) tools/find_duplicates.py --delete --yes "$(UTIL_DIR)"
	@echo "✅ Duplicate cleanup process finished."

# --- Batch Rename ---
rename-by-time: env
	@echo "⏳ Batch renaming files by modification time in: $(UTIL_DIR)"
	$(ENV_ACTIVATE) && $(PYTHON) tools/batch_rename.py "$(UTIL_DIR)"

rename-by-time-dry-run: env
	@echo "🧪 [Dry Run] Simulating batch rename for: $(UTIL_DIR)"
	$(ENV_ACTIVATE) && $(PYTHON) tools/batch_rename.py --dry-run "$(UTIL_DIR)"

# ==============================================================================
# VI. MODEL EXPORT (Refactored for flexibility and OBB/MNN support)
# ==============================================================================
# This section has been optimized. You can now easily override the export
# model and parameters. e.g.:
# make export-onnx EXPORT_MODEL=$(LAST_MODEL) EXPORT_IMGSZ=640 half=True

export-onnx: update-config
	@echo "🚀 Exporting model to ONNX format..."
	@echo "  - Task:   $(TASK)"
	@echo "  - Model:  $(EXPORT_MODEL)"
	@echo "  - ImgSz:  $(EXPORT_IMGSZ)"
	@echo "  - Args:   $(EXPORT_ARGS)"
	$(ENV_ACTIVATE) && yolo export model=$(EXPORT_MODEL) task=$(TASK) format=onnx imgsz=$(EXPORT_IMGSZ) $(EXPORT_ARGS)

export-ncnn: update-config
	@echo "🚀 Exporting model to NCNN format..."
	@echo "  - Task:   $(TASK)"
	@echo "  - Model:  $(EXPORT_MODEL)"
	@echo "  - ImgSz:  $(EXPORT_IMGSZ)"
	@echo "  - Args:   $(EXPORT_ARGS)"
	$(ENV_ACTIVATE) && yolo export model=$(EXPORT_MODEL) task=$(TASK) format=ncnn imgsz=$(EXPORT_IMGSZ) $(EXPORT_ARGS)

export-mnn: update-config
	@echo "🚀 Exporting model to MNN format..."
	@echo "  - Task:   $(TASK)"
	@echo "  - Model:  $(EXPORT_MODEL)"
	@echo "  - ImgSz:  $(EXPORT_IMGSZ)"
	@echo "  - Args:   $(EXPORT_ARGS)"
	$(ENV_ACTIVATE) && yolo export model=$(EXPORT_MODEL) task=$(TASK) format=mnn imgsz=$(EXPORT_IMGSZ) $(EXPORT_ARGS)

# ------------------------------------------------------------------------------
# VII. DATA LABELING HELPERS
# ------------------------------------------------------------------------------
labelImg: datasets/train/labels/classes.txt env
	$(ENV_ACTIVATE) && labelImg datasets/train/images datas/classes.txt datasets/train/labels/

labelImg-val: datasets/val/labels/classes.txt env
	$(ENV_ACTIVATE) && labelImg datasets/val/images datas/classes.txt datasets/val/labels/

labelImg-test: datasets/test/labels/classes.txt env
	$(ENV_ACTIVATE) && labelImg datasets/test/images datas/classes.txt datasets/test/labels/

labelImg-datas: env
	$(ENV_ACTIVATE) && labelImg datas/images datas/classes.txt datas/labels/

labelImgOBB: datasets/train/labels/classes.txt env
	$(ENV_ACTIVATE) && $(ROLABELIMG_BIN) $(CURRENT_DIR)datasets/train/images $(CURRENT_DIR)datas/classes.txt $(CURRENT_DIR)datasets/train/labels

labelImgOBB-val: datasets/val/labels/classes.txt env
	$(ENV_ACTIVATE) && $(ROLABELIMG_BIN) $(CURRENT_DIR)datasets/val/images $(CURRENT_DIR)datas/classes.txt $(CURRENT_DIR)datasets/val/labels

labelImgOBB-test: datasets/test/labels/classes.txt env
	$(ENV_ACTIVATE) && $(ROLABELIMG_BIN) $(CURRENT_DIR)datasets/test/images $(CURRENT_DIR)datas/classes.txt $(CURRENT_DIR)datasets/test/labels

labelImgOBB-datas: env
	$(ENV_ACTIVATE) && $(ROLABELIMG_BIN) $(CURRENT_DIR)datas/images $(CURRENT_DIR)datas/classes.txt $(CURRENT_DIR)datas/labels

datasets/test/labels/classes.txt: datas/classes.txt
	cp $< $@
datasets/train/labels/classes.txt: datas/classes.txt
	cp $< $@
datasets/val/labels/classes.txt: datas/classes.txt
	cp $< $@

# ------------------------------------------------------------------------------
# VIII. CLEANUP (Refactored for simplicity)
# ------------------------------------------------------------------------------
clean:
	@echo "Cleaning prediction and validation artifacts in $(RUNS_DIR)/$(TASK)..."
ifeq ($(PLATFORM), win)
	if exist "$(RUNS_DIR)\$(TASK)\predict*" (for /d %%i in ("$(RUNS_DIR)\$(TASK)\predict*") do rd /S /Q "%%i")
	if exist "$(RUNS_DIR)\$(TASK)\val*" (for /d %%i in ("$(RUNS_DIR)\$(TASK)\val*") do rd /S /Q "%%i")
else
	rm -rf $(RUNS_DIR)/$(TASK)/predict*
	rm -rf $(RUNS_DIR)/$(TASK)/val*
endif
	@echo "Cleanup of temporary runs complete."

clean-all: clean
	@echo "Cleaning all training artifacts in $(RUNS_DIR)/$(TASK)..."
ifeq ($(PLATFORM), win)
	if exist "$(RUNS_DIR)\$(TASK)\train*" (for /d %%i in ("$(RUNS_DIR)\$(TASK)\train*") do rd /S /Q "%%i")
else
	rm -rf $(RUNS_DIR)/$(TASK)/train*
endif
	@echo "Full cleanup complete."