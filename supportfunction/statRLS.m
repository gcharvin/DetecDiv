<<<<<<< Updated upstream
function [h1,h2,h3]=statRLS(rls)
=======
function [h1,h2,h3]=statRLS(rls,varargin)
>>>>>>> Stashed changes
% plot statistics associated with automated RLS data
% this assumes that groundtruth and test data are interwined.

% plot correlation between groundtruth rls and observed rls 


comment='';
for i=1:numel(varargin)
    if strcmp(varargin{i},'Comment')
        comment=varargin{i+1};
    end
end



rlsg=[rls.groundtruth]==1;
rlsg=[rls(rlsg).ndiv];

rlst=[rls.groundtruth]==0;
rlst=[rls(rlst).ndiv];

h1=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.5 0.5]);
plot(rlsg,rlst,'Color','r','Marker','.','MarkerSize',30,'LineStyle','none'); hold on; 
plot(0:max(max(rlst),max(rlsg)),0:max(max(rlst),max(rlsg)),'k','LineStyle','--','LineWidth',2);
r=corrcoef(rlsg,rlst);

xlim([0 max(max(rlst),max(rlsg))]);
ylim([0 max(max(rlst),max(rlsg))]);
xlabel('Ground truth lifespan (gen.)');
ylabel('Computed lifespan (gen.)');
title([comment ' - R^2 =' num2str(r(1,2))]);
set(gca,'FontSize',14);

% plot ecdf for lifespan

[yt,xt]=ecdf(rlst);
[yg,xg]=ecdf(rlsg);


h2=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.5 0.5]);
stairs([0 ; xg],[1 ; 1-yg],'Color','k','LineWidth',2);hold on,
stairs([0 ; xt],[1 ; 1-yt],'Color','g','LineWidth',2); 

legend({['Groundtruth; median= ' num2str(median(rlsg)) ' (N= ' num2str(length(rlsg)) ')'],['Computed; median= ' num2str(median(rlst)) ' (N= ' num2str(length(rlst)) ')']});
xlabel('Divisions');
ylabel('Survival');
p=ranksum(rlst,rlsg);
title([comment ' - Replicative lifespan; p=' num2str(p)]);
set(gca,'FontSize',16);
xlim([0 max(max(rlst),max(rlsg))])
ylim([0 1.05]);


% plot overall distribution of division times 
rlsg=[rls.groundtruth]==1;
rlst=[rls.groundtruth]==0;

divg=[rls(rlsg).divDuration];
divt=[rls(rlst).divDuration];

bins=0:1:40;
[ng xg]=hist(divg,bins);
[nt xt]=hist(divt,bins);

h3=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.5 0.5]);
stairs(xg,ng,'Color','k','LineWidth',2);hold on;
stairs(xt,nt,'Color','g','LineWidth',2); 


p=ranksum(divg,divt);
legend({['Groundtruth; median= ' num2str(median(divg)) ' (N= ' num2str(length(divg)) ')'],['Computed; median= ' num2str(median(divt)) ' (N= ' num2str(length(divt)) ')']});
<<<<<<< Updated upstream
title(['Division times; p=' num2str(p)]);
=======
title([comment ' - Division times; p=' num2str(p)]);
>>>>>>> Stashed changes
set(gca,'FontSize',16);
xlabel('Division time (frames)');
ylabel('# Events');



