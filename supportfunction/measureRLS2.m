function [rls,rlsResults,rlsGroundtruth]=measureRLS2(classi,varargin)

%'Fluo' if =1, will computethe fluo of each channel over the divs

%ClassiType is the classif type of classi :
% ClassiType='bud' : unbudded, small, large, dead etc.
% ClassiType='div' : nodiv, div, dead etc.

% rls combines results and groundtruth is applicable
% rlsResults only results
%rlsGroundtruth only groundtruth
classiftype='bud';
postProcessing=1;
rois=1:numel(classi.roi);
classiid=classi.strid;
classiidfluo=classiid;

for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'ClassiType')
        classiftype=varargin{i+1};
        if strcmp(classiftype,'div') && strcmp(classiftype,'bud')
            error('Please enter a valid classitype');
        end
    end 
    
    %Rois
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
    %ClassID
    if strcmp(varargin{i},'ClassID')
        classiid=varargin{i+1};
    end  
    %ClassIDFluo
    if strcmp(varargin{i},'ClassIDFluo')
        classiidfluo=varargin{i+1};
    end    
end

classes=classi.classes;

%classi id
% if numel(classi.roi(rois(1)).results)~=0
%     classiid=fieldnames(classi.roi(rois(1)).results);
% elseif numel(classi.roi(rois(1)).train)~=0
%     classiid=fieldnames(classi.roi(rois(1)).train);
% else
%     error('Couldnt find classiid, check that there is something in .result or in .train');
% end
% str=[];
% for i=1:numel(classiid)
%     str=[str num2str(i) ' - ' classiid{i} ';'];
% end
% prompt=['Choose which classi : ' str];
% classiidsNum=input(prompt);
% if numel(classiidsNum)==0
%     classiidsNum=numel(classiid);
% end
% classiid=(classiid{classiidsNum});


rls.divDuration=[];
rls.framediv=[];
rls.sep=[];
rls.fluo=[];
rls.trapfov='';
rls.ndiv=0;
rls.totaltime=0;
rls.rules=[];
rls.groundtruth=0;

rlsResults=rls;
rlsGroundtruth=rls;

cc=1;
ccg=1;

for r=rois
    %================RESULTS===============
    if isfield(classi.roi(r).results,classiid)
        if isfield(classi.roi(r).results.(classiid),'id')
            if sum(classi.roi(r).results.(classiid).id)>0
                id=classi.roi(r).results.(classiid).id; % results for classification         

                divTimes=computeDivtime(id,classes,classiftype);
                
                rlsResults(cc).divDuration=divTimes.duration;
                rlsResults(cc).framediv=divTimes.framediv;
                rlsResults(cc).sep=[];
                rlsResults(cc).trapfov=classi.roi(r).id;
                rlsResults(cc).trapclassi=['classi(' num2str(classi.id) ').roi(' num2str(r) ')'];
                rlsResults(cc).ndiv=numel(divTimes.duration);
                if numel(divTimes.framediv)>0
                    rlsResults(cc).totaltime=[divTimes.framediv(1), cumsum(divTimes.duration)+divTimes.framediv(1)];
                else
                    rlsResults(cc).totaltime=0;
                end
                rlsResults(cc).rules=[];
                rlsResults(cc).groundtruth=0;
                rlsResults(cc).fluo=[];
                
                divFluo=computeFluoDiv(classi,r,classiidfluo,rlsResults(cc));
                rlsResults(cc).fluo=divFluo;
            else
                disp(['there is no result available for ROI ' num2str(r) '=' num2str(classi.roi(r).id)]);
            end
        end
    end
    cc=cc+1;

    %==================GROUNDTRUTH===================
    %Groundtruth?
    idg=[];
    if isfield(classi.roi(r).train.(classiid),'id') % test if groundtruth data available
        if sum(classi.roi(r).train.(classiid).id)>0
            idg=classi.roi(r).train.(classiid).id; % results for classification
             disp(['Groundtruth data are available for ROI ' num2str(r) '=' num2str(classi.roi(r).id)]);
            
            divTimesG=computeDivtime(idg,classes,classiftype); % groundtruth data
                        
            rlsGroundtruth(ccg).divDuration=divTimesG.duration;
            rlsGroundtruth(ccg).framediv=divTimesG.framediv;
            rlsGroundtruth(ccg).sep=[];
            rlsGroundtruth(ccg).trapfov=classi.roi(r).id;
            rlsGroundtruth(ccg).trapclassi=['classi(' num2str(classi.id) ').roi(' num2str(r) ')'];
            rlsGroundtruth(ccg).ndiv=numel(divTimesG.duration);
            rlsGroundtruth(ccg).totaltime=[divTimesG.framediv(1), cumsum(divTimesG.duration)+divTimesG.framediv(1)];
            rlsGroundtruth(ccg).rules=[];
            rlsGroundtruth(ccg).groundtruth=1;
            rlsGroundtruth(ccg).fluo=[];
            
            divFluoG=computeFluoDiv(classi,r,classiid,rlsGroundtruth(ccg));
            rlsGroundtruth(ccg).fluo=divFluoG;
        end
    end
    ccg=ccg+1;
