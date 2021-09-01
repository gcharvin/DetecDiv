function [rls,rlsResults,rlsGroundtruth]=measureRLS2(obj,varargin)

%'Fluo' if =1, will computethe fluo of each channel over the divs

%ClassiType is the classif type of obj :
% ClassiType='bud' : unbudded, small, large, dead etc.
% ClassiType='div' : nodiv, div, dead etc.

% rls combines results and groundtruth is applicable
% rlsResults only results
%rlsGroundtruth only groundtruth
objType=[];

%% TODO : Make it roi method and export to result_Pos_xxx.mat
%%
param.classiftype='bud';
param.postProcessing=1;
param.errorDetection=1;
param.ArrestThreshold=100;
param.DeathThreshold=5;

for i=1:numel(varargin)
    
    %Object type
    if strcmp(varargin{i},'ObjectType')
        objType=varargin{i+1};
        if strcmp(objType,'fovs') && strcmp(objType,'classif')
            error('Please enter a valid classitype');
        end
    end
    
    %classif
    if strcmp(varargin{i},'Classif')
        classif=varargin{i+1};
    end

    %Rois
    if strcmp(varargin{i},'Rois') %1xN vector
        rois=varargin{i+1};
    end
    if strcmp(varargin{i},'Fovs')
        fovs=varargin{i+1};
    end
    if strcmp(varargin{i},'RoisArray') %[fovs,...fovs;rois,...rois]
        roisArray=varargin{i+1};
    end
    
    %PARAMS OF DIV DETECTION
    %ClassiType
    if strcmp(varargin{i},'ClassiType')
        param.classiftype=varargin{i+1};
        if strcmp(param.classiftype,'div') && strcmp(param.classiftype,'bud')
            error('Please enter a valid classitype');
        end
    end
    
    %ArrestThreshold
    if strcmp(varargin{i},'ArrestThreshold')
        param.ArrestThreshold=varargin{i+1};
    end
    
    %DeathThreshold
    if strcmp(varargin{i},'DeathThreshold')
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
end
%%
if numel(objType)==0
    objTypeid=input('Indicate object type, among 1- fovs or 2- classif: ');

    if objTypeid==1
        objType='fovs';
    elseif objTypeid==2
        objType='classif';
    else
        error('Invalid object type');
    end
end


%=classif
if strcmp(objType,'classif')
    if ~exist('classif')
        str=[];
        for i=1:numel(obj.processing.classification)
            str=[str num2str(i) ' - ' obj.processing.classification(i).strid ';  '];
        end
        classiid=input(['You want to measures RLS from a classif object, but no classif has been selected, indicate which classif: (Default: 1)' newline str]);
        if numel(classiid)==0, classiid=1; end
        classif=obj.processing.classification(classiid);
    end
    obj2=classif;
    
    if numel(rois)==0
        rois=1:numel(obj.roi);
    end

    %compute RLS
[rls,rlsResults,rlsGroundtruth]=RLS(obj2,classif,param,rois);    
    
    
    %=fovs
elseif strcmp(objType,'fovs')
    
    if ~exist('classif')
        str=[];
        for i=1:numel(obj.processing.classification)
            str=[str num2str(i) ' - ' obj.processing.classification(i).strid ';  '];
        end
        classiid=input(['You want to measures RLS from fov objects, but you need to indicate a classif. Which classif used to compute fov.results, among:' newline str]);
        classif=obj.processing.classification(classiid);
    end
    
    if numel(roisArray)==0
        fovvector=[];
        roivector=[];
        
        if numel(fovs)
            for i=fovs
                % for j=1:numel(obj.fov(i).roi)
                %size( ones(1,length(obj.fov(i).roi)) )
                fovvector = [fovvector i*ones(1,length(obj.fov(i).roi)) ];
                roivector = [roivector  1:length(obj.fov(i).roi) ];
                % end
            end
        else
            % classify all ROIs
            for i=1:length(obj.fov)
                % for j=1:numel(obj.fov(i).roi)
                %size( ones(1,length(obj.fov(i).roi)) )
                fovvector = [fovvector i*ones(1,length(obj.fov(i).roi)) ];
                roivector = [roivector  1:length(obj.fov(i).roi) ];
                % end
            end
        end
        roisArray=[fovvector; roivector];
    end
    
    %compute RLS
    rls=[];
    for f=unique(fovvector)
        obj2=obj.fov(f);
        rois=roivector(2,:);
        rois=rois(fovvector==f);
        rls=vertcat(rls,RLS(obj2,classif,param,rois));
    end
