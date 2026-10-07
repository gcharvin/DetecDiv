function [paramout,dataout,imageout] = core(param,roiobj,frames)
%OBJECTMETRICS.CORE Join computeMetrics output to latent cell identities.
imageout=[];
if nargin<3, frames=[]; end
if nargin==0
    paramout=objectMetrics.setparam(struct()); dataout=[]; return;
end
paramout=normalized(param);
if isempty(roiobj.data)||(numel(roiobj.data)==1&&isempty(roiobj.data(1).data))
    roiobj.load('Data','Silent');
end
family=paramout.family;
if strcmpi(char(string(family)),'<auto>')||isempty(family)
    family=autoFamily(roiobj,paramout.inputData);
end
args={'MaskIndexVariable',paramout.maskIndexVariable};
if ~isempty(frames)&&~(isnumeric(frames)&&all(frames==-1)), args=[args {'Frames',frames}]; end
[tbl,joinReport]=cellMetrics.link(roiobj,family,paramout.inputData,args{:});
geometryGroup=resolveGeometryGroup(roiobj,family,paramout.geometryData,paramout.inputData);
if ~isempty(geometryGroup)
    [geometry,geometryReport]=cellMetrics.link(roiobj,family,geometryGroup,args{:});
    tbl=appendMetrics(tbl,geometry);
    joinReport.geometry_group=geometryGroup;
    joinReport.geometry_join_report=geometryReport;
end
growthApplied=false;
if paramout.deriveGrowth
    if ismember(paramout.sizeVariable,tbl.Properties.VariableNames)
        tbl=cellMetrics.deriveGrowth(tbl,'SizeVariable',paramout.sizeVariable, ...
            'FrameIntervalMinutes',paramout.frameIntervalMinutes,'Window',paramout.growthWindow);
        growthApplied=true;
    else
        warning('objectMetrics:MissingSizeVariable', ...
            'Growth was skipped because "%s" is absent from "%s".', ...
            paramout.sizeVariable,paramout.inputData);
    end
end
groups=repmat({'object_metric'},1,width(tbl));
plots=repmat({false},1,width(tbl));
ds=dataseries(tbl,tbl.Properties.VariableNames,'groupid',paramout.outputName, ...
    'parentid',roiobj.id,'groups',groups,'plot',plots);
ds.class="processing"; ds.type="temporal";
ds.userData=struct('schema_version',uint16(1), ...
    'source_group',paramout.inputData,'join_report',joinReport, ...
    'growth_applied',growthApplied,'identity_semantics', ...
    'Each row is keyed by immutable ObjectId and references TrackId, Frame, and MaskLabel.');
generationSeries=[];
if paramout.averageByGeneration
    [model,~]=roiobj.loadCellModel('MigrateLegacy',true);
    [generationTable,generationReport]=cellMetrics.averageByGeneration( ...
        model,tbl,'ExcludeCensored',paramout.excludeCensored);
    generationSeries=dataseries(generationTable,generationTable.Properties.VariableNames, ...
        'groupid',paramout.generationOutputName,'parentid',roiobj.id, ...
        'groups',repmat({'generation_metric'},1,width(generationTable)), ...
        'plot',repmat({false},1,width(generationTable)));
    generationSeries.class="processing"; generationSeries.type="generation";
    generationSeries.userData=struct('schema_version',uint16(1), ...
        'source_group',paramout.outputName,'source_metrics_group',paramout.inputData, ...
        'family_id',joinReport.family_id,'family_name',joinReport.family_name, ...
        'mask_provider',joinReport.mask_provider,'generation_report',generationReport);
end
dataout=roiobj.data;
dataout=storeSeries(dataout,ds);
if ~isempty(generationSeries), dataout=storeSeries(dataout,generationSeries); end
end

function out=normalized(param)
out=objectMetrics.setparam(struct());
if isstruct(param)
    names=fieldnames(param);
    for i=1:numel(names), out.(names{i})=param.(names{i}); end
