function tests = testCellLatentModelPathRelocation
%TESTCELLLATENTMODELPATHRELOCATION Regression tests for bundle finalization.
tests = functiontests(localfunctions);
end

function testWindowsRootsRelocateForwardAndBackslashPaths(testCase)
source = 'C:\models\latent_v001.partial_1234';
target = 'C:\models\latent_v001';
value = struct( ...
    'checkpoint','C:/models/latent_v001.partial_1234/tracking/checkpoint', ...
    'report',"c:\models\latent_v001.partial_1234\tracking\report.json", ...
    'nested',{{'C:\models\latent_v001.partial_1234\lineage\model.pt'}});

[relocated,audit] = cellLatentModel.utils.relocatePathTree( ...
    value,source,target);

verifyEqual(testCase,relocated.checkpoint, ...
    'C:/models/latent_v001/tracking/checkpoint');
verifyEqual(testCase,relocated.report, ...
    "C:/models/latent_v001/tracking/report.json");
verifyEqual(testCase,relocated.nested{1}, ...
    'C:/models/latent_v001/lineage/model.pt');
verifyEqual(testCase,double(audit.relocated_path_count),3);
verifyEqual(testCase,double(audit.source_paths_remaining),0);
verifyTrue(testCase,audit.verified_no_transient_paths);
verifyFalse(testCase,contains(jsonencode(relocated),'.partial_1234', ...
    'IgnoreCase',true));
verifyFalse(testCase,contains(jsonencode(audit),'.partial_1234', ...
    'IgnoreCase',true));
end

function testRelocationRequiresPathBoundary(testCase)
source = 'C:/models/latent_v001.partial_1234';
target = 'C:/models/latent_v001';
value = struct( ...
    'exact',source, ...
    'sibling','C:/models/latent_v001.partial_12345/model.pt', ...
    'unrelated','C:/models/other/model.pt');

[relocated,audit] = cellLatentModel.utils.relocatePathTree( ...
    value,source,target);

verifyEqual(testCase,relocated.exact,target);
verifyEqual(testCase,relocated.sibling,value.sibling);
verifyEqual(testCase,relocated.unrelated,value.unrelated);
verifyEqual(testCase,double(audit.relocated_path_count),1);
verifyTrue(testCase,audit.verified_no_transient_paths);
end

function testPosixRootsRemainCaseSensitive(testCase)
source = '/srv/models/bundle.partial_uuid/';
target = '/srv/models/bundle/';
value = {'/srv/models/bundle.partial_uuid/model.pt', ...
    '/srv/models/BUNDLE.partial_uuid/other.pt'};

[relocated,audit] = cellLatentModel.utils.relocatePathTree( ...
    value,source,target);

verifyEqual(testCase,relocated{1},'/srv/models/bundle/model.pt');
verifyEqual(testCase,relocated{2},value{2});
verifyEqual(testCase,double(audit.relocated_path_count),1);
verifyTrue(testCase,audit.verified_no_transient_paths);
end

function testCompositeManifestHasOnlyFinalBundlePaths(testCase)
source = 'C:\classifier\models\model_v001.partial_UUID';
target = 'C:\classifier\models\model_v001';
components = struct( ...
    'tracking',struct('checkpoint', ...
        'C:/classifier/models/model_v001.partial_UUID/tracking/checkpoint'), ...
    'lineage',struct('checkpoint', ...
        'C:/classifier/models/model_v001.partial_UUID/lineage/model.pt'));
artifacts = struct('trackingReport', ...
    'C:\classifier\models\model_v001.partial_UUID\tracking\report.json');

[components,audit] = cellLatentModel.utils.relocatePathTree( ...
    components,source,target);
[artifacts,artifactAudit] = cellLatentModel.utils.relocatePathTree( ...
    artifacts,source,target);
manifest = struct('components',components, ...
    'artifacts',artifacts, ...
    'packaging',struct('path_relocation',struct( ...
        'relocated_path_count',audit.relocated_path_count+ ...
            artifactAudit.relocated_path_count, ...
        'verified_no_transient_paths', ...
            audit.verified_no_transient_paths&& ...
            artifactAudit.verified_no_transient_paths)));
encoded = jsonencode(manifest);

