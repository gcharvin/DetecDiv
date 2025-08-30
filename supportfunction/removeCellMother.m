function removeCellMother(roiobj, daughterID, varargin)
% Mutant in-place. Ne retourne rien.
% Option 'setZeroInsteadOfDelete' (false par défaut) :
%   - false : remove(key) dans motherOf (+ birthOf si existe)
%   - true  : ds.userData.motherOf(daughterID) = 0

p = inputParser;
p.addParameter('setZeroInsteadOfDelete', false, @islogical);
p.addParameter('nFrames', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
setZero     = p.Results.setZeroInsteadOfDelete;
nFramesHint = p.Results.nFrames;

ensureCellInformationDataseries(roiobj, 'nFrames', nFramesHint);
idx = find(arrayfun(@(x) strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
ds  = roiobj.data(idx);

daughterID = int32(daughterID);

if ~isKey(ds.userData.motherOf, daughterID)
    warning('removeCellMother: aucune mère enregistrée pour cette fille.');
    return;
end

if setZero
    ds.userData.motherOf(daughterID) = 0;
else
    remove(ds.userData.motherOf, daughterID);
    if isfield(ds.userData,'birthOf') && ~isempty(ds.userData.birthOf) && isKey(ds.userData.birthOf, daughterID)
        remove(ds.userData.birthOf, daughterID);
    end
end
end