end
textFields={'inputData','geometryData','maskIndexVariable','outputName','sizeVariable','generationOutputName'};
for i=1:numel(textFields), out.(textFields{i})=char(string(out.(textFields{i}))); end
out.deriveGrowth=logical(out.deriveGrowth);
validateattributes(out.averageByGeneration,{'logical','numeric'},{'scalar','binary'});
validateattributes(out.excludeCensored,{'logical','numeric'},{'scalar','binary'});
out.averageByGeneration=logical(out.averageByGeneration);
out.excludeCensored=logical(out.excludeCensored);
if out.averageByGeneration && (isempty(strtrim(out.generationOutputName)) || ...
        strcmp(out.generationOutputName,out.outputName) || ...
        strcmp(out.generationOutputName,out.inputData) || ...
        strcmp(out.generationOutputName,out.geometryData))
    error('objectMetrics:InvalidGenerationOutput', ...
        'generationOutputName must be nonempty and distinct from temporal and input dataseries names.');
end
out.frameIntervalMinutes=double(out.frameIntervalMinutes);
out.growthWindow=round(double(out.growthWindow));
if out.frameIntervalMinutes<=0||~isfinite(out.frameIntervalMinutes)
    error('objectMetrics:InvalidFrameInterval','frameIntervalMinutes must be positive.');
end
if out.growthWindow<2||~isfinite(out.growthWindow)
    error('objectMetrics:InvalidGrowthWindow','growthWindow must be at least 2.');
end
end

function dataout=storeSeries(dataout,ds)
hit=find(arrayfun(@(x)strcmp(char(string(x.groupid)),char(string(ds.groupid))),dataout),1);
if isempty(hit)
    if numel(dataout)==1&&isempty(dataout(1).data), dataout=ds; else, dataout(end+1)=ds; end
else
    dataout(hit)=ds;
end
end

function group=resolveGeometryGroup(roiobj,family,requested,primary)
requested=char(string(requested)); group='';
if isempty(requested)||strcmpi(requested,'none'), return; end
if ~strcmpi(requested,'<auto>')
    if ~strcmp(requested,primary), group=requested; end
    return;
end
[model,~]=roiobj.loadCellModel('MigrateLegacy',true);
[idx,~]=cellModel.familyIndex(model,family);
if isempty(idx), return; end
provider=char(string(model.families.mask_provider{idx}));
for i=1:numel(roiobj.data)
    if strcmp(char(string(roiobj.data(i).groupid)),primary), continue; end
    ud=roiobj.data(i).userData;
    if isstruct(ud)&&isfield(ud,'mask_channel')&&strcmpi(char(string(ud.mask_channel)),provider) && ...
            startsWith(char(string(roiobj.data(i).groupid)),'mask_quantification_')
        group=char(string(roiobj.data(i).groupid));
        return;
    end
end
end

function primary=appendMetrics(primary,extra)
[found,rows]=ismember(primary.ObjectId,extra.ObjectId);
identity={'FamilyId','ObjectId','TrackId','Frame','MaskLabel','StateId','ParentTrackId'};
names=setdiff(extra.Properties.VariableNames,identity,'stable');
for i=1:numel(names)
    values=nan(height(primary),1);
    values(found)=double(extra.(names{i})(rows(found)));
    if ismember(names{i},primary.Properties.VariableNames)
        existing=primary.(names{i});
        fill=~isfinite(double(existing))&isfinite(values);
        existing(fill)=values(fill); primary.(names{i})=existing;
    else
        primary.(names{i})=values;
    end
end
end

function family=autoFamily(roiobj,groupId)
[model,~]=roiobj.loadCellModel('MigrateLegacy',true);
hit=find(arrayfun(@(x)strcmp(char(string(x.groupid)),groupId),roiobj.data),1);
providers=strings(0,1);
if ~isempty(hit)&&isstruct(roiobj.data(hit).userData)&& ...
        isfield(roiobj.data(hit).userData,'mask_bindings')
    providers=string({roiobj.data(hit).userData.mask_bindings.mask_channel});
end
candidate=false(numel(model.families.family_id),1);
for i=1:numel(providers)
    candidate=candidate|strcmpi(string(model.families.mask_provider),providers(i));
end
indices=find(candidate);
if isempty(indices)&&numel(model.families.family_id)==1, indices=1; end
if numel(indices)~=1
    error('objectMetrics:AmbiguousFamily', ...
        'Set family explicitly; <auto> resolved %d candidate cell-model families.',numel(indices));
end
family=model.families.family_id(indices);
end
