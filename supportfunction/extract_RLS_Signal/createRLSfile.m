function rls=createRLSfile(classif,roiobjcell,varargin)

Align=1;
GT=0;
szc=size(roiobjcell,1); %number of conditions
comment=cell(szc,1);
environment='local';

for i=1:numel(varargin)
    if strcmp(varargin{i},'GT')
        GT=1;
        comment={'Groundtruth','Prediction'};
    end
    
    if strcmp(varargin{i},'Align')
        Align=1;
    end
    

    if strcmp(varargin{i},'Comment')
        comment=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Envi')
        environment=varargin{i+1};
    end
end



classifstrid=classif.strid;

%%
cc=1;
for cond=1:szc
    for r=1:numel(roiobjcell{cond,1})
        if strcmp(environment,'local')
            roiobjcell{cond,1}(r).path=strrep(roiobjcell{cond,1}(r).path,'/shared/space2/','\\space2.igbmc.u-strasbg.fr\');
        end
        roiobjcell{cond,1}(r).load('results');
        roiobjcell{cond,1}(r).path=strrep(roiobjcell{cond,1}(r).path,'/shared/space2/','\\space2.igbmc.u-strasbg.fr\');
        rls(cc)=roiobjcell{cond,1}(r).results.RLS.(['from_' classifstrid]);              
        
        if GT==1
            %if exist...else error('explicit error message') for robustness
            rls(cc+1)=roiobjcell{cond,1}(r).train.RLS.(['from_' classifstrid]);
            rlscomm{cc,1}=comment{1,2}; %Pred
            rlscomm{cc+1,1}=comment{1,1}; %GT
            
            rlscond(cc,1)=cond;
            rlscond(cc+1,1)=cond;  
            
            cc=cc+2;
        elseif GT==0
            rlscomm{cc,1}=comment{1,cond};
            rlscond(cc,1)=cond;
            
            cc=cc+1;
        end
        %     if isprop(roiobj(i),'train') && numel(roiobj(i).train.(classifstrid).id)>0
        %         roiobj(i).train.(classifstrid).RLS=RLS(roiobj(i),'train',classif,param);
        %     end
        roiobjcell{cond,1}(r).clear;
        
    end
end

for r=1:numel(rls)
    rls(r).condition=rlscond(r);
    rls(r).conditionComment=rlscomm{r};
end

%ALIGN & sort
if Align==1 %align and sort
    rlstmp=[];
    for cond=1:szc
        rlsAligned{cond,1}=AlignSignal(rls([rls(:).condition]==cond));
        rlstmp=[rlstmp; rlsAligned{cond,1}(:)];
    end
    rls=rlstmp;
    clear rlstmp
else %sort only
    rls=rls(:);
    [~, ix]= sort([rls(:).condition]);
    rls=rls(ix);
end
%=

%Selection
%todo: parametrize selection here instead of in the different functions,
%ex:
% % % rls=rls([rls(:).ndiv]>5); %put at least 1 for robustness
% % % rls=rls(~isnan([rls(:).sep])); %take only SEP cells
% % % 
% % % rls=rls( ([rls.frameBirth]<=100) & (~isnan([rls.frameBirth])) );
% % %  %roiobj=roiobj( (strcmp({roiobj.endType},'Death') & [roiobj.frameEnd]>300)  );
% % % rls=rls( ~(strcmp({rls.endType},'Arrest') & [rls.frameEnd]<300)  ); %remove weird cells before frame 300 (stop growing)
% % % rls=rls( ~(strcmp({rls.endType},'Emptied')); %remove emptied roi
% % % rls=rls( ~(strcmp({rls.endType},'Clog')); %remove emptied roi 


%=



%=============================================SEP==========================================
%To do : harmonize for loops
function [rls]=AlignSignal(rls)
align=1; %1: SEP, 2: death 0: birth, only SEP and birth implemented so far
syncType={'birthSynced', 'SEPSynced','deathSynced'};
threshStart=1;
numrls=numel(rls);

for r=1:numrls
    tmpdivDur=rls(r).divDuration;
    RLS(r)=numel(tmpdivDur);
end
maxRLS=max(RLS);
divDur=NaN(numrls,maxRLS);

m=0;
M=0;

%find syncpoint for each RLS
for r=1:numrls
    for d=1:numel(rls(r).divDuration)
        divDur(r,d)=rls(r).divDuration(d);
    end
    if sum(~isnan(divDur(r,:)))>1 && sum(isnan(divDur(r,:)))<maxRLS %divDur is not full of NaN
        
        if align==0
            syncPoint(r)=1;
        elseif align==1
            if sum(~isnan(divDur(r,:)))>threshStart %POST PROCESSING
                [syncPoint(r),~]=findSEP(divDur(r,threshStart:end),1);
                syncPoint(r)=syncPoint(r)+threshStart-1;
            else syncPoint(r)=NaN;
            end
        elseif align==2
            syncPoint(r)=numel(rls(r).divDuration);
        end
        
        %align
        m=max(m,syncPoint(r)); %max divs in preSEP
        M=max(M,sum(~isnan(divDur(r,:)))-syncPoint(r)); %max divs in postSEP
        
    else syncPoint(r)=NaN;
    end
    
    rls(r).sep=syncPoint(r);
end



for r=1:numrls
    %align signal VS syncpoint and store it in rls struct
    
    
    if sum(~isnan(divDur(r,:)))>1 && syncPoint(r)>0 %check if it is worth aligning
        %INIT
        
        %divs
        rls(r).Aligned.(syncType{align+1}).divDuration=NaN(1,m+M);
        
        %signal
        if isfield(rls(r),'divSignal') && ~isempty(rls(r).divSignal)
            rF=fields(rls(r).divSignal); %full, cell, nucleus
            rF(strcmp(rF,'divDuration'))=[]; %is treated before
            %essayer try catch
            for rf=1:numel(rF)
                cF=fields(rls(r).divSignal.(rF{rf})); %obj2
                for cf=1:numel(cF)
                    fF=fields(rls(r).divSignal.(rF{rf}).(cF{cf})); %max, mean, volume...
                    for ff=1:numel(fF)
                        for chan=1:numel(rls(r).divSignal.(rF{rf}).(cF{cf}).(fF{ff})(:,1))
                            rls(r).Aligned.(syncType{align+1}).(rF{rf}).(cF{cf}).(fF{ff})(chan,:)=NaN(1,m+M);
                        end
                    end
                end
            end
        else disp(['No results.divSignal for roi ' num2str(r)]);
        end
        
        %FILL
        %pre+post
        for j=1:sum(~isnan(divDur(r,:))) %divs
            rls(r).Aligned.(syncType{align+1}).divDuration(1,m-syncPoint(r)+j)=divDur(r,j);
            rls(r).Aligned.(syncType{align+1}).zero=m;
            
            if isfield(rls(r),'divSignal') && ~isempty(rls(r).divSignal)
                rF=fields(rls(r).divSignal); %full, cell, nucleus
                rF(strcmp(rF,'divDuration'))=[]; %is treated before
                %essayer try catch
                for rf=1:numel(rF)
                    cF=fields(rls(r).divSignal.(rF{rf})); %obj2
                    for cf=1:numel(cF)
                        fF=fields(rls(r).divSignal.(rF{rf}).(cF{cf})); %max, mean, volume...
                        for ff=1:numel(fF)
                            for chan=1:numel(rls(r).divSignal.(rF{rf}).(cF{cf}).(fF{ff})(:,1))
                                rls(r).Aligned.(syncType{align+1}).(rF{rf}).(cF{cf}).(fF{ff})(chan,m-syncPoint(r)+j)=rls(r).divSignal.(rF{rf}).(cF{cf}).(fF{ff})(chan,j);
                            end
                        end
                    end
                end
            end
        end
    else
    end
end
