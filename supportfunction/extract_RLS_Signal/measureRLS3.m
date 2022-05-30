function measureRLS3(roiobj,param,varargin)


%'Fluo' if =1, will computethe fluo of each channel over the divs

%ClassiType is the classif type of obj :
% ClassiType='bud' : unbudded, small, large, dead etc.
% ClassiType='div' : nodiv, div, dead etc.

% rls combines results and groundtruth is applicable
% rlsResults only results
%rlsGroundtruth only groundtruth
%loadres=1;
%environment='pc';


if numel(param)==0
param.classifierName={'myclassi','myclassi'};
param.classes='unbud small large dead clog empty';
param.classiftype='bud';
%param.timeRate=[];
param.postProcessing=1;
param.errorDetection=1;
param.timeRate=5;
%these param must be adjusted by the user, in particular if the experiment
%is shorter than 500 frames.
param.ArrestThreshold=175;
param.DeathThreshold=3;
param.ClogThreshold=1;
param.EmptyThresholdDiscard=500; %discard roi if empty for more than this number of frames
param.EmptyThresholdNext=100; %if encounter an empy after birth but before birth+EmptyThresholdNext, check the new RLS
param.Frames=[];

for i=1:numel(varargin)
    
%     if strcmp(varargin{i},'Envi')
%         environment=varargin{i+1};
%     end
    
    %PARAMS OF DIV DETECTION
    %ClassiType
    if strcmp(varargin{i},'ClassiType')
        param.classiftype=varargin{i+1};
        if strcmp(param.classiftype,'div') && strcmp(param.classiftype,'bud')
            error('Please enter a valid classitype');
        end                
    end
    
    %ArrestThreshold
      if strcmp(varargin{i},'ClassifierName')
        param.classifierName=varargin{i+1};
      end

    if strcmp(varargin{i},'ArrestThreshold')
        param.ArrestThreshold=varargin{i+1};
    end
    
    %DeathThreshold
    if strcmp(varargin{i},'DeathThreshold')
        param.DeathThreshold=varargin{i+1};
    end
    
    %DeathThreshold
    if strcmp(varargin{i},'ClogThreshold')
        param.DeathThreshold=varargin{i+1};
    end
        
    %postProcessing
    if strcmp(varargin{i},'PostProcessing')
        param.postProcessing=varargin{i+1};
    end
    
    %detectError
    if strcmp(varargin{i},'ErrorDetection')
        param.errorDetection=varargin{i+1};
    end
    
    %frames
    if strcmp(varargin{i},'Frames')
        param.Frames=varargin{i+1};
    end
    
    %timeRate
    if strcmp(varargin{i},'TimeRate')
        param.timeRate=varargin{i+1};
    end
end
end

if ischar(param.classifierName)
classifstrid=param.classifierName;
else
classifstrid=param.classifierName{end};
end

if ~ischar(param)
param.classiftype=param.classiftype{end};
end

classif=evalin('base',classifstrid);
classifstrid=classif.strid;


