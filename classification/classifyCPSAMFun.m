function [data, image] = classifyCPSAM(roiobj, classif, classifier, varargin)
% Segmentation avec CellposeSAM sans tracking

frames = [];
channel = classif.channelName;
gpu = 0;

for i = 1:numel(varargin)
    if strcmp(varargin{i}, 'Frames')
        frames = varargin{i+1};
    elseif strcmp(varargin{i}, 'Channel')
        channel = varargin{i+1};
    elseif strcmp(varargin{i}, 'Exec')
        gpu = varargin{i+1};
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

pixresults=[]; % channels where each mask for each class is stored
cd=1;
for i=1:numel(classif.classes)
    pixresultstmp=findChannelID(roiobj,['results_' classif.strid '_' classif.classes{i}]);
    if numel(pixresultstmp)==0
        pixresults=[pixresults size(roiobj.image,3)+cd];
        cd=cd+1;
    else
        pixresults=[pixresults pixresultstmp];
    end
end

% Préparation des images
gfp = uint8(zeros(size(image, 1), size(image, 2), numel(pix), numel(frames)));
for i = 1:numel(frames)
    tmp = image(:, :, pix, frames(i));
    tmp_uint8 = uint8(255 * mat2gray(tmp));
    gfp(:, :, :, i) = tmp_uint8;
end

tmp_mat_path = fullfile(classif.path, 'tmp.mat');
save(tmp_mat_path, 'gfp');

% Paramètres de segmentation depuis classif.trainingParam
diameter = classif.trainingParam.diameter;

% if isnan(diameter)
%     diameter='None';
% else
%    diameter=num2str(diameter);
% end

flow_threshold = classif.trainingParam.flow_threshold;
mask_threshold = classif.trainingParam.mask_threshold;

% Génération script Python
gpu_flag = "False";
if gpu == 1
    gpu_flag = "True";
end

classif_path_clean = strrep(classif.path, '\\', '/');
if classif_path_clean(end) == '\\'
    classif_path_clean(end) = [];
end

tmp_mat_path_clean = strrep(tmp_mat_path, '\\', '/');

py_script = sprintf( ...
    "import os\n" + ...
    "import h5py\n" + ...
    "import numpy as np\n" + ...
    "import scipy.io as sio\n" + ...
    "import torch\n" + ...
    "from cellpose import models\n" + ...
    "\n" + ...
    "print('torch.cuda.is_available():', torch.cuda.is_available())\n" + ...
    "if torch.cuda.is_available():\n" + ...
    "    print('GPU utilisé :', torch.cuda.get_device_name(0))\n" + ...
    "\n" + ...
    "gfp = sio.loadmat(r'%s')['gfp']\n" + ...
    "gfp_reord = np.transpose(gfp, (3, 0, 1, 2))\n" + ...
    "if gfp_reord.shape[-1] == 1:\n" + ...
    "    gfp_reord = np.repeat(gfp_reord, 3, axis=-1)\n" + ...
    "images = [img.astype(np.uint8) for img in gfp_reord]\n" + ...
    "\n" + ...
    "model = models.CellposeModel(gpu=%s)\n" + ...
    "print('Device du modèle :', model.device)\n" + ...
    "output_path = os.path.join(r'%s', 'results.h5')\n" + ...
    "with h5py.File(output_path, 'w') as f:\n" + ...
    "    for i, img in enumerate(images):\n" + ...
    "        masks, flows, styles = model.eval(img, diameter=%s, channels=[0, 0], flow_threshold=%s)\n" + ...
    "        print(f'[Frame {i}] Nombre de labels :', np.max(masks))\n" + ...
    "        group = f.create_group(f'frame_{i}')\n" + ...
    "        group.create_dataset('masks', data=masks.astype(np.uint16))\n" + ...
    "\n" + ...
    "print('CellposeSAM terminé.')\n", ...
    tmp_mat_path_clean, gpu_flag, classif_path_clean, formatFloat(diameter), num2str(flow_threshold));

py_path = fullfile(classif.path, 'classify_script.py');
fid = fopen(py_path, 'w');
fprintf(fid, '%s', py_script);
fclose(fid);

pyrunfile(py_path);

% Lecture des résultats
hdf5_path = fullfile(classif.path, 'results.h5');
info = h5info(hdf5_path);
% Extraire les indices de frame à partir des noms
frame_indices = zeros(1, numel(info.Groups));
for k = 1:numel(info.Groups)
    name = info.Groups(k).Name;  % ex: '/frame_12'
    tokens = regexp(name, 'frame_(\d+)', 'tokens');
    if ~isempty(tokens)
        frame_indices(k) = str2double(tokens{1}{1});
    end
end

% Trier selon les indices
[~, sorted_idx] = sort(frame_indices);
info.Groups = info.Groups(sorted_idx);


num_frames = numel(info.Groups);
[H, W] = size(image(:,:,1,1));
tmpout = zeros(H, W, 1, num_frames, 'uint16');

for i = 1:num_frames
    gname = info.Groups(i).Name;
    masks = h5read(hdf5_path, [gname, '/masks']);
    [Hm, Wm] = size(masks);

    if Hm ~= H || Wm ~= W
        masks = masks';
    end

    labels = unique(masks);
    labels(labels == 0) = [];
    for k = 1:numel(labels)
        mask = masks == labels(k);
        tmpout(:,:,1,i) = tmpout(:,:,1,i) + uint16(mask) * uint16(k);
    end
end

image(:,:,pixresults,frames) = tmpout;

disp('✅ Résultats intégrés dans image');

function val = formatFloat(x)
% Return 'None' string if NaN, otherwise float as string
if isnan(x)
    val = 'None';
else
    val = num2str(x);
end

