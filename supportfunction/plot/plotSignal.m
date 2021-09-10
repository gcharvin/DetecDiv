function [data]=plotSignal(roiobj,varargin)
%classi script

timeOrGen=0; %time
timefactor=5;
load=0;
RLSfile=0;
plotDivDur=0;
maxBirth=100; %max frame to be born. After, discard rls.

for i=1:numel(varargin)
    if strcmp(varargin{i},'Generation')
        timeOrGen=1;
    end
    
    if strcmp(varargin{i},'RLSfile') %can also take as inpout rls struct file instead of roiobj
        RLSfile=1;
    end
    
    if strcmp(varargin{i},'Load') %load data
        load=1;
    end
    
end

if RLSfile==1
    timeOrGen=1;
end

%% cleaning
roiobj=roiobj([roiobj(:).ndiv]>10); %put at least 1 for robustness
roiobj=roiobj( ([roiobj.frameBirth]<=maxBirth) & (~isnan([roiobj.frameBirth])) );
roiobj=roiobj( ~(strcmp({roiobj.endType},'Arrest') & [roiobj.frameEnd]<400)  ); %remove weird cells before frame 300 (stop growing)
roiobj=roiobj( ~(strcmp({roiobj.endType},'Emptied') & [roiobj.frameEnd]<400)  ); %remove emptied roi before frame 300
%% 
signalstrid='';
classifstrid='';
fluostrid='';


%% load data if required
if load==1
    for r=1:numel(roiobj)
        roiobj(r).load('results');
    end
end

%%
if timeOrGen==0
    if isfield(roiobj(1).results,'signal')
        obj=roiobj(1).results.signal;
    else
        error(['The roi ' roiobj(1) 'has no signal. Extract it using extractSignal'])
    end
    
elseif timeOrGen==1
    
    if RLSfile==0 %if input is rois array
        % ask RLSclassi
        if isfield(roiobj(1).results,'RLS')
            liststrid=fields(roiobj(1).results.RLS); %full, cell, nucleus
            str=[];
        else
            error(['The roi ' roiobj(1) 'has no RLS. Extract it using measureRLS3'])
        end
        for i=1:numel(liststrid)
            str=[str num2str(i) ' - ' liststrid{i} ';'];
        end
        
        classiRLSid=input(['Which classi used for RLS extraction? (Default: 1)' str]);
        if numel(classiRLSid)==0
            classiRLSid=1;
        end
        classifRLSstrid=liststrid{classiRLSid};
        
        if isfield(roiobj(1).results.RLS.(classifRLSstrid),'signal')
            obj=roiobj(1).results.RLS.(classifRLSstrid).divSignal;
        else
            error(['The roi ' roiobj(1) 'has no RLS.signal. Extract it using extractSignal followed by measureRLS3'])
        end
        
    elseif RLSfile==1 %if input is rls struct
        if isfield(roiobj(1),'divSignal')
            obj=roiobj(1).divSignal;
        else
            error(['The roi ' roiobj(1) 'has no divSignal field. Extract it using extractSignal followed by measureRLS2'])
        end
        if isfield(roiobj(1),'Aligned')
            askPlotAligned=input('Aligned signals available, plot this? y/n (Default: n)','s');
            if numel(askPlotAligned)==0
                plotAligned=0;
            elseif strcmp(askPlotAligned,'y') %plot aligned signals
                plotAligned=1;
                
                liststrid=fields(roiobj(1).Aligned); %full, cell, nucleus
                str=[];
                for i=1:numel(liststrid)
                    str=[str num2str(i) ' - ' liststrid{i} ';'];
                end
                alignid=input(['Which alignment used ? (Default: 1)' str]);
                if numel(alignid)==0
                    alignid=1;
                end
                alignstrid=liststrid{alignid};
                
                %remove nosep
                flag=[];
                for r=1:numel(roiobj)
                    if isempty(roiobj(r).Aligned)
                        flag=[flag r];
                    end
                end
                roiobj(flag)=[];
                
                obj=roiobj(1).Aligned.(alignstrid);
            end
        end
    end
    
    %ask if want to plot divDuration
    if isfield(obj,'divDuration')
        askPlotDivDuration=input('Division duration available, plot this? y/n (Default: n)','s');
        if numel(askPlotDivDuration)==0
            plotDivDur=0;
        elseif strcmp(askPlotDivDuration,'y') %plot aligned signals
            plotDivDur=1;
        end
    end
end