end


%=========================================RLS============================================
function [rls,rlsResults,rlsGroundtruth]=RLS(obj2,classif,param,rois)

rls.divDuration=[];
rls.framediv=[];
rls.sep=[];
rls.fluo=[];
rls.name='';
rls.ndiv=0;
rls.totaltime=0;
rls.rules=[];
rls.groundtruth=0;

rlsResults=rls;
rlsGroundtruth=rls;

cc=1;
ccg=1;

classistrid=classif.strid;
classes=classif.classes;
for r=rois
    %================RESULTS===============
    if isfield(obj2.roi(r).results,classistrid)
        if isfield(obj2.roi(r).results.(classistrid),'id')
            if sum(obj2.roi(r).results.(classistrid).id)>0
                id=obj2.roi(r).results.(classistrid).id; % results for classification
                
                divTimes=computeDivtime(id,classes,param.classiftype,param.DeathThreshold,param.ArrestThreshold,param.postProcessing);
                
                rlsResults(cc).divDuration=divTimes.duration;
                rlsResults(cc).frameBirth=divTimes.frameBirth;
                rlsResults(cc).frameEnd=divTimes.frameEnd;
                rlsResults(cc).framediv=divTimes.framediv;
                rlsResults(cc).sep=[];
                rlsResults(cc).name=obj2.roi(r).id;
                rlsResults(cc).roiid=[class(obj2) '(' num2str(obj2.id) ').roi(' num2str(r) ')'];
                rlsResults(cc).ndiv=divTimes.ndiv;
                if numel(divTimes.framediv)>0
                    rlsResults(cc).totaltime=[divTimes.framediv(1), cumsum(divTimes.duration)+divTimes.framediv(1)];
                else
                    rlsResults(cc).totaltime=0;
                end
                rlsResults(cc).rules=[];
                rlsResults(cc).groundtruth=0;
                rlsResults(cc).divSignal=[];
                
                divSignal=computeSignalDiv(obj2,r,rlsResults(cc));
                rlsResults(cc).divSignal=divSignal;
            else
                disp(['there is no result available for ROI ' char(r) '=' char(obj2.roi(r).id)]);
            end
        end
    end
    cc=cc+1;
    
    %==================GROUNDTRUTH===================
    %Groundtruth?
    idg=[];
    if isprop(obj2.roi(r),'train') %MATLAB BUG WITH ISFIELD. logical=0 for fov
        if isfield(obj2.roi(r).train.(classistrid),'id') % test if groundtruth data available
            if sum(obj2.roi(r).train.(classistrid).id)>0
                idg=obj2.roi(r).train.(classistrid).id; % results for classification
                disp(['Groundtruth data are available for ROI ' num2str(r) '=' num2str(obj2.roi(r).id)]);
                
                divTimesG=computeDivtime(idg,classes,param.classiftype,param.DeathThreshold,param.ArrestThreshold,param.postProcessing); % groundtruth data
                
                rlsGroundtruth(ccg).divDuration=divTimesG.duration;
                rlsGroundtruth(ccg).frameBirth=divTimesG.frameBirth;
                rlsGroundtruth(ccg).frameEnd=divTimesG.frameEnd;
                rlsGroundtruth(ccg).framediv=divTimesG.framediv;
                rlsGroundtruth(ccg).sep=[];
                rlsGroundtruth(ccg).name=obj2.roi(r).id;
                rlsGroundtruth(ccg).roiid=[class(obj2) '(' num2str(obj2.id) ').roi(' num2str(r) ')'];
                rlsGroundtruth(ccg).ndiv=divTimesG.ndiv;
                rlsGroundtruth(ccg).totaltime=[divTimesG.framediv(1), cumsum(divTimesG.duration)+divTimesG.framediv(1)];
                rlsGroundtruth(ccg).rules=[];
                rlsGroundtruth(ccg).groundtruth=1;
                rlsGroundtruth(ccg).divSignal=[];
                
                divSignalG=computeSignalDiv(obj2,r,rlsGroundtruth(ccg));
                rlsGroundtruth(ccg).divSignal=divSignalG;
            end
        end
        ccg=ccg+1;
    end
