function userTraining(classif)

% this function load the training process for a specified classification
% task

category=classif.category;

disp(['Number of classes defined by user: ' num2str(numel(classif.classes))]);
    for j=1:numel(classif.classes)
       disp([num2str(j) '- '  classif.classes{j}]);
    end
    
disp(' ');
    
disp(['Number of ROIs available in the training set: ' num2str(numel(classif.roi))]);
    for j=1:numel(classif.roi)
       disp([num2str(j) '- '  classif.roi(j).id]);
    end
    
    
if strcmp(classif.category,'Timeseries') % time series classification and regression
    
    rois=1:numel(classif.roi);
    prompt='Please enter the ROIs list in which to do training; Tyoe 0 to screen all rois; Default:0';
resp= input(prompt);
if numel(resp)==0
    resp=rois;
end

rois=resp;

annotateROIs(classif,rois);

else % image based classification and regression 
    
prompt='Please enter the ROI number in which to do training; Default:1';
classitype= input(prompt);

if numel(classitype)==0
    classitype=1;
end

channel=classif.channel(1);

classif.roi(classitype).display.selectedchannel=zeros(1,numel(classif.roi(classitype).display.selectedchannel));
classif.roi(classitype).display.selectedchannel(channel)=1;

 pix = classif.roi(classitype).findChannelID(classif.strid);
 
%  strfind(obj.processing.classification(classiid).roi(classitype).display.channel, obj.processing.classification(classiid).strid);
%          cc=[];
%         for i=1:numel(pix)
%             if numel(pix{i})~=0
%                 cc=i;
%                
%                 break
%             end
%         end
%        
%         if numel(cc)
            classif.roi(classitype).display.selectedchannel(pix)=1;
   %     end
            
classif.roi(classitype).view(classif.roi(classitype).display.frame,classif); 

end


function annotateROIs(classif,rois)

h=figure('Position',[100 100 800 400]);

strfield=classif.trainingset; % datsaet to be trained on
pix=strfind(strfield,'.');

if numel(pix)==0
    str={strfield};
else
    str={strfield(1:pix(1)-1)};
    
    cc=1;
    for i=1:numel(pix)-1
        str{cc+1}=strfield(pix(i)+1:pix(i+1)-1);
        cc=cc+1;
    end
end
str{cc+1}=strfield(pix(cc)+1:end);

% parse fields

cc=1;

roiid=rois(1);
    
    tmp=classif.roi(roiid);
    
    for j=1:numel(str)
        tmp=tmp.(str{j});
    end    
    
plotData(h,tmp,roiid,classif) 

h.KeyPressFcn={@changeframe};

    
% if classif.output==0 % sequence to sequence 
%     if numel(classif)>0 % classification
%         
%         
%     else % regression 
%         
%         
%     end
%     
% else % seuqnece to one 
%     
% end


function plotData(h,data,roiid,classif)

figure(h);



 for i=1:size(data,1)
     
     subplot(size(data,1),1,i); hold on ; 
     if i==1
          ht=title(['ROI ' num2str(roiid) '  -  ' classif.roi(roiid).id],'Interpreter','none')
     end
     
     x=data(i,:);
     
     plot(x,'Marker','.','MarkerSize',10,'Color','b'); hold on
     
     if i<size(data,1)
     set(gca,'FontSize',14,'XTickLabels',{});
     else
     set(gca,'FontSize',14);    
     end
 end
 
 xlabel('Time (frames');
 
 h.UserData=roiid;
 
 
 
function changeframe(handle,event)


% if strcmp(event.Key,'rightarrow')
%     if obj.display.frame+1>size(obj.image,4)
%         return;
%     end
%     obj.display.frame=obj.display.frame+1;
%     
%     obj.view;
%     
%     hl=findobj(h,'Tag','track');
%     if numel(hl)>0
%         hl.XData=[obj.display.frame obj.display.frame];
%     end
%     % ok=1;
%     
% end
% 
% if strcmp(event.Key,'leftarrow')
%     if obj.display.frame-1<1
%         return;
%     end
%     obj.display.frame=obj.display.frame-1;
%     obj.view;
%     % obj.view(obj.frame-1);
%     hl=findobj(h,'Tag','track');
%     if numel(hl)>0
%         hl.XData=[obj.display.frame obj.display.frame];
%     end
%     %ok=1;
% end

if strcmp(event.Key,'m')
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

hf=findobj('Tag',['Traj' num2str(obj.id)]);
if numel(hf)>1
    warndlg('You have more than 2 traj figure open with the same id (or roi); Please delete non necessary traj figures !');
end
figure(hf);

 
 





