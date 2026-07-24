function tests = testCellLatentModelIntegration
%TESTCELLLATENTMODELINTEGRATION Exercise Python inference and training.
tests = functiontests(localfunctions);
end

function testBuiltinInferencePersistsMultimodalLineage(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
roiobj = syntheticROI(folder,'latent_inference',0);
param = cellLatentModel.utils.defaultExecutionParam();
param.trackChannelName = 'results_trackastra';
param.gfpChannelName = 'ch2-GFP';
param.outputFamilyName = 'Latent integration';
param.device = 'cpu';
param.maxParentContourDistance = 25;
ctx = struct('store',struct('workDir',fullfile(folder,'runtime')));
[resolved,~,imageout] = cellLatentModel.core(param,roiobj,ctx);
verifyEmpty(testCase,imageout);
verifyEqual(testCase,resolved.runtime.package,'cell_latent_model');
verifyTrue(testCase,resolved.runtime.gfp_used);
verifyTrue(testCase,isfile(resolved.auditFile));
audit = jsondecode(fileread(resolved.auditFile));
verifyEqual(testCase,audit.tool,'cell_latent_model');
verifyGreaterThanOrEqual(testCase,double(audit.summary.events),1);
[model,report] = roiobj.loadCellModel('Force',true);
verifyTrue(testCase,report.validation.ok);
[familyIndex,~] = cellModel.familyIndex(model,param.outputFamilyName);
verifyNotEmpty(testCase,familyIndex);
verifyEqual(testCase, ...
    model.families.mask_provider{familyIndex},'results_trackastra');
verifyEqual(testCase, ...
    model.families.lineage_source{familyIndex},'cellLatentModel');
end

function testClassifierLifecycleFormatsTrainsAndValidates(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
classifier = classi(folder,'latent_lifecycle',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'latent_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'latent_validation',1);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.channelName = {'results_trackastra','ch2-GFP'};
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.gfpChannelName = 'ch2-GFP';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
classifier.trainingParam.epochs = 2;
classifier.trainingParam.seedCount = 1;
classifier.trainingParam.device = 'cpu';

formatted = cellLatentModel.format(classifier,1,struct());
verifyEqual(testCase,formatted.status,"OK");
verifyTrue(testCase,isfile(formatted.artifacts.manifest));
trained = cellLatentModel.train(classifier,struct());
verifyEqual(testCase,trained.status,"OK");
verifyTrue(testCase,isfile(trained.artifacts.model));
verifyEqual(testCase,classifier.executionParam.modelSource,'trained');
validated = cellLatentModel.validate(classifier,2,struct());
verifyEqual(testCase,validated.status,"OK");
verifyGreaterThanOrEqual(testCase, ...
    double(validated.metrics.labeled_events),1);
verifyTrue(testCase,isfinite(double(validated.metrics.top1)));
end

function roiobj = syntheticROI(folder,id,offset)
if ~isfolder(folder), mkdir(folder); end
height = 80;
width = 80;
frames = 12;
[xx,yy] = meshgrid(1:width,1:height);
tracks = zeros(height,width,frames,'uint16');
gfp = zeros(height,width,frames,'single');
for frame = 1:frames
    plane = zeros(height,width,'uint16');
    plane(((xx-(32+offset))/10).^2 + ((yy-40)/13).^2 <= 1) = 1;
    plane(((xx-58)/9).^2 + ((yy-40)/12).^2 <= 1) = 2;
    if frame >= 3
        radius = min(8,4+floor((frame-1)/2));
        plane(((xx-(43+offset))/radius).^2 + ...
            ((yy-35)/(radius+1)).^2 <= 1) = 3;
    end
    tracks(:,:,frame) = plane;
    signal = single(0.05*ones(height,width));
    signal((xx-(32+offset)).^2 + (yy-40).^2 <= 16) = ...
        single(1 + 0.05*frame);
    gfp(:,:,frame) = signal;
end
roiobj = roi(id,[1 1 width height]);
roiobj.path = folder;
roiobj.image = zeros(height,width,2,frames,'single');
roiobj.image(:,:,1,:) = single(tracks);
roiobj.image(:,:,2,:) = gfp;
roiobj.channelid = [1 2];
displayState = roiobj.display;
displayState.channel = {'results_trackastra','ch2-GFP'};
displayState.indexed = [true false];
displayState.rgb = [1 1 1; 1 1 1];
roiobj.display = displayState;
end

function writeReviewedLineage(roiobj)
tracks = uint32(squeeze(roiobj.image(:,:,1,:)));
model = cellModel.create(roiobj.id);
result = struct('edges',struct( ...
    'status','linked', ...
    'pred_parent_id',1, ...
    'child_track_id',3, ...
    'bud_appearance_frame',3, ...
    'top_score',1));
[model,~,~] = cellModel.applyLineageResult( ...
    model,tracks,'results_trackastra','<auto>', ...
    'Reviewed lineage',result,true,'manual_review');
roiobj.saveCellModel(model);
end

function removeFolder(folder)
if isfolder(folder)
    try rmdir(folder,'s'); catch, end
end
end
