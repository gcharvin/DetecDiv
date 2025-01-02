import h5py
import numpy as np

def export_yolo_results_to_hdf5(results, output_hdf5_path):
    """
    Exporte les résultats YOLO dans un fichier HDF5.

    Args:
        results (list): Liste d'objets `Results` retournés par YOLO.
        output_hdf5_path (str): Chemin du fichier HDF5 à sauvegarder.
    """

    print(f"Export HDF5 appelé avec {len(results)} résultats.")  # Log de vérification
    
    if not results:
        raise ValueError("Les résultats sont vides. Rien à exporter.")
    


    with h5py.File(output_hdf5_path, 'w') as f:
        for frame_idx, result in enumerate(results):
            # Créer un groupe pour chaque frame
            group = f.create_group(f'frame_{frame_idx}')

            # Extraire les boîtes englobantes (x_min, y_min, x_max, y_max)
            boxes = result.boxes.xyxy.cpu().numpy() if result.boxes is not None else []
            scores = result.boxes.conf.cpu().numpy() if result.boxes is not None else []
            class_ids = result.boxes.cls.cpu().numpy() if result.boxes is not None else []
            track_ids = result.boxes.id.cpu().numpy() if result.boxes is not None else []  # Ajout des track IDs
            # Extraire les masques
            masks = result.masks.data.cpu().numpy() if result.masks is not None else []

            # Sauvegarder dans le groupe HDF5
            group.create_dataset('boxes', data=boxes)
            group.create_dataset('scores', data=scores)
            group.create_dataset('class_ids', data=class_ids)
            group.create_dataset('track_ids', data=track_ids)
            group.create_dataset('masks', data=masks)

            # Ajouter des métadonnées
            group.attrs['path'] = result.path
            group.attrs['original_shape'] = result.orig_shape


    print(f"OK")
    print(f"Résultats YOLO exportés avec succès dans : {output_hdf5_path}")
