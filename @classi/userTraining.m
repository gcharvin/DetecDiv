function userTraining(classif,varargin)

% this function load the annotation/curation process for a specified classification
% task
classitype=[];
for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Roi')
        classitype=varargin{i+1};
    end
end
        
category=classif.category;

% disp(['Number of classes defined by user: ' num2str(numel(classif.classes))]);
%     for j=1:numel(classif.classes)
%        disp([num2str(j) '- '  classif.classes{j}]);
%     end
%     
% disp(' ');
%     
% disp(['Number of ROIs available in the training set: ' num2str(numel(classif.roi))]);
%     for j=1:numel(classif.roi)
%        disp([num2str(j) '- '  classif.roi(j).id]);
%     end
    
    
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

    if numel(classitype)==0
        prompt='Please enter the ROI number in which to do training; Default:1';
        classitype= input(prompt);

        if numel(classitype)==0
            classitype=1;
        end
    end
    channel=classif.channel(1);
    
    if classitype>numel(classif.roi)
        disp('This ROI is ot available; quitting ...');
        return
    end
        
% comment : disable restrictions on channel display:
channel

classif.roi(classitype).display.selectedchannel=zeros(1,numel(classif.roi(classitype).display.selectedchannel));
classif.roi(classitype).display.selectedchannel(channel)=1;


pix = classif.roi(classitype).findChannelID(classif.strid);
pix=  classif.roi(classitype).channelid(pix)
classif.roi(classitype).display.selectedchannel(pix)=1;



            
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

   %     end
            
classif.roi(classitype).view(classif.roi(classitype).display.frame,classif); 

end
end


function annotateROIs(classif,rois)

h=figure('Position',[100 100 800 400]);

%tmp=getData(classif,rois,1);
 classif.roi(rois(1)).display.frame=1;
plotData(h,classif,rois,1);

%plotData(h,tmp,1,classif) 

keys={'a' 'z' 'e' 'r' 't' 'y' 'u' 'i' 'o' 'p' 'q' 's' 'd' 'f' 'g' 'h' 'j'};
h.KeyPressFcn={@changeframe,classif,rois,keys};
end
    
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

function tmp=getData(classif,rois,id)
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

r=rois(id);
    
    tmp=classif.roi(r);
    
    for j=1:numel(str)
        tmp=tmp.(str{j});
    end    
    
end

function plotData(h,classif,rois,roiid) % HERE : must display frame displayed and plot classes a function of rames

figure(h);
clf

 data=getData(classif,rois,roiid);
 
 if classif.output==1 % sequence to one
     cond=0;
 else
     cond=1; % sequence to sequence
 end
 
 for i=1:size(data,1)
     
     subplot(size(data,1)+cond,1,i); hold on ; 
     
     if i==1
          
          str=['ROI ' num2str(roiid) '  -  ' classif.roi(roiid).id ];
          if classif.output==1 % sequence to one
               if  classif.roi(rois(roiid)).train.(classif.strid).id>0
                   str=[str ' - ' classif.classes{classif.roi(rois(roiid)).train.(classif.strid).id}];
               else
                   str=[str ' - unclassified']; 
               end
                 
          else % sequence to sequence
               if  numel(classif.roi(rois(roiid)).train.(classif.strid).id)>=classif.roi(rois(roiid)).display.frame
                    if classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame) >0
                        str=[str ' - ' classif.classes{classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame)}];
                    else
                        str=[str ' - unclasfied']; 
                    end
               else
                   classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame)=0;
                     str=[str ' - unclassified']; 
               end
               
               str= [str ' - frame:' num2str(classif.roi(rois(roiid)).display.frame)];
              
          end
          
          ht=title(str,'Interpreter','none');
          
     end
     
     x=data(i,:);
     
     plot(x,'Marker','.','MarkerSize',10,'Color','b'); hold on
     
     if classif.output==0 % sequence to sequence
         line([ classif.roi(rois(roiid)).display.frame classif.roi(rois(roiid)).display.frame], [0 max(x)],'Color','k');
     end
     
     xlim([0 numel(x)]);
     
     if i<size(data,1)
     set(gca,'FontSize',14,'XTickLabels',{});
     else
     set(gca,'FontSize',14);    
     end
 end
 
 if classif.output==0 % seuqnece to sequence 
      subplot(size(data,1)+cond,1,i+1); hold on ; 
      plot( classif.roi(rois(roiid)).train.(classif.strid).id,'Color','r','LineWidth',2); hold on
      line([ classif.roi(rois(roiid)).display.frame classif.roi(rois(roiid)).display.frame], [0 numel(classif.classes)+1],'Color','k');
       xlim([0 numel(x)]);
       ylim([0 numel(classif.classes)+1]);
 end
 
 
 
 
 % if sequence to sequence, must add the value  for each frame ....
 
 xlabel('Time (frames');
 
 h.UserData=roiid;
 
end
 
function changeframe(handle,event,classif,rois,keys)

roiid=handle.UserData;

refreshe=0;

if strcmp(event.Key,'m')
    if roiid>=numel(rois)
        return;
    end
    roiid=roiid+1;
    refreshe=1;
end

if strcmp(event.Key,'l')
    if roiid<=1
        return;
    end
    roiid=roiid-1;
   refreshe=1;
end

if classif.output==0 % sequence to sequence // allow frame browsing
    
  if strcmp(event.Key,'rightarrow')
       data=getData(classif,rois,roiid);
       ma=size(data,2);
       if classif.roi(rois(roiid)).display.frame<ma
    classif.roi(rois(roiid)).display.frame=classif.roi(rois(roiid)).display.frame+1;
    refreshe=1;
       end
  end
    if strcmp(event.Key,'leftarrow')
     if classif.roi(rois(roiid)).display.frame>1;
    classif.roi(rois(roiid)).display.frame=classif.roi(rois(roiid)).display.frame-1;
    refreshe=1;
     end
  end

end

 % data=getData(classif,rois,roiid);
    % ok=1;

    
   for i=1:numel(keys) % display the selected class for the current image
            if i>numel(classif.classes)
                break
            end
            
            if strcmp(event.Key,keys{i})
                     if classif.output==0
                    classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame)=i;
                     else
                        classif.roi(rois(roiid)).train.(classif.strid).id=i;  
                     end
                    refreshe=1;
                end
   end

   if refreshe==1
    plotData(handle,classif,rois,roiid);
   end
end



 
 





