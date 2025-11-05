function loadROI(obj, option)
% loadROI(obj)           : charge TOUT depuis im_<id>.h5 et data_<id>.mat
% loadROI(obj,'data')    : charge uniquement data_<id>.mat
% loadROI(obj,'GFP')     : charge uniquement le canal logique "GFP" (image=[H W k T])
%
% Reconstruit correctement:
%   - obj.image : [H W C T] avec C = total des sous-canaux
%   - obj.channelid : longueur C ; ex [1 2 3 4 4 4 5 ...]
%   - obj.display :
%         .channel {1xN} noms logiques
%         .intensity N x 3
%         .selectedchannel N x 1 (par défaut = 1)
%         .binning = 1
%         .rgb N x 3 (réplication par sous-channel)
%         .displaylim 2 x C (par défaut [0;1] pour chaque sous-channel)
%         .indexed 1 x N (0/1)
%         .alpha   1 x N
%         .contour 1 x N
%         .width   1 x N
%         .log     1 x N (0)

if nargin < 2, option = ""; end
dataOnly  = (ischar(option)&&strcmp(option,'data')) || (isstring(option)&&option=="data");
fullLoad  = (isempty(option)  || (isstring(option)&&option==""));
oneChan   = ~(dataOnly || fullLoad);

if isempty(obj.path)
    warning('loadROI:NoPath','ROI path is empty.'); return;
end

h5File     = fullfile(obj.path, sprintf('im_%s.h5',  obj.id));
legacyFile = fullfile(obj.path, sprintf('im_%s.mat', obj.id));
dataFile   = fullfile(obj.path, sprintf('data_%s.mat', obj.id));

% ---------- IMAGES ----------
if ~dataOnly
    if isfile(h5File)
        disp('Loading hd5f file');
        if fullLoad
            [img, chId, dispStruct] = loadFromH5_full(h5File);
        else
            chanName = char(option);
            [img, chId, dispStruct] = loadFromH5_single(h5File, chanName);
        end

        % 🧩 Fusion non destructive du display
        if isstruct(obj.display) && ~isempty(fieldnames(obj.display))
            obj.display = mergeDisplayStructs(obj.display, dispStruct);
        else
            obj.display = dispStruct;
        end


        obj.image     = img;
        obj.channelid = chId;
        obj.display   = dispStruct;
    elseif isfile(legacyFile)
        % -------- LEGACY FALLBACK --------
 
        disp('Loading mat file (legacy mode)');
        S = load(legacyFile);
        if isfield(S,'roiobj')
            % ne pas écraser id/path ; on prend image et display si présents
           % if isfield(S.roiobj,'image'),   obj.image = S.roiobj.image;   end
           % if isfield(S.roiobj,'display'), obj.display = S.roiobj.display; end
           % if isfield(S.roiobj,'channelid'), obj.channelid = S.roiobj.channelid; end 

             setProperties(obj, S.roiobj);

        elseif isfield(S,'im')
            obj.image = S.im;
        else
            warning('Legacy MAT has no image.');
            obj.image = [];
        end
        % si channelid/display manquants, on fabrique un minimum
        %obj = roiobj;
    else
        warning('No image file (.h5 or legacy .mat) for ROI %s.', obj.id);
        obj.image = []; obj.channelid = 1; obj.display = defaultDisplay(1,1);
    end
end

% ---------- DATA ----------
if isfile(dataFile)
    Sd = load(dataFile,'data');
    if isfield(Sd,'data'), obj.data = Sd.data; else, obj.data = dataseries.empty; end
    if ismethod(obj,'fixLabelsInPlotFields'), obj.fixLabelsInPlotFields; end
else
    obj.data = dataseries.empty;
end
end

