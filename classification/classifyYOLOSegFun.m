function [data,image] = classifyYOLOSegFun(roiobj,classif,classifier,varargin)

% this function can be used to classify any roi object, by providing the
% classi object and the classifier

debug_flag=false;
gpu=0;
frames=[];
channel=classif.channelName;

for i=1:numel(varargin)
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    end

    if strcmp(varargin{i},'Channel')
        channel=varargin{i+1};
    end
      if strcmp(varargin{i},'Exec')
           gpu=varargin{i+1};
      end
end


% Trouver tous les dossiers dans classif.path qui suivent le motif 'runXX'
runs_list = dir(fullfile(classif.path, 'run*'));

% Vérifier si des dossiers correspondant au motif existent
if isempty(runs_list)
    error('Aucun dossier "runXX" trouvé dans : %s', classif.path);
end

% Extraire les valeurs XX des noms de dossiers en utilisant sscanf
XX_values = arrayfun(@(d) sscanf(d.name, 'run%d'), runs_list, 'UniformOutput', false);

% Supprimer les entrées vides (au cas où certains dossiers ne correspondent pas au format attendu)
XX_values = [XX_values{:}];

if isempty(XX_values)
    error('Aucun dossier "runXX" avec un numéro valide trouvé dans : %s', classif.path);
end

% Trouver le dossier avec la plus grande valeur de XX
[~, latest_idx] = max(XX_values);
latest_run_folder = fullfile(runs_list(XX_values(latest_idx)).folder, runs_list(XX_values(latest_idx)).name);

% Construire le chemin vers le modèle YOLO (dans /weights/best.pt)
model_path = fullfile(latest_run_folder, 'weights', 'best.pt');

% Vérifier si le fichier du modèle existe
if ~exist(model_path, 'file')
    error('Modèle YOLO introuvable dans : %s', model_path);
end

% Afficher le chemin du modèle pour confirmation
disp(['Modèle YOLO trouvé : ', model_path]);

% Input images to classify
if numel(frames)==0
frames = 1:size(roiobj.image, 4); % Default to all frames if not specified
end

if numel(roiobj.image)==0 % load stored image in any case
    roiobj.load;
end

data=roiobj.data;
if numel(data)==0
    roiobj.data=dataseries;
    data=roiobj.data;
end

pix=roiobj.findChannelID(channel);

    if iscell(pix)
            pix=cell2mat(pix);
    end

        pixresults=[]; % channels where each mask for each class is stored
        for i=1:numel(classif.classes)
            pixresultstmp=findChannelID(roiobj,['results_' classif.strid '_' classif.classes{i}]);
            % gather all channels associated with proba

            if numel(pixresultstmp)==0 % channel does not exist, hence create them
                pixresults=[pixresults size(roiobj.image,3)];
            else
                pixresults=[pixresults pixresultstmp];
            end
        end

        % channel where all the masks are put
          pixresults2=findChannelID(roiobj,['results_' classif.strid]);
          if numel(pixresults2)==0 % channels do not exist, hence create them
            pixresults2=size(roiobj.image,3)+1;
          end

image=roiobj.image;
param=[];

%gfp=double(zeros(size(image,1),size(image,2),numel(pix),numel(frames)));

% Préparer les données GFP
gfp = uint8(zeros(size(image, 1), size(image, 2), numel(pix), numel(frames)));

cc = 1;
for fr = frames
    % Extraire la frame actuelle
    tmp = roiobj.image(:, :, pix, fr);  % Dimensions [H, W, C]

    % Normaliser avec mat2gray et convertir en uint8
    tmp_uint8 = uint8(255 * mat2gray(tmp));
  %  figure, imshow(tmp_uint8);

    % Ajouter au tableau GFP
    gfp(:, :, :, cc) = tmp_uint8 ;
    cc = cc + 1;
end

 %gfp=uint8(gfp*256);

 % Sauvegarder la matrice `gfp` sur le disque
    tmp_mat_path = fullfile(classif.path, 'tmp.mat');
    save(tmp_mat_path, 'gfp');
    disp(['Matrice GFP sauvegardée à : ', tmp_mat_path]);


% Set device based on GPU flag
device = 'cpu';
if gpu
    device = 0;
end

if isempty(device)
    device_param = ""; % Ne pas inclure le paramètre 'device' si vide
elseif isnumeric(device)
    device_param = sprintf("    device=%d,\n", device); % Inclure le paramètre avec un nombre
