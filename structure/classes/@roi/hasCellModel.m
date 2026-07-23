function tf = hasCellModel(obj)
%HASCELLMODEL True for a cached model or an existing model sidecar.
tf=false;
try
    tf=isstruct(obj.cellModel)&&isfield(obj.cellModel,'schema_version');
catch
end
if ~tf
    filename=cellModel.pathForROI(obj);
    tf=~isempty(filename)&&isfile(filename);
end
end
