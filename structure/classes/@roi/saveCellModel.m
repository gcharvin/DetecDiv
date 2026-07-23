function report = saveCellModel(obj, model, varargin)
%SAVECELLMODEL Persist the transient model to objects_<roi>.h5.

if nargin<2||isempty(model)
    if isstruct(obj.cellModel)&&isfield(obj.cellModel,'schema_version')
        model=obj.cellModel;
    else
        model=cellModel.create(obj.id);
    end
end
filename=cellModel.pathForROI(obj);
if isempty(filename), error('roi:CellModelPath','ROI path/id is required to save its cell model.'); end
model=cellModel.normalize(model,obj.id);
model.provenance.updated_at=char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
report=cellModel.writeH5(filename,model,varargin{:});
obj.cellModel=model;
d=dir(filename);
obj.cellModelInfo=struct('loaded',true,'filename',filename,'datenum',d.datenum);

displayState=obj.display;
displayState.objectModel=struct('format','detecdiv_cell_model', ...
    'schemaVersion',1,'filename',['objects_' char(string(obj.id)) '.h5'], ...
    'familyCount',numel(model.families.family_id), ...
    'updatedAt',model.provenance.updated_at);
obj.display=displayState;
end
