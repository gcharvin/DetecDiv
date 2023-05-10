function h=plot(data,pos)

% plot specific subdataset using properties included in the dataseries
% object

% specifies roiobj to plot dat along with roi image
% here 
if numel(data.plotProperties)==0
    h=[];
    return;
end


% find if roi is already displayed 
%  hroi=findobj('Tag',['ROI' data.parentid]);
% 
%  if numel(hroi) 
%      pos=hroi.Position;
%  end

h=findobj('Tag',data.id);

if numel(h)==0
h= figure('MenuBar','none','Color','w','Units','normalized','Tag',data.id,'Name',[ data.parentid '//' data.groupid '//' data.id]);

% set position
if nargin==1
pos=[0.1 0.1 0.25 0.15];
end

h.Position=pos;
else
figure(h);
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

end

h.Position(4)=n*0.15;
%h.Position(4)=h.Position(4)-(n-1)*0.15;

varnames=data.data.Properties.VariableNames;
toplot=0;

for i=1:numel(plotidx)

    hs(i)=subplot(n,1,i);

    str={};


    for j=1:numel(plotidx{i})
    toplot=toplot+1;
    tmp=plotidx{i};
    dat=data.getData(varnames{plotidx{i}(j)});
    plot(hs(i),dat); hold on
    str=[str varnames{plotidx{i}(j)}];
    
    end
    legend(hs(i),str,'Interpreter','none','FontSize',10);
    ylabel(hs(i),plotidxgroup{i});

    if data.type=="temporal"
        xlabel(hs(i),"Time");
    end
    set(hs(i),'FontSize',20);
end

if toplot==0
    delete(h)
    return
end

ax=findobj(h,'Type','Axes');
linkaxes(ax,'x')