end

if param.errorDetection==1
    if numel([rlsResults.groundtruth])==numel([rlsGroundtruth.groundtruth])
        disp('Proceeding to error detection')
        for r=1:numel([rlsResults.groundtruth])
            [rlsGroundtruth(r).noFalseDiv, rlsResults(r).noFalseDiv]=detectError(rlsGroundtruth(r),rlsResults(r));
            rlsGroundtruth(r).falseDiv=setdiff(rlsGroundtruth(r).framediv,rlsGroundtruth(r).noFalseDiv);
            rlsResults(r).falseDiv=setdiff(rlsResults(r).framediv,rlsResults(r).noFalseDiv);
            
            rlsGroundtruth(r).divDurationNoFalseDiv=diff(rlsGroundtruth(r).noFalseDiv);
            rlsResults(r).divDurationNoFalseDiv=diff(rlsResults(r).noFalseDiv);
        end
    else disp('Groundtruth and Result vectors dont match, quitting...')
    end
end

if numel([rlsResults.groundtruth])==numel([rlsGroundtruth.groundtruth])
    rls=[rlsResults rlsGroundtruth];
else
    rls=rlsResults;
end
rls=rls(:);
[p ix]= sort({rls(:).roiid});
rls=rls(ix);


%=========================================DIVTIMES=================================================
function [divTimes]=computeDivtime(id,classes,classiftype,DeathThreshold,ArrestThreshold,postProcessing)

divTimes=[];

% first identify frame corresponding to death or clog and birth (non
% empty cavity)

