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

