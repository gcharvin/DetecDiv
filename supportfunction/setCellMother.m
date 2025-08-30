function setCellMother(roiobj, daughterID, motherID, varargin)
% Mutant in-place. Ne retourne rien.
% motherID peut être 0 (= pas de mère). Stockage : ds.userData.motherOf(int32(daughterID)) = double(motherID).
% Option : 'birthFrame', stocké dans ds.userData.birthOf (Map int32->int32).

p = inputParser;
p.addParameter('birthFrame', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.addParameter('nFrames',    [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
birthFrame  = p.Results.birthFrame;
nFramesHint = p.Results.nFrames;

% S'assurer que le dataseries existe/est prêt
ensureCellInformationDataseries(roiobj, 'nFrames', nFramesHint);

% Récupérer l'index du ds
idx = find(arrayfun(@(x) strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
ds  = roiobj.data(idx);

daughterID = int32(daughterID);
motherID   = double(motherID);

if daughterID == motherID
    warning('setCellMother: fille et mère identiques; opération ignorée.');
    return;
end

ds.userData.motherOf(daughterID) = motherID;

if ~isempty(birthFrame)
    if ~isfield(ds.userData,'birthOf') || isempty(ds.userData.birthOf)
        ds.userData.birthOf = containers.Map('KeyType','int32','ValueType','int32');
    end
    % borner birthFrame entre 1 et height(ds.data)
    bf = int32(max(1, min(height(ds.data), birthFrame)));
    ds.userData.birthOf(daughterID) = bf;
end
end
