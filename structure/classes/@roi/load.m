function load(obj, varargin)
% loadROI(obj)                     : charge TOUT depuis im_<id>.h5 et data_<id>.mat
% loadROI(obj,'data')              : charge uniquement data_<id>.mat (mode historique)
% loadROI(obj,'GFP')               : charge/maj uniquement le canal logique "GFP" (image=[H W k T])
%
% Nouveau (varargin) :
%   load(obj,'Channel','GFP')
%   load(obj,'Channel',{'GFP','phase'})
%   load(obj,'Data')          ou load(obj,'data')      -> data uniquement
%   load(obj,'Data',false)                           -> ne pas charger les data
%   load(obj,'Legacy')                               -> force .mat (legacy)
%   load(obj,'Silent')
%   load(obj,'Debug')
%
% Reconstruit correctement:
%   - obj.image : [H W C T] avec C = total des sous-canaux
%   - obj.channelid : longueur C ; ex [1 2 3 4 4 4 5 ...]
%   - obj.display : struct d'affichage (channel, intensity, displaylim, etc.)
%
% ATTENTION : les fonctions auxiliaires suivantes doivent exister plus bas
% dans ce fichier (ou en méthodes privées) :
%   - loadFromH5_full(h5File)
%   - loadFromH5_single(h5File, chanName, img0, chId0, disp0)
%   - defaultDisplay(N,C)
%   - mergeDisplayStructs(dOld,dNew)
%   - debugPrintf(...)

% ================== PARSING DES OPTIONS ==================

% Defaults
% Defaults
wantImages   = true;      % charger les images ?
wantData     = true;      % charger les data ?
forceLegacy  = false;     % forcer .mat ?
silent       = false;     % masquer les fprintf/infos
DEBUG        = false;     % activer debugPrintf
chanNames    = {};        % liste de canaux logiques à charger; {} => tous

% --- Compat historique : load(obj,'data') ou load(obj,'GFP') ---
%     MAIS on ne traite PAS 'silent'/'debug'/'legacy' comme des canaux.
if numel(varargin) == 1 && (ischar(varargin{1}) || isstring(varargin{1}))
    keyRaw = char(varargin{1});
    key    = lower(strtrim(keyRaw));

    if strcmp(key,'data')
        % mode historique "data only"
        wantImages = false;
        wantData   = true;
        varargin   = {};   % on consomme l'argument

    elseif any(strcmp(key, {'silent','debug','legacy'}))
        % Ce sont des flags, pas des noms de canal.
        % On NE les consomme PAS ici : ils seront traités juste après
        % par la boucle générale sur varargin.
        % -> on laisse 'varargin' intact.

    else
        % interprété comme nom de canal logique unique : load(obj,'GFP')
        chanNames  = {keyRaw};   % on garde la casse originale
        wantImages = true;
        wantData   = true;
        varargin   = {};         % on consomme l'argument
    end
end


% --- Parsing général name/flag-value ---
i = 1;
while i <= numel(varargin)
    arg = varargin{i};

    if ~(ischar(arg) || isstring(arg))
        warning('loadROI:BadOption', ...
                'Option #%d ignorée (doit être un char/string).', i);
        i = i + 1;
        continue;
    end

    key = lower(strtrim(char(arg)));

    switch key
        case 'channel'
            % 'Channel', name ou 'Channel', {name1,name2}
            if i+1 > numel(varargin)
                error('loadROI:MissingValue', ...
                      'Valeur manquante après l''option ''Channel''.');
            end
            val = varargin{i+1};
            if ischar(val) || isstring(val)
                chanNames = {char(val)};
            elseif iscell(val)
                chanNames = cellfun(@char, val, 'UniformOutput', false);
            else
                error('loadROI:BadChannelValue', ...
                      'La valeur de ''Channel'' doit être char/string ou cellstr.');
            end
            wantImages = true;
            i = i + 2;

        case 'data'
            % 'Data' (seul)       -> data uniquement (compat)
            % 'Data', true/false  -> contrôle explicite
            if i+1 <= numel(varargin) && islogical(varargin{i+1})
                wantData = varargin{i+1};
                i = i + 2;
            else
                wantImages = false;
                wantData   = true;
                i = i + 1;
            end

        case 'legacy'
            forceLegacy = true;
            i = i + 1;

        case 'silent'
            silent = true;
            i = i + 1;

        case 'debug'
            DEBUG = true;
            i = i + 1;

        otherwise
            warning('loadROI:UnknownOption', ...
                'Option inconnue ''%s'' ignorée.', arg);
            i = i + 1;
    end
end

% Initialisation du debug global pour ce fichier
debugPrintf('init', DEBUG);

[repairedPath, pathWasRepaired] = localRepairPathFromProject( ...
    obj, wantImages, wantData, forceLegacy);
