function [data,image] = classifyYOLOSegFun(roiobj,classif,classifier,varargin)

% this function can be used to classify any roi object, by providing the
% classi object and the classifier

debug_flag=false;
gpu=0;
frames=[];
channel=classif.channelName;
trainingParam=classif.trainingParam;

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

runs_list = dir(fullfile(classif.path, 'run*'));

% On filtre seulement les dossiers (pas les fichiers)
runs_list = runs_list([runs_list.isdir]);

run_nums = [];
valid_runs = [];

for k = 1:length(runs_list)
    name = runs_list(k).name;

    if strcmp(name, 'run')
        run_nums(end+1) = 0;  % cas spécial pour le premier run sans numéro
        valid_runs(end+1) = k;
    else
        tokens = regexp(name, '^run(\d+)$', 'tokens');
        if ~isempty(tokens)
            run_nums(end+1) = str2double(tokens{1}{1});
            valid_runs(end+1) = k;
        end
    end
end

if isempty(run_nums)
    error('Aucun dossier valide de type "run" ou "runXX" trouvé dans : %s', classif.path);
end

% Trouver l'indice du run le plus récent (valeur la plus grande)
[~, idx] = max(run_nums);
latest_idx = valid_runs(idx);

aa = runs_list(latest_idx);
latest_run_folder = fullfile(aa.folder, aa.name);

% Vérification facultative de la présence du modèle
model_path = fullfile(latest_run_folder, 'weights', 'best.pt');
if ~isfile(model_path)
    warning('Modèle YOLO introuvable dans : %s', model_path);
end

% Afficher le chemin du modèle pour confirmation
disp(['Modèle YOLO trouvé : ', model_path]);

% Input images to classify
if numel(frames)==0
frames = 1:size(roiobj.image, 4); % Default to all frames if not specified
end

% if numel(roiobj.image)==0 % load stored image in any case
%     roiobj.load;
% end

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
        cd=1;
        for i=1:numel(classif.classes)
            pixresultstmp=findChannelID(roiobj,['results_' classif.strid '_' classif.classes{i}]);
            % gather all channels associated with proba

            if numel(pixresultstmp)==0 % channel does not exist, hence create them
                pixresults=[pixresults size(roiobj.image,3)+cd];
                cd=cd+1;
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

