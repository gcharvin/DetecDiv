function [data, image] = classifyCPSAMFun(roiobj, classif, classifier, varargin)
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

pixresults = findChannelID(roiobj, ['results_' classif.strid]);
if isempty(pixresults)
    pixresults = size(image, 3) + 1;
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

% Génération script Python
gpu_flag = 'False';
if gpu == 1
    gpu_flag = 'True';
end

py_script = sprintf(...
    'import os' + ...
    '\nimport h5py' + ...
    '\nimport numpy as np' + ...
    '\nimport scipy.io as sio' + ...
    '\nfrom cellpose import models' + ...
    '\ngfp = sio.loadmat(r"%s")["gfp"]' + ...
    '\ngfp_reord = np.transpose(gfp, (3, 0, 1, 2))' + ...
    '\nif gfp_reord.shape[-1] == 1:' + ...
    '\n    gfp_reord = np.repeat(gfp_reord, 3, axis=-1)' + ...
    '\nimages = [img.astype(np.uint8) for img in gfp_reord]' + ...
    '\nmodel = models.Cellpose(gpu=%s, model_type="sam")' + ...
    '\noutput_path = os.path.join(r"%s", "results.h5")' + ...
    '\nwith h5py.File(output_path, "w") as f:' + ...
    '\n    for i, img in enumerate(images):' + ...
    '\n        masks, flows, styles, diams = model.eval(img, diameter=None, channels=[0, 0])' + ...
    '\n        group = f.create_group(f"frame_{i}")' + ...
    '\n        group.create_dataset("masks", data=masks.astype(np.uint16))' + ...
    '\nprint("\u2705 CellposeSAM termin\u00e9.")\n', ...
    strrep(tmp_mat_path, '\\', '/'), gpu_flag, strrep(classif.path, '\\', '/'));

py_path = fullfile(classif.path, 'classify_script.py');
fid = fopen(py_path, 'w');
fprintf(fid, '%s', py_script);
fclose(fid);

pyrunfile(py_path);

% Lecture des résultats
hdf5_path = fullfile(classif.path, 'results.h5');
info = h5info(hdf5_path);
num_frames = numel(info.Groups);
[H, W] = size(image(:,:,1,1));
tmpout = zeros(H, W, 1, num_frames, 'uint16');

for i = 1:num_frames
    gname = info.Groups(i).Name;
    masks = h5read(hdf5_path, [gname, '/masks']);
    labels = unique(masks);
    labels(labels == 0) = [];
    for k = 1:numel(labels)
        mask = masks == labels(k);
        tmpout(:,:,1,i) = tmpout(:,:,1,i) + uint16(mask) * uint16(k);
    end
end

image(:,:,pixresults,frames) = tmpout;

disp('✅ Résultats intégrés dans image');
