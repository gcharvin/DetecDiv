function [data, image] = classifyCPSAM(roiobj, classif, classifier, varargin)
% Segmentation avec CellposeSAM sans tracking (optionnel : tracking basique hongrois)

frames = [];
doTracking = true;
channel = classif.channelName;
gpu = 0;

for i = 1:numel(varargin)
    if strcmp(varargin{i}, 'Frames')
        frames = varargin{i+1};
    elseif strcmp(varargin{i}, 'Channel')
        channel = varargin{i+1};
    elseif strcmp(varargin{i}, 'Exec')
        gpu = varargin{i+1};
    elseif strcmp(varargin{i}, 'Tracking')
        doTracking = varargin{i+1};
    end
end

if isempty(frames)
    frames = 1:size(roiobj.image, 4);
end

image = roiobj.image;
data = roiobj.data;
if isempty(data)
    roiobj.load('data');
    data = roiobj.data;
end

pix = roiobj.findChannelID(channel);
if iscell(pix)
    pix = cell2mat(pix);
end

pixresults=[]; cd=1;
for i=1:numel(classif.classes)
    pixresultstmp=findChannelID(roiobj, ['results_' classif.strid '_' classif.classes{i}]);
    if isempty(pixresultstmp)
        pixresults = [pixresults size(roiobj.image,3)+cd];
        cd = cd+1;
    else
        pixresults = [pixresults pixresultstmp];
    end
end

% Préparation des images
gfp = uint8(zeros(size(image, 1), size(image, 2), numel(pix), numel(frames)));
for i = 1:numel(frames)
    tmp = image(:, :, pix, frames(i));
    gfp(:, :, :, i) = uint8(255 * mat2gray(tmp));
end

tmp_mat_path = fullfile(classif.path, 'tmp.mat');
save(tmp_mat_path, 'gfp', 'frames');  % on sauvegarde aussi frames

% Paramètres de segmentation
% Paramètres de segmentation
diameter = classif.trainingParam.diameter;
flow_threshold = classif.trainingParam.flow_threshold;

% NEW: récupère min_size (et un cellprob_threshold par défaut si absent)
if isfield(classif.trainingParam, 'min_size') && ~isempty(classif.trainingParam.min_size)
    min_size = classif.trainingParam.min_size;
else
    min_size = 10; % défaut raisonnable
end
if isfield(classif.trainingParam, 'cell_prob_threshold') && ~isempty(classif.trainingParam.cell_prob_threshold)
    cellprob_threshold = classif.trainingParam.cell_prob_threshold;
else
    cellprob_threshold = 0; % défaut permissif
end


gpu_flag = "False";
if gpu == 1, gpu_flag = "True"; end

% ==== Vérification modèle entraîné localement ====
model_dir = fullfile(classif.path, 'models');
model_path_to_use = 'sam'; % valeur par défaut
if exist(model_dir, 'dir')
    candidate1 = fullfile(model_dir, classif.strid);
    candidate2 = [candidate1 '.pth'];
    if exist(candidate1, 'file')
        model_path_to_use = candidate1;
    elseif exist(candidate2, 'file')
        model_path_to_use = candidate2;
    end
end

if strcmp(model_path_to_use, 'sam')
    disp('[INFO] Aucun modèle local trouvé, utilisation du modèle CellposeSAM par défaut.');
else
    disp(['[INFO] Modèle local trouvé et utilisé : ' model_path_to_use]);
end

