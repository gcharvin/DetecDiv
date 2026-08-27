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
fast=optionValue(varargin,'Fast',false);
if ~fast
    model=cellModel.normalize(model,obj.id);
else
    model.roi_id=char(string(obj.id));
end
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

function value=optionValue(args,name,fallback)
value=fallback;
for i=1:2:numel(args)
    if (ischar(args{i})||isstring(args{i}))&&strcmpi(args{i},name)
        value=logical(args{i+1});
        return;
    end
end
end
