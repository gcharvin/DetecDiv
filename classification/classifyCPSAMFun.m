function [data, image] = classifyCPSAMFun(roiobj, classif, classifier, varargin)
% Segmentation avec CellposeSAM sans tracking (optionnel : tracking basique hongrois)
%
% Selon classif.outputType :
%   - 'proba'         : écrit une carte de probabilité (cellprob) dans un channel non indexé
%                       nommé [classif.strid '_cellprob'].
%   - 'segmentation'  : écrit un masque d'instances (comme avant) dans un channel indexé
%                       nommé ['results_' classif.strid '_' classif.classes{1}].
%   - 'postprocessing': idem 'segmentation' ici ; le post-traitement sera appliqué ailleurs.

frames      = [];
doTracking  = true;
channel     = classif.channelName;
gpu         = 0;

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
data  = roiobj.data;
if isempty(data)
    roiobj.load('data');
    data = roiobj.data;
end

pix = roiobj.findChannelID(channel);
if iscell(pix)
    pix = cell2mat(pix);
end

% --- Type de sortie demandé ---
if isfield(classif, 'outputType') && ~isempty(classif.outputType)
    outputType = classif.outputType;
else
    outputType = 'segmentation'; % comportement historique par défaut
end

% Pour la segmentation, on garde la logique 'pixresults' existante (un channel par classe)
pixresults = [];
cd = 1;
if ~strcmp(outputType, 'proba')
    for i = 1:numel(classif.classes)
        pixresultstmp = findChannelID(roiobj, ['results_' classif.strid '_' classif.classes{i}]);
        if isempty(pixresultstmp)
            pixresults = [pixresults size(roiobj.image,3)+cd]; %#ok<AGROW>
            cd = cd+1;
        else
            pixresults = [pixresults pixresultstmp]; %#ok<AGROW>
        end
    end
end

% Préparation des images pour CellposeSAM
gfp = uint8(zeros(size(image, 1), size(image, 2), numel(pix), numel(frames)));
for i = 1:numel(frames)
    tmp = image(:, :, pix, frames(i));
    gfp(:, :, :, i) = uint8(255 * mat2gray(tmp));
end

tmp_mat_path = fullfile(classif.path, 'tmp.mat');
save(tmp_mat_path, 'gfp', 'frames');  % on sauvegarde aussi frames

% Paramètres de segmentation
diameter        = classif.trainingParam.diameter;
flow_threshold  = classif.trainingParam.flow_threshold;

if isfield(classif.trainingParam, 'min_size') && ~isempty(classif.trainingParam.min_size)
    min_size = classif.trainingParam.min_size;
else
    min_size = 10;
end
if isfield(classif.trainingParam, 'cell_prob_threshold') && ~isempty(classif.trainingParam.cell_prob_threshold)
    cellprob_threshold = classif.trainingParam.cell_prob_threshold;
else
    cellprob_threshold = 0;
end

gpu_flag = "False";
if gpu == 1, gpu_flag = "True"; end

% ==== Vérification modèle entraîné localement ====
model_dir        = fullfile(classif.path, 'models');
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
model_path_clean   = strrep(model_path_to_use, '\', '/');

% On passe outputType jusqu'au script Python
if strcmp(outputType, 'proba')
    mode_str = 'proba';
else
    % 'segmentation' ou 'postprocessing' -> on délivre des masks d'instances
    mode_str = 'segmentation';
end

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
    "mode = '%s'\n" + ...
    "\n" + ...
    "model = models.CellposeModel(gpu=%s, pretrained_model=r'%s')\n" + ...
    "print('Modèle chargé depuis :', r'%s')\n" + ...
    "\n" + ...
    "H, W = images[0].shape[:2]\n" + ...
    "if mode == 'segmentation':\n" + ...
    "    masks_all = np.zeros((H, W, 1, len(frames_list)), dtype=np.uint16)\n" + ...
    "elif mode == 'proba':\n" + ...
    "    cellprob_all = np.zeros((H, W, 1, len(frames_list)), dtype=np.float32)\n" + ...
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
    "    if mode == 'segmentation':\n" + ...
    "        print(f'[Frame {frame_idx}] labels=', int(np.max(masks)))\n" + ...
    "        masks_all[:, :, 0, i] = masks.astype(np.uint16)\n" + ...
    "    elif mode == 'proba':\n" + ...
    "        # flows[1] est la carte de probabilité (cell probability) dans Cellpose 2.x\n" + ...
    "        cellprob = flows[1]\n" + ...
    "        cellprob_all[:, :, 0, i] = cellprob.astype(np.float32)\n" + ...
    "\n" + ...
    "out = {'frames_list': frames_list}\n" + ...
    "if mode == 'segmentation':\n" + ...
    "    out['masks_all'] = masks_all\n" + ...
    "elif mode == 'proba':\n" + ...
    "    out['cellprob_all'] = cellprob_all\n" + ...
    "sio.savemat(os.path.join(r'%s', 'results.mat'), out)\n" + ...
    "print('CellposeSAM terminé.')\n", ...
    tmp_mat_path_clean, ...
    mode_str, ...
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
test = select_and_load_conda_env; %#ok<NASGU>

% run python routine
pyrunfile(py_path);

% ==== Lecture des résultats depuis results.mat ====
res = load(fullfile(classif.path, 'results.mat'));
frames_list = res.frames_list;

if strcmp(outputType, 'proba')
    % --- MODE PROBA : on intègre la carte de probabilité comme channel non indexé ---
    if ~isfield(res, 'cellprob_all')
        error('classifyCPSAMFun: no cellprob_all found in results.mat while outputType=''proba''.');
    end
    tmpproba = res.cellprob_all;   % (H, W, 1, Nframes)

    % Nom du channel : [classif.strid '_cellprob']
    chNameProba = [classif.strid '_cellprob'];
    pixproba = findChannelID(roiobj, chNameProba);
    if isempty(pixproba)
        pixproba = size(image, 3) + 1;
        % Idéalement, il faudra aussi déclarer ce nouveau channel dans roiobj (meta)
        % via la méthode adaptée dans ta classe roi.
    end

    % Intégration dans l'image (on suppose que type double/single est accepté)
    image(:,:,pixproba, frames_list) = tmpproba;

    disp('✅ Carte de probabilité CellposeSAM intégrée dans image (mode proba).');

else
    % --- MODE SEGMENTATION (ou postprocessing) : masque d'instances + tracking optionnel ---
    if ~isfield(res, 'masks_all')
        error('classifyCPSAMFun: no masks_all found in results.mat while outputType=''segmentation''.');
    end
    tmpout = res.masks_all;   % (H, W, 1, Nframes)

    % Normalisation des IDs frame par frame
    for f = 1:size(tmpout, 4)
        labels = unique(tmpout(:,:,1,f));
        labels(labels == 0) = [];
        new_frame = zeros(size(tmpout(:,:,1,f)), 'uint16');
        for k = 1:numel(labels)
            new_frame(tmpout(:,:,1,f) == labels(k)) = uint16(k);
        end
        tmpout(:,:,1,f) = new_frame;
    end

    if doTracking
        tmpout = trackMasksHungarian(tmpout);
    end

    % Intégration : même logique qu'avant
    image(:,:,pixresults, frames_list) = tmpout;
    disp('✅ Masques CellposeSAM intégrés dans image (mode segmentation).');
end

end


function val = formatFloat(x)
if isnan(x)
    val = 'None';
else
    val = num2str(x);
end
end
