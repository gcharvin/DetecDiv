function motherID = getCellMother(roiobj, daughterID, varargin)
% Retourne motherID (double), NaN si inconnue, 0 si "présente sans mère".
p = inputParser;
p.addParameter('nFrames', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
nFramesHint = p.Results.nFrames;

ensureCellInformationDataseries(roiobj, 'nFrames', nFramesHint);
idx = find(arrayfun(@(x) strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
ds  = roiobj.data(idx);

daughterID = int32(daughterID);
if isKey(ds.userData.motherOf, daughterID)
    motherID = ds.userData.motherOf(daughterID);
else
    motherID = NaN;
end
end
