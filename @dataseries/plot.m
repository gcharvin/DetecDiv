function h=plot(data)

% plot specific subdataset using properties included in the dataseries
% object

if numel(data.plotProperties)==0
    h=[];
    return;
end

h=findobj('Tag',data.id);

if numel(h)==0
h= figure('Color','w','Position',[100 100 1000 200],'Tag',data.id,'Name',data.parentid);
else
clf;
end
% find the number of subplots 

n=0;

groups=data.plotGroup{6};

plotidx={};
plotidxgroup={};


for i=1:numel(groups)

    pix=contains(data.plotProperties(:,end),string(groups{i}));
    pix2=cellfun(@(x) x(:,1)==true, data.plotProperties(:,1));

    pix=find(pix & pix2); % id of plots to be displayed indenpendlty 

    if numel(pix)
        n=n+1;
        plotidx{n}=pix;
        plotidxgroup{n}=groups{i};
    end
    % here : plot data as subplot in the main figure 

end

h.Position(4)=n*200;

varnames=data.data.Properties.VariableNames;
toplot=0;

for i=1:numel(plotidx)

    subplot(n,1,i);

    str={};


    for j=1:numel(plotidx{i})
    toplot=toplot+1;
    tmp=plotidx{i};
    dat=data.getData(varnames{plotidx{i}(j)});
    plot(dat); hold on
    str=[str varnames{plotidx{i}(j)}];
    
    end
    legend(str,'Interpreter','none','FontSize',10);
    ylabel(plotidxgroup{i});

    if data.type=="temporal"
        xlabel("Time");
    end
    set(gca,'FontSize',20);
end

if toplot==0
    delete(h)
    return
end

ax=findobj(h,'Type','Axes');
linkaxes(ax,'x')







