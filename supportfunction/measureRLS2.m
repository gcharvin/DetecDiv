function [rls,rlsresults,rlsgroundtruth]=measureRLS2(roiarr,strid,classiftype)

% roi is an array of @roi

% strid is the strid of the @classi object

%classiftype is the type of classif :
% classiftype='bud' : unbudded, small, large, dead etc.
% classiftype='div' : nodiv, div, dead etc.

% rls combines results and groundtruth is applicable
% rlsresults only results
%rlsgroundtruth only groundtruth

if nargin==2 % default classif method
    classiftype='bud';
end

classes= roiarr(1).classes;

rls.div=[];
rls.sep=[];
rls.fluo=[];
rls.trap='';
rls.ndiv=0;
rls.totaltime=0;
rls.rules=[];
rls.groundtruth=0;

rlsresults=rls;
rlsgroundtruth=rls;

cc=1;
ccg=1;

for i=1:numel(roiarr)
    testr=0;
    if isfield(roiarr(i).results,strid)
        if sum(roiarr(i).results.(strid).id)>0
            id=roiarr(i).results.(strid).id; % results for classification
            testr=1;
        end
    end
    
    if testr==0
        disp(['there is no result available for ROI ' num2str(roiarr(i).id)]);
    end
    
    idg=[];
    if isfield(roiarr(i).train,strid) % test if groundtruth data available
        if sum(roiarr(i).train.(strid).id)>0
            idg=roiarr(i).train.(strid).id; % results for classification
            disp(['Ground truth data are available for ROI ' num2str(roiarr(i).id)]);
        end
    end
    
    divtime=computeDivtime(id,classes,classiftype);
    
    if numel(idg)
        divtimeg=computeDivtime(idg,classes,classiftype); % groundtruth data
    end
    
    
    %   divtime
    rlsresults(cc).div=divtime;
    rlsresults(cc).sep=[];
    rlsresults(cc).fluo=[];
    rlsresults(cc).trap=roiarr(i).id;
    rlsresults(cc).ndiv=numel(divtime);
    rlsresults(cc).totaltime=cumsum(divtime);
    rlsresults(cc).rules=[];
    rlsresults(cc).groundtruth=0;
    cc=cc+1;
    
    if numel(idg) % addgroundtruth to the rls struct
        rlsgroundtruth(ccg).div=divtimeg;
        rlsgroundtruth(ccg).sep=[];
        rlsgroundtruth(ccg).fluo=[];
        rlsgroundtruth(ccg).trap=roiarr(i).id;
        rlsgroundtruth(ccg).ndiv=numel(divtimeg);
        rlsgroundtruth(ccg).totaltime=cumsum(divtimeg);
        rlsgroundtruth(ccg).rules=[];
        rlsgroundtruth(ccg).groundtruth=1;
        ccg=ccg+1;
        
    end
end

rls=[rlsresults ; rlsgroundtruth];
rls=rls(:);


function divtime=computeDivtime(id,classes,classiftype)

divtime=[];

% first identify frame corresponding to death or clog and birth (non
% empty cavity)

switch classiftype
    
    %BUD CLASSIF
    case 'bud'
        deathid=findclassid(classes,'dead');
        clogid=10;%findclassid(classes,'clog');
        lbid=findclassid(classes,'large');
        smid=findclassid(classes,'small');
        unbuddedid=10;%findclassid(classes,'unbudded');
        emptyid=findclassid(classes,'empty');
        
        %find BIRTH
        firstsm=find(id==smid,1,'first');
        firstlg=find(id==lbid,1,'first');
        frameBirth=min(firstsm,firstlg);
        
        
        %find potential the first EMPTY frame, after birth
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
        
        %find potential first CLOG
        frameClog=find(id==clogid,1,'first');
        if numel(frameClog)==0
            frameClog=NaN;
        end
        
        %find END
        frameEnd=min([frameClog frameDeath frameEmptied]);
        if isnan(frameEnd) % cell is not dead or clogged or empty, TO DO: SEPARATE BETWEEN DEATH AND CENSOR
            frameEnd=numel(id);
            %machin.censor=1;
        end

        divtime=[];
        for j=frameBirth:frameEnd-1
            if (id(j)==lbid && id(j+1)==smid) || (id(j)==lbid && id(j+1)==unbuddedid) % cell has divided
                divtime=[divtime j];
            end
        end

        if numel(divtime)<3
            %continue
        else
            divtime=diff(divtime); % division times !
        end
                    
            %DIV CLASSIF
            case 'div'
                deathid=findclassid(classes,'dead');
                clogid=findclassid(classes,'clog');
                div=findclassid(classes,'div');
                nodiv=findclassid(classes,'nodiv');
                
                
                %frameBirth=find(id==emptyid,1,'last');
                
                %if numel(frameBirth)==0 % cavity was not empty;
                frameBirth=1;
                %end
                
                frameEnd=find(id==deathid | id==clogid);
                
                if numel(frameEnd)==0 % cell is not dead --> censored
                    frameEnd=numel(id);
                else
                    % find strech of dead cells
                    
                    bwDeath=id==deathid;
                    l=bwlabel(bwDeath);
                    
                    for k=1:max(l)
                        bwDeath=l==k;
                        if sum(bwDeath)> 5
                            frameEnd=find(bwDeath,1,'first');
                            break
                        end
                    end
                end
                
                divtime=[];
                for j=frameBirth:frameEnd-1
                    % j
                    if id(j)==div % cell has divided
                        %  j
                        divtime=[divtime j];
                    end
                end
                
                if numel(divtime)<3
                    %continue
                else
                    divtime=diff(divtime); % division times !
                end         
end
        
        
        
        
        
        
function clid=findclassid(classes,str)
clid=[];
for i=1:numel(classes)
    if strcmp(classes{i},str)
        clid=i;
        break;
    end
end