if pathWasRepaired
    obj.path = repairedPath;
    if ~silent
        fprintf('[loadROI] ROI path relinked to: %s\n', obj.path);
    end
end

% ================== CHEMINS & PRÉ-CHECK ==================

if isempty(obj.path)
    if ~silent
        warning('loadROI:NoPath','ROI path is empty.');
    end
    return;
end

h5File     = fullfile(obj.path, sprintf('im_%s.h5',  obj.id));
legacyFile = fullfile(obj.path, sprintf('im_%s.mat', obj.id));
dataFile   = fullfile(obj.path, sprintf('data_%s.mat', obj.id));

% ================== CHARGEMENT DES IMAGES ==================

if wantImages
    if ~forceLegacy && isfile(h5File)
        if ~silent
            fprintf('Loading HDF5 image file: %s\n', sprintf('im_%s.h5', obj.id));
        end

        if isempty(chanNames)
            % ---------- Tous les canaux ----------
            [img, chId, dispStruct] = loadFromH5_full(h5File);
        else
            % ---------- Un ou plusieurs canaux spécifiques ----------
            img        = obj.image;
            chId       = obj.channelid;
            dispStruct = obj.display;

            % A partial image must use a compact mapping: one channelid
            % entry for each plane actually present in obj.image. Older
            % partial loads kept the complete logical mapping and made
            % missing planes look like loaded zero-valued channels.
            if isempty(img)
                chId = [];
            elseif numel(chId) ~= size(img,3)
                if ~silent
                    warning('loadROI:InvalidPartialChannelMapping', ...
                        ['ROI "%s" has %d image plane(s) but %d channelid entries. ' ...
                         'Reloading the requested channels with a compact mapping.'], ...
                        obj.id, size(img,3), numel(chId));
                end
                img = [];
                chId = [];
            else
                chId = reshape(chId, 1, []);
            end

            for c = 1:numel(chanNames)
                cname = chanNames{c};
                [img, chId, dispStruct] = loadFromH5_single( ...
                    h5File, cname, img, chId, dispStruct);
            end
        end

        % Fusion non destructive du display
        if isstruct(obj.display) && ~isempty(fieldnames(obj.display))
            obj.display = mergeDisplayStructs(obj.display, dispStruct);
        else
            obj.display = dispStruct;
        end

        obj.image     = img;
        obj.channelid = chId;

                % --- Normalize datatype: many pipelines expect uint16-like intensities ---
        if isa(obj.image,'double') || isa(obj.image,'single')
            mx = max(obj.image(:));
            if mx > 1
                if ~silent
                    fprintf('[loadROI] NOTE: HDF5 image loaded as %s with max=%g -> casting to uint16\n', class(obj.image), mx);
                end
                obj.image = uint16(max(0, min(65535, round(obj.image))));
            end
        end


    elseif isfile(legacyFile)
        % -------- LEGACY FALLBACK (.mat) --------
        if ~silent
            fprintf('Loading MAT (legacy) image file: %s\n', sprintf('im_%s.mat', obj.id));
        end

        S = load(legacyFile);
        if isfield(S,'roiobj')
            % ne pas écraser id/path ; on prend les autres props
            setProperties(obj, S.roiobj);

        elseif isfield(S,'im')
            obj.image = S.im;
        else
            if ~silent
                warning('Legacy MAT has no image.');
            end
            obj.image = [];
        end

        if isempty(obj.channelid)
            obj.channelid = 1;
        end
        if isempty(obj.display)
            obj.display = defaultDisplay(1, numel(obj.channelid));
        end

    else
        % Pas de fichier image pour cette ROI
        if ~silent
            warning('No image file (.h5 or legacy .mat) for ROI %s.', obj.id);
        end
        % On ne touche obj.image/obj.display que s'ils sont vides
        if isempty(obj.image)
            obj.image     = [];
            obj.channelid = 1;
            obj.display   = defaultDisplay(1,1);
        end
    end
end

% ================== CHARGEMENT DES DONNÉES ==================

if wantData
    if isfile(dataFile)
        Sd = load(dataFile,'data');
        if isfield(Sd,'data')
            obj.data = Sd.data;
        else
            obj.data = dataseries.empty;
        end

        % --- sanitize dataseries handles (remove invalid/deleted) ---
try
    if isa(obj.data,'handle')
        obj.data = obj.data(isvalid(obj.data));
    end
catch
end

% si tout a sauté, remettre un dataseries vide (optionnel mais pratique)
if isempty(obj.data)
    obj.data = dataseries;
end


        if ismethod(obj,'fixLabelsInPlotFields')
            obj.fixLabelsInPlotFields;
        end

        if ~silent
            fprintf('Loading data file: %s\n', sprintf('data_%s.mat', obj.id));
        end
    else
        obj.data = dataseries.empty;
        if ~silent
            fprintf('No data file for ROI %s (expected: %s).\n', obj.id, dataFile);
        end
    end
