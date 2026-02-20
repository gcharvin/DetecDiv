function ensureCellInformationDataseries(roi, varargin)
% Assure la présence d'un dataseries groupid="cell_information" (type="temporal")
% avec une table (nFrames x 1) colonne 'lineage' (cell) initialisée à {NaN}.
% In-place, idempotent, sans isfield sur objets (on utilise isprop).
%
% Usage conseillé juste après:  roi.load('data'); ensureCellInformationDataseries(roi);

p = inputParser;
p.addParameter('nFrames', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
nFramesHint = p.Results.nFrames;

% --- 1) S'assurer que roi.data existe et est un tableau de dataseries
if ~isprop(roi,'data') || isempty(roi.data)
    roi.data = dataseries;  % crée UNE instance vide par convention
end

% --- 2) Trouver (ou préparer) l'index du dataseries "cell_information"
idxCI = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data), 1, 'first');

if isempty(idxCI)
    % Aucun 'cell_information'. Réutiliser l'unique instance vide si possible.
    if numel(roi.data)==1 && isEmptyDataseries(roi.data(1))
        idxCI = 1;
    else
        idxCI = numel(roi.data) + 1;
        roi.data(idxCI) = dataseries; %#ok<AGROW>
    end
end

% Raccourci handle
ds = roi.data(idxCI);

% --- 3) Initialiser METADATA sans remplacer l'objet
if ~isprop(ds,'class') || ds.class==""
    ds.class = "other";
end
if ~isprop(ds,'type') || ds.type==""
    ds.type = "temporal";
end
if ~isprop(ds,'groupid') || ds.groupid==""
    ds.groupid = 'cell_information';
end
if isprop(roi,'id')
    ds.parentid = roi.id;   % info non destructive
end

% --- 4) Déterminer nFrames (jamais via roi.nFrames)
nFromTable = heightSafe(ds.data);
nFromImage = [];
if isprop(roi,'image') && ~isempty(roi.image) && ndims(roi.image)>=4
    nFromImage = size(roi.image,4);
end
nFrames = firstNonEmptyNum([nFromTable, nFromImage, nFramesHint, 1]);

% --- 5) Assurer la table 'lineage' (cell), sans détruire l'existant
if ~istable(ds.data) || ~ismember('lineage', ds.data.Properties.VariableNames)
    T = table(cell(nFrames,1), 'VariableNames', {'lineage'});
    T.lineage(:) = {nan};
    ds.data = T;
else
    curH = height(ds.data);
    if curH < nFrames
        extra = table(cell(nFrames-curH,1), 'VariableNames', {'lineage'});
        extra.lineage(:) = {nan};
        ds.data = [ds.data; extra];
    elseif curH > nFrames
        ds.data = ds.data(1:nFrames,:);
    end
    % s'assurer du type cell pour la colonne
    if ~iscell(ds.data.lineage)
        lin = ds.data.lineage;
        ds.data.lineage = num2cell(lin);
        empt = cellfun(@isempty, ds.data.lineage);
        ds.data.lineage(empt) = {nan};
    end
end

% --- 6) Assurer userData (struct) + Maps SANS ÉCRASER si existent
if ~isprop(ds,'userData') || isempty(ds.userData) || ~isstruct(ds.userData)
    ds.userData = struct();
end

% motherOf : Map int32->double (ne JAMAIS recréer si déjà une Map, même vide)
if ~isfield(ds.userData,'motherOf') || ~isa(ds.userData.motherOf,'containers.Map')
    ds.userData.motherOf = containers.Map('KeyType','int32','ValueType','double');
end

% birthOf : Map int32->int32 (optionnelle)
if ~isfield(ds.userData,'birthOf') || ~isa(ds.userData.birthOf,'containers.Map')
    ds.userData.birthOf = containers.Map('KeyType','int32','ValueType','int32');
end

if ~isfield(ds.userData,'version'), ds.userData.version = 1; end
if ~isfield(ds.userData,'note'),    ds.userData.note    = "lineage stored in userData.motherOf (Option A)"; end

% --- 7) Propriétés d'affichage minimales (non destructives)
if ~isprop(ds,'plotGroup') || isempty(ds.plotGroup) || numel(ds.plotGroup)<6
    ds.plotGroup = {[] [] [] [] [] {'lineage'}};
end
if ~isprop(ds,'groupProperties') || isempty(ds.groupProperties)
    ds.groupProperties = {'lineage','Plot','auto','auto'};
end

ds.show=0;
% rien à retourner (handle)

end

% ================= Helpers (objets → propriétés) =================
function tf = isEmptyDataseries(ds)
% "vide" = pas de table ou table vide ET pas de groupid renseigné
tf = (~istable(ds.data) || heightSafe(ds.data)==0) && ...
     (~isprop(ds,'groupid') || ds.groupid=="");
end

function h = heightSafe(T)
if istable(T), h = height(T); else, h = []; end
end

function v = firstNonEmptyNum(cands)
% prend le premier nombre non-vide (tolère des [])
mask = ~arrayfun(@isempty, arrayfun(@(x){x}, cands));
if any(mask), v = cands(find(mask,1,'first')); else, v = []; end
end
