function userTraining(obj,classiid)

% this function load the training process for a specified classification
% task

category=obj.processing.classification(classiid).category;

disp(['Number of classes defined by user: ' num2str(numel(obj.processing.classification(classiid).classes))]);
    for j=1:numel(obj.processing.classification(classiid).classes)
       disp([num2str(j) '- '  obj.processing.classification(classiid).classes{j}]);
    end
    

disp(' ');
    
disp(['Number of ROIs available in the training set: ' num2str(numel(obj.processing.classification(classiid).roi))]);
    for j=1:numel(obj.processing.classification(classiid).roi)
       disp([num2str(j) '- '  obj.processing.classification(classiid).roi(j).id]);
    end
    
    
prompt='Please enter the ROI number in which to do training; Default:1';
classitype= input(prompt);

if numel(classitype)==0
    classitype=1;
end

channel=obj.processing.classification(classiid).channel;

obj.processing.classification(classiid).roi(classitype).display.selectedchannel=zeros(1,numel(obj.processing.classification(classiid).roi(classitype).display.selectedchannel));
obj.processing.classification(classiid).roi(classitype).display.selectedchannel(channel)=1;
obj.processing.classification(classiid).roi(classitype).view(obj.processing.classification(classiid).roi(classitype).display.frame,category); 

