function roiobj = updateCellInformationLineage(app, roiobj, frame, varargin)
% OPTION A (léger) : ne remplit pas la vue par frame.
% Assure seulement qu'il existe un dataseries 'cell_information' de type "temporal"
% cohérent avec nFrames, avec table (nFrames x 1) et une colonne 'lineage' de {NaN}
% pour compatibilité UI.
%
% Usage :
%   roiobj = updateCellInformationLineage(app, roiobj, frame);
%   roiobj = updateCellInformationLineage(app, roiobj, frame, 'nFrames', 200);

p = inputParser;
p.addParameter('nFrames', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});

if isempty(p.Results.nFrames)
    nFrames = inferNumFrames(roiobj);
else
    nFrames = p.Results.nFrames;
end

[idx, ds] = getOrCreateCellInfoDataseries(roiobj, nFrames);

% On ne remplit rien d'autre : userData.motherOf est la vérité.
% Tu peux, si tu veux, stocker des métadonnées supplémentaires :
if ~isfield(ds.userData, 'version'), ds.userData.version = 1; end
if ~isfield(ds.userData, 'note'),    ds.userData.note    = "lineage stored in userData.motherOf (Option A)"; end

roiobj.data(idx) = ds;
end

% ---------- Helpers locaux ----------
function n = inferNumFrames(roiobj)
n = 1;
if isfield(roiobj,'image') && ~isempty(roiobj.image) && ndims(roiobj.image) >= 4
    n = size(roiobj.image,4);
elseif isfield(roiobj,'nFrames') && ~isempty(roiobj.nFrames)
    n = roiobj.nFrames;
end
n = max(1,n);
end

function [idx, ds] = getOrCreateCellInfoDataseries(roiobj, nFrames)
data = roiobj.data;
if isempty(data)
    data = dataseries; % objet vide par défaut
end

pix = find(arrayfun(@(x) isfield(x,'groupid') && strcmp(x.groupid,'cell_information'), data), 1, 'first');

if isempty(pix)
    % --- Créer
    idx = numel(data) + 1;
    data(idx) = dataseries;
    data(idx).class   = "other";
    data(idx).type    = "temporal";
    data(idx).groupid = "cell_information";
    if isfield(roiobj,'id'), data(idx).parentid = roiobj.id; end

    % Table minimale (nFrames x 1), avec colonne 'lineage' = {NaN}
    T = table(cell(nFrames,1), 'VariableNames', {'lineage'});
    T.lineage(:) = {nan};
    data(idx).data = T;

    % Propriétés d'affichage/groupe (compat UI)
    data(idx).plotGroup       = {[] [] [] [] [] {'lineage'}};
    data(idx).groupProperties = {'lineage','Plot','auto','auto'};

    % Vérité persistante
    data(idx).userData.motherOf = containers.Map('KeyType','int32','ValueType','double');

    ds = data(idx);

else
    % --- Existant : mettre à jour taille & champs manquants
    idx = pix;
    ds  = data(idx);

    % Assurer la colonne 'lineage'
    if isempty(ds.data) || ~ismember('lineage', ds.data.Properties.VariableNames)
        ds.data = table(cell(nFrames,1), 'VariableNames', {'lineage'});
        ds.data.lineage(:) = {nan};
    end

    % Ajuster le nombre de lignes
    curH = height(ds.data);
    if curH < nFrames
        extra = table(cell(nFrames-curH,1), 'VariableNames', {'lineage'});
        extra.lineage(:) = {nan};
        ds.data = [ds.data; extra];
    elseif curH > nFrames
        ds.data = ds.data(1:nFrames,:);
    end

    % S'assurer que l