end

if numel([rlsResults.groundtruth])==numel([rlsGroundtruth.groundtruth])
rls=[rlsResults rlsGroundtruth];
else
    rls=rlsGroundtruth;
end
rls=rls(:);
[p ix]= sort({rls(:).trapclassi});
rls=rls(ix);





%=========================================DIVTIMES=================================================
function [divTimes]=computeDivtime(id,classes,classiftype)%,postProcessing)

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
        
        %==============find BIRTH===============
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
                
        %========find potential first EMPTY frame, after birth=======
        frameEmptied=[];
        bwEmpty=(id==emptyid);
        bwEmptyLabeled=bwlabel(bwEmpty);
        for k=1:max(bwEmptyLabeled)
            bwEmpty=(bwEmptyLabeled==k);
            if sum(bwEmpty)> 3 && find(bwEmpty,1,'first')>frameBirth
                frameEmptied=find(bwEmpty,1,'first');
                break
            end
        end
        if numel(frameEmptied)==0
            frameEmptied=NaN;
        end
        
        % find DEATH (need 5 frames to be validated)
        frameDeath=NaN;
        bwDeath=(id==deathid);
        bwDeathLabeled=bwlabel(bwDeath);
        
        for k=1:max(bwDeathLabeled)
            bwDeath=(bwDeathLabeled==k);
            if sum(bwDeath)> 5
                frameDeath=find(bwDeath,1,'first');
                break
            end
        end
        
        %=================find potential first CLOG==============
        frameClog=find(id==clogid,1,'first');
        if numel(frameClog)==0
            frameClog=NaN;
        end
        
        %===============find END===================
        frameEnd=min([frameClog frameDeath frameEmptied]);
        if isnan(frameEnd) % cell is not dead or clogged or empty, TO DO: SEPARATE BETWEEN DEATH AND CENSOR
            frameEnd=numel(id);
            %machin.censor=1;
        end
        
        %==============detect divisions============
        divFrames=[];
        for j=frameBirth:frameEnd-1
            if (id(j)==lbid && id(j+1)==smid) || (id(j)==lbid && id(j+1)==unbuddedid) % cell has divided
                divFrames=[divFrames j];
            end
        end
        if numel(divFrames)==0
            divFrames=NaN;
        end
        
%         if numel(divFrames)<3
%             %continue
%         else
            divTimes.framediv=divFrames;
            divTimes.duration=diff(divFrames); % division times !
%         end
        

        
    %====================CLASSIF DIV======================
    case 'div'
        deathid=findclassid(classes,'dead');
        censorid=findclassid(classes,'censor');
        nodivid=findclassid(classes,'nodiv');
        divid=findclassid(classes,'div');
        emptyid=findclassid(classes,'empty');
        
        
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


%==============================================FLUO======================================================
function divFluo=computeFluoDiv(classi,r,classiidfluo,rls)
divFluo=[];
if isfield(classi.roi(r).results,classiidfluo)
    %essayer try catch
    if isfield(classi.roi(r).results.(classiidfluo),'fluo')
        if isfield(classi.roi(r).results.(classiidfluo).fluo,'maxf')
            for chan=1:numel(classi.roi(r).results.(classiidfluo).fluo.maxf(:,1))
                tt=1;
                for t=1:rls.ndiv
                    divFluo.maxf(chan,t)=mean(classi.roi(r).results.(classiidfluo).fluo.maxf(chan,rls.framediv(tt):rls.framediv(tt+1)));
                    tt=tt+1;
                end
            end
        else
            disp(['There is no fluo.maxf data for this ROI' num2str(r)])
        end
        
        
        if isfield(classi.roi(r).results.(classiidfluo).fluo,'meanf')
            for chan=1:numel(classi.roi(r).results.(classiidfluo).fluo.meanf(:,1))
                tt=1;
                for t=1:rls.ndiv
                    divFluo.meanf(chan,t)=mean(classi.roi(r).results.(classiidfluo).fluo.meanf(chan,rls.framediv(tt):rls.framediv(tt+1)));
                    tt=tt+1;
                end
            end
        else
            disp(['There is no fluo.meanf data for this ROI' num2str(r)])
        end
    end
end



function clid=findclassid(classes,str)
clid=[];
for ck=1:numel(classes)
    if strcmp(classes{ck},str)
        clid=ck;
        break;
    end
end
