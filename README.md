# YOLO (ultralytics) 训练自己的数据

use `Makefile` to run the training process.

```
===================== YOLO Makefile Help =====================
Usage: make [target] [VARIABLE=value]

---------------------- Setup & Environment ---------------------
  help                      Show this help message.
  env                       Create a Python virtual environment in './env'.
  install-dev               Install all required Python dependencies.
  update-config             Update Ultralytics settings (dirs).

---------------------- Core Settings ---------------------------
  TASK              The main task type. Either 'detect' or 'obb'.
                    (default: detect)

---------------------- Example Overrides -----------------------
  make train TASK=obb
  make predict-to-file TASK=obb PREDICT_IMG_DIR=./my_obb_images/

---------------------- Training & Validation -------------------
  train                     Start a new training session.
  resume                    Resume the last training session.
  train-10                  Run a short training session for 10 epochs.
  val                       Validate the best trained model.

---------------------- Prediction & Inference ------------------
  predict-cli               Run prediction on test images using YOLO CLI.
  predict-to-file           Run prediction and save results as YOLO label files.
                            (Uses predict_and_save.py script)

---------------------- Model Export ----------------------------
  export-onnx               Export the model to ONNX format.
  export-ncnn               Export the model to NCNN format.
  export-mnn                Export the model to MNN format.
    > Override with: EXPORT_MODEL=$/Volumes/work/yolo/yolov8project/runs/detect/train/weights/last.pt EXPORT_IMGSZ=640 half=True

---------------------- Data Labeling ---------------------------
  labelImg                  Launch labelImg for the training set.
  labelImg-val              Launch labelImg for the validation set.
  labelImg-test             Launch labelImg for the test set.
  labelImg-datas            Launch labelImg for the datas set.

---------------------- Cleanup ---------------------------------
  clean                     Remove prediction and validation run artifacts.
  clean-all                 Remove all run artifacts, including training.

---------------------- Example Overrides -----------------------
  make train EPOCHS=50
  make predict-to-file     PREDICT_IMG_DIR=./new_images/ PREDICT_LABEL_DIR=./new_labels/
==================================================================

---------------------- Data Utilities --------------------------
  split-dataset             Split data from 'datas' to 'datasets' (MOVE files).
  split-dataset-copy        Split data by COPYING files (safer).
                            > Ratios: SPLIT_RATIOS=
  convert-labels-to-obb     Convert standard labels to OBB (saves to new dir).
  convert-labels-to-detect  Convert OBB labels to standard (saves to new dir).
  convert-labels-to-obb-overwrite    (DESTRUCTIVE!) Convert to OBB in-place.
  convert-labels-to-detect-overwrite (DESTRUCTIVE!) Convert to standard in-place.
                              > Target Dir: CONVERT_DIR=datasets
  find-duplicates           Scan a directory for duplicate files (safe).
  clean-duplicates-dry-run  Show which duplicates would be deleted and ask for confirmation.
  clean-duplicates          (DESTRUCTIVE!) Automatically find and delete duplicate files.
                            > Uses --yes to run non-interactively.
  rename-by-time            Batch rename files in a directory by modification time.
  rename-by-time-dry-run    Show what rename-by-time would do without changing files.
  > All utilities default to: UTIL_DIR=/Volumes/work/yolo/yolov8project/datasets/train/images

---------------------- Example Overrides -----------------------
  make train EPOCHS=50
  make predict-to-file PREDICT_IMG_DIR=./new_images/ PREDICT_LABEL_DIR=./new_labels/
  make find-duplicates UTIL_DIR=./my_downloads/
==================================================================
```