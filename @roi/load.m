function load(obj, option)
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
        disp(['Loading hd5f file: ' h5File]);
        if fullLoad
            [img, chId, dispStruct] = loadFromH5_full(h5File);
        else
            chanName = char(option);
          %  [img, chId, dispStruct] = loadFromH5_single(h5File, chanName);
            [img, chId, dispStruct] = loadFromH5_single(h5File, chanName, obj.image, obj.channelid, obj.display);

        end

        % 🧩 Fusion non destructive du display
        if isstruct(obj.display) && ~isempty(fieldnames(obj.display))
    obj.display = mergeDisplayStructs(obj.display, dispStruct);
        else
    obj.display = dispStruct;
        end


        obj.image     = img;
        obj.channelid = chId;
        
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
    attrs(i).displaylim       = readAttOrDefault(h5File,p,'display_displaylim',      [1 ; 1]);
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

function [img, channelid, dispStruct] = loadFromH5_single(h5File, chanName, img0, chId0, disp0)
% loadFromH5_single
%   - Charge UNIQUEMENT le dataset logique 'chanName' depuis h5File
%   - Le place dans l'hypervolume global [H W C T] aux indices C corrects
%   - Met à jour uniquement les champs de display nécessaires à ce canal
%
% Signatures:
%   [img, channelid, disp] = loadFromH5_single(h5File, chanName)
%   [img, channelid, disp] = loadFromH5_single(h5File, chanName, img0, chId0, disp0)
%
% Entrées optionnelles:
%   img0   : image globale existante [H W C T] (peut être [])
%   chId0  : channelid existant (1xC) (peut être [])
%   disp0  : struct display existant (peut être [])

if nargin < 3, img0  = []; end
if nargin < 4, chId0 = []; end
if nargin < 5, disp0 = struct(); end

info  = h5info(h5File);
dsets = info.Datasets;

if isempty(dsets)
    error('loadFromH5_single:NoDatasets','No datasets in %s', h5File);
end

% --- Trouver le dataset par "channel_name" (attribut) ou par nom
target = [];
target_idx = [];
for i = 1:numel(dsets)
    p = ['/' dsets(i).Name];
    nm = dsets(i).Name;
    chn = nm;
    try
        chn = h5readatt(h5File, p, 'channel_name');
    catch
    end
    if strcmpi(chn, chanName) || strcmpi(nm, chanName)
        target = dsets(i);
        target_idx = i;
        break;
    end
end
if isempty(target)
    error('loadFromH5_single:NotFound','Channel "%s" not found in %s', chanName, h5File);
end

pTarget = ['/' target.Name];

% --- Lire le bloc + normaliser [H W k T]
blkRaw = h5read(h5File, pTarget);
szR = size(blkRaw);
% on suppose déjà rangé [H W k T] (comme ton full loader). Sinon, adapter ici.
switch numel(szR)
    case 2, sz = [szR 1 1];
    case 3, sz = [szR 1];
    otherwise, sz = szR;
end
H = sz(1); W = sz(2); k = sz(3); T = sz(4);
blk = reshape(blkRaw, H, W, k, T);  % normalisation simple

% --- Lire/estimer les indices globaux pour ce canal
% Essai 1 : utiliser channel_indices s'il existe
try
    idxProvided = h5readatt(h5File, pTarget, 'channel_indices'); idxProvided = idxProvided(:).';
catch
    idxProvided = [];
end

% Pour connaître le C total et les indices occupés par les autres canaux,
% on scanne vite fait les attributs des autres datasets (pas besoin des data)
allIdx = {};
for i = 1:numel(dsets)
    p = ['/' dsets(i).Name];
    try
        ci = h5readatt(h5File, p, 'channel_indices'); ci = ci(:).';
    catch
        ci = [];
    end
    allIdx{i} = ci;
end

% Stratégie d'indexation:
% - Si idxProvided cohérent -> on s'en sert
% - Sinon, si img0 existe -> on append/replace intelligemment
% - Sinon, on repack séquentiel minimal (C = somme k de tous les dsets, si dispo),
%   mais comme on ne charge qu'un canal, on place au début.

