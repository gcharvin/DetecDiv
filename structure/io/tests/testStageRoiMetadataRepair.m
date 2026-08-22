function tests = testStageRoiMetadataRepair
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(repoRoot);
detecdiv_setup_path;
end

function testAuditIsReadOnlyAndStagePreservesPayloads(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @()removeFolder(root));

[h5Path, matPath] = fixture(root);
sourceH5Hash = fileHash(h5Path);
sourceMatHash = fileHash(matPath);
repairRoot = fullfile(root, 'repairs');

audit = stageRoiMetadataRepair(h5Path, matPath, 'Pos0_1_50', repairRoot, ...
    'BrightfieldChannels', {'Channel1_z2'});
verifyEqual(testCase, audit.mode, 'audit');
verifyFalse(testCase, audit.audit_before.is_consistent);
verifyFalse(testCase, isfolder(repairRoot));
verifyEqual(testCase, fileHash(h5Path), sourceH5Hash);
verifyEqual(testCase, fileHash(matPath), sourceMatHash);

report = stageRoiMetadataRepair(h5Path, matPath, 'Pos0_1_50', repairRoot, ...
    'Stage', true, ...
    'RepairStem', 'roi50_metadata_only', ...
    'BrightfieldChannels', {'Channel1_z2'});

verifyTrue(testCase, isfolder(report.repair_dir));
verifyTrue(testCase, isfile(report.candidate.manifest_path));
verifyTrue(testCase, report.candidate.audit.is_consistent);
verifyEqual(testCase, fileHash(h5Path), sourceH5Hash);
verifyEqual(testCase, fileHash(matPath), sourceMatHash);

candidateH5 = report.candidate.h5_path;
verifyEqual(testCase, double(h5readatt(candidateH5,'/Channel1_z2','display_indexed')), 0);
verifyEqual(testCase, reshape(double(h5readatt(candidateH5,'/Channel1_z2','display_intensity')),1,[]), [1 1 1]);
verifyEqual(testCase, reshape(double(h5readatt(candidateH5,'/Channel1_z2','display_rgb')),1,[]), [1 1 1]);
verifyEqual(testCase, double(h5readatt(candidateH5,'/Channel1_z2','display_alpha')), 1);
verifyEqual(testCase, double(h5readatt(candidateH5,'/Channel1_z2','display_contour')), 0);
verifyEqual(testCase, double(h5readatt(candidateH5,'/Channel1_z2','display_selectedchannel')), 1);
verifyEqual(testCase, double(h5readatt(candidateH5,'/Channel1_z2','channel_indices')), 1);
verifyEqual(testCase, double(h5readatt(candidateH5,'/results_cellposeSAM_cell','channel_indices')), 2);
verifyEqual(testCase, reshape(double(h5readatt(candidateH5,'/CombinedChannel','channel_indices')),1,[]), 3:5);

expectedMap = [1 2 3 3 3];
for path = {'/Channel1_z2','/results_cellposeSAM_cell','/CombinedChannel'}
    verifyEqual(testCase, reshape(double(h5readatt(candidateH5,path{1},'channelid')),1,[]), expectedMap);
end

sourceCatalog = payloadHashes(h5Path);
candidateCatalog = payloadHashes(candidateH5);
verifyEqual(testCase, candidateCatalog, sourceCatalog);

s = load(report.candidate.classifier_mat_path, 'classiObj');
r = s.classiObj.roi(1);
verifyFalse(testCase, logical(r.display.indexed(1)));
verifyEqual(testCase, double(r.display.intensity(1,:)), [1 1 1]);
verifyEqual(testCase, double(r.display.rgb(1,:)), [1 1 1]);
verifyEqual(testCase, double(r.display.alpha(1)), 1);
verifyFalse(testCase, logical(r.display.contour(1)));
verifyTrue(testCase, logical(r.display.selectedchannel(1)));
verifyEqual(testCase, double(r.channelid), expectedMap);

