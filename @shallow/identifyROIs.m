function identifyROIs(obj,varargin)

if numel(obj.processing.roi.pattern)==0
    disp('There are no patterns available !');
    disp('First define a pattern using shallowObj.setPattern() method');
    return;
end

fovid=1:numel(obj.fov);
channelid=1;
keepexisting=false;
frameid=1;

test=false ; % just claculate ROIs and plots them but does not assign ROIs to object
thr=0.5;

for i=1:numel(varargin)
    if strcmp(varargin{i},'FOV')
        fovid=varargin{i+1};
    end
    if strcmp(varargin{i},'Frames')
        frameid=varargin{i+1};
    end
    if strcmp(varargin{i},'Keep')
        keepexisting=varargin{i+1};
    end
    if strcmp(varargin{i},'Test')
        test=true;
    end
    if strcmp(varargin{i},'Threshold')
        thr=varargin{i+1};
    end
end

%frameid
% read image
out=[];
out.positions=[];
out.scaled=[];
out.fovid=[];
scale=1;
cc=1;

crop=[];
for i=fovid
    if  numel(obj.fov(i).crop)>0
        crop=obj.fov(i).crop;
        break;
    end
end

% str='';
% arrcrop=[];
% for i=fovid
% if  numel(obj.fov(i).crop)>0
%
%     str=[str ' ' num2str(i)];
%     arrcrop=[arrcrop i];
% end
% end
%
% cr=0;
% if numel(str)
% disp(['These FOVs have a crop region defined :' str]);
% disp('Please enter the reference crop FOV to be used for other uncropped FOVs; Type 0 if no crop should be used');
% prompt=['Reference FOV ID for cropping; Default: ' num2str(arrcrop(1))];
% cr=input(prompt);
% if numel(cr)==0
%     cr=arrcrop(1);
% end
% end

for i=fovid % loop on all possible field of view
    
    disp(['Loading source file for FOV ' num2str(i) '....']);
    
    tmp=readImage(obj.fov(i),frameid,channelid);
    if numel(tmp)==0
        disp('unable to load image: quitting !');
        return
    end
    
    disp('Identifying traps using autocorrelation function....');
    
   [tmppos scores]=findTraps(tmp,obj.processing.roi.pattern,thr);

   if numel(tmppos)==0
      disp('could not find any ROIs in image .... Quitting !');
      return;
   end
   
    out(cc).positions=tmppos;
    out(cc).fovid=i;
    
    disp(['Found ' num2str(size(out(cc).positions,1)) ' ROIs !']);
    
    %aa=out(cc).positions
    
    %  polyin = polyshape([0 0 1 1],[1 0 0 1]);
    %  poly1 = rotate(polyin,45);
    
    %scale=0.5;
    
    scaled=round(scale*out(cc).positions);
    
    % make all positions uniform
    x=round(mean(scaled(:,2)-scaled(:,1)));
    y=round(mean(scaled(:,4)-scaled(:,3)));
    
    rois=[];
    scaled(:,2)=scaled(:,1)+x;
    scaled(:,4)=scaled(:,3)+y;
    
    rois(:,2)=scaled(:,1);
    rois(:,1)=scaled(:,3);
    rois(:,3)=y;
    rois(:,4)=x;
    
    scaled=rois;
    
    
    for j=1:size(scaled,1)
        if  scaled(j,1)+x-1>size(tmp,2)/2
            scaled(j,1)=scaled(j,1)-1;
        end
        if  scaled(j,2)+y-1>size(tmp,1)/2
            scaled(j,2)=scaled(j,2)-1;
        end
    end
    
    ccc=1;
    
    scaled2=scaled;
    
    croppingarea=crop;
    %obj.fov(i).crop; % get the cropping area for the given fov
    
    % if cr>0 & numel(croppingarea)==0 % a reference FOV id has been defined for cropping
    %     croppingarea=obj.fov(cr).crop;
    % end
    
    if  numel(croppingarea)>0% include crop factor in ROI selection
        scaled2=[];
        
        for j=1:size(scaled,1)
            xq=[scaled(j,1)  scaled(j,1) scaled(j,1)+x  scaled(j,1)+x ];
            yq=[scaled(j,2) scaled(j,2)+y  scaled(j,2)   scaled(j,2)+y ];
            
            %   if  scaled(j,1)<=obj.fov(i).crop(1) | scaled(j,2)<=obj.fov(i).crop(2) |  scaled(j,1)+x>obj.fov(i).crop(1)+obj.fov(i).crop(3) | scaled(j,2)+y>obj.fov(i).crop(2)+obj.fov(i).crop(4)
            if sum(inpolygon(xq,yq,croppingarea(:,1),croppingarea(:,2)))<4 % roi is not fully within cropped region
                continue
            else
            end
            
            scaled2(ccc,:)=scaled(j,:);
            ccc=ccc+1;
        end
        
        disp(['FOV is cropped: only ' num2str(ccc-1) ' ROIs have been selected !']);
    end
    
    if test
        figure, imshow(tmp,[])
        
        for kk=1:size(scaled2,1)
            roitmp=scaled2(kk,:);
            roitmp=[roitmp(1) roitmp(2) roitmp(1)+ roitmp(3) roitmp(2)+ roitmp(4)];
            h=patch([roitmp(1) roitmp(3) roitmp(3) roitmp(1) roitmp(1)],[roitmp(2) roitmp(2) roitmp(4) roitmp(4) roitmp(2)],[1 0 0],'FaceAlpha',0.3,'Tag',['roitag_' num2str(i)],'UserData',i);
        end
    end
    
    out(cc).scaled=scaled2;
    cc=cc+1;