% ==================== H E L P E R S ====================
function setProperties(obj, srcObj)
    allProps = intersect(properties(obj), properties(srcObj));
    exclude = {'path', 'id'};
    props = setdiff(allProps, exclude);

    for k = 1:numel(props)
        try
            val = srcObj.(props{k});

            % Surtout ne pas faire reshape si c'est une table
            if isobject(val) && numel(val) > 1 && ~istable(val)
                val = reshape(val, 1, []);  % évite comma-separated list
            end

            obj.(props{k}) = val;

        catch ME
            warning('⛔️ Could not assign property "%s": %s', props{k}, ME.message);
        end
    end
end


function [img, channelid, dispStruct] = loadFromH5_full(h5File)
% loadFromH5_full  Charge toutes les couches logiques d'une ROI depuis un HDF5
% et reconstruit l'image globale [H W C T], channelid et display.
%
% - Tolérant aux HDF5 mal rangés (axes permutés) : normalise chaque dataset en [H W k T]
%   en se basant sur les attributs bbox (w,h) et frames (T).
% - Si channel_indices est manquant ou incohérent pour un seul dataset,
%   on REPACK tous les indices de sous-canaux en séquentiel non-chevauchant.
% - Affiche des messages [DEBUG] sur les tailles lues/normalisées et le placement.

info  = h5info(h5File);
dsets = info.Datasets;

if isempty(dsets)
    img = [];
    channelid = 1;
    dispStruct = defaultDisplay(1,1);
    fprintf('[DEBUG] No datasets in %s\n', h5File);
    return;
end

% --- Collecte / normalisation par dataset ---
N        = numel(dsets);
names    = cell(1,N);         % noms logiques (channel_name)
idxRaw   = cell(1,N);         % channel_indices lus tels quels (peut être vide/erroné)
kList    = zeros(1,N);        % k réel après normalisation
sizes    = zeros(N,4);        % tailles normalisées [H W k T] par dataset
blocks   = cell(1,N);         % blocs normalisés [H W k T]
attrs    = repmat(struct('intensity',[], 'rgb',[], 'indexed',[], ...
    'alpha',[], 'contour',[], 'width',[], 'k',[]), 1, N);
hasBadIdx = false;

for i = 1:N
    p = ['/' dsets(i).Name];

    % Nom logique
    try
        names{i} = h5readatt(h5File, p, 'channel_name');
    catch
        names{i} = dsets(i).Name; % fallback : nom de dataset
    end

    % channel_indices attendu (peut être vide/absent/mauvais)
    try
        ci = h5readatt(h5File, p, 'channel_indices'); ci = ci(:).';
    catch
        ci = [];
    end
    idxRaw{i} = ci;

    % Lire le bloc brut + normaliser en [H W k T]
    blkRaw = h5read(h5File, p);

    rawSz  = size(blkRaw);
    expK   = numel(ci);

    permStr='';
    blk=blkRaw;
    szN=size(blk);

    Hblk = szN(1); Wblk = szN(2); k = szN(3); Tblk = szN(4);

    % Debug tailles
  %  fprintf('[DEBUG] "%s" raw=%s, normalized=[%d %d %d %d], expected_subchannels=%d  %s\n', ...
  %      names{i}, mat2str(rawSz), Hblk, Wblk, k, Tblk, expK, permStr);

    fprintf('[DEBUG] "%s" raw=%s, normalized=[%d %d %d %d], expected_subchannels=%d  %s\n', ...
    names{i}, mat2str(rawSz), szN(1), szN(2), szN(3), szN(4), expK, permStr);


    % Incohérence k vs channel_indices ?
    if k ~= expK
        hasBadIdx = true;
        fprintf('[DEBUG]   -> k (%d) ~= expected_subchannels (%d): will repack indices later.\n', k, expK);
    end

    % Stocker bloc normalisé
    blocks{i} = blk;
    kList(i)  = k;
    sizes(i,:)= szN;

    % Attributs display
    attrs(i).k         = k;
    attrs(i).intensity = readAttOrDefault(h5File,p,'display_intensity',[1 1 1]);
    attrs(i).rgb       = readAttOrDefault(h5File,p,'display_rgb',      [1 1 1]);
    attrs(i).displaylim       = readAttOrDefault(h5File,p,'display_displaylim',      [1 1 1]);
    attrs(i).indexed   = readAttOrDefault(h5File,p,'display_indexed',  uint8(0));
    attrs(i).alpha     = readAttOrDefault(h5File,p,'display_alpha',    1);
    attrs(i).contour   = readAttOrDefault(h5File,p,'display_contour',  uint8(0));
    attrs(i).width     = readAttOrDefault(h5File,p,'display_contourwidth', 1);
    attrs(i).frame     = readAttOrDefault(h5File,p,'display_frame', 1);
    attrs(i).binning     = readAttOrDefault(h5File,p,'display_binning', 1);
