function []=plotSignal2(rlsfile,varargin)
%classi script

%todo : simplify code. remove if plotDuration==1 and replace it by : if
%rf=divDuration, skip the rest of the questions.

figExport=0;
nameFile='signal';
timeOrGen=0; %time
timefactor=5;
load=0;
maxBirth=200; %max frame to be born. After, discard rls.
condition=1;


for i=1:numel(varargin)
    if strcmp(varargin{i},'Generation')
        timeOrGen=1;
    end
    
    if strcmp(varargin{i},'Condition')
        condition=varargin{i+1};
    end
    
    %     if strcmp(varargin{i},'RLSfile') %can also take as input rls struct file instead of roiobj
    %         RLSfile=1;
    %     end
    
    if strcmp(varargin{i},'Load') %load data
        load=1;
    end
    
    if strcmp(varargin{i},'NameFile')
        nameFile=varargin{i+1};
        figExport=1;
    end
    
end

% if isa(rls,'roi')
%     RLSfile=0;
%
% elseif isa(rls,'struct')
%RLSfile=1;
timeOrGen=1;
% end


%% selection
% rls=rls([rls(:).condition]==condition);
rlsfile=rlsfile([rlsfile(:).ndiv]>7); %put at least 1 for robustness
rlsfile=rlsfile([rlsfile(:).sep]>5); %take only SEP cells

rlsfile=rlsfile( ([rlsfile.frameBirth]<=maxBirth) & (~isnan([rlsfile.frameBirth])) );
%roiobj=roiobj( (strcmp({roiobj.endType},'Death') & [roiobj.frameEnd]>300)  );
rlsfile=rlsfile( ~(strcmp({rlsfile.endType},'Arrest') & [rlsfile.frameEnd]<300)  ); %remove weird cells before frame 300 (stop growing)
rlsfile=rlsfile( ~(strcmp({rlsfile.endType},'Emptied') & [rlsfile.frameEnd]<300)  ); %remove emptied roi before frame 300

for cond=1:numel(condition)
    rois{cond}=1:numel(rlsfile([rlsfile.condition]==condition(cond)));
    comment{cond}=rlsfile(find([rlsfile.condition]==condition(cond)),1).conditionComment;
end
%%
signalstrid='';
classifstrid='';
fluostrid='';


%% load data if required
if load==1
    for cond=conditions
    for r=rois{cond}
        rlsfile(r).load('results');
    end
    end
end

%%
if timeOrGen==0 %time
    if isfield(rlsfile(1).results,'signal')
        for cond=conditions
            rlstmp=rlsfile([rlsfile.condition]==condition(cond));
            listfields=fieldnames(obj{cond}(1,1));
            for r=rois{cond}
                for f=listfields
                    if isfield(rlstmp(r).results.signal,f)
                        obj{cond}(r,1).(f)=rlstmp(r).results.signal.(f); %assign obj
                    end
                end
            end
        end
    else
        error(['The roi ' rlsfile(1) 'has no signal. Extract it using extractSignal'])
    end
    
