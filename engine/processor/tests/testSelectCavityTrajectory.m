classdef testSelectCavityTrajectory < matlab.unittest.TestCase
    methods (Test)
        function motherResidentKeepsIdentityAndExposesBud(testCase)
            [model,familyId]=baseModel();
            model=addParent(model,familyId,1,2,3,0.95);
            obs=rows([1 2 3 4 5 6 3 4 5 6], ...
                [1 1 1 1 1 1 2 2 2 2], ...
                [50 50 50 50 50 50 75 78 80 82]);
            param=selectCavityTrajectory.setparam();
            param.mode='mother_resident';
            param.anchorYNormalized=0.5;
            result=selectCavityTrajectory.decode( ...
                model,familyId,obs,param,[100 40],6);
            testCase.verifyEqual(result.assignments.TargetTrackID,uint64(ones(6,1)));
            testCase.verifyEqual(result.assignments.CompanionBudTrackID(3:6), ...
                uint64(2*ones(4,1)));
            testCase.verifyEqual(height(result.lifespans),1);
        end

        function daughterTipUsesTypedLineageHandover(testCase)
            [model,familyId]=baseModel();
            model=addParent(model,familyId,1,2,3,0.99);
            obs=rows([1 2 3 4 5 6 3 4 5 6], ...
                [1 1 1 1 1 1 2 2 2 2], ...
                [72 72 72 70 68 66 82 86 92 95]);
            param=selectCavityTrajectory.setparam();
            param.mode='daughter_tip';
            param.minHandoverAgeFrames=2;
            param.minHandoverTipGain=0.05;
            param.lineageHandoverPenalty=0.25;
            param.handoverTipGainWeight=5;
            param.replacementPenalty=20;
            result=selectCavityTrajectory.decode( ...
                model,familyId,obs,param,[100 40],6);
            testCase.verifyEqual(result.assignments.TargetTrackID(1:4),uint64(ones(4,1)));
            testCase.verifyEqual(result.assignments.TargetTrackID(5:6),uint64(2*ones(2,1)));
            testCase.verifyTrue(any(result.events.TransitionType=="lineage_handover"));
            testCase.verifyEqual(height(result.lifespans),2);
        end

        function unrelatedReplacementStartsNewEpisode(testCase)
            [model,familyId]=baseModel();
            obs=rows(1:6,[1 1 1 3 3 3],[50 50 50 50 50 50]);
            param=selectCavityTrajectory.setparam();
            param.mode='mother_resident';
            param.replacementPenalty=1;
            result=selectCavityTrajectory.decode( ...
                model,familyId,obs,param,[100 40],6);
            testCase.verifyEqual(result.assignments.TargetTrackID,uint64([1 1 1 3 3 3]'));
            testCase.verifyTrue(any(result.events.TransitionType=="unrelated_replacement"));
            testCase.verifyEqual(height(result.lifespans),2);
        end

        function shortGapPreservesEpisode(testCase)
            [model,familyId]=baseModel();
            obs=rows([1 2 4 5],[1 1 1 1],[50 50 50 50]);
            param=selectCavityTrajectory.setparam();
            param.mode='mother_resident';
            param.maxVirtualGapFrames=1;
            result=selectCavityTrajectory.decode( ...
                model,familyId,obs,param,[100 40],5);
            testCase.verifyEqual(result.assignments.TargetTrackID,uint64(ones(5,1)));
            testCase.verifyTrue(result.assignments.Abstained(3));
            testCase.verifyEqual(result.assignments.TransitionType(3:4), ...
                ["gap_start";"gap_close"]);
            testCase.verifyEqual(height(result.lifespans),1);
        end

        function viewResolverDerivesLifespans(testCase)
            [model,familyId]=baseModel();
            obs=rows(1:3,[1 1 1],[50 50 50]);
            result=selectCavityTrajectory.decode( ...
                model,familyId,obs,selectCavityTrajectory.setparam(),[100 40],3);
            [assignments,events,lifespans]=cavityTrajectoryView.resolveInput(result.assignments);
            testCase.verifyEqual(height(assignments),3);
            testCase.verifyEqual(height(events),0);
            testCase.verifyEqual(height(lifespans),1);
        end

        function processorMaterializesPipelineOutputs(testCase)
            folder=tempname; mkdir(folder);
            cleanup=onCleanup(@()removeFolder(folder)); %#ok<NASGU>
            r=roi('cavity_test',[1 1 10 10]); r.path=folder;
            stack=zeros(10,10,1,4,'uint16');
            stack(4:7,4:7,1,:)=1;
            stack(7:8,7:8,1,3:4)=2;
            r.addChannel(stack,'pred_tracks',[1 1 1],[0 0 0]);
            model=cellModel.create(r.id); familyId=uint32(1);
            model.families.family_id=familyId;
            model.families.name={'pred_latent_lineage'};
            model.families.mask_provider={'pred_tracks'};
            model.families.lineage_source={'pred:cellLatentModel'};
            model.families.color_rgb=uint8([50 150 250]);
            [ff,ll]=ndgrid(1:4,1);
            instanceFrames=ff(:); labels=ll(:);
            instanceFrames=[instanceFrames;3;4]; labels=[labels;2;2];
            n=numel(instanceFrames);
            model.instances.object_id=uint64((1:n)');
            model.instances.family_id=repmat(familyId,n,1);
            model.instances.frame=uint32(instanceFrames);
            model.instances.mask_label=uint32(labels);
            model.instances.track_id=uint64(labels);
            model.instances.state_id=zeros(n,1,'uint16');
            model=addParent(model,familyId,1,2,3,0.95);
            r.saveCellModel(model,'KeepBackup',false);
            param=selectCavityTrajectory.setparam();
            param.inputFamily='pred_latent_lineage';
            ctx=struct('store',struct('workDir',folder));
            [out,data,image]=selectCavityTrajectory.process(param,r,ctx);
            testCase.verifyNotEmpty(r.findChannelID('cavity_target_cell'));
            testCase.verifyNotEmpty(r.findChannelID('cavity_target_bud'));
            testCase.verifyNotEmpty(r.findChannelID('cavity_target_object'));
            testCase.verifyTrue(isfile(out.artifactFile));
            testCase.verifyTrue(any(arrayfun(@(x)strcmp(x.groupid,'cavity_trajectory'),data)));
            testCase.verifyEqual(size(image,4),4);
        end

        function visualizersRenderTrajectoryAndPool(testCase)
            previous=get(groot,'defaultFigureVisible');
            set(groot,'defaultFigureVisible','off');
            cleanup=onCleanup(@()set(groot,'defaultFigureVisible',previous)); %#ok<NASGU>
            [model,familyId]=baseModel();
            obs=rows(1:4,[1 1 1 1],[50 50 50 50]);
            result=selectCavityTrajectory.decode( ...
                model,familyId,obs,selectCavityTrajectory.setparam(),[100 40],4);
            fig1=cavityTrajectoryView.plotTrajectory(result);
            [fig2,pool]=cavityTrajectoryView.plotLifespanPool({result,result});
            figureCleanup=onCleanup(@()closeFigures([fig1 fig2])); %#ok<NASGU>
            testCase.verifyTrue(isgraphics(fig1));
            testCase.verifyTrue(isgraphics(fig2));
            testCase.verifyEqual(height(pool),2);
        end
    end
end

function removeFolder(folder)
try
    if isfolder(folder), rmdir(folder,'s'); end
catch
end
end

function closeFigures(figures)
for i=1:numel(figures)
    try if isgraphics(figures(i)), close(figures(i)); end, catch, end
end
end

function [model,familyId]=baseModel()
model=cellModel.create('test_roi'); familyId=uint32(1);
model.families.family_id=familyId;
model.families.name={'pred_latent_lineage'};
model.families.mask_provider={'pred_tracks'};
model.families.lineage_source={'pred:cellLatentModel'};
model.families.color_rgb=uint8([50 150 250]);
end

function model=addParent(model,familyId,parent,child,eventFrame,confidence)
model.relations.relation_id=uint64(1);
model.relations.family_id=uint32(familyId);
model.relations.parent_track_id=uint64(parent);
model.relations.child_track_id=uint64(child);
model.relations.event_frame=uint32(eventFrame);
model.relations.type_id=uint8(1);
model.relations.confidence=single(confidence);
end

function obs=rows(frame,track,y)
frame=double(frame(:)); track=double(track(:)); y=double(y(:));
n=numel(frame);
obs=struct('frame',uint32(frame),'track_id',uint64(track), ...
    'mask_label',uint32(track),'centroid_x',20*ones(n,1), ...
    'centroid_y',y,'area',100*ones(n,1));
end
