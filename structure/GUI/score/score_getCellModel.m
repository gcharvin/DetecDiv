function [model, status] = score_getCellModel(roiobj)
%SCORE_GETCELLMODEL Return a cached/sidecar model without implicit migration.

model=[]; status='missing';
if isempty(roiobj), return; end
try
    if ~roiobj.hasCellModel(), return; end
    [model,report]=roiobj.loadCellModel();
    if report.validation.ok, status='ok'; else, status='invalid'; end
catch ME
    status=['error: ' ME.message];
    model=[];
end
end