switch classiftype
    
    %========================CLASSIF BUD========================
    case 'bud'
        deathid=findclassid(classes,'dead');
        clogid=findclassid(classes,'clog');
        lbid=findclassid(classes,'large');
        smid=findclassid(classes,'small');
        unbuddedid=findclassid(classes,'unbud');
        emptyid=findclassid(classes,'empty');
        
        
        %==============1// find BIRTH===============
        frameBirth=NaN;
        firstunb=find(id==unbuddedid,1,'first');
        firstsm=find(id==smid,1,'first');
        firstlg=find(id==lbid,1,'first');
        if numel(firstunb)==0
            firstunb=NaN;
        end
        if numel(firstsm)==0
            firstsm=NaN;
        end
        if numel(firstlg)==0
            firstlg=NaN;
        end
        frameBirth=min([firstunb,firstsm,firstlg]);
        
        %=======2// Identify potential END====
        %========find potential first EMPTY frame, after birth=======
        frameEmptied=NaN;
        bwEmpty=(id==emptyid);
        bwEmptyLabeled=bwlabel(bwEmpty);
        for k=1:max(bwEmptyLabeled)
            bwEmpty=(bwEmptyLabeled==k);
            if sum(bwEmpty)> 2 && find(bwEmpty,1,'first')>frameBirth
                frameEmptied=find(bwEmpty,1,'first');
                break
            end
        end
        
        %======find DEATH (need 5 frames to be validated)======
        frameDeath=NaN;
        bwDeath=(id==deathid);
        bwDeathLabeled=bwlabel(bwDeath);
        
        for k=1:max(bwDeathLabeled)
            bwDeath=(bwDeathLabeled==k);
            if sum(bwDeath)> DeathThreshold
                frameDeath=find(bwDeath,1,'first');
                break
            end
        end
        
        %=================find potential first CLOG==============
        frameClog=NaN;
        frameClog=find(id==clogid,1,'first');
        
        %=======find potential division arrest==========
        frameArrest=NaN;
        for arrestid=[unbuddedid,smid,lbid]
            bwArrest=(id==arrestid);
            bwArrestLabel=bwlabel(bwArrest);
            for k=1:max(bwArrestLabel)
                bwArrest=(bwArrestLabel==k);
                if sum(bwArrest)> ArrestThreshold
                    if numel(frameArrest)==1
                        frameArrest=min(frameArrest,(find(bwArrest,1,'first')+ ArrestThreshold));
                    else
                        frameArrest=find(bwArrest,1,'first')+ ArrestThreshold;
                    end
                    break
                end
            end
        end
        
        %===============3/ find END===================
        frameEnd=min([frameClog, frameDeath, frameEmptied, frameArrest]);
        if isnan(frameEnd) % cell is not dead or clogged or empty, TO DO: SEPARATE BETWEEN DEATH AND CENSOR
            frameEnd=numel(id);
            %machin.censor=1;
        end
        
        %==============4/ detect divisions============
        %==post-processing
        if postProcessing==1
            bwsmid=(id==smid);
            bwsmidLabel=bwlabel(bwsmid); %find small islets
            for k=1:max(bwsmidLabel)
                bwsmidk(k,:)=(bwsmidLabel==k);
            end
            
            for k=2:max(bwsmidLabel)
                if sum(bwsmidk(k,:))==1 %if a smallid islet is of size 1, check the neighbours islets
                    idx=find(bwsmidk(k,:),1);
                    idxprev=find(bwsmidk(k-1,:),1,'last');%find previous islet end
                    if k<max(bwsmidLabel),  idxnext=find(bwsmidk(k+1,:),1,'first');else, idxnext=NaN; end %find next islet start
                    if (idx-idxprev<3) || (idxnext-idx <3) %if the potential false bud emergence is too close from another small islet -->correct it
                        id(idx)=id(idx-1);
                    end
                end
            end
            
            %small->unbud, can be improved by checking the islets size
            for j=1:numel(id)-1
                if (id(j)==smid && id(j+1)==unbuddedid)
                    id(j)=lbid;
                end
            end
        end
        
        %=====Div counting=====
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
        divTimes.framediv=divFrames;
        divTimes.duration=diff(divFrames); % division times !
        divTimes.ndiv=numel(divTimes.framediv);
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


%==============================================SIGNAL======================================================
function divFluo=computeSignalDiv(obj2,r,rls)
divFluo=[];
%check all the fields of .results.signal and mean them by div
if isfield(obj2.roi(r).results,'signal')
    resultFields=fields(obj2.roi(r).results.signal); %full, cell, nucleus
    %essayer try catch
    for rf=resultFields
        classiFields=fields(obj2.roi(r).results.signal.(rf)); %obj2
        for cf=classiFields
            fluoFields=fields(obj2.roi(r).results.signal.(rf).(cf)); %max, mean, volume...
            for ff=fluoFields
                for chan=1:numel(obj2.roi(r).results.signal.(rf).(cf).(ff)(:,1))
                    tt=1;
                    for t=1:rls.ndiv
                        divSignal.(rf).(cf).(ff)(chan,t)=mean(obj2.roi(r).results.signal.(rf).(cf).(ff)(chan,rls.framediv(tt):rls.framediv(tt+1)));
                        tt=tt+1;
                    end
                end
            end
        end
    end
