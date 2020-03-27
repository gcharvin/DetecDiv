function trainClassifier(obj,classiid)

% this function load the training process for a specified classification
% task

category=obj.processing.classification(classiid).category{1};


disp(['Number of ROIs avaiable in the training set: ' num2str(numel(obj.processing.classification(classiid).roi))]);
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

obj.processing.classification(classiid).roi(classitype).view(1,category); 

% TO DO HERE : 
% 1) set menu for classes, in roi view function
% 2) prompt number of classes to be used and their name , define add class and
% remove class function in the menu 
% 3) Display class attribution on the image using appropriate color code
% 4) define  keyboard function to quickly assign classes to image 
% 5) Record classes number in specific variable and store in classification
% variable 
%

% prompt='Please enter the ROI number in which to do training; Default:1';
% classitype= input(prompt);
% 
% if numel(classitype)==0
%     classitype=1;
% end
