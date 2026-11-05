function report = validateClassifier(classif, roiIndices, varargin)
%VALIDATECLASSIFIER Validate existing GT in bulk without opening an editor.
% ConfirmReviewed is an explicit human attestation for historical GT. It
% marks only the training scope reviewed; content validation is still required.
if nargin < 2 || isempty(roiIndices), roiIndices = 1:numel(classif.roi); end
p = inputParser;
p.addParameter('ConfirmReviewed',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('ProgressFcn',[],@(x)isempty(x)||isa(x,'function_handle'));
p.addParameter('CancelFcn',[],@(x)isempty(x)||isa(x,'function_handle'));
p.parse(varargin{:});
indices = unique(double(roiIndices(:).'),'stable');
if any(~isfinite(indices) | indices ~= round(indices) | ...
        indices < 1 | indices > numel(classif.roi))
    error('annotationManager:InvalidRoiIndex','Select valid ROI indices.');
end
template = struct('roiIndex',0,'roiId','','status','pending','message','');
items = repmat(template,numel(indices),1);
for k = 1:numel(indices)
    items(k).roiIndex = indices(k);
    items(k).roiId = char(string(classif.roi(indices(k)).id));
end
cancelled = false;
for k = 1:numel(indices)
    if ~isempty(p.Results.CancelFcn) && p.Results.CancelFcn()
        cancelled = true; break;
    end
    try
        session = annotationManager.createSession(classif,indices(k));
        summary = session.summary('VerifyHash',true);
        if strcmp(summary.status,'approved')
            items(k).status = 'ready';
            items(k).message = 'Already Ready; content hash verified.';
        elseif any([summary.components.required] & ...
                ~[summary.components.groundTruthExists])
            items(k).status = 'invalid';
            missing = summary.components([summary.components.required] & ...
                ~[summary.components.groundTruthExists]);
            items(k).message = ['Missing GT: ' strjoin({missing.id},', ')];
        else
            if p.Results.ConfirmReviewed
                session.markReviewed('Save',false);
            end
            validation = session.validate();
            if validation.valid
                items(k).status = 'ready';
            else
                items(k).status = 'invalid';
                items(k).message = char(strjoin(string(validation.errors),newline));
            end
        end
    catch ME
        items(k).status = 'failed';
        items(k).message = ME.message;
    end
    if ~isempty(p.Results.ProgressFcn)
        p.Results.ProgressFcn(k,numel(indices),items(k));
    end
end
report = struct('items',items,'cancelled',cancelled, ...
    'ready',nnz(strcmp({items.status},'ready')), ...
    'invalid',nnz(strcmp({items.status},'invalid')), ...
    'failed',nnz(strcmp({items.status},'failed')), ...
    'pending',nnz(strcmp({items.status},'pending')));
end