% generer le fichier de config de tracking 
% prepare settings file for tracking
%% Génération de tracker_settings.yaml
py_bool = ["False", "True"];
% Modifiable en-tête : changez ces valeurs selon vos besoins
tracker_type        = trainingParam.tracker_type{end};        % 'botsort' ou 'bytetrack'
track_high_thresh   = trainingParam.track_high_thresh;               % seuil 1ʳᵉ association
track_low_thresh    = trainingParam.track_low_thresh;                % seuil 2ᵉ association
new_track_thresh    = trainingParam.new_track_thresh;               % seuil création d'un nouveau track
track_buffer        = trainingParam.track_buffer ;                 % durée du buffer (frames)
match_thresh        = trainingParam.match_thresh;               % seuil IoU pour matching
fuse_score          = trainingParam.fuse_score;               % fusion score+IoU ?
gmc_method          = trainingParam.gmc_method{end};    % 'sparseOptFlow' ou 'orb' ou 'none'
with_reid           = trainingParam.with_reid;               % activer Re‑ID ?
currentPath = fileparts(mfilename('fullpath'));
[parent1, ~] = fileparts(currentPath);
[parent2, ~] = fileparts(parent1);
reid_model_path     =fullfile(parent2,'osnet_x0_25_msmt17.onnx');
reid_model_path  = strrep(reid_model_path , '\', '\\');

proximity_thresh    = trainingParam.proximity_thresh;                % distance cos ≤ prox = « même objet »
appearance_thresh   = trainingParam.appearance_thresh;               % poids apparence vs IoU (0–1)

save_images=py_bool(trainingParam.save+1);
save_txt=       py_bool(trainingParam.save_txt+1);

% Conversion des booléens en « true »/« false »
fuse_score_str = py_bool(fuse_score+1);
with_reid_str  =  py_bool(with_reid+1);

% Ouvre le fichier en écriture
trackersettingspath=fullfile(classif.path, 'tracker_settings.yaml');

fid = fopen(trackersettingspath,'w');
if fid == -1
    error('Impossible de créer tracker_settings.yaml');
end

% Écriture ligne par ligne
fprintf(fid, '# Ultralytics YOLO 🚀, AGPL‑3.0 license\n');
fprintf(fid, '# Default YOLO tracker settings for BoT‑SORT tracker https://github.com/NirAharon/BoT-SORT\n\n');

fprintf(fid, 'tracker_type: %s # tracker type, [''botsort'', ''bytetrack'']\n', tracker_type);
fprintf(fid, 'track_high_thresh: %g # threshold for the first association\n', track_high_thresh);
fprintf(fid, 'track_low_thresh: %g # threshold for the second association\n', track_low_thresh);
fprintf(fid, 'new_track_thresh: %g # threshold for init new track if the detection does not match any tracks\n', new_track_thresh);
fprintf(fid, 'track_buffer: %d # buffer to calculate the time when to remove tracks\n', track_buffer);
fprintf(fid, 'match_thresh: %g # threshold for matching tracks\n', match_thresh);
fprintf(fid, 'fuse_score: %s # Whether to fuse confidence scores with the iou distances before matching\n\n', fuse_score_str);

fprintf(fid, '# --- BoT‑SORT : Global Motion Compensation --------------\n');
fprintf(fid, 'gmc_method: %s # ou ''orb'', ''none''\n\n', gmc_method);

fprintf(fid, '# ---------  ACTIVATION Re‑ID  ----------\n');
fprintf(fid, 'with_reid: %s # << activer\n', with_reid_str);
fprintf(fid, 'reid_model_path: "%s"   # chemin vers le modèle ONNX\n', reid_model_path);
fprintf(fid, 'proximity_thresh: %g           # distance cos <= 0.5 = « même objet »\n', proximity_thresh);
fprintf(fid, 'appearance_thresh: %g         # pondération Re‑ID vs IoU (0–1)\n', appearance_thresh);

% Ferme le fichier
fclose(fid);
disp('Fichier tracker_settings.yaml généré avec succès.');

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

%  'reid_model_path', "C:/Users/Gilles/osnet_x0_25_msmt17.onnx"   # chemin vers le modèle ONNX

%tracker_path = fullfile(classif.path, 'bytetrack.yaml');

% script python
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
    "gfp_reord = np.transpose(gfp, (3, 0, 1, 2))" + ...
     "\n" + ...
     "if gfp_reord.shape[-1] == 1: "+ ...
     "           gfp_reord = np.repeat(gfp_reord, 3, axis=-1)" + ...
    "\n" + ...
    "# Convertir en liste d'images (H, W, C)\n" + ...
     "\n" + ...
     "images = [img.astype(np.uint8) for img in gfp_reord]"+...
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
"# Vérifier que le tracker existe\n" + ...
"tracker_path = os.path.join(project, 'tracker_settings.yaml')\n" + ...
"if not os.path.isfile(tracker_path):\n" + ...
"    raise FileNotFoundError(f'Fichier tracker introuvable à : {tracker_path}')\n" + ...
"else:\n" + ...
"    print(f'Fichier tracker trouvé à : {tracker_path}')\n\n" + ...
    "\n" + ...
    "# Effectuer le suivi et la segmentation\n" + ...
    "results = model.track(\n" + ...
    "    source=resized_images,\n" + ...
    "    device=0,\n" + ...
    "    save=%s,\n" + ...
    "    tracker=tracker_path,\n" + ...
    "    persist=True,\n" + ...
    "    save_txt=%s,\n" + ...
    "    project=project\n" + ...
    ")\n\n" + ...
"for i, res in enumerate(results):\n" + ...
"    if not res.boxes:\n" + ...
"        continue\n" + ...
"    if res.boxes.id is not None:\n" + ...
"        order = np.argsort(res.boxes.id.cpu().numpy())\n" + ...
"        res.boxes = res.boxes[order]\n" + ...
"        res.masks.data = res.masks.data[order]\n" + ...
"    else:\n" + ...
"        print(f'[Frame {i}] Aucun track_id attribué.')\n" + ...
"        if res.boxes and res.boxes.xyxy is not None:\n" + ...
"            print(f'[Frame {i}] {len(res.boxes)} détection(s) avec scores = {res.boxes.conf.cpu().numpy()}')\n\n" + ...
    "\n" + ...
    "def mean_iou(box_a, box_b):\n" + ...
"    # box = [x1,y1,x2,y2] en numpy\n" + ...
"    x1 = np.maximum(box_a[...,0], box_b[...,0])\n" + ...
"    y1 = np.maximum(box_a[...,1], box_b[...,1])\n" + ...
"    x2 = np.minimum(box_a[...,2], box_b[...,2])\n" + ...
"    y2 = np.minimum(box_a[...,3], box_b[...,3])\n" + ...
"    inter = np.maximum(x2-x1, 0) * np.maximum(y2-y1, 0)\n" + ...
"    area  = (box_a[...,2]-box_a[...,0])*(box_a[...,3]-box_a[...,1])\n" + ...
"    area += (box_b[...,2]-box_b[...,0])*(box_b[...,3]-box_b[...,1]) - inter\n" + ...
"    return (inter/area) if area.any() else 0.0\n\n" + ...
"for f in range(1, len(results)):\n" + ...
"    prev, curr = results[f-1], results[f]\n\n" + ...
"    # 🛡 Vérifier que des track_ids sont bien présents\n" + ...
"    if curr.boxes.id is None or prev.boxes.id is None:\n" + ...
"        print(f'[Frame {f}] Impossible de vérifier les track_ids (aucun ID disponible).')\n" + ...
"        continue\n\n" + ...
"    for tid in np.unique(curr.boxes.id.cpu()):\n" + ...
"        i_prev = (prev.boxes.id.cpu() == tid).nonzero(as_tuple=True)[0]\n" + ...
"        i_curr = (curr.boxes.id.cpu() == tid).nonzero(as_tuple=True)[0]\n" + ...
"        if i_prev.numel() == 0 or i_curr.numel() == 0:\n" + ...
"            continue\n" + ...
"        iou = mean_iou(prev.boxes.xyxy[i_prev], curr.boxes.xyxy[i_curr])\n\n" + ...
"        if iou < 0.1:\n" + ...
"            print(f'ID-switch probable pour track_id={tid.item()} entre frames {f}→{f+1} (IoU={iou.item():.2f})')\n\n" + ...
    "# Exporter les résultats au format HDF5\n" + ...
    "export_yolo_results_to_hdf5(results, output_hdf5_path)\n", ...
    tmp_mat_path, classi_path, model_path,save_images,save_txt);


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
%disp(info);

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

