function [data, image] = classifyCellTRACKTRFun(roiobj, classif, classifier, varargin)
% Inférence Cell-TRACTR sur images brutes + réinjection des masques
% - Exporte les frames MATLAB vers un dossier unique CTC/<dataset>/<seqX...>
% - Lance pipeline.py
% - Relit maskNNN.tif + res_track.txt directement dans .../results/<dataset>/test/CTC/<seqX...>
% - Injecte les masques dans roiobj.image

% --------- Params d'appel ---------
frames = [];
channel = classif.channelName;
gpu = 0; %#ok<NASGU>

for i = 1:numel(varargin)
    if strcmp(varargin{i}, 'Frames'),  frames  = varargin{i+1}; end
    if strcmp(varargin{i}, 'Channel'), channel = varargin{i+1}; end
    if strcmp(varargin{i}, 'Exec'),    gpu     = varargin{i+1}; end
end
if isempty(frames), frames = 1:size(roiobj.image, 4); end

% --------- Données ROI ---------
image = roiobj.image;
data  = roiobj.data;
if isempty(data), roiobj.load('data'); data = roiobj.data; end

% canal à exporter
pix = roiobj.findChannelID(channel);
if iscell(pix), pix = cell2mat(pix); end
if isempty(pix), error('Canal "%s" introuvable dans la ROI.', channel); end

% normalisation/uint8
seq_img = uint8(255 * mat2gray(image(:,:,pix,frames)));

% --------- Chemins (alignés avec YAML d'inférence) ---------
if isfield(classif, 'trainingParam') && isfield(classif.trainingParam, 'data_dir')
    data_dir = classif.trainingParam.data_dir;
else
    data_dir = classif.path; % fallback
end
dataset   = 'test';                           % inférence sur test
repo_path = classif.trainingParam.repo_path;  % racine repo Cell-TRACTR

% res_name : utilise classif.trainingParam.res_name si dispo, sinon 1er dossier
results_root = fullfile(classif.path, 'results');   % parent des runs d'entraînement
if isfield(classif.trainingParam,'res_name') && isfolder(fullfile(results_root, classif.trainingParam.res_name))
    res_name = classif.trainingParam.res_name;
else
    d = dir(results_root); d = d([d.isdir]); names = setdiff({d.name},{'.','..'});
    if isempty(names), error('Aucun run dans %s', results_root); end
    res_name = names{1};
end

% --------- Génère un nom de séquence UNIQUE (sûr en parallèle) ---------
% Format: seq<HHMMSSFFF><r2>  (finit par 2 chiffres pour matcher le regex côté pipeline)
tstamp = datestr(now,'HHMMSSFFF');      % 9 chiffres
r2 = randi(99);                         % 2 chiffres
seqName = sprintf('seq%s%02d', tstamp, r2);

% --------- Export CTC/<dataset>/<seqName> sous data_dir ---------
ctc_root = fullfile(data_dir, 'CTC', dataset, seqName);
if ~exist(ctc_root, 'dir'), mkdir(ctc_root); end

disp('[Cell-TRACTR] Export des frames en TIFF...');
for i = 1:numel(frames)
    fname = sprintf('img_%03d.tif', i-1); % index 0-based
    % (option) si ton checkpoint attend 3 canaux :
    % imwrite(repmat(seq_img(:,:,1,i),[1 1 3]), fullfile(ctc_root, fname));
    imwrite(seq_img(:,:,1,i), fullfile(ctc_root, fname));
end

% --------- Lancement pipeline ---------
pythonScript = fullfile(repo_path, 'src', 'pipeline.py');

cmd = sprintf('python "%s" --results_path "%s" with res_name=%s dataset=%s', ...
    pythonScript, results_root, res_name, dataset);

disp('[Cell-TRACTR] Launching pipeline.py ...');
[status, result] = system(cmd, '-echo');
if status ~= 0
    disp('❌ Erreur pipeline.py :');
    disp(result);
    error('Erreur lors de l''exécution du pipeline Cell-TRACTR.');
end

% --------- Lecture des résultats (sans sous-dossier TRA) ---------
% Arbo attendue (selon ton pipeline) :
% <classif.path>/results/<dataset>/test/CTC/<seqName>/
out_base = fullfile(classif.path, 'results', dataset, 'test');

% Tolère "CTC" ou "ctc"
cand_dirs = { ...
    fullfile(out_base, 'CTC', seqName), ...
    fullfile(out_base, 'ctc', seqName) ...
};
res_dir = '';
for k = 1:numel(cand_dirs)
    if isfolder(cand_dirs{k}), res_dir = cand_dirs{k}; break; end
end
if isempty(res_dir)
    error('Répertoire résultats introuvable. Cherché: %s', strjoin(cand_dirs, ' | '));
end
fprintf('[Cell-TRACTR] Résultats trouvés: %s\n', res_dir);

% --------- Lecture des masques (maskNNN.tif) ---------
fl = dir(fullfile(res_dir, 'mask*.tif'));

H = size(seq_img,1); W = size(seq_img,2);
masks_all = zeros(H, W, 1, numel(frames), 'uint16');  % un masque par frame demandée

if isempty(fl)
    warning('Aucun fichier mask*.tif trouvé dans %s. Pas d''objet détecté ?', res_dir);
else
    % tri naturel si dispo
    fnames = {fl.name};
    if exist('natsortfiles','file'), fnames = natsortfiles(fnames); else, fnames = sort(fnames); end

    % map maskNNN (0-based) -> position dans "frames" (1-based)
    for iFile = 1:numel(fnames)
        fname = fnames{iFile};
        tok = regexp(fname, '^mask(\d+)\.tif$', 'tokens', 'once');
        if isempty(tok), continue; end
        idx0 = str2double(tok{1});          % 0-based écrit par pipeline
        pos  = find(frames == (idx0 + 1), 1, 'first');
        if isempty(pos), continue; end      % masque hors sous-ensemble de frames demandé
        m = imread(fullfile(res_dir, fname));
        if ~isa(m,'uint16'), m = uint16(m); end
        if size(m,1) ~= H || size(m,2) ~= W
            m = imresize(m, [H W], 'nearest');
        end
        masks_all(:,:,1,pos) = m;
    end
end

% (optionnel) Lecture du tracking global si présent
res_track_file = fullfile(res_dir, 'res_track.txt');
if isfile(res_track_file)
    try
        data.res_track = readmatrix(res_track_file);
    catch
        data.res_track = [];
        warning('Impossible de lire res_track.txt (format inattendu).');
    end
else
    data.res_track = [];
end

% --------- Injection dans image ---------
pixresults = size(image,3) + 1;                 % nouveau canal
if size(image,4) < frames(end), image(:,:,:,frames(end)) = 0; end
image(:,:,pixresults,frames) = masks_all;

% (utile si tu veux connaître après coup le nom unique utilisé)
data.seq_name = seqName;

disp('✅ Résultats Cell-TRACTR intégrés.');
end
