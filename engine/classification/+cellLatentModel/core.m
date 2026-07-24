function [paramout,dataout,imageout] = core(param,roiobj,ctx,classif)
%CELLLATENTMODEL.CORE Infer relations and update the canonical cell model.
if nargin < 3, ctx = struct(); end
if nargin < 4, classif = []; end
paramout = cellLatentModel.normalizeParam(param,ctx,classif);
if isempty(roiobj.image), roiobj.load; end
[tracks,~] = channelStack(roiobj,paramout.trackChannelName,true);
gfp = [];
if ~isempty(paramout.gfpChannelName)
    [gfp,~] = channelStack(roiobj,paramout.gfpChannelName,false);
end
auditFile = resolveAuditFile(roiobj,paramout.outputFamilyName,ctx);
if ~isfolder(fileparts(auditFile)), mkdir(fileparts(auditFile)); end
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,0,'Running multimodal lineage inference...', ...
        'Scope','event','Indeterminate',true);
end
result = cellLatentModel.infer( ...
    tracks,gfp,paramout,char(string(roiobj.id)),ctx);
writeJsonAtomic(auditFile,result);
[model,loadReport] = roiobj.loadCellModel('MigrateLegacy',true);
[model,familyId,applyReport] = cellModel.applyLineageResult( ...
    model,tracks,paramout.trackChannelName,paramout.inputFamily, ...
    paramout.outputFamilyName,result,paramout.overwriteOutputFamily, ...
    'cellLatentModel');
model.provenance.last_classifier = 'cellLatentModel';
model.provenance.last_audit_artifact = auditFile;
model.provenance.last_processor_version = '0.1.0';
saveReport = roiobj.saveCellModel(model);
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,1,'Latent lineage saved.', ...
        'Scope','integration');
end
paramout.outputFamilyId = double(familyId);
paramout.auditFile = auditFile;
paramout.cellModelFile = char(saveReport.filename);
paramout.artifacts = {auditFile,char(saveReport.filename)};
paramout.summary = result.summary;
paramout.runtime = struct( ...
    'backend','Python', ...
    'package','cell_latent_model', ...
    'model_source',paramout.modelSource, ...
    'model',paramout.modelPath, ...
    'gfp_used',~isempty(gfp));
paramout.cellModelReport = struct( ...
    'load',loadReport,'apply',applyReport,'save',saveReport);
paramout.saveChannels = {};
dataout = roiobj.data;
imageout = [];
if paramout.debug
    fprintf('[cellLatentModel] %d linked, %d review; family %u; GFP=%d.\n', ...
        double(result.summary.linked),double(result.summary.review), ...
        familyId,~isempty(gfp));
end
end

function [stack,pix] = channelStack(roiobj,name,isLabels)
try pix = roiobj.findChannelID(name,'exact');
catch, pix = roiobj.findChannelID(name);
end
if isempty(pix)
    try
        roiobj.load('Channel',name,'Data',false,'Silent');
        pix = roiobj.findChannelID(name,'exact');
    catch
    end
end
if isempty(pix)
    error('cellLatentModel:ChannelNotFound', ...
        'Channel "%s" was not found.',name);
end
pix = pix(1);
stack = squeeze(roiobj.image(:,:,pix,:));
if ismatrix(stack)
    stack = reshape(stack,size(stack,1),size(stack,2),1);
end
if isLabels
    values = double(stack(:));
    if any(~isfinite(values)) || any(values < 0) || ...
            any(mod(values,1) ~= 0)
        error('cellLatentModel:InvalidLabels', ...
            'Tracked masks must be finite non-negative integers.');
    end
    stack = uint32(stack);
else
    stack = single(stack);
end
end

function filename = resolveAuditFile(roiobj,outputFamily,ctx)
root = '';
try
    if isfield(ctx,'store') && isfield(ctx.store,'workDir')
        root = char(string(ctx.store.workDir));
    end
catch
end
if isempty(root)
    sidecar = cellModel.pathForROI(roiobj);
    root = fullfile(fileparts(sidecar),'artifacts','cellLatentModel');
end
stamp = char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
safeFamily = regexprep(outputFamily,'[^A-Za-z0-9_-]+','_');
safeRoi = regexprep(char(string(roiobj.id)),'[^A-Za-z0-9_-]+','_');
filename = fullfile(root,sprintf('cell_latent_%s_%s_%s.json', ...
    safeRoi,safeFamily,stamp));
end

function writeJsonAtomic(filename,value)
temporary = [filename '.tmp'];
fid = fopen(temporary,'w');
if fid < 0
    error('cellLatentModel:AuditWriteFailed', ...
        'Cannot create %s.',temporary);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
clear cleanup;
[ok,message] = movefile(temporary,filename,'f');
if ~ok
    error('cellLatentModel:AuditWriteFailed', ...
        'Cannot finalize %s: %s',filename,message);
end
end