destIdx = [];
if ~isempty(idxProvided) && numel(idxProvided) == k
    destIdx = idxProvided;
end

% Taille C existante si img0 fourni
if ~isempty(img0)
    C0 = size(img0,3);
else
    % sinon, déduire un C théorique à partir des attributs si disponibles
    C0 = 0;
    for i = 1:numel(allIdx)
        if ~isempty(allIdx{i})
            C0 = max(C0, max(allIdx{i}));
        end
    end
    if C0 == 0
        % fallback minimal
        C0 = k;
    end
end

% Décide où placer ce bloc:
if isempty(destIdx)
    % Pas d'indices fournis -> on essaye de réutiliser un slot existant
    % si le canal existe déjà dans disp0.channel (par son nom)
    reuse = false;
    if isstruct(disp0) && isfield(disp0,'channel') && ~isempty(disp0.channel)
        % chercher le canal logique par nom exact (insensible à la casse)
        logicalNames = disp0.channel;
        hit = find(strcmpi(logicalNames, chanName), 1);
        if ~isempty(hit) && isfield(disp0,'selectedchannel') && hit <= numel(disp0.selectedchannel)
            % si on connaît déjà combien de sous-canaux affectés à ce logique
            % on reconstitue via chId0 (si dispo)
            if ~isempty(chId0)
                destIdx = find(chId0 == hit);
                % si vide ou tailles différentes, on abandonne la réutilisation
                if numel(destIdx) ~= k
                    destIdx = [];
                else
                    reuse = true;
                end
            end
        end
    end

    if ~reuse
        % Append à la fin
        start = C0 + 1;
        destIdx = start:(start + k - 1);
        C0 = start + k - 1;
    end
else
    % S'assure que C0 couvre destIdx
    C0 = max(C0, max(destIdx));
end

% --- Construire/étendre l'image globale
if isempty(img0)
    img = zeros(H, W, C0, T, 'like', blk);
else
    img = img0;
    % agrandir si nécessaire
    if size(img,1) ~= H || size(img,2) ~= W || size(img,4) ~= T
        error('loadFromH5_single:DimMismatch', 'Existing image dims do not match target dataset dims.');
    end
    if size(img,3) < max(destIdx)
        img(:,:,end+1:max(destIdx),:) = 0;
    end
end

% Place le bloc
img(:,:,destIdx,:) = blk;

% --- Mettre à jour channelid
if isempty(chId0)
    % On doit reconstruire un id logique minimal: 1 logique unique
    channelid = zeros(1, size(img,3));
    channelid(destIdx) = 1;
else
    channelid = chId0;
    if numel(channelid) < size(img,3)
        channelid(end+1:size(img,3)) = 0;
    end
    % Si le canal existe déjà (cas reuse), on garde l'id existant.
    % Sinon, on crée un nouveau "logique" à la fin.
    if all(channelid(destIdx) == 0)
        nextLogical = max(channelid) + 1;
        channelid(destIdx) = nextLogical;
    end
end

% --- Lire les attributs display pour ce canal
att.intensity  = readAttOrDefault(h5File, pTarget, 'display_intensity',  [1 1 1]);
att.rgb        = readAttOrDefault(h5File, pTarget, 'display_rgb',        [1 1 1]);
att.displaylim = readAttOrDefault(h5File, pTarget, 'display_displaylim', [0; 1]);
att.indexed    = readAttOrDefault(h5File, pTarget, 'display_indexed',    uint8(0));
att.alpha      = readAttOrDefault(h5File, pTarget, 'display_alpha',      1);
att.contour    = readAttOrDefault(h5File, pTarget, 'display_contour',    uint8(0));
att.width      = readAttOrDefault(h5File, pTarget, 'display_contourwidth', 1);
att.frame      = readAttOrDefault(h5File, pTarget, 'display_frame',      1);
att.binning    = readAttOrDefault(h5File, pTarget, 'display_binning',    1);

