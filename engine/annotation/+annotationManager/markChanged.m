function entry = markChanged(roiObj, spec, varargin)
%ANNOTATIONMANAGER.MARKCHANGED Invalidate approval and mark edited units reviewed.

saveFlag = true;
for i = 1:2:numel(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        if strcmpi(char(string(varargin{i})), 'Save') && i < numel(varargin)
            saveFlag = logical(varargin{i+1});
        end
    end
end
args = varargin;
saveIdx = find(cellfun(@(x) (ischar(x) || isstring(x)) && ...
    strcmpi(char(string(x)), 'Save'), args), 1, 'first');
if isempty(saveIdx)
    args = [args {'Save', false}];
else
    args{saveIdx+1} = false;
end
entry = annotationManager.markReviewed(roiObj, spec, args{:});
entry.status = 'draft';
entry.approved_at = '';
entry.approved_hash = '';
entry = annotationManager.setEntry(roiObj, spec, entry, 'Save', saveFlag);
end
