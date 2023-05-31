function paramout=computeRLS(param,roiobj,frames)


if nargin==0
    listout=listROIDataID("classification"); % lists all data that were generated using a classifier
    listout{end+1}=listout{end};

    paramout=[];

    tip={'Classification data output name',...
        'Use post processing - data cleaning up',...
        'Error detection',...
        'Arrest threshold frame number',...
        'Death threshold frame number',...
        'Clog threshold frame number',...
        'Empty Threshold Discard frame number',...
        'EmptyThresholdNext',...
        };

    paramout.classification_data=listout;
   % paramout.classes='unbud small large dead clog empty';
    %paramout.classiftype='bud';
    paramout.postProcessing=true;
    paramout.errorDetection=false;
    %these paramout must be adjusted by the user, in particular if the experiment
    %is shorter than 500 frames.
    paramout.ArrestThreshold=175;
    paramout.DeathThreshold=3;
    paramout.ClogThreshold=1;
    paramout.EmptyThresholdDiscard=500; %discard roi if empty for more than this number of frames
    paramout.EmptyThresholdNext=100; %if encounter an empy after birth but before birth+EmptyThresholdNext, check the new RLS
 
    paramout.tip=tip;

    return;
else
    paramout=param;
end

param=paramout;

roiobj.load('results');
 
listdata={roiobj.data.groupid};
pix=find(matches(listdata,param.classification_data{end}));

if numel(pix)==0
    disp('impossible to find the classified data');
    return;
end

data=roiobj.data(pix);

    if nargin~=3 %auto bounds
        if isfield(data.userData,'bounds')
            frames=data.userData.bounds;
        end
    end

id =data.getData('id'); % class id for classif output
id_training=data.getData('id_training'); % class id ouput for training; 