% --- Mettre à jour uniquement ce qu'il faut dans le display
% On part de disp0 si fournit, sinon on crée un squelette minimal
if isempty(disp0) || ~isstruct(disp0) || ~isfield(disp0,'channel')
    % squelette minimal: un seul canal logique
    L = max(channelid);               % nb de canaux logiques
    C = size(img,3);                  % nb de sous-channels
    dispStruct = defaultDisplay(L, C);
else
    dispStruct = disp0;
    % Ajuster tailles C si l'image a grandi
    C = size(img,3);
    if ~isfield(dispStruct,'displaylim') || size(dispStruct.displaylim,2) ~= C
        % on ré-étend/recale displaylim en gardant l'existant
        dlim = repmat([0;1],1,C);
        if isfield(dispStruct,'displaylim') && ~isempty(dispStruct.displaylim)
            oldC = size(dispStruct.displaylim,2);
            dlim(:,1:min(oldC,C)) = dispStruct.displaylim(:,1:min(oldC,C));
        end
        dispStruct.displaylim = dlim;
    end
    if ~isfield(dispStruct,'rgb') || size(dispStruct.rgb,1) ~= max(1,size(dispStruct.intensity,1))
        % Par design chez toi, rgb est de taille N x 3 (un par canal logique)
        % On recale plus bas au bon index logique
    end
end

% Nom logique du canal (depuis attribut)
try
    logicalName = h5readatt(h5File, pTarget, 'channel_name');
catch
    logicalName = target.Name;
end

% Assigner / créer le canal logique correspondant
%   - on affecte les propriétés "par canal logique" (intensity, indexed, alpha, contour, width, selectedchannel)
%   - et les colonnes de displaylim correspondant aux sous-canaux destIdx
%   - pour le nom, on place/étend dispStruct.channel

logicalId = unique(channelid(destIdx));
if numel(logicalId) ~= 1
    % sécurité: tous les destIdx doivent appartenir au même logique
    logicalId = logicalId(1);
end

% Assurer la taille des tableaux logiques
Nlog = max(logicalId, isfield(dispStruct,'intensity')*size(dispStruct.intensity,1));
if ~isfield(dispStruct,'intensity') || size(dispStruct.intensity,1) < Nlog
    miss = Nlog - (isfield(dispStruct,'intensity')*size(dispStruct.intensity,1));
    if ~isfield(dispStruct,'intensity') || isempty(dispStruct.intensity)
        dispStruct.intensity = repmat([1 1 1], Nlog, 1);
    else
        dispStruct.intensity(end+1:end+miss,:) = repmat([1 1 1], miss, 1);
    end
end
fields1xN = {'indexed','alpha','contour','width','selectedchannel','log'};
for f = fields1xN
    ff = f{1};
    if ~isfield(dispStruct,ff) || numel(dispStruct.(ff)) < Nlog
        cur = [];
        if isfield(dispStruct,ff), cur = dispStruct.(ff); end
        def = 0; if any(strcmp(ff,{'alpha','width','selectedchannel'})), def = 1; end
        dispStruct.(ff) = [cur, repmat(def, 1, Nlog - numel(cur))];
    end
end
if ~isfield(dispStruct,'channel') || numel(dispStruct.channel) < Nlog
    cur = {};
    if isfield(dispStruct,'channel') && ~isempty(dispStruct.channel), cur = dispStruct.channel; end
    cur(end+1:Nlog) = arrayfun(@(k)sprintf('channel_%d',k), (numel(cur)+1):Nlog, 'UniformOutput', false);
    dispStruct.channel = cur;
end

