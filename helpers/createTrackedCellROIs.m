function created = createTrackedCellROIs(shallowObj, varargin)
% createTrackedCellROIs  Backward-compatible wrapper to roiTracked package.
%
% New code should call roiTracked.createTrackedCellROIs directly.

    created = roiTracked.createTrackedCellROIs(shallowObj, varargin{:});
end