if numel(id)~=0 

      if isfield(data.userData,'classes')
            classes=data.userData.classes;
      else
            disp('could not identify classes used in the classification pipeline');
            return;
      end

    proba=[];
    for i=1:numel(classes)
        str=['prob_' classes{i}];

        proba=[proba data.getData(str)];
    end

     divTimes=computeDivtime(id,proba',classes,param,frames);

     if numel(divTimes.framediv)>0

    % framesOut=[divTimes.frameBirth divTimes.framediv divTimes.frameEnd];

     event="Budding";
     event=repmat(event,[1 numel(divTimes.duration)]);
     event=[event divTimes.endType];
   
     divDuration=[NaN, divTimes.duration, NaN, NaN];

     totaltime=[0, divTimes.framediv(1)-divTimes.frameBirth, cumsum(divTimes.duration)+divTimes.framediv(1)-divTimes.frameBirth -divTimes.frameEnd-divTimes.frameBirth];
 
     sep=[];
       
     end

end

% HERE : formatt! 

event 
divDuration
totaltime

return;

divTimes_training=[];

if numel(id_training)~=0 

      if isfield(data.userData,'classes')
            classes=data.userData.classes;
      else
            disp('could not identify classes used in the classification pipeline');
            return;
      end

    for i=1:numel(classes)
        str=['prob_' classes{i}];

        proba=[proba data.getData(str)];
    end

     divTimes_training=computeDivtime(id_training,[],classes,param,frames);

%        divDuration=divTimes.duration;
%        frameBirth=divTimes.frameBirth;
%        frameEnd=divTimes.frameEnd;
%        endType=divTimes.endType;
%        framediv=divTimes.framediv;
%        sep=[];
%        ndiv=divTimes.ndiv;
% 
%         if numel(divTimes.framediv)>0
%             totaltime=[divTimes.framediv(1)-divTimes.frameBirth, cumsum(divTimes.duration)+divTimes.framediv(1)-divTimes.frameBirth];
%         else
%             totaltime=0;
%         end
end



pixdata=find(arrayfun(@(x) strcmp(x.groupid, ['RLS_' param.classification_data{end}]),roiobj.data)); % find if object exists already
%
 if numel(pixdata)
            cc=pixdata(1); % data to be overwritten
  else
            n=numel(roiobj.data);
            if n==1 & numel(roiobj.data.data)==0
                cc=1; % replace empty dataset
            else
                cc=numel(roiobj.data)+1;
            end
  end

  plotgroup={'divisions'};
  temp=dataseries(divDuration',{'divDuration'},...
            'groupid',['RLS_' param.classification_data{end}],'parentid',roiobj.id,'plot',{true},'groups',plotgroup);

  roiobj.data(cc)=temp;
  roiobj.data(cc).class="processing";
  roiobj.data(cc).type="generation";
  roiobj.data(cc).plotGroup={[] [] [] [] [] unique(plotgroup)};

 
if numel(divTimes_training)
% here add data
end

% to do : compute fluo, find sep, sync trajectories 


% if strcmp(roitype,'result')
%     %================RESULTS===============
%     if isfield(roi.results,classifstrid) && isfield(roi.results.(classifstrid),'id') && sum(roi.results.(classifstrid).id)>0
%         
%         classes=roi.results.(classifstrid).classes;
%         id=roi.results.(classifstrid).id; % results for classification
%         proba=roi.results.(classifstrid).prob;
%         
%         divTimes=computeDivtime(id,proba,classes,param);
%         
%         rlsResults.divDuration=divTimes.duration;
%         rlsResults.frameBirth=divTimes.frameBirth;
%         rlsResults.frameEnd=divTimes.frameEnd;
%         rlsResults.endType=divTimes.endType;
%         rlsResults.framediv=divTimes.framediv;
%         rlsResults.sep=[];
%         rlsResults.name=roi.id;
%         rlsResults.roiid=i;
%         rlsResults.ndiv=divTimes.ndiv;
%         if numel(divTimes.framediv)>0
%             rlsResults.totaltime=[divTimes.framediv(1)-divTimes.frameBirth, cumsum(divTimes.duration)+divTimes.framediv(1)-divTimes.frameBirth];
%         else
%             rlsResults.totaltime=0;
%         end
%         rlsResults.rules=[];
%         rlsResults.groundtruth=0;
%         rlsResults.divSignal=[];
%         
%         divSignal=computeSignalDiv(roi,rlsResults);
%         rlsResults.divSignal=divSignal;
%         
%         rlsResults.bounds=param.Frames;
%         
%         %sep
%         rlsResults.sep=findSync(rlsResults);
%     else
%         %        warning(['There is no result available for ROI ' char(roi.id)]);
%         rlsResults.groundtruth=0;
%         rlsResults.divDuration=[];
%         rlsResults.frameBirth=[];
%         rlsResults.frameEnd=[];
%         rlsResults.endType=[];
%         rlsResults.framediv=[];
%         rlsResults.sep=[];
%         rlsResults.roiid=i;
%         rlsResults.name=roi.id;
%         rlsResults.ndiv=-1;
%         rlsResults.totaltime=-1;
%         rlsResults.rules=[];
%         rlsResults.bounds=param.Frames;
%         rlsResults.divSignal=[];
%     end
%     
%     rls=rlsResults;
% elseif strcmp(roitype,'train')
%     %==================GROUNDTRUTH=================== 
%     idg=[];
%     if isfield(roi.train,(classifstrid)) && isfield(roi.train.(classifstrid),'id') && sum(roi.train.(classifstrid).id)>0
%         classes=roi.train.(classifstrid).classes;
%         idg=roi.train.(classifstrid).id; % results for classification
%         disp(['Groundtruth data are available for ROI ' num2str(roi.id)]);
%         
%         proba=-1;
%         divTimesG=computeDivtime(idg,proba,classes,param); % groundtruth data
%         
%         rlsGroundtruth.divDuration=divTimesG.duration;
%         rlsGroundtruth.frameBirth=divTimesG.frameBirth;
%         rlsGroundtruth.frameEnd=divTimesG.frameEnd;
%         rlsGroundtruth.endType=divTimesG.endType;
%         rlsGroundtruth.framediv=divTimesG.framediv;
%         rlsGroundtruth.sep=[];
%         rlsGroundtruth.name=roi.id;
%         rlsGroundtruth.roiid=i;
%         %rlsGroundtruth.roiid=[];
%         rlsGroundtruth.ndiv=divTimesG.ndiv;
%         rlsGroundtruth.totaltime=[divTimesG.framediv(1)-divTimesG.frameBirth, cumsum(divTimesG.duration)+divTimesG.framediv(1)-divTimesG.frameBirth];
%         rlsGroundtruth.rules=[];
%         rlsGroundtruth.groundtruth=1;
%         rlsGroundtruth.divSignal=[];
%         rlsGroundtruth.bounds=param.Frames;
%         
%         divSignalG=computeSignalDiv(roi,rlsGroundtruth);
%         rlsGroundtruth.divSignal=divSignalG;
%         
%         %sep
%         rlsGroundtruth.sep=findSync(rlsGroundtruth);
%     else
%         disp(['There is no groundtruth available for ROI ' char(roi.id)]);
%         rlsGroundtruth.groundtruth=1;
%         rlsGroundtruth.divDuration=[];
%         rlsGroundtruth.frameBirth=[];
%         rlsGroundtruth.frameEnd=[];
%         rlsGroundtruth.endType=[];
%         rlsGroundtruth.framediv=[];
%         rlsGroundtruth.sep=[];
%         rlsGroundtruth.roiid=i;
%         rlsGroundtruth.name=roi.id;
%         rlsGroundtruth.ndiv=-1;
%         rlsGroundtruth.totaltime=-1;
%         rlsGroundtruth.rules=[];
%         rlsGroundtruth.bounds=param.Frames;
%         rlsGroundtruth.divSignal=[];
%     end
%     rls=rlsGroundtruth;
% end


%% =========================================DIVTIMES=================================================
function [divTimes]=computeDivtime(id,proba,classes,param,frames)

    id=id(frames);

divTimes=[];

% first identify frame corresponding to death or clog and birth (non
% empty cavity)

% switch param.classiftype
%     
%     %========================CLASSIF BUD========================
%     case 'bud'

        deathid=find(matches(classes,'dead'));
        clogid=find(matches(classes,'clog'));
        lbid=find(matches(classes,'large'));
        smid=find(matches(classes,'small'));
        unbuddedid=find(matches(classes,'unbud'));
        emptyid=find(matches(classes,'empty'));
        
        %% post process
        if (proba~=-1) & (param.postProcessing==1)
            probaPP=proba;
            probaPP(smid,:)=medfilt1(probaPP(smid,:),4);
            probaPP(lbid,:)=medfilt1(probaPP(lbid,:),4);
            
            [~,idPP]=max(probaPP,[],1);
            id=idPP;
        end

      
        %%
        
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
        
        %==find DEATH (need param.DeathThreshold frames to be validated)======
        frameDeath=NaN;
        if ~isnan(frameBirth)
            idpostBirth=id;
            idpostBirth(1:frameBirth)=0;%only consider death if cell is born (to ignore death if first images of roi is death=
            bwDeath=(idpostBirth==deathid);
            bwDeath(1:frameBirth)=0; %useless?
            bwDeathLabeled=bwlabel(bwDeath);
            for k=1:max(bwDeathLabeled)
                bwDeath=(bwDeathLabeled==k);
                if sum(bwDeath)>= param.DeathThreshold || find(bwDeath,1,'last')==numel(id) || (id(find(bwDeath,1,'last')+1)==emptyid)% if ... or if the last frame is "dead",  or if dead is followed by empty (dead cells often squeeze through the trap), then consider as death
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
        
        
        
        
%         %%=================================CLASSIF DIV======================================
%     case 'div'
%         deathid=findclassid(classes,'dead');
%         censorid=findclassid(classes,'censor');
%         nodivid=findclassid(classes,'nodiv');
%         divid=findclassid(classes,'div');
%         emptyid=findclassid(classes,'birth');
%         
%         
%         startFrame=find(id==emptyid,1,'last');
%         if numel(startFrame)==0
%             startFrame=1;
%         end
%         
%         endFrame=min( find(id==deathid,1,'first')  ,  find(id==censorid,1,'first'));
%         if numel(endFrame)==0
%             endFrame=numel(id);
%         end
%         
%         divFrames=startFrame;
%         for j=startFrame:endFrame
%             if id(j)==divid % cell has divided
%                 divFrames=[divFrames j];
%             end
%         end
%         divTimes.framediv=divFrames;
%         divTimes.duration=diff(divFrames); % division times !
% end