% Appliquer les attributs *pour ce canal logique*
dispStruct.channel{logicalId}     = logicalName;
dispStruct.intensity(logicalId,:) = double(att.intensity(:).');
dispStruct.indexed(logicalId)     = double(att.indexed(1));
dispStruct.alpha(logicalId)       = double(att.alpha(1));
dispStruct.contour(logicalId)     = double(att.contour(1));
dispStruct.width(logicalId)       = double(att.width(1));
if ~isfield(dispStruct,'frame') || isempty(dispStruct.frame)
    dispStruct.frame = double(att.frame);
else
    % on ne change pas le frame global si déjà défini
end
if ~isfield(dispStruct,'binning') || isempty(dispStruct.binning)
    dispStruct.binning = double(att.binning);
end
% selectedchannel: on ne touche pas si déjà défini, sinon 1 par défaut
if ~isfield(dispStruct,'selectedchannel') || isempty(dispStruct.selectedchannel)
    dispStruct.selectedchannel = ones(1, Nlog);
end
if ~isfield(dispStruct,'log') || isempty(dispStruct.log)
    dispStruct.log = zeros(1, Nlog);
end

% displaylim par sous-canal (colonnes destIdx)
dlimChan = double(att.displaylim);
if isequal(size(dlimChan), [1 2]), dlimChan = dlimChan(:); end % robustesse
if numel(dlimChan) == 2
    dlimChan = repmat(dlimChan(:), 1, k);  % 2 x k
end
if size(dlimChan,1) ~= 2 || size(dlimChan,2) ~= k
    % sécurité: fallback [0;1]
    dlimChan = repmat([0;1], 1, k);
end
dispStruct.displaylim(:, destIdx) = dlimChan;

% rgb "par canal logique" (conforme à ton full loader actuel)
% NB: ton full loader mettait rgb comme N x 3 (un par canal logique)
if ~isfield(dispStruct,'rgb') || size(dispStruct.rgb,1) < Nlog
    cur = [];
    if isfield(dispStruct,'rgb') && ~isempty(dispStruct.rgb), cur = dispStruct.rgb; end
    dispStruct.rgb = [cur; repmat([1 1 1], Nlog - size(cur,1), 1)];
end
dispStruct.rgb(logicalId,:) = double(att.rgb(:).');

% stretchlim inchangé (si existant)
% fin.

fprintf('[DEBUG] Single-load: placed "%s" into C-indices %s (logical=%d). H=%d W=%d k=%d T=%d\n', ...
    chanName, mat2str(destIdx), logicalId, H, W, k, T);

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

    % selectedchannel doit refléter le canal actif (par défaut 1)
    % -> ne surtout pas copier 'width'
    selectedchannel(i) = 1;

    % rgb est stocké par CANAL LOGIQUE => N x 3
    rgbSub(i,:) = double(attrs(i).rgb);

    % display limits pour les sous-canaux
    idx = idxList{i};
    displimChan = double(attrs(i).displaylim);
    if numel(displimChan)==2
        displimChan = repmat(displimChan(:), 1, numel(idx)); % 2 x k
    end
    displim(:,idx) = displimChan;
end

frame   = double(attrs(1).frame);
binning = double(attrs(1).binning);

dispStruct = struct();
dispStruct.intensity       = intensity;          % N x 3
dispStruct.frame           = frame;
dispStruct.selectedchannel = selectedchannel;    % 1 x N
dispStruct.binning         = binning;
dispStruct.rgb             = rgbSub;             % N x 3  ✅
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
% Favorise dNew (valeurs lues du fichier) champ par champ.
dispOut = dOld;

fn = fieldnames(dNew);
for i = 1:numel(fn)
    f = fn{i};
    if ~isfield(dispOut,f) || isempty(dispOut.(f))
        dispOut.(f) = dNew.(f);
        continue;
    end

    a = dispOut.(f);
    b = dNew.(f);

    % Si types numériques/logicaux -> on préfère b (la lecture H5)
    if (isnumeric(a)||islogical(a)) && (isnumeric(b)||islogical(b))
        % Aligne la taille si nécessaire (on ne jette pas b)
        if ~isequal(size(a), size(b))
            dispOut.(f) = b;
        else
            dispOut.(f) = b;  % new wins
        end
    elseif iscell(a) && iscell(b)
        % Pour cell arrays (ex: channel), prends b si tailles diffèrent, sinon b aussi
        if ~isequal(size(a), size(b))
            dispOut.(f) = b;
        else
            dispOut.(f) = b;
        end
    else
        % Par défaut, b (plus récent)
        dispOut.(f) = b;
    end
end
end
