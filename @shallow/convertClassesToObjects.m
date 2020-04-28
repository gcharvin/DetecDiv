function convertClassesToObjects(obj,strin,strout,roilist)
% this function converts pixel classification delimited objects into
% objects , ie it removes unnecessary information
% strin is the name of the classes channel
% strout is the name of the output object channel


if nargin==3
   % classify all ROIs
   roilist=[];
   roilist2=[];
   
   for i=1:length(obj.fov)
      % for j=1:numel(obj.fov(i).roi)
      
     %size( ones(1,length(obj.fov(i).roi)) )
           roilist = [roilist i*ones(1,length(obj.fov(i).roi)) ];
           roilist2 = [roilist2  1:length(obj.fov(i).roi) ]; 
      % end
   end
  
roilist(2,:)=roilist2;
end


for i=1:size(roilist,2) % loop on all ROIs
  %  aa=roilist(1,i),bb=roilist(2,i)
    
 roiobj=obj.fov(roilist(1,i)).roi(roilist(2,i));
 
 if ischar(strin)
 cc=roiobj.findChannelID(strin);
 else
 cc=strin;
 end
 
 
 if numel(cc)==0
     displ(['Channel ' strin ' does not exist']);
     return;
 end
 
 if i==1 % ask how to convert classes into objects
         prompt='Please enter class numbers to be considered as object  [Default: 2]): ';
        imageclassifier= input(prompt,'s');
        if numel(imageclassifier)==0
         imageclassifier=2;
        else
          imageclassifier=str2num(imageclassifier);  
        end
 end

 disp(['Processing ROI ' num2str(i) '...']);
 
 if numel(roiobj.image)==0
    roiobj.load; 
 end
 
 im=roiobj.image(:,:,cc,:);
 
 l=logical(zeros(size(im)));
 
 for j=1:numel(imageclassifier) 
 l= l | im==imageclassifier(j);
 end
 
 l=uint16(l);
 rgb=[1 1 1];
 intensity=[0 0 0];
 roiobj.addChannel(l,strout,rgb,intensity);
end
  
 