%%
for i=1:numel(roiobj)
    roiobj(i).load('results');
    roiobj(i).path=strrep(roiobj(i).path,'/shared/space2/','\\space2.igbmc.u-strasbg.fr\');
    
    if param.Frames==0 %auto bounds
        if isfield(roiobj(i).train.(classifstrid),'bounds')
            param.Frames=roiobj(i).train.(classifstrid).bounds;
        end
    end
    roiobj(i).results.RLS.(['from_' classifstrid])=RLS(roiobj(i),'result',classif,param,i); %struct() use to keep measureRLS2 code
    roiobj(i).train.RLS.(['from_' classifstrid])=RLS(roiobj(i),'train',classif,param,i); %struct() use to keep measureRLS2 code
    
    %     if isprop(roiobj(i),'train') && numel(roiobj(i).train.(classifstrid).id)>0
    %         roiobj(i).train.(classifstrid).RLS=RLS(roiobj(i),'train',classif,param);
    %     end
    
    roiobj(i).save('results');
    roiobj(i).clear;
end

%=========================================RLS============================================
function [rls,rlsResults,rlsGroundtruth]=RLS(roi,roitype,classif,param,i)

% rls.divDuration=[];
% rls.frameBirth=[];
% rls.frameEnd=[];
% rls.endType=[];
% rls.framediv=[];
% rls.sep=[];
% rls.roiid=[];
% rls.name='';
% rls.ndiv=0;
% rls.totaltime=0;
% rls.rules=[];
% rls.divSignal=[];
%
%
% rlsResults=rls;
% rlsGroundtruth=rls;


classistrid=classif.strid;
classes=classif.classes;

if strcmp(roitype,'result')
    %================RESULTS===============
    if isfield(roi.results,classistrid) && isfield(roi.results.(classistrid),'id') && sum(roi.results.(classistrid).id)>0
        
        id=roi.results.(classistrid).id; % results for classification
        proba=roi.results.(classistrid).prob;
        
        divTimes=computeDivtime(id,proba,classes,param);
        
        rlsResults.divDuration=divTimes.duration;
        rlsResults.timeRate=param.timeRate;
        rlsResults.frameBirth=divTimes.frameBirth;
        rlsResults.frameEnd=divTimes.frameEnd;
        rlsResults.endType=divTimes.endType;
        rlsResults.framediv=divTimes.framediv;
        rlsResults.sep=[];
        rlsResults.name=roi.id;
        rlsResults.roiid=i;
        rlsResults.ndiv=divTimes.ndiv;
        if numel(divTimes.framediv)>0
            rlsResults.totaltime=[divTimes.framediv(1)-divTimes.frameBirth, cumsum(divTimes.duration)+divTimes.framediv(1)-divTimes.frameBirth];
        else
            rlsResults.totaltime=0;
        end
        rlsResults.rules=[];
        rlsResults.groundtruth=0;
        rlsResults.divSignal=[];
        
        divSignal=computeSignalDiv(roi,rlsResults);
        rlsResults.divSignal=divSignal;
        
        rlsResults.bounds=param.Frames;
        
        %sep
        rlsResults.sep=findSync(rlsResults);
    else
%        warning(['There is no result available for ROI ' char(roi.id)]);
        rlsResults.groundtruth=0;
        rlsResults.divDuration=[];
        rlsResults.timeRate=param.timeRate;
        rlsResults.frameBirth=[];
        rlsResults.frameEnd=[];
        rlsResults.endType=[];
        rlsResults.framediv=[];
        rlsResults.sep=[];
        rlsResults.roiid=i;
        rlsResults.name=roi.id;
        rlsResults.ndiv=-1;
        rlsResults.totaltime=-1;
        rlsResults.rules=[];
        rlsResults.bounds=param.Frames;
        rlsResults.divSignal=[];
    end
    
    rls=rlsResults;
elseif strcmp(roitype,'train')
    %==================GROUNDTRUTH===================
    idg=[];
    if isfield(roi.train,(classistrid)) && isfield(roi.train.(classistrid),'id') && sum(roi.train.(classistrid).id)>0
        idg=roi.train.(classistrid).id; % results for classification
        disp(['Groundtruth data are available for ROI ' num2str(roi.id)]);
        
        proba=-1;
        divTimesG=computeDivtime(idg,proba,classes,param); % groundtruth data
        
        rlsGroundtruth.divDuration=divTimesG.duration;
        rlsGroundtruth.timeRate=param.timeRate;
        rlsGroundtruth.frameBirth=divTimesG.frameBirth;
        rlsGroundtruth.frameEnd=divTimesG.frameEnd;
        rlsGroundtruth.endType=divTimesG.endType;
        rlsGroundtruth.framediv=divTimesG.framediv;
        rlsGroundtruth.sep=[];
        rlsGroundtruth.name=roi.id;
        rlsGroundtruth.roiid=i;
        %rlsGroundtruth.roiid=[];
        rlsGroundtruth.ndiv=divTimesG.ndiv;
        rlsGroundtruth.totaltime=[divTimesG.framediv(1)-divTimesG.frameBirth, cumsum(divTimesG.duration)+divTimesG.framediv(1)-divTimesG.frameBirth];
        rlsGroundtruth.rules=[];
        rlsGroundtruth.groundtruth=1;
        rlsGroundtruth.divSignal=[];
        rlsGroundtruth.bounds=param.Frames;
        
        divSignalG=computeSignalDiv(roi,rlsGroundtruth);
        rlsGroundtruth.divSignal=divSignalG;
        
        %sep
        rlsGroundtruth.sep=findSync(rlsGroundtruth);
    else
        disp(['There is no groundtruth available for ROI ' char(roi.id)]);
        rlsGroundtruth.groundtruth=1;
        rlsGroundtruth.divDuration=[];
        rlsGroundtruth.timeRate=param.timeRate;
        rlsGroundtruth.frameBirth=[];
        rlsGroundtruth.frameEnd=[];
        rlsGroundtruth.endType=[];
        rlsGroundtruth.framediv=[];
        rlsGroundtruth.sep=[];
        rlsGroundtruth.roiid=i;
        rlsGroundtruth.name=roi.id;
        rlsGroundtruth.ndiv=-1;
        rlsGroundtruth.totaltime=-1;
        rlsGroundtruth.rules=[];
        rlsGroundtruth.bounds=param.Frames;
        rlsGroundtruth.divSignal=[];
    end
    rls=rlsGroundtruth;
end




















%% =========================================DIVTIMES=================================================
function [divTimes]=computeDivtime(id,proba,classes,param)
if numel(param.Frames)==2
    id=id(param.Frames(1):param.Frames(2));
end
divTimes=[];

% first identify frame corresponding to death or clog and birth (non
% empty cavity)

switch param.classiftype
    
    %========================CLASSIF BUD========================
    case 'bud'
        deathid=findclassid(classes,'dead');
        clogid=findclassid(classes,'clog');
        lbid=findclassid(classes,'large');
        smid=findclassid(classes,'small');
        unbuddedid=findclassid(classes,'unbud');
        emptyid=findclassid(classes,'empty');
        
        if (proba~=-1) & (param.postProcessing==1)
            probaPP=proba;
            probaPP(smid,:)=medfilt1(probaPP(smid,:),4);
            probaPP(lbid,:)=medfilt1(probaPP(lbid,:),4);
            
            [~,idPP]=max(probaPP,[],1);
            id=idPP;
        end
        
        
        %===1// find BIRTH===
        
        firstunb=find(id==unbuddedid,1,'first');
        firstsm=find(id==smid,1,'first');
        firstlg=find(id==lbid,1,'first');
        if numel(firstunb)==0 %isempty
            firstunb=NaN;
        end
        if numel(firstsm)==0
            firstsm=NaN;
        end
        if numel(firstlg)==0
            firstlg=NaN;
        end
        frameBirth=min([firstunb,firstsm,firstlg]);
        
        %===2// Identify potential END===
        %==find potential first EMPTY frame, after birth
        frameFirstEmptiedAfterBirth=NaN;
        bwEmpty=(id==emptyid);
        bwEmptyLabeled=bwlabel(bwEmpty);
        for k=1:max(bwEmptyLabeled)
            bwEmpty=(bwEmptyLabeled==k);
            if sum(bwEmpty)> 2 && find(bwEmpty,1,'first')>frameBirth
                frameFirstEmptiedAfterBirth=find(bwEmpty,1,'first');
                break
            end
        end
        
        %==post-process empty : if empty very early: check the next rls
        if frameFirstEmptiedAfterBirth<param.EmptyThresholdNext%frameFirstEmptiedAfterBirth>param.EmptyThresholdDiscard
            frameAfterFirstEmpty=find(bwEmpty,1,'last');
            %search from after the first empty islet (after first birth)
            %until the end
            firstunb=find(id(frameAfterFirstEmpty:end)==unbuddedid,1,'first');
            firstsm=find(id(frameAfterFirstEmpty:end)==smid,1,'first');
            firstlg=find(id(frameAfterFirstEmpty:end)==lbid,1,'first');
            if numel(firstunb)==0 %isempty
                firstunb=NaN;
            end
            if numel(firstsm)==0
                firstsm=NaN;
            end
            if numel(firstlg)==0
                firstlg=NaN;
            end
            frameBirth=min([firstunb,firstsm,firstlg]);
        end
        %
        
        %==find DEATH (need N frames to be validated)======
        frameDeath=NaN;
        if ~isnan(frameBirth)
            idpostBirth=id;
            idpostBirth(1:frameBirth)=0;%only consider death if cell is born (to ignore death if first images of roi is death=
            bwDeath=(idpostBirth==deathid);
            bwDeath(1:frameBirth)=0; %useless?
            bwDeathLabeled=bwlabel(bwDeath);
            for k=1:max(bwDeathLabeled)
                bwDeath=(bwDeathLabeled==k);
                if sum(bwDeath)>= param.DeathThreshold || find(bwDeath,1,'last')==numel(id) % if ... or if the last frame is "dead", then consider as death
                    frameDeath=find(bwDeath,1,'first');
                    break
                end
            end
        end
        %
        
        
        %==find potential first CLOG==============
        frameClog=NaN;
        if ~isnan(frameBirth)
            idpostBirth=id;
            idpostBirth(1:frameBirth)=0;%only consider clog if cell is born (to ignore clog if first images of roi is clog=
            bwClog=(idpostBirth==clogid);
            bwClog(1:frameBirth)=0; %useless?
            bwClogLabeled=bwlabel(bwClog);
            for k=1:max(bwClogLabeled)
                bwClog=(bwClogLabeled==k);
                if sum(bwClog)>= param.ClogThreshold
                    frameClog=find(bwClog,1,'first');
                    break
                end
            end
        end        
%         if ~isnan(frameBirth)            
%             frameClog=find((idpostBirth==clogid),1,'first');
%         end
        %
        
        
        %==find potential division arrest==========
        frameArrest=NaN;
        for arrestid=[unbuddedid,smid,lbid]
            bwArrest=(id==arrestid);
            bwArrestLabel=bwlabel(bwArrest);
            for k=1:max(bwArrestLabel)
                bwArrest=(bwArrestLabel==k);
                if sum(bwArrest)> param.ArrestThreshold
                    if ~isnan(frameArrest)
                        frameArrest=min(frameArrest,(find(bwArrest,1,'first')+ param.ArrestThreshold));
                    else
                        frameArrest=find(bwArrest,1,'first')+ param.ArrestThreshold;
                    end
                    break
                end
            end
        end
        %
        
        %===3/ find END===
        if isnan(frameBirth) %if timeseries has never seen unb, small or large
            frameEnd=NaN;
            endType='NeverBorn';
        else
            frameEnd=min([frameClog, frameDeath, frameFirstEmptiedAfterBirth, frameArrest]);
            if isnan(frameEnd) % cell is not dead or clogged or empty, TO DO: SEPARATE BETWEEN DEATH AND CENSOR
                frameEnd=numel(id);
                %machin.censor=1;
            end
            endTypeid=find([frameClog, frameDeath, frameFirstEmptiedAfterBirth, frameArrest, numel(id)]==frameEnd,1,'last');
            endTypeList={'Clog', 'Death', 'Emptied', 'Arrest', 'stillAlive'};
            endType=endTypeList{endTypeid};
        end
        %
        
        
        %===4/ detect divisions===
        %==post-processing
%         if param.postProcessing==1
%             stopProcessing=0;
%             while stopProcessing==0
%                 bwsmid=(id==smid);
%                 bwsmidLabel=bwlabel(bwsmid); %find small islets
%                 for k=1:max(bwsmidLabel)
%                     bwsmidk(k,:)=(bwsmidLabel==k);
%                 end
%                 
%                 if max(bwsmidLabel)>2
%                     for k=2:max(bwsmidLabel)-1
%                         if sum(bwsmidk(k,:))>=1 %if a smallid islet is of size 1, check the neighbours islets
%                             idx=find(bwsmidk(k,:),1,'first');
%                             %idxprev=find(bwsmidk(k-1,:),1,'last');%find previous islet end
%                             idxnext=find(bwsmidk(k+1,:),1,'first');%find next islet start
%                             idxprev=find(bwsmidk(k-1,:),1,'last'); %find prev islet start
%                             
%                             if (idx-idxprev<5) %if the potential false small is too close from another small islet -->correct it as the previous class
%                                 id(idx)=id(idx-1); break
%                             elseif (idxnext-idx <5) %if the potential false small is too close from another small islet -->correct it as the previous class
%                                 id(idx)=id(idx-1); break
%                             end
%                         end
%                         stopProcessing=1;
%                     end
%                 else
%                     stopProcessing=1;
%                 end
%             end
%             
%             %small->unbud, can be improved by checking the islets size
%             bwsmid=(id==smid);
%             bwsmidLabel=bwlabel(bwsmid); %find small islets
% 
%             for j=1:numel(id)-1
%                 if (id(j)==smid && id(j+1)==unbuddedid)
%                     
%                     isletLabel=bwsmidLabel(j);
%                     idxToCorrect=(bwsmidLabel==isletLabel); %islet to correct
%                     id(idxToCorrect)=lbid;
%                 end
%             end
%         end
        
        %=====Div counting=====
        %
        %
        divFrames=[];
        startAfterBudEmergence=0;
        if ~isnan(frameBirth)
            %===divided before start of timelapse==?
            if id(frameBirth)==smid || id(frameBirth)==lbid
                startAfterBudEmergence=1;
            end
            
            %==detect bud emergence==
            for j=frameBirth:frameEnd-1
                if (id(j)==lbid && id(j+1)==smid) || (id(j)==unbuddedid && id(j+1)==smid) % bud has emerged
                    divFrames=[divFrames j+1];
                end
            end
        end
        %
        if numel(divFrames)==0
            divFrames=NaN;
        end
        divTimes.frameBirth=frameBirth;
        divTimes.frameEnd=frameEnd;
        divTimes.endType=endType;
        divTimes.framediv=divFrames;
        divTimes.duration=diff(divFrames); % division times !
        divTimes.ndiv=sum(~isnan([divTimes.framediv]));
        %if timelapse started while the cell is small or large
        if startAfterBudEmergence==1
            divTimes.ndiv=divTimes.ndiv+1;
        end
        
        
        
        
        %%=================================CLASSIF DIV======================================
    case 'div'
        deathid=findclassid(classes,'dead');
        censorid=findclassid(classes,'censor');
        nodivid=findclassid(classes,'nodiv');
        divid=findclassid(classes,'div');
        emptyid=findclassid(classes,'birth');
        
        
        startFrame=find(id==emptyid,1,'last');
        if numel(startFrame)==0
            startFrame=1;
        end
        
        endFrame=min( find(id==deathid,1,'first')  ,  find(id==censorid,1,'first'));
        if numel(endFrame)==0
            endFrame=numel(id);
        end
        
        divFrames=startFrame;
        for j=startFrame:endFrame
            if id(j)==divid % cell has divided
                divFrames=[divFrames j];
            end
        end
        divTimes.framediv=divFrames;
        divTimes.duration=diff(divFrames); % division times !
end









%% ==============================================SIGNAL======================================================
function divSignal=computeSignalDiv(roi,rls)
divSignal=[];
divSignal.divDuration=rls.divDuration; % redundant with rls.divDuration, but convenient for plotSignal.m
%check all the fields of .results.signal and mean them by div
if isfield(roi.results,'signal') && ~isempty(roi.results.signal)>0
    rF=fields(roi.results.signal); %full, cell, nucleus
    %essayer try catch
    for rf=1:numel(rF)
        cF=fields(roi.results.signal.(rF{rf})); %obj2
        for cf=1:numel(cF)
            fF=fields(roi.results.signal.(rF{rf}).(cF{cf})); %max, mean, volume...
            for ff=1:numel(fF)
                for chan=1:numel(roi.results.signal.(rF{rf}).(cF{cf}).(fF{ff})(:,1))
                    tt=1;
                    %                     if numel(rls.divDuration)==0
                    %                             divSignal.(rF{rf}).(cF{cf}).(fF{ff})(chan)=[];
                    %                     else
                    if numel(rls.divDuration)>0
                        for t=1:numel(rls.divDuration)
                            divSignal.(rF{rf}).(cF{cf}).(fF{ff})(chan,t)=nanmean(roi.results.signal.(rF{rf}).(cF{cf}).(fF{ff})(chan,rls.framediv(tt):rls.framediv(tt+1)));
                            divSignal.(rF{rf}).(cF{cf}).([fF{ff} 'FoldInc'])(chan,t)=nanmean(roi.results.signal.(rF{rf}).(cF{cf}).(fF{ff})(chan,rls.framediv(tt):rls.framediv(tt+1)))./nanmean(roi.results.signal.(rF{rf}).(cF{cf}).(fF{ff})(chan,rls.framediv(1):rls.framediv(2)));
                            tt=tt+1;
                        end
                    end
                    if numel(rls.divDuration)>1 && numel(isnan(divSignal.(rF{rf}).(cF{cf}).(fF{ff})(chan,:)))==0 %incrate only if all frames have signal. To code : incrate if signal as different snap frequency
                        divSignal.(rF{rf}).(cF{cf}).([fF{ff} 'IncRate'])(chan,:)=diff(divSignal.(rF{rf}).(cF{cf}).(fF{ff})(chan,:))./divSignal.(rF{rf}).(cF{cf}).(fF{ff})(chan,1:end-1);
                        divSignal.(rF{rf}).(cF{cf}).([fF{ff} 'IncRate'])=[NaN divSignal.(rF{rf}).(cF{cf}).([fF{ff} 'IncRate'])];
                    end
                    
                    %                     end
                end
            end
        end
    end
else disp(['No results.signal for roi ' num2str(roi.id)]);
end























%%
%=============================================SEP==========================================
function [syncPoint]=findSync(rls)
align=1; %1: SEP, 2: death
syncType={'birthSynced', 'SEPSynced','deathSynced'};
threshStart=1;
numrls=numel(rls);

divDur=rls.divDuration;
if numel(divDur)>1
    [syncPoint,~]=findSEP(divDur,1); %find SEP using classical xhi² fit based on div frequency
else syncPoint=NaN;
end


function clid=findclassid(classes,str)
clid=[];
for ck=1:numel(classes)
    if strcmp(classes{ck},str)
        clid=ck;
        break;
    end
end
