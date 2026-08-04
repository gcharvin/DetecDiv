function [model, status] = score_getCellModel(roiobj)
%SCORE_GETCELLMODEL Return a cached/sidecar model without implicit migration.

model=[]; status='missing';
if isempty(roiobj), return; end
try
    % Rendering calls this helper several times per frame (mask provider,
    % family colors, track/state colors, lineage). A model stored in the ROI
    % cache has already been normalized and validated by loadCellModel or
    % saveCellModel; do not stat the H5 file and revalidate every table on
    % each display refresh.
    if isprop(roiobj, 'cellModel') && isstruct(roiobj.cellModel) && ...
            isfield(roiobj.cellModel, 'schema_version') && ...
            isprop(roiobj, 'cellModelInfo') && isstruct(roiobj.cellModelInfo) && ...
            isfield(roiobj.cellModelInfo, 'loaded') && roiobj.cellModelInfo.loaded
        model = roiobj.cellModel;
        status = 'ok';
        return;
    end

    if ~roiobj.hasCellModel(), return; end
    [model,report]=roiobj.loadCellModel();
    if report.validation.ok, status='ok'; else, status='invalid'; end
catch ME
    status=['error: ' ME.message];
    model=[];
end
end