if plotDivDur==0
    %% ask signal
    liststrid=fields(obj); %full, cell, nucleus
    str=[];
    for i=1:numel(liststrid)
        str=[str num2str(i) ' - ' liststrid{i} ';'];
    end
    
    signalid=input(['Which signal extraction type? (Default: 1)' str]);
    if numel(signalid)==0
        signalid=1;
    end
    
    %% ask classistrid
    liststrid=fields(obj.(signalstrid));
    str=[];
    
    for i=1:numel(liststrid)
        str=[str num2str(i) ' - ' liststrid{i} ';'];
    end
    classifid=input(['Which classi used for extracting signal? (Default: 1)' str]);
    if numel(classifid)==0
        classifid=1;
    end
    
    classifstrid=liststrid{classifid};
    
    %% ask fluo
    
    liststrid=fields(obj.(signalstrid).(classifstrid));
    str=[];
    
    for i=1:numel(liststrid)
        str=[str num2str(i) ' - ' liststrid{i} ';'];
    end
    fluoid=input(['Which type of signal? (Default: 1)' str]);
    if numel(fluoid)==0
        fluoid=1;
    end
    
    fluostrid=liststrid{fluoid};
    
    %% ask channel
    channumber=size(obj.(signalstrid).(classifstrid).(fluostrid),1);
    str=[];
    
    chanid=input(['Which channel ? (Default: 1)' num2str(1:channumber)]);
    if numel(chanid)==0
        chanid=1;
    end
    
end
%% data to vector
for r=1:numel(roiobj)
    
    if plotDivDur==0
        
        %assign obj
        if timeOrGen==0
            if isfield(roiobj(r).results,'signal')
                obj=roiobj(r).results.signal;
            else
                error(['The roi ' roiobj(r) 'has no ' signalstrid 'signal from classi ' classifstrid ', be sure extracted it well, using extractSignal'])
            end
            for chan=chanid
                data(r,:)=obj.(signalstrid).(classifstrid).(fluostrid)(chan,:);
                hold on
            end
            
        elseif timeOrGen==1
            if RLSfile==0 %if input is roi array
                if isfield(roiobj(r).results.RLS.(classifRLSstrid),'signal')
                    obj=roiobj(r).results.RLS.(classifRLSstrid).divSignal;
                else
                    error(['The roi ' roiobj(r) 'has no RLS.signal. Extract it using extractSignal followed by measureRLS3'])
                end
            elseif RLSfile==1 %if input is rls struct
                if isfield(roiobj(r),'divSignal')
                    obj=roiobj(r).divSignal;
                elseif plotAligned==1
                    obj=roiobj(r).Aligned.(alignstrid);
                else
                    error(['The roi ' roiobj(r) 'has no divSignal field. Extract it using extractSignal followed by measureRLS2'])
                end
            end
            
            %extract
                data(r,:)=obj.(signalstrid).(fluostrid)(chan,:);
                hold on
        end
    
        
    elseif plotDivDur==1
     
        %assign obj
        if timeOrGen==1
            if RLSfile==0 %if input is roi array
                if isfield(roiobj(r).results,'RLS')
                    obj=roiobj(r).results.RLS;
                else
                    error(['The roi ' roiobj(r) 'has no RLS. Extract it using extractSignal followed by measureRLS3'])
                end
                
            elseif RLSfile==1 %if input is rls struct
                if plotAligned==0    
                    obj=roiobj(r);
                elseif plotAligned==1
                    obj=roiobj(r).Aligned.(alignstrid);
                end
            end
            data(r,:)=obj.divDuration*timefactor;
        end
    end

%extract data
%      if isfield(obj,signalstrid)
%       if  isfield(obj.(signalstrid),classifstrid)
%         else
%             error(['The roi ' roiobj(r) 'has no ' signalstrid 'signal (or RLS.signal) according to your choice), be sure extracted it, using extractSignal'])
%         end
%     else
%         error(['The roi ' roiobj(r) 'has no signal (or RLS.signal according to your choice). Extract it using extractSignal'])
%     end
end

%% plot
lw=1;
fz=16;
figExport=0;
if figExport==1
    lw=0.5;
    fz=8;
end

if plotAligned==1
    x0=numel(data(1,:));
    zero=obj.zero;
    x=[-zero+1:x0-zero];
else
    x=1:numel(data(1,:));
end
%all
figure;
for r=1:numel(roiobj)
    hold on
    plot(x,data(r,:))
end

%averaged value
meanData=nanmean(data,1);
stdData=nanstd(data,1);


figure;
box on
title(['']);
plot(x,meanData)
hold on

closedx=[];
shadedstd=[];
closedx = [x, fliplr(x)];
shadedstd = [meanData-stdData, fliplr(meanData+stdData)];
ptch=patch(closedx, shadedstd,'r');
ptch.FaceAlpha=0.15;
ptch.EdgeAlpha=0.3;
ptch.LineStyle='--';
ptch.LineWidth=lw;
ptch.EdgeColor='r';

legend(['N=' num2str(numel(data(:,1)))])

set(gca,'FontSize',fz, 'FontName','Myriad Pro','LineWidth',2*lw,'FontWeight','bold','TickLength',[0.02 0.02]);

end