else disp(['No results.signal for roi ' num2str(r)]);
end
%==============================================DIVERROR======================================================
function [framedivNoFalseNeg, framedivNoFalsePos]=detectError(rlsGroundtruthr, rlsResultsr)
framedivNoFalseNeg=NaN;
framedivNoFalsePos=NaN;
if numel(rlsGroundtruthr.framediv)>1 && numel(rlsResultsr.framediv)>1
    %====1/false neg (groundtruth has a div that results doesnt)====
    clear B IdxI IdxMinDist distance regiondup regiondupk firstdupk bwregiondup
    for i=1:numel(rlsGroundtruthr.framediv)
        for j=1:numel(rlsResultsr.framediv)
            distance(i,j)=rlsGroundtruthr.framediv(i)-rlsResultsr.framediv(j);
            pairij(i,j)=0;
        end
    end
    
    %deal with cases where distance values are m and -m,make -m to 0 so its
    %picked as the min
    [B,I]=mink(abs(distance),2,2);
    for l=1:size(B,1)
        if B(l,1)==B(l,2)
            [~,idxI]=min([distance(l,I(l,1)) distance(l,I(l,2))]);
            distance(l,idxI)=0;%choose the negaitve value, put it to 0
        end
    end
    
    for i=1:numel(rlsGroundtruthr.framediv)
        [~,idxmini]=min(abs(distance(i,:)));
        pairij(i,idxmini)=1;
    end
    
    for i=1:numel(rlsGroundtruthr.framediv)
        for j=1:numel(rlsResultsr.framediv)
            if pairij(i,j)==1
                distance2(i,j)=distance(i,j);
            else distance2(i,j)=NaN;
            end
        end
    end
    
    for j=1:numel(rlsResultsr.framediv)
        pairij(:,j)=(-1)*pairij(:,j);
        [~, idx]=min(abs(distance2(:,j)));
        pairij(idx,j)=1;
    end
    falsepair=sum((pairij==-1),2);
    framedivNoFalseNeg=rlsGroundtruthr.framediv(not(falsepair'));
    
    
    
    clear B IdxI IdxMinDist distance pairij idx falsepair distance2
    %====2/false pos (res has a div that gt doesnt)====
    for i=1:numel(rlsResultsr.framediv)
        for j=1:numel(framedivNoFalseNeg)
            distance(i,j)=rlsResultsr.framediv(i)-framedivNoFalseNeg(j);
            pairij(i,j)=0;
        end
    end
    
    %deal with cases where distance values are m and -m,make -m to 0 so its
    %picked as the min
    [B,I]=mink(abs(distance),2,2);
    for l=1:size(B,1)
        if B(l,1)==B(l,2)
            [~,idxI]=min([distance(l,I(l,1)) distance(l,I(l,2))]);
            distance(l,idxI)=0;%choose the negaitve value, put it to 0
        end
    end
    
    %identify pairs, including false
    for i=1:numel(rlsResultsr.framediv)
        [~,idxmini]=min(abs(distance(i,:)));
        pairij(i,idxmini)=1;
    end
    
    for i=1:numel(rlsResultsr.framediv)
        for j=1:numel(framedivNoFalseNeg)
            if pairij(i,j)==1
                distance2(i,j)=distance(i,j);
            else distance2(i,j)=NaN;
            end
        end
    end
    
    %identify false pairs
    for j=1:numel(framedivNoFalseNeg)
        pairij(:,j)=(-1)*pairij(:,j);
        [~, idx]=min(abs(distance2(:,j)));
        pairij(idx,j)=1;
    end
    falsepair=sum((pairij==-1),2);
    framedivNoFalsePos=rlsResultsr.framediv(not(falsepair'));
end



function clid=findclassid(classes,str)
clid=[];
for ck=1:numel(classes)
    if strcmp(classes{ck},str)
        clid=ck;
        break;
    end
end