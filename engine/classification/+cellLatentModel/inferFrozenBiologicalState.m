function [state,refs] = inferFrozenBiologicalState( ...
        tracks,observations,param,roiId,ctx)
%INFERFROZENBIOLOGICALSTATE Reuse the promoted scene-state backend.
if nargin<5||isempty(ctx),ctx=struct();end
[workDir,removeAtEnd]=runtimeWorkDir(ctx,roiId);
cleanup=onCleanup(@()cleanupRuntime(workDir,removeAtEnd));
inputPath=fullfile(workDir,'predicted_tracks_and_observations.h5');
configPath=fullfile(workDir,'biological_state_config.json');
outputPath=fullfile(workDir,'pred_biological_state.json');
stdoutPath=fullfile(workDir,'biological_state_stdout.txt');
writeStack(inputPath,'/pred_stable_tracks',uint32(tracks),'uint32');
cfg=struct('schema_version',1, ...
    'input_path',normalizedPath(inputPath), ...
    'tracks_dataset','/pred_stable_tracks', ...
    'brightfield_dataset','', ...
    'nucleus_dataset','', ...
    'budneck_dataset','', ...
    'state_runtime_config',normalizedPath(param.stateRuntimeConfigPath), ...
    'output_path',normalizedPath(outputPath), ...
    'roi_id',char(string(roiId)), ...
    'frame_interval_minutes',double(param.frameIntervalMinutes), ...
    'device',char(string(param.device)));
pairs={'brightfield','/brightfield'; ...
       'nucleus','/nucleus';'budneck','/budneck'};
for i=1:size(pairs,1)
    name=pairs{i,1};dataset=pairs{i,2};
    if isfield(observations,name)&&~isempty(observations.(name))
        writeStack(inputPath,dataset,single(observations.(name)),'single');
        cfg.([name '_dataset'])=dataset;
    end
end
writeJson(configPath,cfg);
detecdiv_check_cancel(ctx,'cellLatentModel before biological-state inference');
runtime=cellLatentModel.utils.runPythonModule( ...
    'infer-detecdiv-biological-state',configPath,ctx,stdoutPath);
detecdiv_check_cancel(ctx,'cellLatentModel after biological-state inference');
if ~isfile(outputPath)
    error('cellLatentModel:MissingBiologicalStateOutput', ...
        'The promoted biological-state component produced no output.');
end
state=jsondecode(fileread(outputPath));
if ~isstruct(state)||~isfield(state,'records')
    error('cellLatentModel:InvalidBiologicalStateOutput', ...
        'The promoted biological-state output has no records contract.');
end
refs=struct('runtime',runtime,'workDir',workDir,'stdout',stdoutPath, ...
    'output',outputPath,'config',configPath);
clear cleanup;
cleanupRuntime(workDir,removeAtEnd);
end

function writeStack(filename,dataset,stack,datatype)
stored=permute(stack,[2 1 3]);
sz=[size(stack,2),size(stack,1),size(stack,3)];
h5create(filename,dataset,sz,'Datatype',datatype, ...
    'ChunkSize',[min(sz(1),256),min(sz(2),256),1],'Deflate',1);
h5write(filename,dataset,stored);
h5writeatt(filename,dataset,'axis_order','time,y,x');
end

function [workDir,removeAtEnd]=runtimeWorkDir(ctx,roiId)
root='';
try root=char(string(ctx.store.workDir));catch,end
if isempty(root)
    root=tempname;mkdir(root);removeAtEnd=true;
else
    if ~isfolder(root),mkdir(root);end
    removeAtEnd=false;
end
safe=regexprep(char(string(roiId)),'[^A-Za-z0-9_.-]+','_');
stamp=char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
workDir=fullfile(root,['cell_latent_state_' safe '_' stamp]);
mkdir(workDir);
end

function cleanupRuntime(workDir,removeAtEnd)
if ~removeAtEnd||~isfolder(workDir),return;end
try rmdir(workDir,'s');catch,end
parent=fileparts(workDir);
try if isfolder(parent)&&isempty(dir(fullfile(parent,'*'))),rmdir(parent);end;catch,end
end

function writeJson(filename,value)
fid=fopen(filename,'w');
if fid<0,error('cellLatentModel:ConfigWriteFailed','Cannot create %s.',filename);end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end

function value=normalizedPath(value)
value=strrep(char(string(value)),'\','/');
end