end

if ~test
    disp('Now creating ROIs for selected FOVs....');
    
    
    %reverseStr = '';
    for j=1:numel(out)
        
        existingROI=numel(obj.fov(out(j).fovid).roi);
        
        if existingROI==1
            if numel(obj.fov(out(j).fovid).roi(1).id)==0
                existingROI=0;
            end
        end
        
        
        if existingROI>0
            
            %  prompt=['There are ' num2str(existingROI) ' already existing ROIs in FOV ' obj.fov(out(j).fovid).id '. Delete (Y/N) [Y] ?'];
            
            %   str= input(prompt,'s');
            %  if isempty(str)
            %      str='Y';
            %  end
            
            if ~keepexisting %strcmp(str,'Y')
                obj.fov(out(j).fovid).removeROI(1:numel(obj.fov(out(j).fovid).roi));
            end
            
        end
        
        for i=1:size(out(j).scaled,1)
            
            % j,i
            %  aa=out(j).scaled(i,:)
            
            %    obj.fov(out(j).fovid).addROI(out(j).scaled(i,:),j);
            
            obj.fov(out(j).fovid).addROI(out(j).scaled(i,:), obj.fov(out(j).fovid).id);
            
            %   msg = sprintf('%d / %d Traps created', i , size(positions,1) ); %Don't forget this semicolon
            %   fprintf([reverseStr, msg]);
            %   reverseStr = repmat(sprintf('\b'), 1, length(msg));
            
        end
    end
end
end

function [positions scores]=findTraps(img,pattern,thr)

% position provides the list of boundaries for the traps
%img = rgb2gray(img);

c = normxcorr2(pattern,img);

%figure, imshow(img)
%figure, surf(c), shading flat

%thr=0.5; % threshold for detected peaks

BW = im2bw(c,thr);

pp = regionprops(BW,'centroid');
pos = round(cat(1, pp.Centroid));

orien=imrotate(img,180);
c2 = normxcorr2(pattern,orien);

BW = im2bw(c2,thr);
BW=imrotate(BW,180);

pp = regionprops(BW,'centroid');
pos2 = round(cat(1, pp.Centroid));

pos=[pos ; pos2];

%    [tmppos2 scores2]=findTraps(orien,obj.processing.roi.pattern,thr);
%    tmppos=[tmppos; tmppos2];
%    scores=[scores scores2]; % HERE 
   
%positions=fliplr(positions);

%positions=zeros(1,4);
%scores=0;
positions=[];
scores=[];
%positions.minex=[];
%positions.maxex=[];
%positions.miney=[];
%positions.maxey=[];

cc=1;
%figure;

%size(img)
for ex=1:size(pos,1)
    
    minex=pos(ex,2)-size(pattern,1);
    maxex=pos(ex,2);
    miney=pos(ex,1)-size(pattern,2);
    maxey=pos(ex,1);
    
    if minex<1
        continue
    end
    if miney<1
        continue
    end
    if maxex>size(img,2)
        continue
    end
    if maxey>size(img,1)
        continue
    end
    
    positions(cc,1)=minex;
    positions(cc,3)=miney;
    positions(cc,2)=maxex;
    positions(cc,4)=maxey;
    
    scores(cc)=c(pos(ex,2),pos(ex,1)); % computing scores 
    
    
    %imgout=img(minex:maxex,miney:maxey);
    %imshow(imgout,[]);
    %title(num2str(ex));
    %pause(0.1);
    %close
    
    cc=cc+1;
end
end

%
% function tform=registerImages(ref,test)
%
%   [optimizer, metric] = imregconfig('monomodal');
% %    optimizer.InitialRadius = 0.01;
% %  optimizer.Epsilon = 1.5e-4;
% %  optimizer.GrowthFactor = 1.05;
% %  optimizer.MaximumIterations = 1000;
%
% %size(img8)
%
%  tform=imregtform(test,ref,'translation',optimizer,metric);
% end