manifest = jsondecode(fileread(report.candidate.manifest_path));
verifyTrue(testCase, manifest.dataset_payload_contract.unchanged);
verifyEqual(testCase, manifest.label_contract, ...
    ['No pixels, labels, tracks, parent links, states, or annotation status ' ...
     'were changed. Only HDF5/display metadata was normalized.']);
end

function [h5Path, matPath] = fixture(root)
h5Path = fullfile(root, 'im_Pos0_1_50.h5');
writeDataset(h5Path, '/Channel1_z2', uint16(reshape(1:48,[4 4 1 3])), ...
    'Channel1_z2', 2, [2 1 5], 1);
writeDataset(h5Path, '/results_cellposeSAM_cell', uint16(mod(reshape(1:48,[4 4 1 3]),4)), ...
    'results_cellposeSAM_cell', 1, [2 1 5], 1);
writeDataset(h5Path, '/CombinedChannel', uint16(reshape(1:144,[4 4 3 3])), ...
    'CombinedChannel', 2:4, [1 2 2 2 3], 0);

c = classi(root, 'latent_model_1', 1);
c.trainingParam = struct('brightfieldChannelName','Channel1_z2');
r = roi('Pos0_1_50', [1 1 4 4]);
r.path = root;
r.image = [];
r.channelid = [1 2 3 3 3];
r.display = displayFixture();
c.roi = r;
classiObj = c; %#ok<NASGU>
matPath = fullfile(root, 'latent_model_1_classification.mat');
save(matPath, 'classiObj');
end

function display = displayFixture()
display = struct();
display.channel = {'Channel1_z2','results_cellposeSAM_cell','CombinedChannel'};
display.intensity = [1 1 1; 0 0 0; 1 1 1];
display.rgb = ones(3,3);
display.selectedchannel = [false true true];
display.indexed = [true true false];
display.alpha = [0.25 0.35 1];
display.contour = [false true false];
display.width = [1 1.5 0];
display.displaylim = repmat([0;1],1,5);
display.colorMode = {'rgb','rgb','rgb'};
display.colormapName = {'','',''};
display.log = [false false false];
display.frame = 1;
display.binning = 1;
display.valueTransform = repmat(struct('mode','raw','unit','raw', ...
    'physicalRange',[0 1],'encodedRange',[0 65535], ...
    'transform','linear'),1,3);
end

function writeDataset(file, path, value, channelName, indices, channelid, indexed)
h5create(file, path, size(value), 'Datatype', class(value));
h5write(file, path, value);
h5writeatt(file, path, 'channel_name', channelName);
h5writeatt(file, path, 'channel_indices', indices);
h5writeatt(file, path, 'channelid', channelid);
h5writeatt(file, path, 'num_subchannels', numel(indices));
h5writeatt(file, path, 'display_indexed', uint8(indexed));
if strcmp(channelName,'Channel1_z2')
    h5writeatt(file,path,'display_intensity',[1 1 1]);
    h5writeatt(file,path,'display_rgb',[1 1 1]);
    h5writeatt(file,path,'display_alpha',0.25);
    h5writeatt(file,path,'display_contour',uint8(0));
    h5writeatt(file,path,'display_selectedchannel',uint8(0));
end
end

function records = payloadHashes(file)
info = h5info(file);
records = strings(1,numel(info.Datasets));
for i = 1:numel(info.Datasets)
    path = ['/' info.Datasets(i).Name];
    records(i) = string(info.Datasets(i).Name) + ":" + arrayHash(h5read(file,path));
end
records = sort(records);
end

function hash = arrayHash(value)
d = java.security.MessageDigest.getInstance('SHA-256');
d.update(typecast(value(:),'uint8'));
raw = typecast(d.digest(),'uint8');
hash = lower(string(reshape(dec2hex(raw,2).',1,[])));
end

function hash = fileHash(path)
d = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(path,'rb');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
while true
    bytes = fread(fid,1024*1024,'*uint8');
    if isempty(bytes), break; end
    d.update(bytes);
end
raw = typecast(d.digest(),'uint8');
hash = lower(reshape(dec2hex(raw,2).',1,[]));
end

function removeFolder(path)
if isfolder(path), rmdir(path,'s'); end
end
