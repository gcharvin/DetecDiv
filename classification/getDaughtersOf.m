function daughters = getDaughtersOf(roiobj, motherID, varargin)
% Retourne un vecteur ligne des IDs filles (double) dont la mère == motherID.
p = inputParser;
p.addParameter('nFrames', [], @(x) isempty(x) || (isscalar(x) && x>=1));
p.parse(varargin{:});
nFramesHint = p.Results.nFrames;

ensureCellInformationDataseries(roiobj, 'nFrames', nFramesHint);
idx = find(arrayfun(@(x) strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
ds  = roiobj.data(idx);

keysD = ds.userData.motherOf.keys;
daughters = [];
for k = 1:numel(keysD)
    d = double(keysD{k});
    if ds.userData.motherOf(int32(d)) == motherID
        daughters(end+1) = d; %#ok<AGROW>
    end
end
end
