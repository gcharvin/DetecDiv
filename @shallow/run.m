function run(obj,fun,varargin)
% this function executes an ROI method to a number of ROIs in specific fov 

roilist=[];

args={};
for i=1:numel(varargin)
    if strcmp(varargin{i},'roilist')
        roilist=varargin{i+1};
    end
     if strcmp(varargin{i},'args')
       args=varargin{i+1};
    end
end

if numel(roilist)==0
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

% construct function handle
han='@(x';
for i=1:numel(args)
    han=[han ', arg' num2str(i)];
end
han=[han ') ' fun '(x'];
for i=1:numel(args)
    han=[han ', arg' num2str(i)];
end
 han=[han ')'];
 han=eval(han)
 
 
for i=1:size(roilist,2) % loop on all ROIs
  %  aa=roilist(1,i),bb=roilist(2,i)
    
 roiobj=obj.fov(roilist(1,i)).roi(roilist(2,i));
 
% args=roiobj
han(roiobj,args{:})
end