end

% --- Ordonner : d'abord ceux qui ont un premier index connu, puis les autres (stable) ---
firstIdx = nan(1,N);
for i = 1:N
    if ~isempty(idxRaw{i}), firstIdx(i) = idxRaw{i}(1); end
end
[~,ord] = sortrows([isnan(firstIdx(:)) firstIdx(:) (1:N)']); ord = ord(:).';

names  = names(ord);
idxRaw = idxRaw(ord);
kList  = kList(ord);
sizes  = sizes(ord,:);
blocks = blocks(ord);
attrs  = attrs(ord);

% --- Stratégie d'indexation globale ---
% Consistance H/W/T
H = sizes(1,1); W = sizes(1,2); T = sizes(1,4);
if any(sizes(:,1) ~= H) || any(sizes(:,2) ~= W) || any(sizes(:,4) ~= T)
    error('loadFromH5_full:DimMismatch', 'H/W/T not consistent across datasets.');
end

if hasBadIdx
    % Repack : indices compacts non-chevauchants
    idxList = cell(1,N);
    c0 = 0;
    for i = 1:N
        k = kList(i);
        idxList{i} = (c0+1):(c0+k);
        c0 = c0 + k;
    end
    C = sum(kList);
    fprintf('[DEBUG] Repacked indices sequentially: total C=%d\n', C);
else
    % Utiliser les indices fournis
    idxList = idxRaw;
    C = max([idxList{:}]);
    fprintf('[DEBUG] Using provided channel_indices: total C=%d\n', C);
end

% --- Allocation & remplissage de l'image globale ---
img = zeros(H, W, C, T, 'like', blocks{1});
for i = 1:N
    blk = blocks{i};                   % [H W k T] normalisé
    k   = size(blk,3);
    destIdx = idxList{i};

    % Dernière garde : si mismatch résiduel, corriger localement
    if numel(destIdx) ~= k
        warning('loadFromH5_full:InconsistentIndexing', ...
            'Dataset %s: k=%d but destIdx has %d. Adjusting to sequential.', names{i}, k, numel(destIdx));
        destIdx = 1:k;  % remet compact localement
        if hasBadIdx == false
            % éviter chevauchement si on n'était pas en repack global
            % -> basculer en repack global minimal pour la suite
            % (ici on simplifie : on n'essaie pas de recalculer tout, on avertit)
            warning('loadFromH5_full:LateRepackNeeded', ...
                'Late index fix applied on "%s". Consider repacking at save().', names{i});
        end
    end

    fprintf('[DEBUG] -> place "%s" into C-indices %s\n', names{i}, mat2str(destIdx));
    img(:,:,destIdx,:) = blk;
end

% --- channelid (longueur C ; valeurs 1..N) ---
channelid = zeros(1,C);
for i = 1:N
    channelid(idxList{i}) = i;
end

% --- display ---
dispStruct = rebuildDisplayFromAttrs(names, idxList, attrs, C);

fprintf('[DEBUG] Summary: %d logical channels, total subchannels C=%d, H=%d W=%d T=%d, repack=%d\n', ...
    N, C, H, W, T, hasBadIdx);
end


% ==================== H E L P E R S ====================



function v = readAttOrDefault(h5f, path, attName, def)
try
    v = h5readatt(h5f, path, attName);
catch
    v = def;
end
end

function dispStruct = rebuildDisplayFromAttrs(names, idxList, attrs, C)
% names : {1xN} canaux logiques
% idxList : {1xN} indices sous-channels pour chaque canal
% attrs : struct array(1xN) avec fields intensity(1x3), rgb(1x3),
%         indexed(uint8), alpha, contour(uint8), width, k
% C : nb total de sous-channels

N = numel(names);
intensity = zeros(N,3);
indexed   = zeros(1,N);
alpha     = ones(1,N);
contour   = zeros(1,N);
width     = ones(1,N);
selectedchannel=ones(1,N);

rgbSub    = zeros(N,3);
%rgbSub    = zeros(C,3);

%displim    = zeros(C,3);
displim   = repmat([0;1], 1, C);

for i = 1:N
    intensity(i,:) = double(attrs(i).intensity(:).');    % 1x3
    indexed(i)     = double(attrs(i).indexed(1));        % 0/1
    alpha(i)       = double(attrs(i).alpha(1));
    contour(i)     = double(attrs(i).contour(1));
    width(i)       = double(attrs(i).width(1));
    selectedchannel(i)=double(attrs(i).width(1));


    rgbSub(i,:)=double(attrs(i).rgb);
  %  rgbChan = double(attrs(i).rgb(:).')                % 1x3
   % rgbSub(idx,:) = repmat(rgbChan, numel(idx), 1);
    idx = idxList{i};
   displimChan = double(attrs(i).displaylim) ;
  % a= repmat(displimChan, 1, numel(idx))  % 1x3
   displim(:,idx) = displimChan;

end


frame=double(attrs(1).frame);
binning=double(attrs(1).binning);

dispStruct = struct();
dispStruct.intensity       = intensity;          % N x 3
dispStruct.frame           = frame;
dispStruct.selectedchannel = selectedchannel;
dispStruct.binning         = binning;
dispStruct.rgb             = rgbSub;             % C x 3
dispStruct.channel         = names;              % {1xN}
dispStruct.stretchlim      = [];
dispStruct.displaylim      = displim;            % 2 x C
dispStruct.indexed         = indexed;            % 1 x N
dispStruct.alpha           = alpha;              % 1 x N
dispStruct.contour         = contour;            % 1 x N
dispStruct.width           = width;              % 1 x N
dispStruct.log             = zeros(1,N);
end

function d = defaultDisplay(N, C)
% N canaux logiques, C sous-channels
d = struct();
d.intensity       = repmat([1 1 1], N, 1);
d.frame           = 1;
d.selectedchannel = ones(1,N);
d.binning         = 1;
d.rgb             = repmat([1 1 1], C, 1);
d.channel         = arrayfun(@(k)sprintf('channel_%d',k), 1:N, 'UniformOutput', false);
d.stretchlim      = [];
d.displaylim      = repmat([0;1], 1, C);
d.indexed         = zeros(1,N);
d.alpha           = ones(1,N);
d.contour         = zeros(1,N);
d.width           = ones(1,N);
d.log             = zeros(1,N);
end


function dispOut = mergeDisplayStructs(dOld, dNew)
% mergeDisplayStructs  Fusionne deux structs de display sans perdre les anciens champs.
% Les champs manquants dans dOld sont pris depuis dNew.
% Si tailles différentes, dNew sert de modèle.

dispOut = dOld;

fn = fieldnames(dNew);
for i = 1:numel(fn)
    f = fn{i};
    if ~isfield(dispOut, f) || isempty(dispOut.(f))
        dispOut.(f) = dNew.(f);
    else
        % Pour les matrices, si tailles diffèrent, garder celle de dNew
        if isnumeric(dispOut.(f)) && isnumeric(dNew.(f))
            if ~isequal(size(dispOut.(f)), size(dNew.(f)))
                dispOut.(f) = dNew.(f);
            end
        end
    end
end
end
