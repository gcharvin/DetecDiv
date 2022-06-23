function []=plotSignal2(rlsfile,varargin)
%classi script

%todo : ignore if roi has no signal instead of error
%rf=divDuration, skip the rest of the questions.

figExport=0;
nameFile='signal';
timeOrGen=0; %time
timefactor=5;


maxBirth=200; %max frame to be born. After, discard rls.
condition=1:max([rlsfile.condition]);
MinDiv=1;
MinSep=0;
plotAligned=0;


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

    if strcmp(varargin{i},'MinDiv') %load data
        MinDiv=varargin{i+1};
    end

    if strcmp(varargin{i},'MinSep') %load data
        MinSep=varargin{i+1};
    end

    if strcmp(varargin{i},'FrameInterval') %load data
        timefactor=varargin{i+1};
    end

    if strcmp(varargin{i},'maxBirth') %load data
        maxBirth=varargin{i+1};
    end


    if strcmp(varargin{i},'timeOrGen') %load data
        if strcmp(varargin{i+1},'Time')
            timeOrGen=0;
        else
            timeOrGen=1;
        end
    end

end

% if isa(rls,'roi')
%     RLSfile=0;
%
% elseif isa(rls,'struct')
%RLSfile=1;
%timeOrGen=1;
% end


%% selection
% rls=rls([rls(:).condition]==condition);
rlsfile=rlsfile([rlsfile(:).ndiv]>MinDiv); %put at least 1 for robustness
rlsfile=rlsfile([rlsfile(:).sep]>MinSep); %take only SEP cells

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


%%
if timeOrGen==0 %time
    if isfield(rlsfile(1),'signalPerFrame')
        for cond=1:numel(condition)
            rlstmp=rlsfile([rlsfile.condition]==condition(cond));
            obj{cond}(1,1)=rlstmp(1).signalPerFrame;
            
            listfields=fieldnames(obj{cond}(1,1));
            for r=rois{cond}
                for f=1:numel(listfields)
                    if isfield(rlstmp(r).signalPerFrame,listfields{f})
                        obj{cond}(r,1).(listfields{f})=rlstmp(r).signalPerFrame.(listfields{f}); %assign obj
                    end
                end
            end
        end
    else
        error(['The roi ' rlsfile(1).name ' has no signalPerFrame field. Extract it using extractSignal followed by measureRLS3'])
    end
        
elseif timeOrGen==1 %generations    
    if isfield(rlsfile(1),'Aligned')
        %   askPlotAligned=input('Aligned signals available, plot this? y/n (Default: n)','s');
        %  if numel(askPlotAligned)==0 || strcmp(askPlotAligned,'n')
        %      plotAligned=0;
        %  elseif strcmp(askPlotAligned,'y') %plot aligned signals
        plotAligned=1;
        %  end
    end

    if plotAligned==0
        if isfield(rlsfile(1),'divSignal')
            for cond=1:numel(condition)
                rlstmp=rlsfile([rlsfile.condition]==condition(cond));
                obj{cond}(1,1)=rlstmp(1).divSignal;

                listfields=fieldnames(obj{cond}(1,1));
                for r=rois{cond}
                    for f=1:numel(listfields)
                        if isfield(rlstmp(r).divSignal,listfields{f})
                            obj{cond}(r,1).(listfields{f})=rlstmp(r).divSignal.(listfields{f}); %assign obj
                        end
                    end
                end
            end
        else
            error(['The roi ' rlsfile(1).name ' has no divSignal field. Extract it using extractSignal followed by measureRLS3'])
        end

    elseif plotAligned==1
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
        %  alignid=input(['Which alignment used ? (Default: 1)' str]);
        %  if numel(alignid)==0
        alignid=1;
        %  end
        alignstrid=liststrid{alignid};

        for cond=1:numel(condition)
            rlstmp=rlsfile([rlsfile.condition]==condition(cond));
            obj{cond}(1,1)=rlstmp(1).Aligned.(alignstrid);
            listfields=fieldnames(obj{cond}(1,1));
            for r=rois{cond}
                for f=1:numel(listfields)
                    if isfield(rlstmp(r).Aligned.(alignstrid),listfields{f})
                        obj{cond}(r,1).(listfields{f})=rlstmp(r).Aligned.(alignstrid).(listfields{f}); %assign obj
                    end
                end
            end
        end
    end

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
        cr=1;
        for r=rois{cond}
            if isfield(obj{cond}(r),signalstrid) %normally useless cause should be taken into account earlier
                if isfield(obj{cond}(r).(signalstrid),classifstrid)
                    if isfield(obj{cond}(r).(signalstrid).(classifstrid),fluostrid)
                        obj2{cond}{cr,1}=obj{cond}(r).(signalstrid).(classifstrid).(fluostrid);
                        cr=cr+1;
                    else
                        warning(['this roi has no ' signalstrid '.' classifstrid '.' fluostrid 'field, roi ignored']);
                    end
                else
                    warning(['this roi has no ' signalstrid '.' classifstrid 'field, roi ignored']);
                end
            else
                warning(['this roi has no ' signalstrid 'field, roi ignored']);
            end
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
    data{cond}=nan(numel(obj2{cond}),max(cellfun(@numel,obj2{cond}))/channumber);
end

for cond=1:numel(condition)
    for r=1:numel(obj2{cond})
        %extract
        if plotDivDuration==1
            data{cond}(r,:)=obj2{cond}{r,1}*timefactor;
%         elseif strcmp(fluostrid,'volume')
%             data{cond}(r,:)=obj2{cond}{r,1}(chanid,:)*0.1056; %normalize into microns²
        elseif timeOrGen==0
            sdatavector=[rlstmp(r).frameBirth,rlstmp(r).frameEnd];
            data{cond}(r,sdatavector(1):sdatavector(2))=obj2{cond}{r,1}(chanid,sdatavector(1):sdatavector(2));
        else
            sdatavector=numel(obj2{cond}{r,1}(chanid,:));
            data{cond}(r,1:sdatavector)=obj2{cond}{r,1}(chanid,:);
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
    for r=1:numel(obj2{cond})
        hold on
        plot(x{cond}(:),data{cond}(r,:))
    end


    %averaged value
    meanData{cond}=nanmean(data{cond},1);
    stdData{cond}=nanstd(data{cond},1);
    if plotAligned==1
        meanPreSync{cond}=nanmean(data{cond}(:,1:zero{cond}),2);
        meanPopPreSync{cond}=nanmean(meanPreSync{cond});
        meanPostSync{cond}=nanmean(data{cond}(:,zero{cond}:end),2);
        meanPopPostSync{cond}=nanmean(meanPostSync{cond});
        [~,p{cond}]=ttest2(meanPreSync{cond},meanPostSync{cond});
        disp(['mean pre for condition ' num2str(cond) ' is ' num2str(meanPopPreSync{cond})])
        disp(['mean post for condition ' num2str(cond) ' is ' num2str(meanPopPostSync{cond})])
        disp(['p-value pre VS post SEP for condition ' num2str(cond) ' is ' num2str(p{cond})])
    end
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
    
    if timeOrGen==1
        step=5;
        if plotAligned==0
            first=0;
        else
            first=-30;
        end
    else
        step=100;
        first=0;
    end
    
    Xtk=[first:step:x{cond}(end)];
    %Xtk=[-30:5:5];
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