classif_path_clean = strrep(classif.path, '\', '/');
tmp_mat_path_clean = strrep(tmp_mat_path, '\', '/');
model_path_clean = strrep(model_path_to_use, '\', '/');

py_script = sprintf( ...
    "import os\n" + ...
    "import numpy as np\n" + ...
    "import scipy.io as sio\n" + ...
    "import torch\n" + ...
    "from cellpose import models\n" + ...
    "\n" + ...
    "print('torch.cuda.is_available():', torch.cuda.is_available())\n" + ...
    "if torch.cuda.is_available():\n" + ...
    "    print('GPU utilisé :', torch.cuda.get_device_name(0))\n" + ...
    "\n" + ...
    "mat_data = sio.loadmat(r'%s')\n" + ...
    "gfp = mat_data['gfp']\n" + ...
    "frames_list = mat_data['frames'].flatten().astype(int)\n" + ...
    "gfp_reord = np.transpose(gfp, (3, 0, 1, 2))\n" + ...
    "if gfp_reord.shape[-1] == 1:\n" + ...
    "    gfp_reord = np.repeat(gfp_reord, 3, axis=-1)\n" + ...
    "images = [img.astype(np.uint8) for img in gfp_reord]\n" + ...
    "\n" + ...
    "model = models.CellposeModel(gpu=%s, pretrained_model=r'%s')\n" + ...
    "print('Modèle chargé depuis :', r'%s')\n" + ...
    "\n" + ...
    "H, W = images[0].shape[:2]\n" + ...
    "masks_all = np.zeros((H, W, 1, len(frames_list)), dtype=np.uint16)\n" + ...
    "\n" + ...
    "for i, (img, frame_idx) in enumerate(zip(images, frames_list)):\n" + ...
    "    masks, flows, styles = model.eval(\n" + ...
    "        img,\n" + ...
    "        diameter=%s,\n" + ...
    "        channels=[0, 0],\n" + ...
    "        flow_threshold=%s,\n" + ...
    "        cellprob_threshold=%s,\n" + ...
    "        min_size=%d,\n" + ...
    "        resample=True,\n" + ...
    "        normalize=True\n" + ...
    "    )\n" + ...
    "    print(f'[Frame {frame_idx}] labels=', int(np.max(masks)))\n" + ...
    "    masks_all[:, :, 0, i] = masks.astype(np.uint16)\n" + ...
    "\n" + ...
    "sio.savemat(os.path.join(r'%s', 'results.mat'), {'masks_all': masks_all, 'frames_list': frames_list})\n" + ...
    "print('CellposeSAM terminé.')\n", ...
    tmp_mat_path_clean, ...
    gpu_flag, ...
    model_path_clean, ...
    model_path_clean, ...
    formatFloat(diameter), ...
    formatFloat(flow_threshold), ...
    formatFloat(cellprob_threshold), ...
    round(min_size), ...
    classif_path_clean ...
);


py_path = fullfile(classif.path, 'classify_script.py');
fid = fopen(py_path, 'w'); fprintf(fid, '%s', py_script); fclose(fid);

% test the existence of python environment
test=select_and_load_conda_env;

% run python routine
pyrunfile(py_path);

% ==== Lecture des résultats directement depuis .mat ====
res = load(fullfile(classif.path, 'results.mat'));
tmpout = res.masks_all;
frames_list = res.frames_list;

% === Normalisation des IDs frame par frame ===
for f = 1:size(tmpout, 4)
    labels = unique(tmpout(:,:,1,f));
    labels(labels == 0) = []; % enlever le fond
    new_frame = zeros(size(tmpout(:,:,1,f)), 'uint16');
    for k = 1:numel(labels)
        new_frame(tmpout(:,:,1,f) == labels(k)) = uint16(k);
    end
    tmpout(:,:,1,f) = new_frame;
end


if doTracking
    tmpout = trackMasksHungarian(tmpout);
end

image(:,:,pixresults, frames_list) = tmpout;
disp('✅ Résultats intégrés dans image');
end

function val = formatFloat(x)
if isnan(x)
    val = 'None';
else
    val = num2str(x);
end
end

function tracked_masks = trackMasksHungarian(masks4D)
% Hongrois + distance gating ; next_id strictement monotone (pas de saut lié aux frames futures)

[H, W, ~, num_frames] = size(masks4D);
tracked_masks = masks4D;

% --- next_id basé UNIQUEMENT sur la frame 1 ---
ids_f1 = unique(masks4D(:,:,1,1)); ids_f1(ids_f1==0) = [];
if isempty(ids_f1)
    next_id = uint16(1);
else
    next_id = uint16(max(ids_f1) + 1);
end

disp('[Tracking] Début du suivi (Hongrois + distance gating)...');

for t = 1:(num_frames-1)
    mask_t  = tracked_masks(:,:,1,t);
    mask_t1 = masks4D(:,:,1,t+1);   % labels locaux frame t+1 (avant tracking)

    labels_t  = unique(mask_t);  labels_t(labels_t==0) = [];
    labels_t1 = unique(mask_t1); labels_t1(labels_t1==0) = [];

    if isempty(labels_t) || isempty(labels_t1)
        tracked_masks(:,:,1,t+1) = mask_t1; % aucune donnée à apparier, on copie tel quel
        continue;
    end

    % Aires
    areas_t  = arrayfun(@(id) sum(mask_t(:)  == id), labels_t);
    areas_t1 = arrayfun(@(id) sum(mask_t1(:) == id), labels_t1);

    % Centroïdes
    cent_t  = zeros(numel(labels_t),  2);
    cent_t1 = zeros(numel(labels_t1), 2);
    for iL = 1:numel(labels_t)
        [yy, xx] = find(mask_t == labels_t(iL));
        cent_t(iL,:) = [mean(xx), mean(yy)];
    end
    for jL = 1:numel(labels_t1)
        [yy, xx] = find(mask_t1 == labels_t1(jL));
        cent_t1(jL,:) = [mean(xx), mean(yy)];
    end

    % Diamètre médian pour le seuil de distance
    diam_t  = sqrt(4*areas_t  / pi);
    diam_t1 = sqrt(4*areas_t1 / pi);
    med_diam = median([diam_t(:); diam_t1(:)]);
    if isempty(med_diam) || ~isfinite(med_diam) || med_diam==0
        med_diam = min(H,W)/20;
    end
    gate_factor = 3.0;
    dmax = gate_factor * med_diam;

    % Distances (sans pdist2)
    D = zeros(numel(labels_t), numel(labels_t1));
    for iL = 1:numel(labels_t)
        dx = cent_t1(:,1) - cent_t(iL,1);
        dy = cent_t1(:,2) - cent_t(iL,2);
        D(iL,:) = sqrt(dx.^2 + dy.^2);
    end

    % Matrice de coût avec gating distance
    big = 1e6;
    costMat = big * ones(numel(labels_t), numel(labels_t1));
    for iL = 1:numel(labels_t)
        bin_i = (mask_t == labels_t(iL));
        Ai = areas_t(iL);
        for jL = 1:numel(labels_t1)
            if D(iL,jL) > dmax
                continue; % paire interdite
            end
            bin_j = (mask_t1 == labels_t1(jL));
            inter = sum(bin_i(:) & bin_j(:));
            uni   = sum(bin_i(:) | bin_j(:));
            iou = (uni==0) * 0 + (uni>0) * (inter/uni);

            mean_size_pair = (Ai + areas_t1(jL)) / 2;
            size_diff = abs(Ai - areas_t1(jL)) / max(1, mean_size_pair);

            dist_term = 0.2 * (D(iL,jL) / dmax); % léger tie-breaker

            costMat(iL,jL) = (1 - iou) + 0.5*size_diff + dist_term;
        end
    end

    maxAcceptableCost = 1.6;
    [assignments, ~, unassigned_t1] = matchpairs(costMat, maxAcceptableCost);

    % Nouvelle frame avec IDs finaux
    mask_new_t1 = zeros(size(mask_t1), 'uint16');

    % Appariés -> conserver l'ID précédent
    for a = 1:size(assignments,1)
        id_t  = labels_t(assignments(a,1));
        id_t1 = labels_t1(assignments(a,2));
        mask_new_t1(mask_t1 == id_t1) = id_t;
    end

    % Naissances -> IDs neufs monotones (jamais recalculés depuis des frames futures)
    for j = unassigned_t1'
        id_t1 = labels_t1(j);
        mask_new_t1(mask_t1 == id_t1) = next_id;
        next_id = next_id + 1;
    end

    tracked_masks(:,:,1,t+1) = mask_new_t1;
end

disp('[Tracking] Terminé.');
end

