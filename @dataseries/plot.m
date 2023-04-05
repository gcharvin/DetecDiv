function h=plot(data)

% plot specific subdataset using properties included in the dataseries
% object

h=findobj('Tag',data.id);

if numel(h)==0
h= figure('Color','w','Position',[100 100 1000 400],'Tag',data.id);
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

varnames=data.data.Properties.VariableNames;

for i=1:numel(plotidx)

    subplot(n,1,i);

    for j=1:numel(plotidx{i})
       
    tmp=plotidx{i};
    dat=data.getData(varnames{plotidx{i}(j)});
    plot(dat); hold on
    
    end
    ylabel(plotidxgroup{i})

end