elseif timeOrGen==1 %generations
    
    %     if RLSfile==0 %if input is rois array
    %         % ask RLSclassi
    %         if isfield(rls(1).results,'RLS')
    %             liststrid=fields(rls(1).results.RLS); %full, cell, nucleus
    %             str=[];
    %         else
    %             error(['The roi ' rls(1) 'has no RLS. Extract it using measureRLS3'])
    %         end
    %         for i=1:numel(liststrid)
    %             str=[str num2str(i) ' - ' liststrid{i} ';'];
    %         end
    %         str=erase(str,'from_');
    %
    %         classiRLSid=input(['Which classi used for RLS extraction? (Default: 1)' str]);
    %         if numel(classiRLSid)==0
    %             classiRLSid=1;
    %         end
    %         classifRLSstrid=liststrid{classiRLSid};
    %
    %         if isfield(rls(1).results.RLS.(classifRLSstrid),'signal')
    %             for r=rois
    %                 obj(r,1)=rls(r).results.RLS.(classifRLSstrid).divSignal; %assign obj
    %             end
    %
    %         else
    %             error(['The roi ' rls(1) 'has no RLS.signal. Extract it using extractSignal followed by measureRLS3'])
    %         end
    
    
    
    
    %     elseif RLSfile==1 %if input is rls struct
    if isfield(rlsfile(1),'divSignal')
        for cond=1:numel(condition)
            rlstmp=rlsfile([rlsfile.condition]==condition(cond));
            obj{cond}(1,1)=rlstmp(1).divSignal;
            
            listfields=fieldnames(obj{cond}(1,1));
            for r=rois{cond}
                for f=listfields
                    if isfield(rlstmp(r).divSignal,f)
                        obj{cond}(r,1).(f)=rlstmp(r).divSignal.(f); %assign obj
                    end
                end
            end
        end
    else
        error(['The roi ' rlsfile(1).name 'has no divSignal field. Extract it using extractSignal followed by measureRLS2'])
    end
    
    if isfield(rlsfile(1),'Aligned')
        askPlotAligned=input('Aligned signals available, plot this? y/n (Default: n)','s');
        if numel(askPlotAligned)==0
            plotAligned=0;
        elseif strcmp(askPlotAligned,'y') %plot aligned signals
            plotAligned=1;
            clear obj
            %remove nosep
            flag=[];
            for r=1:numel(rlsfile)
                if isempty(rlsfile(r).Aligned)
                    flag=[flag r];
                end
            end
            rlsfile(flag)=[];
            for cond=1:numel(condition) %updates variable storing number of rois
                rois{cond}=1:numel(rlsfile([rlsfile.condition]==condition(cond)));
            end
            
            liststrid=fields(rlsfile(1).Aligned); %full, cell, nucleus
            str=[];
            for i=1:numel(liststrid)
                str=[str num2str(i) ' - ' liststrid{i} '; '];
            end
            alignid=input(['Which alignment used ? (Default: 1)' str]);
            if numel(alignid)==0
                alignid=1;
            end
            alignstrid=liststrid{alignid};
            
            for cond=1:numel(condition)
                rlstmp=rlsfile([rlsfile.condition]==condition(cond));
                for r=rois{cond}
                    obj{cond}(r,1)=rlstmp(r).Aligned.(alignstrid); %assign obj
                end
            end
            
        end
    end
    %     end
    
    %     %ask if want to plot divDuration
    %     if isfield(obj,'divDuration')
    %         askPlotDivDuration=input('Division duration available, plot this? y/n (Default: n)','s');
    %         if numel(askPlotDivDuration)==0
    %             plotDivDur=0;
    %         elseif strcmp(askPlotDivDuration,'y') %plot aligned signals
    %             plotDivDur=1;
    %         end
    %     end
end


%% ask signal
liststrid=fields(obj{1}(1)); %full, cell, nucleus, div
liststrid(contains(liststrid,'zero'))=[];

str=[];
for i=1:numel(liststrid)
    str=[str num2str(i) ' - ' liststrid{i} '; '];
end

signalid=input(['Which signal type? (Default: 1)' str]);
if numel(signalid)==0
    signalid=1;
end

signalstrid=liststrid{signalid};
if strcmp(signalstrid,'divDuration')
    plotDivDuration=1;
    
    for cond=1:numel(condition)
        obj2{cond}={obj{cond}.divDuration}'; %assign obj
    end
    
    channumber=1;
else
    plotDivDuration=0;
end

%% ask classistrid
if plotDivDuration==0
    liststrid=fields(obj{1}(1).(signalstrid));
    str=[];
    
    for i=1:numel(liststrid)
        str=[str num2str(i) ' - ' liststrid{i} '; '];
    end
    classifid=input(['Which classi used for extracting signal? (Default: 1)' str]);
    if numel(classifid)==0
        classifid=1;
    end
    
    classifstrid=liststrid{classifid};
    
    %% ask fluo
    liststrid=fields(obj{1}(1).(signalstrid).(classifstrid));
    str=[];
    
    for i=1:numel(liststrid)
        str=[str num2str(i) ' - ' liststrid{i} '; '];
    end
    fluoid=input(['Which type of signal? (Default: 1)' str]);
    if numel(fluoid)==0
        fluoid=1;
    end
    
    fluostrid=liststrid{fluoid};
    
    
    %% ask rate
    if contains(fluostrid,'IncRate')
        plotRate=1;
    else
        plotRate=0;
    end
    
    for cond=1:numel(condition)
        for r=rois{cond}
            obj2{cond}{r,1}=obj{cond}(r).(signalstrid).(classifstrid).(fluostrid);
        end
    end
    %% ask channel
    channumber=size(obj2{1}{1,1},1);
    str=[];
    chanid=input(['Which channel ? (Default: 1)' num2str(1:channumber)]);
    if numel(chanid)==0
        chanid=1;
    end
    
