import os
from ultralytics import YOLO

def train_yolov11():
    # Vérifier les arguments globaux
    global images_folder, labels_folder, output_model_path, yaml_path, epochs, learning_rate, batch_size, device

    print("Arguments received in Python:")
    print(f"Images folder: {images_folder}")
    print(f"Labels folder: {labels_folder}")
    print(f"Output model path: {output_model_path}")
    print(f"YAML path: {yaml_path}")
    print(f"Epochs: {epochs}")
    print(f"Learning rate: {learning_rate}")
    print(f"Batch size: {batch_size}")
    print(f"Device: {device}")

    # Vérifiez que les arguments sont corrects
    if not os.path.exists(images_folder):
        raise FileNotFoundError(f"Images folder does not exist: {images_folder}")
    if not os.path.exists(labels_folder):
        raise FileNotFoundError(f"Labels folder does not exist: {labels_folder}")
    if not os.path.exists(yaml_path):
        raise FileNotFoundError(f"YAML file does not exist: {yaml_path}")

   # Extract directory and file name from output_model_path
    output_dir = os.path.dirname(output_model_path)
    output_file = os.path.basename(output_model_path)

    model = YOLO('yolo11n-seg.pt')

    model.train(
        data=yaml_path,
        epochs=int(epochs),
        batch=int(batch_size),
        lr0=float(learning_rate),
        device=device
    )

    # Sauvegarder le modèle
    model.export(format='torchscript', export_dir=output_dir)
    print(f"Model saved to {os.path.join(output_dir, output_file)}")

# Appeler la fonction si ce script est exécuté
if __name__ == "__main__":
    train_yolov11()
