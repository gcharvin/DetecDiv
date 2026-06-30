function ensureCellInformationDataseries(roiobj, varargin)
% Mutant in-place. Ne retourne rien.
% - Crée ou répare le dataseries groupid="cell_information", type="temporal".
% - Table : une colonne 'lineage' (cell), nFrames lignes, chaque case = {NaN}.
% - Stocke le parentage persistant dans ds.userData.motherOf (Map int32->double).
%
% Usage recommandé juste après chargement :
%   roiobj.load('data');
%   ensureCellInformationDataseries(roiobj);  % sans nFrames -> déduit de image ou 1
%
% Paramètres opcionnels :
%   'nFrames' : force la hauteur de la table si tu connais la durée.

p = inputParser;
p.addParameter('nFrames', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
nFramesHint = p.Results.nFrames;

data = roiobj.data;
if isempty(data)
    % Par convention chez toi : roiobj.data contient souvent déjà UNE instance vide.
    % Au pire, on en crée une.
    data = dataseries;
    roiobj.data = data; % in-place
end

% Chercher un ds cell_information
idx = find(arrayfun(@(x) isfield(x,'groupid') && strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');

% Déterminer nFrames (sans roiobj.nFrames)
nFromImg = [];
if isfield(roiobj, 'image') && ~isempty(roiobj.image) && ndims(roiobj.image) >= 4
    nFromImg = size(roiobj.image, 4);
end

if isempty(idx)
    % Choisir l'index pour créer : si un seul ds vide, on le remplace ; sinon on append
    if numel(roiobj.data) == 1 && (isempty(roiobj.data.data) || heightSafe(roiobj.data.data) == 0)
        idx = 1;
        ds = roiobj.data(idx);
    else
        idx = numel(roiobj.data) + 1;
        roiobj.data(idx) = dataseries; %#ok<AGROW>
        ds = roiobj.data(idx);
    end

    ds.class   = "other";
    ds.type    = "temporal";
    ds.groupid = "cell_information";
    if isfield(roiobj, 'id'), ds.parentid = roiobj.id; end

    nFrames = firstNonEmpty([nFramesHint, nFromImg, 1]);
    T = table(cell(nFrames,1), 'VariableNames', {'lineage'});
    T.lineage(:) = {nan};
    ds.data = T;

    ds.plotGroup       = {[] [] [] [] [] {'lineage'}};
    ds.groupProperties = {'lineage','Plot','auto','auto'};

    ds.userData.motherOf = containers.Map('KeyType','int32','ValueType','double');
    ds.userData.lineageSources = struct();
    ds.userData.activeLineageSource = 'manual';
    ds.userData.version  = 1;
    ds.userData.note     = "lineage stored in userData.motherOf and userData.lineageSources";

else
    % Réparer l'existant
    ds = roiobj.data(idx);

    nFrames = firstNonEmpty([heightSafe(ds.data), nFromImg, nFramesHint, 1]);

    if isempty(ds.data) || ~ismember('lineage', ds.data.Properties.VariableNames)
        ds.data = table(cell(nFrames,1), 'VariableNames', {'lineage'});
        ds.data.lineage(:) = {nan};
    else
        curH = height(ds.data);
        if curH < nFrames
            extra = table(cell(nFrames-curH,1), 'VariableNames', {'lineage'});
            extra.lineage(:) = {nan};
            ds.data = [ds.data; extra];
        elseif curH > nFrames
            ds.data = ds.data(1:nFrames, :);
        end
    end

    if ~isfield(ds,'userData') || ~isfield(ds.userData,'motherOf') || isempty(ds.userData.motherOf)
        ds.userData.motherOf = containers.Map('KeyType','int32','ValueType','double');
    end
    if ~isfield(ds.userData,'lineageSources') || ~isstruct(ds.userData.lineageSources)
        ds.userData.lineageSources = struct();
    end
    if ~isfield(ds.userData,'activeLineageSource') || isempty(ds.userData.activeLineageSource)
        ds.userData.activeLineageSource = 'manual';
    end
    if ~isfield(ds.userData,'version'), ds.userData.version = 1; end
    if ~isfield(ds.userData,'note'),    ds.userData.note    = "lineage stored in userData.motherOf and userData.lineageSources"; end

    if isempty(ds.plotGroup) || numel(ds.plotGroup) < 6
        ds.plotGroup = {[] [] [] [] [] {'lineage'}};
    end
    if ~isfield(ds,'groupProperties') || isempty(ds.groupProperties)
        ds.groupProperties = {'lineage','Plot','auto','auto'};
    end
end
end

% ---- helpers ----
function h = heightSafe(T)
if istable(T), h = height(T); else, h = 0; end
end
function v = firstNonEmpty(candidates)
% candidates est un vecteur numérique potentiellement avec []
mask = ~arrayfun(@isempty, arrayfun(@(x){x}, candidates));
if any(mask), v = candidates(find(mask,1,'first')); else, v = []; end
end
