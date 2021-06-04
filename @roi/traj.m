function h=traj(obj,classistr,varargin)

% trajectory

% classistr represents the strid of the classifier to be displayed

% option is the particular class id to be be represented as probability;
% default : 1

idclas=1;
hidefig=0;
comment='';
reg=0;
for i=1:numel(varargin)
    %hide
    if strcmp(varargin{i},'Hide')
        hidefig=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Comment')
        comment=varargin{i+1};
    end
    
    if strcmp(varargin{i},'option')
        idclas=varargin{i+1};
    end
    
       if strcmp(varargin{i},'Regression')
       reg=1;
    end
    
end

if numel(obj.results)==0
    disp('There is no result available for this position');
    return;
end

if ~isfield(obj.results,classistr)
    disp('There is no result available for this classification id');
    return;
end

if numel(obj.image)==0
    obj.load;
end

if reg==0 % this is a classification, not regression
% find class names
classes={};
cc=1;
for i=1:max(obj.results.(classistr).id)
    pix=find(obj.results.(classistr).id==i,1,'first');
    classes{cc}=char(obj.results.(classistr).labels(pix));
    cc=cc+1;
end
end

if hidefig==1
    h=figure('Tag',['Traj' num2str(obj.id)],'Color','w','Units', 'Normalized', 'Position',[0 0 1 1],'Visible','off');
else
    h=figure('Tag',['Traj' num2str(obj.id)],'Color','w','Units', 'Normalized', 'Position',[0 0 1 1]);
end

%===========CLASSES============

if reg==0 % classif 
acla=subplot(2,1,1);
else % regression
 acla=gca;
 
end
set(gca,'FontSize',20);


str={};
% GT
if numel(obj.train)~=0
    x=1:numel(obj.train.(classistr).id);
    y=obj.train.(classistr).id;
    
    plot(x,y,'Color','k','LineWidth',3); hold on;
    str{1}= 'Groundtruth';
end

% results
xr=1:numel(obj.results.(classistr).id);
yr=obj.results.(classistr).id;
plot(xr,yr,'Color','r','LineWidth',2); hold on;
 
if numel(obj.train)~=0
    if reg==0 % classif
acc= 100*sum(yr==y)./length(y);
    else % regression
    acc= mean( (yr-y).^2 );    
    end
else
acc=0;    
end

if reg==0
str{end+1}=['Classification results; ' num2str(acc) '% accurate'];
else
  str{end+1}=['Regression results; RMSE= ' num2str(acc)];  
end

% results in case a separate CNN is used
if isfield(obj.results.(classistr),'idCNN')
    xrCNN=1:numel(obj.results.(classistr).idCNN);
    yrCNN=obj.results.(classistr).idCNN;
    plot(xrCNN,yrCNN,'Color','g','LineWidth',1); hold on;
    
    if reg==0 % classif
    accCNN= 100*sum(yrCNN==y)./length(y);
    str{end+1}=['Classification results CNN; ' num2str(accCNN) '% accurate'];
    else % regression
           accCNN= mean( (yrCNN-y).^2 );    
      str{end+1}=['Regression results; RMSE= ' num2str(accCNN)];  
    end
end

str2=str;

pix=find(xr==obj.display.frame);
line([xr(pix) xr(pix)],[1 max(obj.results.(classistr).id)],'Color',[0.5 0.5 0.5],'LineWidth',2,'Tag','track');
str{end+1}='Cursor position';

legend(str);

hl=findobj(h,'Tag','track');

ylim([0 max(obj.results.(classistr).id)+1]);

if reg==0 % classif 
set(acla,'YTick',1:max(obj.results.(classistr).id),'YTickLabel',classes,'Fontsize',14);
else % reg
set(acla,'YTick',1:max(obj.results.(classistr).id),'Fontsize',14);   
end

if reg==0
title([comment ' - ' classistr ' - classification results for ROI ' obj.id],'Interpreter','none');
ylabel('Classes');
else
  title([comment ' - ' classistr ' - Regression  results for ROI ' obj.id],'Interpreter','none');
ylabel('Regression value');
end


if reg==0 % classi : display prbability of class as well 
%========PROB===========
aprob=subplot(2,1,2);

% GT
if numel(obj.train)~=0
    x=1:numel(obj.train.(classistr).id);
    y=obj.train.(classistr).id==idclas;
    plot(x,y,'Color','k','LineWidth',3); hold on;
end

% LSTM
if isfield(obj.results.(classistr),'prob')
    prob=obj.results.(classistr).prob;
    
    if   numel(obj.results.(classistr).classes)~=size(obj.results.(classistr).prob,1)
        prob=prob';
    end
    
    xr=1:numel(prob(idclas,:));
    yr=prob(idclas,:);
    
    plot(xr,yr,'Color','r','LineWidth',1,'LineStyle','-','Marker','.','MarkerSize',15); hold on;
end

% CNN
if isfield(obj.results.(classistr),'probCNN')
    probCNN=obj.results.(classistr).probCNN;
    
    if   numel(obj.results.(classistr).classes)~=size(obj.results.(classistr).probCNN,1)
        probCNN=probCNN';
    end
    
    xrCNN=1:numel(probCNN(idclas,:));
    yrCNN=probCNN(idclas,:);
    
    plot(xrCNN,yrCNN,'Color','g','LineWidth',1,'LineStyle','-','Marker','.','MarkerSize',15); hold on;
end
    
% Re LSTM   
if isfield(obj.results.(classistr),'probcorr')
    probcorr=obj.results.(classistr).probcorr;
    %if   numel(obj.results.(classistr).classes)~=size(obj.results.(classistr).prob,1)
    %    prob=prob';
    %end
    xr=1:numel(probcorr(idclas,:));
    yr=probcorr(idclas,:);
    
    plot(xr,yr,'Color','g','LineWidth',2,'LineStyle','-','Marker','.','MarkerSize',5); hold on;
    str2{end+1}='Reclassification LSTM';
end
    
legend(str2);

ylim([0 1]);

xlabel('Time (frames)');
ylabel(['P( class =  '  obj.results.(classistr).classes{idclas} ')']);

set(gca,'FontSize',16);
end

%ylabel('Budding state');
%set(gca,'YTick',[0 1 2],'YTickLabel',{'unbbuded','small b','large b'})

%hp(2)=subplot(2,1,2);

%obj.plotrls('plot','handle',hp(2));
%xlim([0 x(end)])



%set(h,'WindowButtonDownFcn',{@wbdcb,xdiff,fluodiff,obj.div.raw,obj.div.classi});

h.KeyPressFcn={@changeframe2,obj,h};



function changeframe2(handle,event,obj,h)

% if strcmp(event.Key,'uparrow')
% val=str2num(handle.Tag(5:end));
% han=findobj(0,'tag','movi')
% han.trap(val-1).view;
% delete(handle);
% end

if strcmp(event.Key,'rightarrow')
    if obj.display.frame+1>size(obj.image,4)
        return;
    end
    obj.display.frame=obj.display.frame+1;
    
    obj.view;
    
    hl=findobj(h,'Tag','track');
    if numel(hl)>0
        hl.XData=[obj.display.frame obj.display.frame];
    end
    % ok=1;
    
end

if strcmp(event.Key,'leftarrow')
    if obj.display.frame-1<1
        return;
    end
    obj.display.frame=obj.display.frame-1;
    obj.view;
    % obj.view(obj.frame-1);
    hl=findobj(h,'Tag','track');
    if numel(hl)>0
        hl.XData=[obj.display.frame obj.display.frame];
    end
    %ok=1;
end
hf=findobj('Tag',['Traj' num2str(obj.id)]);
figure(hf);