%assignin('base','results',results);

disp('Lecture complète');

% ====== Paramètres généraux =================================================
num_classes = numel(pixresults);      % autant de canaux que de classes
num_frames  = numel(results);

image_height = size(roiobj.image,1);
image_width  = size(roiobj.image,2);

% ====== Matrice de sortie (H,W,C,T) ========================================
tmpout = zeros(image_height, image_width, num_classes, num_frames, 'single');

% ====== Mapping TrackID → instance_value par classe ========================
trackMap        = cell(1,num_classes);           % un containers.Map par classe
instanceCounter = zeros(1,num_classes);          % compteur d’instances / classe
for c = 1:num_classes
    trackMap{c} = containers.Map('KeyType','double','ValueType','double');
end

% ====== BOUCLE SUR LES FRAMES =============================================
for frame_idx = 1:num_frames
    res = results(frame_idx);
    if isempty(res.class_ids)        % aucune détection ?
        continue;
    end

    % -----------------------------------------------------------------------
    % 1. si res.track_ids absent -> créer une suite 1:N
    % -----------------------------------------------------------------------
    if isempty(res.track_ids)
        res.track_ids = single(1:numel(res.class_ids)).';
    end

    % -----------------------------------------------------------------------
    % 2. Boucle sur chaque objet détecté de la frame
    % -----------------------------------------------------------------------
    Nobj = numel(res.class_ids);
    for k = 1:Nobj
        % ----- 2.1 Infos de l’objet ----------------------------------------
        class_id = res.class_ids(k) + 1;      % 1‑indexé pour MATLAB
        tid      = res.track_ids(k);          % Track ID fourni par BoTSORT

        % ----- 2.2 Instance_value unique pour (classe,track_id) ------------
        tmap = trackMap{class_id};
        if ~isKey(tmap, tid)
            instanceCounter(class_id) = instanceCounter(class_id) + 1;
            tmap(tid) = instanceCounter(class_id);
        end
        instVal = tmap(tid);

        % ----- 2.3 Masque binaire H×W --------------------------------------
        mask = res.masks(:,:,k) > 0;          % masques stockés (H,W,N)
        mask=mask';

        % if frame_idx==7 || frame_idx==8
        %     figure, imshow(mask,[])
        %     title(['Frame ' num2str(frame_idx) ' id ' num2str(tid)  ' map '  num2str(instVal)])
        % end

        if ~isequal(size(mask),[image_height,image_width])
            mask = imresize(mask,[image_height,image_width],'nearest');
        end

        % ----- 2.4 Écriture sans overlap -----------------------------------
        layer = tmpout(:,:,class_id,frame_idx);
        layer(mask & layer==0) = instVal;     % ne pas écraser valeur existante
        tmpout(:,:,class_id,frame_idx) = layer;
    end
