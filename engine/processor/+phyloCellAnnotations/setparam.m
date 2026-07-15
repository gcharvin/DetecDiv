function paramout = setparam(ctx)
% phyloCellAnnotations.setparam  Defaults for phyloCell annotation import.

if nargin < 1 || isempty(ctx)
    ctx = struct();
end

paramout = struct();
paramout.pkg = 'phyloCellAnnotations';
paramout.outputName = 'phyloCell_lineage';
paramout.cellChannelName = 'phyloCell_cells';
paramout.nucleusChannelName = 'phyloCell_nuclei';
paramout.createCellMasks = true;
paramout.createNucleusMasks = true;
paramout.createLineage = true;
paramout.createScoreLineage = true;
paramout.scrubGraphics = false;
paramout.existingPolicy = 'replace';
paramout.frames = [];
paramout.coordinateScale = [];
paramout.coordinateBinning = [];
paramout.tip = { ...
    'Output dataseries groupid for imported phyloCell lineage metadata', ...
    'Logical channel name for indexed cell masks', ...
    'Logical channel name for indexed nucleus masks', ...
    'Create indexed cell masks from segmentation.cells1 contours', ...
    'Create indexed nucleus masks from segmentation.nucleus contours', ...
    'Create lineage/object dataseries from tcells1/tnucleus metadata', ...
    'Optional [x y] scale from phyloCell source coordinates to extracted ROI pixels', ...
    'Optional binning factor for phyloCell source coordinates; coordinateScale becomes 1/binning' ...
    };

if isfield(ctx, 'outputName') && ~isempty(ctx.outputName)
    paramout.outputName = char(string(ctx.outputName));
end
end