else
    device_param = sprintf("    device='%s',\n", device); % Inclure le paramètre avec une chaîne
end

% Chemin de sortie des résultats
    output_results_path = fullfile(classif.path, 'results');
    if ~exist(output_results_path, 'dir')
        mkdir(output_results_path);
    end

tmp_mat_path = strrep(tmp_mat_path, '\', '\\');
model_path = strrep(model_path, '\', '\\');
output_results_path = strrep(output_results_path, '\', '\\');
classi_path=strrep(classif.path, '\', '\\');

% Trouver le chemin de 'export_yolo_results_to_hdf5.py'
export_function_path = which('export_yolo_results_to_hdf5.py');
if isempty(export_function_path)
    error('Le module export_yolo_results_to_hdf5.py est introuvable. Assurez-vous qu''il est dans le MATLAB path.');
end

% Convertir le chemin pour qu'il soit compatible avec Python
export_function_path = strrep(export_function_path, '\', '\\');
disp(['Chemin du module export_yolo_results_to_hdf5 trouvé : ', export_function_path]);

% % Générer le script Python temporaire
% 
% python_script_content = sprintf( ...
%     "import h5py\n" + ...
%     "import numpy as np\n" + ...
%     "from ultralytics import YOLO\n" + ...
%     "import scipy.io as sio\n" + ...
%     "import os\n" + ...
%     "import cv2\n" + ...
%     "\n" + ...
%     "# Fonction pour exporter les résultats au format HDF5\n" + ...
%     "def export_yolo_results_to_hdf5(results, output_hdf5_path):\n" + ...
%     "    print(f'Export HDF5 appelé avec {len(results)} résultats.')\n" + ...
%     "    if not results:\n" + ...
%     "        raise ValueError('Les résultats sont vides. Rien à exporter.')\n" + ...
%     "    with h5py.File(output_hdf5_path, 'w') as f:\n" + ...
%     "        for frame_idx, result in enumerate(results):\n" + ...
%     "            group = f.create_group(f'frame_{frame_idx}')\n" + ...
%     "            boxes = result.boxes.xyxy.cpu().numpy() if result.boxes else []\n" + ...
%     "            scores = result.boxes.conf.cpu().numpy() if result.boxes else []\n" + ...
%     "            class_ids = result.boxes.cls.cpu().numpy() if result.boxes else []\n" + ...
%     "            track_ids = result.boxes.id.cpu().numpy() if result.boxes else []\n" + ...
%     "            masks = result.masks.data.cpu().numpy() if result.masks else []\n" + ...
%     "            group.create_dataset('boxes', data=boxes)\n" + ...
%     "            group.create_dataset('scores', data=scores)\n" + ...
%     "            group.create_dataset('class_ids', data=class_ids)\n" + ...
%     "            group.create_dataset('track_ids', data=track_ids)\n" + ...
%     "            group.create_dataset('masks', data=masks)\n" + ...
%     "            group.attrs['path'] = result.path\n" + ...
%     "            group.attrs['original_shape'] = result.orig_shape\n" + ...
%     "    print(f'Resultats YOLO exportés dans : {output_hdf5_path}')\n" + ...
%     "\n" + ...
%     "# Configurations\n" + ...
%     "mat_path = r'%s'\n" + ...
%     "project = r'%s'\n" + ...
%     "model_path = r'%s'\n" + ...
%     "output_hdf5_path = os.path.join(project, 'results.h5')\n" + ...
%     "\n" + ...
%     "# Charger et prétraiter les images\n" + ...
%     "gfp = sio.loadmat(mat_path)['gfp']\n" + ...
%     "print(f'Dimensions de gfp : {gfp.shape}')\n" + ...
%     "\n" + ...
%     "# Convertir en liste d'images (H, W, C)\n" + ...
%     "images = [cv2.cvtColor(img.astype(np.uint8), cv2.COLOR_GRAY2BGR) if img.ndim == 2 else img.astype(np.uint8) \n" + ...
%     "          for img in gfp.transpose(3, 0, 1, 2)]\n" + ...
%     "\n" + ...
%     "# Déterminer la taille des images\n" + ...
%     "height, width = images[0].shape[:2]\n" + ...
%     "print(f'Original image size: {height}x{width}')\n" + ...
%     "\n" + ...
%     "# Calculer le multiple de 32 juste au-dessus\n" + ...
%     "target_height = int(np.ceil(height / 32) * 32)\n" + ...
%     "target_width = int(np.ceil(width / 32) * 32)\n" + ...
%     "print(f'Adjusted model size (multiple of 32): {target_height}x{target_width}')\n" + ...
%     "\n" + ...
%     "# Redimensionner les images à cette taille\n" + ...
%     "resized_images = [cv2.resize(img, (target_width, target_height), interpolation=cv2.INTER_LINEAR) for img in images]\n" + ...
%     "\n" + ...
%     "model = YOLO(model_path)\n" + ...
%     "\n" + ...
%     "# Effectuer le suivi et la segmentation\n" + ...
%     "results = model.track(\n" + ...
%     "    source=resized_images,\n" + ...
%     "    device=0,\n" + ...
%     "    save=True,\n" + ...
%     "    tracker='botsort.yaml',\n" + ...
%     "    save_txt=True,\n" + ...
%     "    project=project\n" + ...
%     ")\n" + ...
%     "\n" + ...
%     "# Exporter les résultats au format HDF5\n" + ...
%     "export_yolo_results_to_hdf5(results, output_hdf5_path)\n", ...
%     tmp_mat_path, classi_path, model_path);

python_script_content = sprintf( ...
    "import h5py\n" + ...
    "import numpy as np\n" + ...
    "from ultralytics import YOLO\n" + ...
    "import scipy.io as sio\n" + ...
    "import os\n" + ...
    "import cv2\n" + ...
    "\n" + ...
    "# Fonction pour exporter les résultats au format HDF5\n" + ...
    "def export_yolo_results_to_hdf5(results, output_hdf5_path):\n" + ...
    "    print(f'Export HDF5 appelé avec {len(results)} résultats.')\n" + ...
    "    if not results:\n" + ...
    "        raise ValueError('Les résultats sont vides. Rien à exporter.')\n" + ...
    "    with h5py.File(output_hdf5_path, 'w') as f:\n" + ...
    "        for frame_idx, result in enumerate(results):\n" + ...
    "            group = f.create_group(f'frame_{frame_idx}')\n" + ...
    "\n" + ...
    "            # Gestion des boîtes englobantes\n" + ...
    "            if result.boxes:\n" + ...
    "                boxes = result.boxes.xyxy.cpu().numpy() if hasattr(result.boxes, 'xyxy') and result.boxes.xyxy is not None else np.empty((0, 4))\n" + ...
    "                scores = result.boxes.conf.cpu().numpy() if hasattr(result.boxes, 'conf') and result.boxes.conf is not None else np.empty((0,))\n" + ...
    "                class_ids = result.boxes.cls.cpu().numpy() if hasattr(result.boxes, 'cls') and result.boxes.cls is not None else np.empty((0,))\n" + ...
    "                track_ids = result.boxes.id.cpu().numpy() if hasattr(result.boxes, 'id') and result.boxes.id is not None else np.empty((0,))\n" + ...
    "            else:\n" + ...
    "                boxes = np.empty((0, 4))\n" + ...
    "                scores = np.empty((0,))\n" + ...
    "                class_ids = np.empty((0,))\n" + ...
    "                track_ids = np.empty((0,))\n" + ...
    "\n" + ...
    "            # Gestion des masques\n" + ...
    "            masks = result.masks.data.cpu().numpy() if result.masks and hasattr(result.masks, 'data') and result.masks.data is not None else np.empty((0,))\n" + ...
    "\n" + ...
    "            # Création des datasets\n" + ...
    "            group.create_dataset('boxes', data=boxes)\n" + ...
    "            group.create_dataset('scores', data=scores)\n" + ...
    "            group.create_dataset('class_ids', data=class_ids)\n" + ...
    "            group.create_dataset('track_ids', data=track_ids)\n" + ...
    "            group.create_dataset('masks', data=masks)\n" + ...
    "\n" + ...
    "            # Ajout des métadonnées\n" + ...
    "            group.attrs['path'] = getattr(result, 'path', '')\n" + ...
    "            group.attrs['original_shape'] = getattr(result, 'orig_shape', ())\n" + ...
    "\n" + ...
    "    print(f'Resultats YOLO exportés dans : {output_hdf5_path}')\n" + ...
    "\n" + ...
    "# Configurations\n" + ...
    "mat_path = r'%s'\n" + ...
    "project = r'%s'\n" + ...
    "model_path = r'%s'\n" + ...
    "output_hdf5_path = os.path.join(project, 'results.h5')\n" + ...
    "\n" + ...
    "# Charger et prétraiter les images\n" + ...
    "gfp = sio.loadmat(mat_path)['gfp']\n" + ...
    "print(f'Dimensions de gfp : {gfp.shape}')\n" + ...
    "\n" + ...
    "# Convertir en liste d'images (H, W, C)\n" + ...
    "images = [cv2.cvtColor(img.astype(np.uint8), cv2.COLOR_GRAY2BGR) if img.ndim == 2 else img.astype(np.uint8) \n" + ...
    "          for img in gfp.transpose(3, 0, 1, 2)]\n" + ...
    "\n" + ...
    "# Déterminer la taille des images\n" + ...
    "height, width = images[0].shape[:2]\n" + ...
    "print(f'Original image size: {height}x{width}')\n" + ...
    "\n" + ...
    "# Calculer le multiple de 32 juste au-dessus\n" + ...
    "target_height = int(np.ceil(height / 32) * 32)\n" + ...
    "target_width = int(np.ceil(width / 32) * 32)\n" + ...
    "print(f'Adjusted model size (multiple of 32): {target_height}x{target_width}')\n" + ...
    "\n" + ...
    "# Redimensionner les images à cette taille\n" + ...
    "resized_images = [cv2.resize(img, (target_width, target_height), interpolation=cv2.INTER_LINEAR) for img in images]\n" + ...
    "\n" + ...
    "model = YOLO(model_path)\n" + ...
    "\n" + ...
    "# Effectuer le suivi et la segmentation\n" + ...
    "results = model.track(\n" + ...
    "    source=resized_images,\n" + ...
    "    device=0,\n" + ...
    "    save=True,\n" + ...
    "    tracker='botsort.yaml',\n" + ...
    "    save_txt=True,\n" + ...
    "    project=project\n" + ...
    ")\n" + ...
    "\n" + ...
    "# Exporter les résultats au format HDF5\n" + ...
    "export_yolo_results_to_hdf5(results, output_hdf5_path)\n", ...
    tmp_mat_path, classi_path, model_path);


% Afficher le contenu pour vérifier
%disp(python_script_content);

% Chemin du script Python
python_script_path = fullfile(classif.path, 'classify_script.py');

% Ouvrir le fichier en mode texte avec encodage UTF-8
fid = fopen(python_script_path, 'w', 'n', 'UTF-8');
if fid == -1
    error('Impossible de créer le fichier Python : %s', python_script_path);
end

% Écrire le contenu du script Python
fprintf(fid, '%s', python_script_content);

% Fermer le fichier
fclose(fid);

% Afficher le chemin pour confirmer
disp(['Script Python sauvegardé à : ', python_script_path]);

  % Appel du script Python pour effectuer l'inférence
    try
        pyrunfile(python_script_path);
        disp('Exécution du script Python terminée avec succès.');
    catch ME
        error('Erreur lors de l''exécution du script Python : %s', ME.message);
    end

% lire le fichier hdf5 de yolo: 

% Chemin du fichier HDF5
hdf5_path = fullfile(classif.path, 'results.h5');

% Lire les groupes dans le fichier
info = h5info(hdf5_path);
disp(info);

% disp('Groupes et datasets dans le fichier HDF5 :');
% for i = 1:numel(info.Groups)
%     disp(['Groupe : ', info.Groups(i).Name]);
%     disp('Datasets :');
%     disp({info.Groups(i).Datasets.Name}); % Affiche les noms des datasets disponibles
% end


% for i = 1:numel(info.Groups)
%     disp(['Groupe trouvé : ', info.Groups(i).Name]);
%     disp('Datasets disponibles :');
%     disp({info.Groups(i).Datasets.Name});  % Affiche les noms des datasets du groupe
% end


% Initialiser une structure pour stocker les résultats
results = struct();

% Parcourir les groupes (frames)
frame_indices = zeros(1, numel(info.Groups)); % Pour stocker les indices numériques des frames

% Extraire les indices numériques des frames
for i = 1:numel(info.Groups)
    group_name = info.Groups(i).Name;  % Nom du groupe (ex: '/frame_0')
    % Extraire le numéro de la frame (après le dernier '_')
    frame_index = sscanf(group_name, '/frame_%d');
    frame_indices(i) = frame_index;
end

% Trier les indices et récupérer l'ordre de tri
[~, sorted_indices] = sort(frame_indices);

% Lire les données dans l'ordre trié
results = struct([]);
for sorted_idx = 1:numel(sorted_indices)
    i = sorted_indices(sorted_idx);
    group_name = info.Groups(i).Name;  % Nom du groupe (ex: '/frame_0')
    %disp(['Lecture des données pour : ', group_name]);
    
    % Lire les boîtes englobantes
    boxes = h5read(hdf5_path, [group_name, '/boxes']);
    
    % Lire les scores
    scores = h5read(hdf5_path, [group_name, '/scores']);
    
    % Lire les identifiants de classe
    class_ids = h5read(hdf5_path, [group_name, '/class_ids']);
    
    % Lire les masques
    masks = h5read(hdf5_path, [group_name, '/masks']);

    track_ids = h5read(hdf5_path, [group_name, '/track_ids']);  % Lire les track IDs
    
    % Lire les attributs
    attrs = h5info(hdf5_path, group_name);
    path = attrs.Attributes(strcmp({attrs.Attributes.Name}, 'path')).Value;
    original_shape = attrs.Attributes(strcmp({attrs.Attributes.Name}, 'original_shape')).Value;
    
    % Stocker les données dans la structure de résultats
    results(sorted_idx).frame_name = group_name;
    results(sorted_idx).boxes = boxes;
    results(sorted_idx).scores = scores;
    results(sorted_idx).class_ids = class_ids;
    results(sorted_idx).masks = masks;
    results(sorted_idx).path = path;
    results(sorted_idx).track_ids = track_ids;  % Ajouter les track IDs
    results(sorted_idx).original_shape = original_shape;
end

disp('Lecture complète');


% Taille des masques
image_height = size(roiobj.image, 1);
image_width = size(roiobj.image, 2);

num_classes = numel(pixresults); %numel(classif.classes);  % Nombre de classes
num_frames = numel(results);

% Nombre de frames dans les résultats

% Initialiser la matrice tmpout
tmpout = zeros(image_height, image_width, num_classes, num_frames);

% Initialiser un compteur pour les instances par classe et frame
%instance_counters = zeros(num_classes, num_frames);

% Initialiser une map pour stocker les relations entre track_ids et instances
track_id_to_instance_map = containers.Map('KeyType', 'double', 'ValueType', 'double');
track_id_to_class_map = containers.Map('KeyType', 'double', 'ValueType', 'double'); % Associe les Track IDs aux classes
instance_counter = 1; % Compteur global pour les instances

% Parcourir les frames dans les résultats
for frame_idx = 1:num_frames
    frame_results = results(frame_idx);

    % Extraire l'image brute pour la frame (canal 1)
    raw_image = roiobj.image(:, :, 1, frame_idx);

    % Normaliser l'image brute pour affichage
    raw_image_normalized = double(raw_image) / double(max(raw_image(:)));

    % Redimensionner l'image brute à 512x512 pour l'affichage
    overlay_image = imresize(repmat(raw_image_normalized, [1, 1, 3]), [512, 512]);

    % Initialiser les annotations pour bounding boxes
    bboxes = [];
    labels = {};
    
    % Créer un masque de superposition (initialisé à zéro)
    mask_overlay = zeros(512, 512, 3);

    % Vérifier si les bounding boxes existent
    if isempty(frame_results.boxes)
        warning('Aucune bounding box pour la frame %d.', frame_idx);
        continue;
    end

    % Extraire les bounding boxes sous forme de matrice 4xN
    boxes_xyxy = frame_results.boxes;  % Chaque colonne est une bounding box [x_min; y_min; x_max; y_max]

    % Extraire les scores
    scores = frame_results.scores;  % Tableau des scores

    % Extraire ou générer les track IDs
    if isfield(frame_results, 'track_ids') && ~isempty(frame_results.track_ids)
        track_ids = frame_results.track_ids;  % Liste des track IDs
    else
        % Si les track IDs sont vides, générer des identifiants uniques pour chaque objet
        track_ids = (instance_counter:instance_counter + size(boxes_xyxy, 2) - 1)';
        instance_counter = instance_counter + size(boxes_xyxy, 2);
    end

    % Parcourir les objets détectés dans la frame
    for obj_idx = 1:size(boxes_xyxy, 2)  % Le nombre de colonnes correspond au nombre d'objets
        class_id = frame_results.class_ids(obj_idx) + 1;  % Indice de la classe (1-indexé pour MATLAB)
        mask = squeeze(frame_results.masks(:, :, obj_idx))';  % Extraire le masque et permuter les dimensions x et y
        
        % Vérifiez si les dimensions du masque correspondent à l'image originale
        if size(mask, 1) ~= size(roiobj.image, 1) || size(mask, 2) ~= size(roiobj.image, 2)
            % Redimensionner le masque pour qu'il corresponde à la taille de l'image originale
            mask = imresize(mask, [size(roiobj.image, 1), size(roiobj.image, 2)], 'nearest');
        end

        % Extraire ou générer un track ID unique
        track_id = track_ids(obj_idx);

        % Vérifier si le track ID existe déjà dans la map
        if isKey(track_id_to_instance_map, track_id)
            % Vérifier si la classe actuelle correspond à la classe enregistrée pour ce Track ID
            if track_id_to_class_map(track_id) ~= class_id
                warning('Conflit de classe pour le Track ID %d: Classe enregistrée %d, Classe actuelle %d.', track_id, track_id_to_class_map(track_id), class_id);
                % Créer une nouvelle instance pour éviter le conflit
                instance_value = instance_counter;
                track_id_to_instance_map(track_id) = instance_value;
                track_id_to_class_map(track_id) = class_id; % Mettre à jour la classe associée
                instance_counter = instance_counter + 1;
            else
                % Si la classe correspond, utiliser l'instance existante
                instance_value = track_id_to_instance_map(track_id);
            end
        else
            % Si le track ID est nouveau, l'ajouter à la map avec une nouvelle valeur d'instance
            instance_value = instance_counter;
            track_id_to_instance_map(track_id) = instance_value;
            track_id_to_class_map(track_id) = class_id; % Associer la classe au Track ID
            instance_counter = instance_counter + 1;
        end
        
        % Ajouter le masque à la matrice tmpout avec la valeur d'instance unique
        tmpout(:, :, class_id, frame_idx) = tmpout(:, :, class_id, frame_idx) + (mask * instance_value);

        if debug_flag
            % Extraire la bounding box correspondante (colonne `obj_idx`)
            box_xyxy = boxes_xyxy(:, obj_idx)';
            
            % Convertir la bounding box en [x, y, width, height] et redimensionner pour 512x512
            box_xyxy_resized = round(box_xyxy * (512 / image_height));  % Échelle basée sur la hauteur de l'image
            box_xywh = [box_xyxy_resized(1), box_xyxy_resized(2), ...
                        box_xyxy_resized(3) - box_xyxy_resized(1), ...
                        box_xyxy_resized(4) - box_xyxy_resized(2)];
            
            % Ajouter la bounding box à `bboxes`
            bboxes = [bboxes; box_xywh];

            detection_score = scores(obj_idx);  % Score de la détection
            labels{end+1} = sprintf('%s #%d (%.2f)', classif.classes{class_id}, track_id, detection_score);

            % Redimensionner le masque pour correspondre à 512x512 pour l'affichage
            mask_resized = imresize(mask, [512, 512], 'nearest');

            % Superposer le masque avec une couleur spécifique à la classe
            color = rand(1, 3);  % Couleur aléatoire
            for c = 1:3
                mask_overlay(:, :, c) = mask_overlay(:, :, c) + mask_resized * color(c);
            end
        end
    end


     if debug_flag
    % Normaliser le masque pour éviter les débordements
    mask_overlay = mask_overlay / max(mask_overlay(:));

    % Vérifier que le nombre de labels correspond au nombre de bounding boxes
    if size(bboxes, 1) ~= numel(labels)
        error('Le nombre de bounding boxes (%d) ne correspond pas au nombre de labels (%d).', size(bboxes, 1), numel(labels));
    end

   
        % Ajouter les annotations sur l'image brute
        annotated_image = insertObjectAnnotation(uint8(overlay_image * 255), 'Rectangle', bboxes, labels);

        % Ajouter le masque superposé à l'image annotée
        final_image = imadd(uint8(annotated_image), uint8(mask_overlay * 255));

        % Afficher l'image annotée avec les masques superposés
        figure;
        imshow(final_image);
        title(sprintf('Frame %d - Annotations et Masques', frame_idx));
        drawnow;
    end
end

% Vérification de la matrice
disp('Matrice tmpout construite avec succès.');
disp(size(tmpout));  % Affiche les dimensions : [H, W, num_classes, num_frames]


    % Ajouter les résultats dans les canaux appropriés
    image = roiobj.image;
  
    disp('Traitement des résultats terminé.');


image(:,:,pixresults,frames)=tmpout;
%image(:,:,pixresults2,frames)=tmpout2;

fprintf('\n');