end

%% data to vector
for cond=1:numel(condition)
    data{cond}=nan(numel(rois{cond}),max(cellfun(@numel,obj2{cond}))/channumber);
end

for cond=1:numel(condition)
    for r=rois{cond}
        %extract
        if plotDivDuration==1
            data{cond}(r,:)=obj2{cond}{r,1}*timefactor;
        elseif strcmp(fluostrid,'volume')
            data{cond}(r,:)=obj2{cond}{r,1}(chanid,:)*0.1056; %normalize into microns²
        else
            data{cond}(r,:)=obj2{cond}{r,1}(chanid,:);
        end
    end
end

%% plot
lw=1;
fz=16;
mz=5;
if figExport==1
    lw=0.5;
    fz=8;
    sz=7.5;
    szy=4;
    mz=3.5;
end

for cond=1:numel(condition)
    if plotAligned==1
        x0{cond}=numel(data{cond}(1,:));
        zero{cond}=obj{cond}.zero;
        x{cond}=[-zero{cond}+1:x0{cond}-zero{cond}];
    else
        x{cond}=1:numel(data{cond}(1,:));
    end
    
    
    %all
    figure;
    for r=rois{cond}
        hold on
        plot(x{cond}(:),data{cond}(r,:))
    end
    
    
    %averaged value
    meanData{cond}=nanmean(data{cond},1);
    stdData{cond}=nanstd(data{cond},1);
    for i=1:numel(stdData{cond})
        numberOfCells{cond}(i)=sum(~isnan(data{cond}(:,i)));
        semData{cond}(i)=stdData{cond}(i)/sqrt(numberOfCells{cond}(i));
    end
end

signalFig=figure;
hold on
box on
title(['']);
% plot(x,meanData)
% hold on
%
% closedx=[];
% shadedstd=[];
% closedx = [x, fliplr(x)];
% shadedstd = [meanData-semData, fliplr(meanData+semData)];
% ptch=patch(closedx, shadedstd,'r');
% ptch.FaceAlpha=0.15;
% ptch.EdgeAlpha=0.3;
% ptch.LineStyle='--';
% ptch.LineWidth=lw;
% ptch.EdgeColor='r';
colmap=colormap(lines);

for cond=1:numel(condition)
    errorbar(x{cond},meanData{cond},semData{cond},'o','MarkerEdgeColor','k','MarkerFaceColor',colmap(cond,:),'MarkerSize',mz,'Color',colmap(cond,:));
    leg{cond}=[comment{cond} ' N=' num2str(numel(data{cond}(:,1)))];
    
    %Xtk=[x{cond}(1):5:x{cond}(end)];
    Xtk=[-30:5:5];
    set(gca,'FontSize',fz, 'FontName','Myriad Pro','LineWidth',2*lw,'FontWeight','bold','TickLength',[0.02 0.02],'XTick',Xtk);
    xlim([Xtk(1) Xtk(end)]);
    ylim(1)=0;
end
legend(leg);

if figExport==1
    ax=gca;
    xf_width=sz; yf_width=szy;
    set(gcf, 'PaperPositionMode', 'auto', 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [5 5 xf_width yf_width]) %0.8 if .svg is used
    signalFig.Renderer='painters';
    %saveas(rlsFig,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig1\RLS\RLS_sir2_fob1.svg')
    exportgraphics(signalFig,['' nameFile '.pdf'])
    %print(rlsFig,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig1\RLS\RLS_sir2_fob1','-dpdf')%,'BackgroundColor','none','ContentType','vector')
    %export_fig RLS_sir2_fob1.pdf
end
end

