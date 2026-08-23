function tests = testCellLatentModelCodeSnapshot
%TESTCELLLATENTMODELCODESNAPSHOT Exact, immutable source snapshot contract.
tests = functiontests(localfunctions);
end

function testSnapshotIsSourceOnlyHashedAndImmutable(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
cellRepo = fullfile(root,'cell_latent_model');
detecdivRepo = fullfile(root,'DetecDiv');
bundle = fullfile(root,'external_bundle','model_v001');
mkdir(bundle);

writeText(fullfile(cellRepo,'src','cell_latent_model','train.py'), ...
    'VALUE = 1');
writeText(fullfile(cellRepo,'src','cell_latent_model','__pycache__', ...
    'train.pyc'),'compiled');
writeText(fullfile(cellRepo,'src','cell_latent_model','models', ...
    'weights.pt'),'weights');
writeText(fullfile(cellRepo,'configs','base.json'),'{}');
writeText(fullfile(cellRepo,'pyproject.toml'),'[project]');
writeText(fullfile(cellRepo,'uv.lock'),'version = 1');
writeText(fullfile(detecdivRepo,'engine','classification', ...
    '+cellLatentModel','train.m'),'function train, end');
writeText(fullfile(detecdivRepo,'engine','classification', ...
    '+cellLatentModel','tests','testIgnored.m'),'function testIgnored, end');
writeText(fullfile(detecdivRepo,'engine','classification', ...
    '+cellLatentTracker','train.m'),'function train, end');
writeText(fullfile(detecdivRepo,'engine','classification', ...
    '+classifierBinding','trainingScopeSpec.m'), ...
    'function trainingScopeSpec, end');
ioFiles = {'classifierApplyTrainingExecutionDefaults.m', ...
    'classifierPersistTrainingExecutionDefaults.m', ...
    'classifierPersistTrainingResult.m', ...
    'classifierTrainingExecutionDefaults.m'};
for index = 1:numel(ioFiles)
    writeText(fullfile(detecdivRepo,'structure','io',ioFiles{index}), ...
        ['function ' erase(ioFiles{index},'.m') ', end']);
end

gitInit(cellRepo);
gitInit(detecdivRepo);
writeText(fullfile(cellRepo,'src','cell_latent_model','train.py'), ...
    'VALUE = 2');

record = cellLatentModel.utils.snapshotTrainingCode(bundle, ...
    'CellLatentModelRepo',cellRepo,'DetecDivRepo',detecdivRepo);

verifyTrue(testCase,isfile(record.manifest));
verifyNotEmpty(testCase,record.manifest_sha256);
verifyTrue(testCase,isfile(fullfile(bundle,'code_snapshot', ...
    'clm','s','cell_latent_model','train.py')));
verifyTrue(testCase,isfile(fullfile(bundle,'code_snapshot', ...
    'clm','c','base.json')));
verifyTrue(testCase,isfile(fullfile(bundle,'code_snapshot', ...
    'dd','lm','train.m')));
verifyFalse(testCase,isfile(fullfile(bundle,'code_snapshot', ...
    'clm','s','cell_latent_model','__pycache__','train.pyc')));
verifyFalse(testCase,isfile(fullfile(bundle,'code_snapshot', ...
    'clm','s','cell_latent_model','models','weights.pt')));
verifyFalse(testCase,isfile(fullfile(bundle,'code_snapshot', ...
    'dd','lm','tests','testIgnored.m')));
payload = jsondecode(fileread(record.manifest));
verifyEqual(testCase,double(payload.file_count),double(record.file_count));
verifyEqual(testCase,payload.content_tree_sha256,record.content_tree_sha256);
verifyTrue(testCase,payload.repositories(1).git_available);
verifyTrue(testCase,payload.repositories(1).working_tree_dirty);
verifyNotEmpty(testCase,jsonencode(record));

manifestHash = sha256File(record.manifest);
verifyError(testCase,@()cellLatentModel.utils.snapshotTrainingCode( ...
    bundle,'CellLatentModelRepo',cellRepo,'DetecDivRepo',detecdivRepo), ...
    'cellLatentModel:CodeSnapshotExists');
verifyEqual(testCase,sha256File(record.manifest),manifestHash);
end

function gitInit(root)
[status,~] = system(sprintf('git -C "%s" init -q',root));
assert(status==0,'Git is required by this provenance test.');
system(sprintf('git -C "%s" config user.email test@example.invalid',root));
system(sprintf('git -C "%s" config user.name DetecDivTest',root));
system(sprintf('git -C "%s" add .',root));
[status,output] = system(sprintf( ...
    'git -C "%s" commit -q -m snapshot-fixture',root));
assert(status==0,output);
end

function writeText(filename,text)
folder = fileparts(filename);
if ~isfolder(folder), mkdir(folder); end
fid = fopen(filename,'w');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,text,'char');
end

function value = sha256File(filename)
fid=fopen(filename,'r');cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
hash=typecast(digest.digest(bytes),'uint8');
value=lower(reshape(dec2hex(hash,2).',1,[]));
end