verifyFalse(testCase,contains(encoded,'.partial_UUID', ...
    'IgnoreCase',true));
verifyTrue(testCase,contains(encoded, ...
    'C:/classifier/models/model_v001/tracking/checkpoint'));
verifyTrue(testCase,contains(encoded, ...
    'C:/classifier/models/model_v001/tracking/report.json'));
verifyEqual(testCase,double(manifest.packaging.path_relocation. ...
    relocated_path_count),3);
verifyTrue(testCase,manifest.packaging.path_relocation. ...
    verified_no_transient_paths);
end


function testTextArtifactsAreRelocatedAndRehashed(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
source = 'C:\classifier\models\model_v002.partial_UUID';
target = 'C:\classifier\models\model_v002';
report = fullfile(root,'training_report.json');
config = fullfile(root,'training_config.json');
plain = fullfile(root,'training_stdout.txt');
writeText(report,jsonencode(struct( ...
    'checkpoint',[source '\tracking\checkpoint'], ...
    'sibling','C:\classifier\models\model_v002.partial_UUID_extra\x.pt', ...
    'x0_5',true)));
reportText = fileread(report);
reportText = strrep(reportText,'"x0_5"','"0.5"');
reportText = strrep(reportText,'"sibling"', ...
    '"checkpoint/manifest.json":"stable","metric":NaN,"sibling"');
writeText(report,reportText);
writeText(config,jsonencode(struct( ...
    'output_dir',strrep([source '\lineage'],'\','/'))));
writeText(plain,sprintf('output=%s\\tracking\n',source));

audit = cellLatentModel.utils.relocateTextArtifacts( ...
    root,source,target);

decodedReport = jsondecode(fileread(report));
decodedConfig = jsondecode(fileread(config));
rawReport = fileread(report);
verifyTrue(testCase,contains(rawReport,'"0.5"'));
verifyTrue(testCase,contains(rawReport,'"checkpoint/manifest.json"'));
verifyTrue(testCase,contains(rawReport,'"metric":NaN'));
verifyFalse(testCase,contains(rawReport,'"x0_5"'));
verifyEqual(testCase,normalizePath(decodedReport.checkpoint), ...
    'C:/classifier/models/model_v002/tracking/checkpoint');
verifyEqual(testCase,decodedReport.sibling, ...
    'C:\classifier\models\model_v002.partial_UUID_extra\x.pt');
verifyEqual(testCase,normalizePath(decodedConfig.output_dir), ...
    'C:/classifier/models/model_v002/lineage');
plainText = regexprep(strrep(fileread(plain),'\','/'),'/+','/');
verifyTrue(testCase,contains(plainText, ...
    'C:/classifier/models/model_v002/tracking'));
verifyEqual(testCase,double(audit.checked_file_count),3);
verifyEqual(testCase,double(audit.rewritten_file_count),3);
verifyEqual(testCase,double(audit.relocated_path_count),3);
verifyEqual(testCase,double(audit.source_paths_remaining),0);
verifyTrue(testCase,audit.verified_no_transient_paths);
end

function testAppendJsonFieldPreservesExternalDictionaryKeys(testCase)
root=tempname;
mkdir(root);
cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
manifest=fullfile(root,'manifest.json');
writeText(manifest,[ ...
    '{"files":{"relations.npz":"abc"},' ...
    '"thresholds":{"0.5":true},"metric":NaN}']);
sources=struct('path','C:/dataset/source.h5','sha256','def','bytes',3);

cellLatentModel.utils.appendJsonField( ...
    manifest,'materialized_sources',sources);

raw=fileread(manifest);
decoded=jsondecode(raw);
verifyTrue(testCase,contains(raw,'"relations.npz"'));
verifyTrue(testCase,contains(raw,'"0.5"'));
verifyTrue(testCase,contains(raw,'"metric":NaN'));
verifyTrue(testCase,contains(raw,'"materialized_sources"'));
verifyEqual(testCase,decoded.materialized_sources.sha256,'def');
end

function writeText(filename,text)
fid=fopen(filename,'w');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,text,'char');
end

function value=normalizePath(value)
value=regexprep(strrep(char(string(value)),'\','/'),'/+','/');
end