else
    % Demande explicite de ne pas charger les data
    obj.data = dataseries.empty;
end

% ================== HARMONISATION plotProperties / plotGroup ==================

if isprop(obj, 'data') && ~isempty(obj.data)
    for dd = 1:numel(obj.data)
        if ~isprop(obj.data(dd),'plotProperties') || isempty(obj.data(dd).plotProperties)
            continue;
        end
        if ~isprop(obj.data(dd),'plotGroup')
            % Si plotGroup n'existe pas, on initialise une cellule 1x6 vide
            obj.data(dd).plotGroup = cell(1,6);
        end

        pp = obj.data(dd).plotProperties;
        pg = obj.data(dd).plotGroup;

        % S'assurer que plotGroup est une cellule 1x6
        if ~iscell(pg)
            pg = cell(1,6);
        elseif numel(pg) < 6
            pg(1,6) = {[]};
        end

        % --- Groupes présents dans plotProperties (6e colonne) ---
        if size(pp,2) >= 6
            groupsFromProps = pp(:,6);
        else
            groupsFromProps = {};
        end

        if ~iscell(groupsFromProps)
            groupsFromProps = num2cell(groupsFromProps);
        end

        % Garder uniquement les chaînes non vides
        isNonEmptyStr = cellfun(@(x) (ischar(x) && ~isempty(x)) || ...
                                         (isstring(x) && strlength(x) > 0), ...
                                groupsFromProps);
        groupsFromProps = groupsFromProps(isNonEmptyStr);
        groupsFromProps = cellfun(@char, groupsFromProps, 'UniformOutput', false);

        % --- Groupes déjà présents dans plotGroup{6} ---
        existingGroups = {};
        if numel(pg) >= 6 && ~isempty(pg{6})
            existingGroups = pg{6};
            if ischar(existingGroups)
                existingGroups = {existingGroups};
            end
        end

        % Union des deux listes, en conservant l'ordre d'apparition
        allGroups = unique([existingGroups(:); groupsFromProps(:)]', 'stable');

        % Mise à jour
        pg{6} = allGroups;
        obj.data(dd).plotGroup = pg;
    end
end

end


% ==================== H E L P E R S ====================
function [pathOut, repaired] = localRepairPathFromProject(obj, wantImages, wantData, forceLegacy)
% Recover a stale Hub/drive ROI path from roi -> fov -> shallow.io.
pathOut = '';
repaired = false;
try
    pathOut = char(string(obj.path));
catch
end

if localRoiFilesSatisfyLoad(pathOut, obj.id, wantImages, wantData, forceLegacy)
    return;
end

try
    fovObj = obj.parent;
    if isempty(fovObj) || ~isprop(fovObj, 'parent') || isempty(fovObj.parent)
        return;
    end
    shallowObj = fovObj.parent;
    if ~isa(shallowObj, 'shallow') || ~isprop(shallowObj, 'io') || ~isstruct(shallowObj.io)
        return;
    end
    if ~isfield(shallowObj.io, 'path') || isempty(shallowObj.io.path) || ...
            ~isfield(shallowObj.io, 'file') || isempty(shallowObj.io.file) || ...
            ~isprop(fovObj, 'id') || isempty(fovObj.id)
        return;
    end

    projectFile = char(string(shallowObj.io.file));
    [~, projectName, projectExt] = fileparts(projectFile);
    if isempty(projectExt)
        projectName = projectFile;
    end
    candidate = fullfile(char(string(shallowObj.io.path)), ...
        projectName, char(string(fovObj.id)));
    if localRoiFilesSatisfyLoad(candidate, obj.id, wantImages, wantData, forceLegacy)
        pathOut = candidate;
        repaired = true;
    end
catch
    repaired = false;
end
end

function tf = localRoiFilesSatisfyLoad(folder, roiId, wantImages, wantData, forceLegacy)
tf = false;
if isempty(folder) || isempty(roiId)
    return;
end
h5 = fullfile(folder, sprintf('im_%s.h5', roiId));
legacy = fullfile(folder, sprintf('im_%s.mat', roiId));
data = fullfile(folder, sprintf('data_%s.mat', roiId));
imageReady = ~wantImages || (forceLegacy && isfile(legacy)) || ...
    (~forceLegacy && (isfile(h5) || isfile(legacy)));
dataReady = ~wantData || isfile(data) || imageReady;
tf = imageReady && dataReady;
end

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
    debugPrintf('[DEBUG] No datasets in %s\n', h5File);
    return;
end

% --- Collecte / normalisation par dataset ---
N        = numel(dsets);
names    = cell(1,N);         % noms logiques (channel_name)
idxRaw   = cell(1,N);         % channel_indices lus tels quels (peut être vide/erroné)
kList    = zeros(1,N);        % k réel après normalisation
sizes    = zeros(N,4);        % tailles normalisées [H W k T] par dataset
blocks   = cell(1,N);         % blocs normalisés [H W k T]
frameLists = cell(1,N);
attrs    = repmat(struct('intensity',[], 'rgb',[], 'indexed',[], ...
    'alpha',[], 'contour',[], 'width',[], 'k',[], ...
    'selectedchannel',[]), 1, N);

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
    frameAttr = readAttOrDefault(h5File, p, 'frames', []);
    expT = numel(frameAttr);
    if isempty(expT) || expT < 1
        expT = 1;
    end
    kAttr = readAttOrDefault(h5File, p, 'num_subchannels', []);
    if isempty(expK) || expK < 1
        if ~isempty(kAttr)
            expK = double(kAttr(1));
        else
            expK = 1;
        end
    end

    permStr=''; %#ok<NASGU>
    blk = normalizeH5BlockForLoad(blkRaw, expK, expT, names{i});
    szN = size(blk);
    szN(end+1:4) = 1;

    Hblk = szN(1); Wblk = szN(2); k = szN(3); Tblk = szN(4); %#ok<NASGU>
    frameList = normalizeH5FrameList(frameAttr, Tblk);

    % Debug tailles
    debugPrintf('[DEBUG] "%s" raw=%s, normalized=[%d %d %d %d], expected_subchannels=%d\n', ...
        names{i}, mat2str(rawSz), szN(1), szN(2), szN(3), szN(4), expK);

    % Incohérence k vs channel_indices ?
    if k ~= expK
        hasBadIdx = true;
        debugPrintf('[DEBUG]   -> k (%d) ~= expected_subchannels (%d): will repack indices later.\n', ...
            k, expK);
    end

    % Stocker bloc normalisé
    blocks{i} = blk;
    frameLists{i} = frameList;
    kList(i)  = k;
    sizes(i,:)= szN;

    % Attributs display
    attrs(i).k         = k;
    attrs(i).intensity = readAttOrDefault(h5File,p,'display_intensity',[1 1 1]);
    attrs(i).rgb       = readAttOrDefault(h5File,p,'display_rgb',      [1 1 1]);
    attrs(i).colorMode = readAttOrDefault(h5File,p,'display_color_mode','rgb');
    attrs(i).colormapName = readAttOrDefault(h5File,p,'display_colormap_name','');
    attrs(i).displaylim       = readAttOrDefault(h5File,p,'display_displaylim',      [1 ; 1]);
    attrs(i).indexed   = readAttOrDefault(h5File,p,'display_indexed',  uint8(0));
    attrs(i).alpha     = readAttOrDefault(h5File,p,'display_alpha',    1);
    attrs(i).contour   = readAttOrDefault(h5File,p,'display_contour',  uint8(0));
    attrs(i).width     = readAttOrDefault(h5File,p,'display_contourwidth', 1);
    attrs(i).log       = readAttOrDefault(h5File,p,'display_log', uint8(0));
    attrs(i).frame     = readAttOrDefault(h5File,p,'display_frame', 1);
    attrs(i).binning   = readAttOrDefault(h5File,p,'display_binning', 1);
    % aa=readAttOrDefault(h5File,p,'display_selectedchannel',1)
    attrs(i).selectedchannel = readAttOrDefault(h5File,p,'display_selectedchannel',1);
    attrs(i).valueTransform = readValueTransformOrDefault(h5File, p);
end

% --- Ordonner : d'abord ceux qui ont un premier index connu, puis les autres (stable) ---
firstIdx = nan(1,N);
for i = 1:N
    if ~isempty(idxRaw{i}), firstIdx(i) = idxRaw{i}(1); end
end
[~,ord] = sortrows([isnan(firstIdx(:)) firstIdx(:) (1:N)']); 
ord = ord(:).';

names  = names(ord);
idxRaw = idxRaw(ord);
kList  = kList(ord);
sizes  = sizes(ord,:);
blocks = blocks(ord);
attrs  = attrs(ord);
frameLists = frameLists(ord);

% --- Stratégie d'indexation globale ---
% Consistance H/W. T can differ when a channel is missing frames; keep the
% channel and leave absent frames as zero instead of shifting channel ids.
H = sizes(1,1); W = sizes(1,2);
if any(sizes(:,1) ~= H) || any(sizes(:,2) ~= W)
    good = (sizes(:,1) == H) & (sizes(:,2) == W);
    if ~any(good)
        error('loadFromH5_full:DimMismatch', 'H/W not consistent across datasets.');
    end

    badNames = names(~good);
    if ~isempty(badNames)
        warning('loadFromH5_full:DimMismatch', ...
            'Dropping %d dataset(s) with inconsistent H/W: %s', ...
            numel(badNames), strjoin(badNames, ', '));
    end

    names  = names(good);
    idxRaw = idxRaw(good);
    kList  = kList(good);
    sizes  = sizes(good,:);
    blocks = blocks(good);
    attrs  = attrs(good);
    frameLists = frameLists(good);
    N      = numel(names);
end

T = max(cellfun(@(x) max(x(:)), frameLists));
if any(sizes(:,4) ~= T)
    shortNames = names(sizes(:,4) ~= T);
    warning('loadFromH5_full:FrameMismatch', ...
        'Padding %d channel dataset(s) with missing frames in %s: %s', ...
        numel(shortNames), h5File, strjoin(shortNames, ', '));
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
    debugPrintf('[DEBUG] Repacked indices sequentially: total C=%d\n', C);
else
    % Utiliser les indices fournis
    idxList = idxRaw;
    allIdx = [idxList{:}];
    expectedIdx = 1:sum(kList);
    if isempty(allIdx) || any(~isfinite(double(allIdx))) || any(double(allIdx) < 1) || ...
            numel(unique(double(allIdx))) ~= numel(allIdx) || ~isequal(sort(double(allIdx)), expectedIdx)
        idxList = cell(1,N);
        c0 = 0;
        for i = 1:N
            k = kList(i);
            idxList{i} = (c0+1):(c0+k);
            c0 = c0 + k;
        end
        C = sum(kList);
        debugPrintf('[DEBUG] Repacked non-compact channel_indices sequentially: total C=%d\n', C);
    else
        C = max(allIdx);
        debugPrintf('[DEBUG] Using provided channel_indices: total C=%d\n', C);
    end
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

    debugPrintf('[DEBUG] -> place "%s" into C-indices %s\n', names{i}, mat2str(destIdx));
    img(:,:,destIdx,frameLists{i}) = blk;
end

% --- channelid (longueur C ; valeurs 1..N) ---
channelid = zeros(1,C);
for i = 1:N
    channelid(idxList{i}) = i;
end

% --- display ---
dispStruct = rebuildDisplayFromAttrs(names, idxList, attrs, C);

debugPrintf('[DEBUG] Summary: %d logical channels, total subchannels C=%d, H=%d W=%d T=%d, repack=%d\n', ...
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

if isempty(img0)
    % display/channelid can still describe every H5 channel after the
    % image cache has been cleared. None of those entries maps an image
    % plane until the requested dataset is loaded below.
    chId0 = [];
else
    chId0 = reshape(chId0, 1, []);
    if numel(chId0) ~= size(img0,3)
        error('loadFromH5_single:InvalidExistingChannelMapping', ...
            'Existing image has %d plane(s), but channelid has %d entries.', ...
            size(img0,3), numel(chId0));
    end
end

info  = h5info(h5File);
dsets = info.Datasets;

if isempty(dsets)
    error('loadFromH5_single:NoDatasets','No datasets in %s', h5File);
end

% --- Trouver le dataset par "channel_name" (attribut) ou par nom
target = [];
targetIdx = [];
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
        targetIdx = i;
        break;
    end
end
if isempty(target)
    error('loadFromH5_single:NotFound','Channel "%s" not found in %s', chanName, h5File);
end

pTarget = ['/' target.Name];

% --- Lire le bloc + normaliser [H W k T]
frameAttr = readAttOrDefault(h5File, pTarget, 'frames', []);
expT = numel(frameAttr);
if isempty(expT) || expT < 1
    expT = 1;
end
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
frameList = normalizeH5FrameList(frameAttr, T);

% --- Lire/estimer les indices globaux pour ce canal
% Essai 1 : utiliser channel_indices s'il existe
% channel_indices is intentionally ignored for partial loads: score keeps a
% compact in-memory image and uses channelid for logical-channel mapping.

% Pour connaître le C total et les indices occupés par les autres canaux,
% on scanne vite fait les attributs des autres datasets (pas besoin des data)

% Stratégie d'indexation:
% - Si idxProvided cohérent -> on s'en sert
% - Sinon, si img0 existe -> on append/replace intelligemment
% - Sinon, on repack séquentiel minimal (C = somme k de tous les dsets, si dispo),
%   mais comme on ne charge qu'un canal, on place au début.

destIdx = [];
logicalIdWanted = targetIdx;
if isstruct(disp0) && isfield(disp0,'channel') && ~isempty(disp0.channel)
    logicalNames = disp0.channel;
    if isstring(logicalNames), logicalNames = cellstr(logicalNames); end
    if ~iscell(logicalNames), logicalNames = {char(string(logicalNames))}; end
    hit = find(strcmpi(logicalNames, chanName), 1);
    if ~isempty(hit)
        logicalIdWanted = hit;
    end
end

% Taille C existante si img0 fourni
if ~isempty(img0)
    C0 = size(img0,3);
else
    % sinon, déduire un C théorique à partir des attributs si disponibles
    C0 = k;
end

% Décide où placer ce bloc:
if isempty(img0)
    destIdx = 1:k;
end
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
    img = zeros(H, W, C0, max(frameList), 'like', blk);
else
    img = img0;
    % agrandir si nécessaire
    if size(img,1) ~= H || size(img,2) ~= W
        error('loadFromH5_single:DimMismatch', 'Existing image spatial dims do not match target dataset dims.');
    end
    if size(img,3) < max(destIdx)
        img(:,:,end+1:max(destIdx),:) = 0;
    end
    if size(img,4) < max(frameList)
        img(:,:,:,end+1:max(frameList)) = 0;
    end
end

% Place le bloc
img(:,:,destIdx,frameList) = blk;

% --- Mettre à jour channelid
if isempty(chId0)
    % On doit reconstruire un id logique minimal: 1 logique unique
    channelid = zeros(1, size(img,3));
    channelid(destIdx) = logicalIdWanted;
else
    channelid = chId0;
    if numel(channelid) < size(img,3)
        channelid(end+1:size(img,3)) = 0;
    end
    % Si le canal existe déjà (cas reuse), on garde l'id existant.
    % Sinon, on crée un nouveau "logique" à la fin.
    channelid(destIdx) = logicalIdWanted;
end

% --- Lire les attributs display pour ce canal
att.intensity  = readAttOrDefault(h5File, pTarget, 'display_intensity',  [1 1 1]);
att.rgb        = readAttOrDefault(h5File, pTarget, 'display_rgb',        [1 1 1]);
att.colorMode  = readAttOrDefault(h5File, pTarget, 'display_color_mode', 'rgb');
att.colormapName = readAttOrDefault(h5File, pTarget, 'display_colormap_name', '');
att.displaylim = readAttOrDefault(h5File, pTarget, 'display_displaylim', [0; 1]);
att.indexed    = readAttOrDefault(h5File, pTarget, 'display_indexed',    uint8(0));
att.alpha      = readAttOrDefault(h5File, pTarget, 'display_alpha',      1);
att.contour    = readAttOrDefault(h5File, pTarget, 'display_contour',    uint8(0));
att.width      = readAttOrDefault(h5File, pTarget, 'display_contourwidth', 1);
att.log        = readAttOrDefault(h5File, pTarget, 'display_log',         uint8(0));
att.frame      = readAttOrDefault(h5File, pTarget, 'display_frame',      1);
att.binning    = readAttOrDefault(h5File, pTarget, 'display_binning',    1);
att.selectedchannel = readAttOrDefault(h5File, pTarget, 'display_selectedchannel', 1);
att.valueTransform = readValueTransformOrDefault(h5File, pTarget);


% --- Mettre à jour uniquement ce qu'il faut dans le display
% On part de disp0 si fournit, sinon on crée un squelette minimal
if isempty(disp0) || ~isstruct(disp0) || ~isfield(disp0,'channel')
    % squelette minimal: un seul canal logique
    L = max(channelid);               % nb de canaux logiques
    C = size(img,3);                  % nb de sous-channels
    dispStruct = defaultDisplay(L, C);
else
    dispStruct = disp0;
    if isfield(dispStruct,'channel')
        if ischar(dispStruct.channel) || isstring(dispStruct.channel)
            dispStruct.channel = cellstr(string(dispStruct.channel));
        end
    end
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
        def = 0; 
        if any(strcmp(ff,{'alpha','width','selectedchannel'})), def = 1; end
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
if localShouldForceIndexedChannel(logicalName)
    dispStruct.intensity(logicalId,:) = [0 0 0];
    dispStruct.indexed(logicalId) = 1;
    dispStruct.contour(logicalId) = 1;
    dispStruct.alpha(logicalId) = 0.35;
    dispStruct.width(logicalId) = 1.5;
end
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
    dispStruct.selectedchannel(logicalId) = double(att.selectedchannel(1));
end
if ~isfield(dispStruct,'log') || isempty(dispStruct.log)
    dispStruct.log = zeros(1, Nlog);
end
dispStruct.log(logicalId) = double(att.log(1) ~= 0);

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
dispStruct.colorMode = ensureStringCellArray(dispStruct, 'colorMode', Nlog, 'rgb');
dispStruct.colormapName = ensureStringCellArray(dispStruct, 'colormapName', Nlog, '');
dispStruct.colorMode{logicalId} = char(string(att.colorMode));
dispStruct.colormapName{logicalId} = char(string(att.colormapName));
dispStruct.valueTransform = ensureValueTransformArray(dispStruct, Nlog);
dispStruct.valueTransform(logicalId) = att.valueTransform;

% stretchlim inchangé (si existant)
% fin.

debugPrintf('[DEBUG] Single-load: placed "%s" into C-indices %s (logical=%d). H=%d W=%d k=%d T=%d\n', ...
    chanName, mat2str(destIdx), logicalId, H, W, k, T);

end

function blk = normalizeH5BlockForLoad(blkRaw, expK, expT, datasetName)
if nargin < 2 || isempty(expK) || ~isfinite(expK) || expK < 1
    expK = 1;
end
if nargin < 3 || isempty(expT) || ~isfinite(expT) || expT < 1
    expT = 1;
end
if nargin < 4 || isempty(datasetName)
    datasetName = '<unknown>';
end

rawSz = size(blkRaw);
nDims = ndims(blkRaw);

switch nDims
    case 2
        sz = [rawSz 1 1];
    case 3
        sz = [rawSz 1];
        thirdDim = rawSz(3);

        if expK == 1 && expT > 1
            sz = [rawSz(1) rawSz(2) 1 thirdDim];
        elseif expK > 1 && expT == 1
            sz = [rawSz(1) rawSz(2) thirdDim 1];
        elseif expK > 1 && expT > 1
            if thirdDim == expK
                sz = [rawSz(1) rawSz(2) thirdDim 1];
            elseif thirdDim == expT
                sz = [rawSz(1) rawSz(2) 1 thirdDim];
            elseif thirdDim == expK * expT
                sz = [rawSz(1) rawSz(2) expK expT];
            end
        end
    otherwise
        sz = rawSz;
        sz(end+1:4) = 1;
end

try
    blk = reshape(blkRaw, sz(1), sz(2), sz(3), sz(4));
catch ME
    error('loadFromH5_full:BadDatasetShape', ...
        'Cannot reshape dataset %s from raw size %s to [H W k T]=[%d %d %d %d]: %s', ...
        char(string(datasetName)), mat2str(rawSz), sz(1), sz(2), sz(3), sz(4), ME.message);
end
end

function frameList = normalizeH5FrameList(frameAttr, T)
if nargin < 2 || isempty(T) || ~isfinite(T) || T < 1
    T = 1;
end

frameList = [];
try
    if ~isempty(frameAttr)
        frameList = double(frameAttr(:).');
        frameList = frameList(isfinite(frameList));
    end
catch
    frameList = [];
end

if numel(frameList) ~= T
    frameList = 1:T;
else
    frameList = round(frameList);
    if any(frameList == 0) && ~any(frameList < 0)
        frameList = frameList + 1;
    end
    if any(frameList < 1) || numel(unique(frameList)) ~= numel(frameList)
        frameList = 1:T;
    end
end
end


% ==================== H E L P E R S ====================

% 
% function v = readAttOrDefault(h5f, path, attName, def)
% try
%     v = h5readatt(h5f, path, attName);
% catch
%     v = def;
% end
% end

function vt = readValueTransformOrDefault(h5File, h5Path)
vt = rawValueTransform();
try
    mode = lower(strtrim(char(string(readAttOrDefault(h5File, h5Path, 'value_mode', 'raw')))));
catch
    mode = 'raw';
end
if ~strcmp(mode, 'physical')
    return;
end

unit = 'physical';
try
    unit = char(string(readAttOrDefault(h5File, h5Path, 'physical_unit', unit)));
catch
end
physicalMin = readAttOrDefault(h5File, h5Path, 'physical_min', NaN);
physicalMax = readAttOrDefault(h5File, h5Path, 'physical_max', NaN);
encodedMin = readAttOrDefault(h5File, h5Path, 'encoded_min', 0);
encodedMax = readAttOrDefault(h5File, h5Path, 'encoded_max', 65535);
transform = 'linear';
try
    transform = char(string(readAttOrDefault(h5File, h5Path, 'physical_transform', transform)));
catch
end

physicalRange = double([physicalMin physicalMax]);
encodedRange = double([encodedMin encodedMax]);
if any(~isfinite(physicalRange)) || any(~isfinite(encodedRange)) || ...
        physicalRange(2) <= physicalRange(1) || encodedRange(2) <= encodedRange(1)
    vt = rawValueTransform();
    return;
end

vt = struct( ...
    'mode', 'physical', ...
    'unit', unit, ...
    'physicalRange', physicalRange, ...
    'encodedRange', encodedRange, ...
    'transform', transform);
end

function vt = ensureValueTransformArray(dispStruct, nLog)
defaultValue = rawValueTransform();
if isfield(dispStruct, 'valueTransform') && ~isempty(dispStruct.valueTransform) && isstruct(dispStruct.valueTransform)
    oldValue = dispStruct.valueTransform(:).';
else
    oldValue = repmat(defaultValue, 1, 0);
end
vt = repmat(defaultValue, 1, numel(oldValue));
for i = 1:numel(oldValue)
    vt(i) = normalizeValueTransform(oldValue(i));
end
if numel(vt) < nLog
    vt(end+1:nLog) = defaultValue;
elseif numel(vt) > nLog
    vt = vt(1:nLog);
end
end

function value = ensureStringCellArray(dispStruct, fieldName, nLog, defaultValue)
if isfield(dispStruct, fieldName) && ~isempty(dispStruct.(fieldName))
    rawValue = dispStruct.(fieldName);
    if isstring(rawValue)
        value = cellstr(rawValue(:).');
    elseif ischar(rawValue)
        value = {rawValue};
    elseif iscell(rawValue)
        value = cell(1, numel(rawValue));
        for i = 1:numel(rawValue)
            value{i} = char(string(rawValue{i}));
        end
    else
        value = {};
    end
else
    value = {};
end
if numel(value) < nLog
    value(end+1:nLog) = {defaultValue};
elseif numel(value) > nLog
    value = value(1:nLog);
end
end

function s = normalizeValueTransform(s)
defaultValue = rawValueTransform();
try
    if ~isfield(s, 'mode') || isempty(s.mode), s.mode = defaultValue.mode; end
    if ~isfield(s, 'unit') || isempty(s.unit), s.unit = defaultValue.unit; end
    if ~isfield(s, 'physicalRange') || isempty(s.physicalRange) || numel(s.physicalRange) ~= 2
        s.physicalRange = defaultValue.physicalRange;
    end
    if ~isfield(s, 'encodedRange') || isempty(s.encodedRange) || numel(s.encodedRange) ~= 2
        s.encodedRange = defaultValue.encodedRange;
    end
    if ~isfield(s, 'transform') || isempty(s.transform), s.transform = defaultValue.transform; end
catch
    s = defaultValue;
end
end

function vt = rawValueTransform()
vt = struct( ...
    'mode', 'raw', ...
    'unit', 'raw', ...
    'physicalRange', [0 65535], ...
    'encodedRange', [0 65535], ...
    'transform', 'linear');
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
selectedchannel = ones(1,N);
logFlag   = zeros(1,N);
colorMode = repmat({'rgb'}, 1, N);
colormapName = repmat({''}, 1, N);

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
    if isfield(attrs, 'log') && ~isempty(attrs(i).log)
        logFlag(i) = double(attrs(i).log(1) ~= 0);
    end
    if isfield(attrs, 'colorMode') && ~isempty(attrs(i).colorMode)
        colorMode{i} = char(string(attrs(i).colorMode));
    end
    if isfield(attrs, 'colormapName') && ~isempty(attrs(i).colormapName)
        colormapName{i} = char(string(attrs(i).colormapName));
    end
    if localShouldForceIndexedChannel(names{i})
        intensity(i,:) = [0 0 0];
        indexed(i) = 1;
        contour(i) = 1;
        alpha(i) = 0.35;
        width(i) = 1.5;
    end

    % selectedchannel doit refléter le canal actif (par défaut 1)
    % -> ne surtout pas copier 'width'
    if ~isempty(attrs(i).selectedchannel)
        selectedchannel(i) = double(attrs(i).selectedchannel(1));
    else
        selectedchannel(i) = 1;  % fallback anciens fichiers
    end

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
dispStruct.log             = logFlag;
dispStruct.colorMode       = colorMode;
dispStruct.colormapName    = colormapName;
dispStruct.valueTransform  = repmat(rawValueTransform(), 1, N);
for i = 1:N
    dispStruct.valueTransform(i) = attrs(i).valueTransform;
end

end

function tf = localShouldForceIndexedChannel(channelName)
tf = false;
try
    name = lower(string(channelName));
    tf = startsWith(name, "results_") || contains(name, "mask") || ...
        contains(name, "track") || endsWith(name, "_cell");
catch
    tf = false;
end
end
% 
% function d = defaultDisplay(N, C)
% % N canaux logiques, C sous-channels
% d = struct();
% d.intensity       = repmat([1 1 1], N, 1);
% d.frame           = 1;
% d.selectedchannel = ones(1,N);
% d.binning         = 1;
% d.rgb             = repmat([1 1 1], C, 1);
% d.channel         = arrayfun(@(k)sprintf('channel_%d',k), 1:N, 'UniformOutput', false);
% d.stretchlim      = [];
% d.displaylim      = repmat([0;1], 1, C);
% d.indexed         = zeros(1,N);
% d.alpha           = ones(1,N);
% d.contour         = zeros(1,N);
% d.width           = ones(1,N);
% d.log             = zeros(1,N);
% end

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

% ==================== DEBUG PRINT HELPER ====================
function debugPrintf(varargin)
% debugPrintf('init', true/false) pour (dés)activer le debug global
% debugPrintf(fmt, ...) agit comme fprintf si le debug est activé

persistent DEBUG_ENABLED

if nargin >= 2 && ischar(varargin{1}) && strcmp(varargin{1}, 'init')
    DEBUG_ENABLED = logical(varargin{2});
    return;
end

if isempty(DEBUG_ENABLED) || ~DEBUG_ENABLED
    return;
end

fprintf(varargin{:});
end
