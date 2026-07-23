function [model, report] = loadCellModel(obj, varargin)
%LOADCELLMODEL Lazily load objects_<roi>.h5 or build an in-memory migration.

p=inputParser;
p.addParameter('Force',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('MigrateLegacy',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('PersistMigration',false,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
filename=cellModel.pathForROI(obj);

if ~p.Results.Force && cacheIsCurrent(obj,filename)
    model=obj.cellModel;
    validation=cellModel.validate(model);
    report=struct('source','cache','filename',string(filename), ...
        'validation',validation,'migration',struct());
    return;
end

migration=struct();
if ~isempty(filename) && isfile(filename)
    model=cellModel.readH5(filename);
    source='h5';
elseif p.Results.MigrateLegacy
    [model,migration]=cellModel.fromLegacy(obj);
    source='legacy';
    if p.Results.PersistMigration
        writeReport=cellModel.writeH5(filename,model);
        migration.write=writeReport;
        source='legacy_persisted';
    end
else
    model=cellModel.create(obj.id);
    source='empty';
end

obj.cellModel=model;
obj.cellModelInfo=cacheInfo(filename);
obj.cellModelInfo.loaded=true;
validation=cellModel.validate(model);
report=struct('source',source,'filename',string(filename), ...
    'validation',validation,'migration',migration);
end

function tf=cacheIsCurrent(obj,filename)
tf=false;
try
    if ~isstruct(obj.cellModel)||~isfield(obj.cellModel,'schema_version')|| ...
            ~isstruct(obj.cellModelInfo)||~isfield(obj.cellModelInfo,'loaded')||~obj.cellModelInfo.loaded
        return;
    end
    if ~isfile(filename)
        tf=strcmp(char(string(obj.cellModelInfo.filename)),filename);
        return;
    end
    info=dir(filename);
    tf=strcmp(char(string(obj.cellModelInfo.filename)),filename)&& ...
        isfield(obj.cellModelInfo,'datenum')&&obj.cellModelInfo.datenum==info.datenum;
catch
    tf=false;
end
end

function info=cacheInfo(filename)
info=struct('loaded',false,'filename',filename,'datenum',NaN);
if ~isempty(filename)&&isfile(filename), d=dir(filename); info.datenum=d.datenum; end
end
