function stats(classif)

% compute, displays and stores statististics regarding the selected classification 


disp(['Number of ROIs  in the @classi object: ' num2str(numel(classif.roi))]);

idstat=[];

path=classif.path;
name=classif.strid;
strpath=[path '/' name];

 

classistr=classif.strid;

for j=1:numel(classif.roi)
    
 obj=classif.roi(j);
 
 disp([num2str(j) ' - '  obj.id ' - checking data']);
  
% classiid represents the strid of the classifier to be displayed

resok=0;
ground=0;

if numel(obj.results)==0
    disp('There is no result available for this roi');
else
    resok=1;
end

if ~isfield(obj.results,classistr)
    disp('There is no result available for this classification id');
else
   resok=1; 
end
    
% if roi was used for user training, display the training data first

if numel(obj.train)~=0
   if isfield(obj.train,classistr)
       if numel(obj.train.(classistr).id) > 0
           if sum(obj.train.(classistr).id)>0 % training exists for this ROI !
               ground=1;
               
           end 
       end
   end
end

% then display the results

if ground ==1 && resok==1 % list of rois used to compute stats
    idstat=[idstat j];
end
end

cc=1;

% accuracy per ROI

acc=[];
sumyr=[];
sumyg=[];

for i=idstat
    obj=classif.roi(i);
     
    yr=obj.results.(classistr).id;
    yg=obj.train.(classistr).id;
    
    acc(cc)= 100*sum(yr==yg)./length(yg);
    
    
    sumyr=[sumyr yr];
    sumyg=[sumyg yg];
    
    cc=cc+1;
end

acctot= 100*sum(sumyr==sumyg)./length(sumyg);

figure('Color','w','Position',[100 100 1000 600]);
plot(acc,'Color','k','LineWidth',2,'Marker','o');
ylim([0 100]);
ylabel('Validation accuracy (%)');
xlabel('ROI #');
title(['Mean accuracy: '  num2str(acctot)  '% - classifier: ' name],'interpreter','none');
set(gca,'FontSize',20);

disp(['Saving plot to ' strpath '_accuracy_ROIs.fig']);
savefig([strpath '_accuracy_ROIs.fig']);
disp(['Saving plot to ' strpath '_accuracy_ROIs.pdf']);
saveas(gca,[strpath '_accuracy_ROIs.pdf']);

%  accuracy per class for all ROIs

acc=[];
sumyr=[];
sumyg=[];

for i=idstat
    obj=classif.roi(i);
     
    yr=obj.results.(classistr).id;
    yg=obj.train.(classistr).id;
    
    sumyr=[sumyr yr];
    sumyg=[sumyg yg];
    
    cc=cc+1;
end

for i=1:numel(classif.classes)
    
    pix= sumyg==i;
    
    ss=sumyr(pix);
    
    acc(i)=100*sum(ss==i)./sum(pix);
    
end

acctot= 100*sum(sumyr==sumyg)./length(sumyg);

figure('Color','w','Position',[100 100 1000 600]);
plot(acc,'Color','k','LineWidth',2,'Marker','o');
ylim([0 100]);
xlim([0 numel(classif.classes)+1]);
ylabel('Validation accuracy (%)');
xlabel('classes');
title(['Mean accuracy: '  num2str(acctot)  '% - classifier: ' name],'interpreter','none');
set(gca,'FontSize',20,'XTick',1:numel(classif.classes),'XTickLabel',classif.classes);

savefig([strpath '_accuracy_classes.fig']);
saveas(gca,[strpath '_accuracy_classes.pdf']);
