function varargout = phyloCell_mainGUI(varargin)
% phyloCell_mainGUI  No-op shim for stale callbacks in legacy MAT files.
%
% Some phyloCell segmentation files contain serialized graphics callbacks
% that reference the original GUI. DetecDiv only needs the data objects, so
% this shim prevents callback-resolution noise when those objects are loaded
% without the full phyloCell application on the MATLAB path.

varargout = cell(1, nargout);
end