end
% ====== FIN BOUCLE FRAMES ==================================================

% — copier vers les canaux de l’image finale —
image(:,:,pixresults,frames) = tmpout;


% ==== Fin de la boucle frames ====
% num_classes = numel(pixresults); %numel(classif.classes);  % Nombre de classes
% num_frames = numel(results);
% 
% % Nombre de frames dans les résultats
% 
% % Initialiser la matrice tmpout
% tmpout = zeros(image_height, image_width, num_classes, num_frames);
% 
% % Initialiser un compteur pour les instances par classe et frame
% %instance_counters = zeros(num_classes, num_frames);
% 
% % Initialiser une map pour stocker les relations entre track_ids et instances
% track_id_to_instance_map = containers.Map('KeyType', 'double', 'ValueType', 'double');
% track_id_to_class_map = containers.Map('KeyType', 'double', 'ValueType', 'double'); % Associe les Track IDs aux classes
% instance_counter = 1; % Compteur global pour les instances
% 
% % Parcourir les frames dans les résultats
% for frame_idx = 1:num_frames
%     frame_results = results(frame_idx);
% 
%     % Extraire l'image brute pour la frame (canal 1)
%     raw_image = roiobj.image(:, :, 1, frame_idx);
% 
%     % Normaliser l'image brute pour affichage
%     raw_image_normalized = double(raw_image) / double(max(raw_image(:)));
% 
%     % Redimensionner l'image brute à 512x512 pour l'affichage
%     overlay_image = imresize(repmat(raw_image_normalized, [1, 1, 3]), [512, 512]);
% 
%     % Initialiser les annotations pour bounding boxes
%     bboxes = [];
%     labels = {};
% 
%     % Créer un masque de superposition (initialisé à zéro)
%     mask_overlay = zeros(512, 512, 3);
% 
%     % Vérifier si les bounding boxes existent
%     if isempty(frame_results.boxes)
%         warning('Aucune bounding box pour la frame %d.', frame_idx);
%         continue;
%     end
% 
%     % Extraire les bounding boxes sous forme de matrice 4xN
%     boxes_xyxy = frame_results.boxes;  % Chaque colonne est une bounding box [x_min; y_min; x_max; y_max]
% 
%     % Extraire les scores
%     scores = frame_results.scores;  % Tableau des scores
% 
%     % Extraire ou générer les track IDs
%     if isfield(frame_results, 'track_ids') && ~isempty(frame_results.track_ids)
%         track_ids = frame_results.track_ids;  % Liste des track IDs
%     else
%         % Si les track IDs sont vides, générer des identifiants uniques pour chaque objet
%         track_ids = (instance_counter:instance_counter + size(boxes_xyxy, 2) - 1)';
%         instance_counter = instance_counter + size(boxes_xyxy, 2);
%     end
% 
%     % Parcourir les objets détectés dans la frame
%     for obj_idx = 1:size(boxes_xyxy, 2)  % Le nombre de colonnes correspond au nombre d'objets
%         class_id = frame_results.class_ids(obj_idx) + 1;  % Indice de la classe (1-indexé pour MATLAB)
%         mask = squeeze(frame_results.masks(:, :, obj_idx))';  % Extraire le masque et permuter les dimensions x et y
% 
%         % Vérifiez si les dimensions du masque correspondent à l'image originale
%         if size(mask, 1) ~= size(roiobj.image, 1) || size(mask, 2) ~= size(roiobj.image, 2)
%             % Redimensionner le masque pour qu'il corresponde à la taille de l'image originale
%             mask = imresize(mask, [size(roiobj.image, 1), size(roiobj.image, 2)], 'nearest');
%         end
% 
%         % Extraire ou générer un track ID unique
%         track_id = track_ids(obj_idx);
% 
%         % Vérifier si le track ID existe déjà dans la map
%         if isKey(track_id_to_instance_map, track_id)
%             % Vérifier si la classe actuelle correspond à la classe enregistrée pour ce Track ID
%             if track_id_to_class_map(track_id) ~= class_id
%                 warning('Conflit de classe pour le Track ID %d: Classe enregistrée %d, Classe actuelle %d.', track_id, track_id_to_class_map(track_id), class_id);
%                 % Créer une nouvelle instance pour éviter le conflit
%                 instance_value = instance_counter;
%                 track_id_to_instance_map(track_id) = instance_value;
%                 track_id_to_class_map(track_id) = class_id; % Mettre à jour la classe associée
%                 instance_counter = instance_counter + 1;
%             else
%                 % Si la classe correspond, utiliser l'instance existante
%                 instance_value = track_id_to_instance_map(track_id);
%             end
%         else
%             % Si le track ID est nouveau, l'ajouter à la map avec une nouvelle valeur d'instance
%             instance_value = instance_counter;
%             track_id_to_instance_map(track_id) = instance_value;
%             track_id_to_class_map(track_id) = class_id; % Associer la classe au Track ID
%             instance_counter = instance_counter + 1;
%         end
% 
%         % Ajouter le masque à la matrice tmpout avec la valeur d'instance unique
%        % tmpout(:, :, class_id, frame_idx) = tmpout(:, :, class_id, frame_idx) + (mask * instance_value);
%           % NOUVEAU : on n’écrit instance_value que sur les pixels non encore étiquetés
%     layer   = tmpout(:, :, class_id, frame_idx);
%     maskIdx = mask > 0;                          % vrai exactement sur le masque
%     % n’écrire instance_value que là où layer est encore 0
%     layer(maskIdx & layer == 0) = instance_value;
%     tmpout(:, :, class_id, frame_idx) = layer;
% 
% 
%         if debug_flag
%             % Extraire la bounding box correspondante (colonne `obj_idx`)
%             box_xyxy = boxes_xyxy(:, obj_idx)';
% 
%             % Convertir la bounding box en [x, y, width, height] et redimensionner pour 512x512
%             box_xyxy_resized = round(box_xyxy * (512 / image_height));  % Échelle basée sur la hauteur de l'image
%             box_xywh = [box_xyxy_resized(1), box_xyxy_resized(2), ...
%                         box_xyxy_resized(3) - box_xyxy_resized(1), ...
%                         box_xyxy_resized(4) - box_xyxy_resized(2)];
% 
%             % Ajouter la bounding box à `bboxes`
%             bboxes = [bboxes; box_xywh];
% 
%             detection_score = scores(obj_idx);  % Score de la détection
%             labels{end+1} = sprintf('%s #%d (%.2f)', classif.classes{class_id}, track_id, detection_score);
% 
%             % Redimensionner le masque pour correspondre à 512x512 pour l'affichage
%             mask_resized = imresize(mask, [512, 512], 'nearest');
% 
%             % Superposer le masque avec une couleur spécifique à la classe
%             color = rand(1, 3);  % Couleur aléatoire
%             for c = 1:3
%                 mask_overlay(:, :, c) = mask_overlay(:, :, c) + mask_resized * color(c);
%             end
%         end
%     end
% 
% 
%      if debug_flag
%     % Normaliser le masque pour éviter les débordements
%     mask_overlay = mask_overlay / max(mask_overlay(:));
% 
%     % Vérifier que le nombre de labels correspond au nombre de bounding boxes
%     if size(bboxes, 1) ~= numel(labels)
%         error('Le nombre de bounding boxes (%d) ne correspond pas au nombre de labels (%d).', size(bboxes, 1), numel(labels));
%     end
% 
% 
%         % Ajouter les annotations sur l'image brute
%         annotated_image = insertObjectAnnotation(uint8(overlay_image * 255), 'Rectangle', bboxes, labels);
% 
%         % Ajouter le masque superposé à l'image annotée
%         final_image = imadd(uint8(annotated_image), uint8(mask_overlay * 255));
% 
%         % Afficher l'image annotée avec les masques superposés
%         figure;
%         imshow(final_image);
%         title(sprintf('Frame %d - Annotations et Masques', frame_idx));
%         drawnow;
%     end
% end

% Vérification de la matrice
disp('Matrice tmpout construite avec succès.');
disp(size(tmpout));  % Affiche les dimensions : [H, W, num_classes, num_frames]


    % Ajouter les résultats dans les canaux appropriés
  image = roiobj.image;
  
disp('Traitement des résultats terminé.');

image(:,:,pixresults,frames)=tmpout;
%image(:,:,pixresults2,frames)=tmpout2;

fprintf('\n');





