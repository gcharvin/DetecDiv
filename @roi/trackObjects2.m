function objout=trackObjects2(obj,channelstr,inputchannelstr,frames,classiid,classifier)

% trackObjects used object apearance as a criterai for matching in the
% distance matrix

% treackObjet2 uses a purely classifiaction-based method to compute the
% likelyhood of associtation between two cells on consecutive images 

% distance is taken into account as well. a threshold on distance is
% calculated

% channelstr: segmented objects channel
% input image channel 

display=0;

channelID=obj.findChannelID(channelstr);

if numel(channelID)==0 % this channel contains the segmented objects
   disp([' This channel ' channelstr ' does not exist ! Quitting ...']) ;
   return;
end

inputchannelID=obj.findChannelID(inputchannelstr);

if numel(inputchannelID)==0 % this channel contains the raw images used to segment objects or to characterize the object
   disp([' This channel ' inputchannelstr ' does not exist ! Quitting ...']) ;
   return;
end

if numel(obj.image)==0
    obj.load
end
if numel(obj.image)==0
  disp('Could not load images, check your network connection ... quitting !') ;
  return;
end

im=obj.image(:,:,channelID,:);

rawim=obj.image(:,:,inputchannelID,:);

totphc=rawim;
meanphc=0.5*double(mean(totphc(:)));
maxphc=double(meanphc+0.5*(max(totphc(:))-meanphc));


if nargin<4
    frames=1:size(im,4);
end

if numel(frames)==0
   frames=1:size(im,4);  
end


if nargin<6
    disp('Loading classifier....')
    % loading the classifier // not recommende because it takes time
    classif=obj.processing.classification(classiid);
    path=classif.path;
    name=classif.strid;
    str=[path '/' name '.mat'];
    load(str); % load classifier
end
% classify new images
    

%creates an output channel to update results
pixresults=findChannelID(obj,['track_' channelstr]);

if numel(pixresults)>0
%pixresults=find(roiobj.channelid==cc); % find channels corresponding to trained data

obj.image(:,:,pixresults,:)=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
   % add channel is necessary 
   matrix=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   rgb=[1 1 1];
   intensity=[0 0 0];
   pixresults=size(obj.image,3)+1;
   obj.addChannel(matrix,['track_' channelstr],rgb,intensity);
end

% calculate the mean object size during the movie
area=[];

disp('Computing mean cell size in mo....')
for i=1:size(im,4)
   
    stats=regionprops(im(:,:,1,i)>0,'Area');
    tmp=[stats.Area];
   % size(tmp)
    area=[area; tmp'];
end

area=area';
areamean=mean(area);
distancemean=2*sqrt(areamean)*2/pi;

% typical cell size in movie x 2 

%

% inititialization 

%figure, imshow(im(:,:,1,frames(1)),[])


imref=bwlabel(im(:,:,1,frames(1)));



imrefraw=rawim(:,:,1,frames(1));

%figure, imshow(imrefraw,[])

imrefraw = double(imadjust(imrefraw,[meanphc/65535 maxphc/65535],[0 1]))/256;
imrefraw=uint8(imrefraw);

%figure, imshow(imrefraw,[])
%return;

obj.image(:,:,pixresults,frames(1))=imref;
%rawim(:,:,1,frames(1);

cellsref=getCells(imref);%,rawim(:,:,1,frames(1)),meanphc,maxphc);

%cellsref
%return;

% display
if display==1
   figure; 
   for i=1:numel(cellsref)
      line(cellsref(i).ox,-cellsref(i).oy,'LineStyle','none','Marker','.','MarkerSize',40,'Color','b'); 
      text(cellsref(i).ox,-0.5*cellsref(i).oy,num2str(i),'Color','b');
   end
end
    
% loop on frames
for i=frames(1)+1:frames(end) % loop on all frames
    
    imtest=im(:,:,1,i);
    
    imtestraw=rawim(:,:,1,i);
    imtestraw = double(imadjust(imtestraw,[meanphc/65535 maxphc/65535],[0 1]))/256;
    imtestraw=uint8(imtestraw);

    [ltest,ntest]=bwlabel(imtest);
    
    cellstest=getCells(ltest);%,obj.image(:,:,inputchannelID,i));%,meanphc,maxphc);
    
    if display==1
   
   for j=1:numel(cellstest)
      line(cellstest(j).ox,-cellstest(j).oy,'LineStyle','none','Marker','.','MarkerSize',35,'Color','r'); 
       text(cellstest(j).ox,-0.5*cellstest(j).oy,num2str(j),'Color','r');
      
   end
   
   
    end

    
    cellsrefstore=cellsref;
    
    [cellsref,cost]=hungarianTracker(cellsref,cellstest,imrefraw,imtestraw,distancemean,classifier);
   % cost
    %imref
    
    imrefraw=imtestraw;
    
    if display==1
    for j=1:numel(cellsrefstore)
        for k=1:numel(cellstest)
            if ~isinf(cost(j,k))
        line([cellsrefstore(j).ox cellstest(k).ox],[-cellsrefstore(j).oy -cellstest(k).oy],'Color','k');
        
        text(0.5*(cellsrefstore(j).ox+cellstest(k).ox),-0.5*(cellsrefstore(j).oy+cellstest(k).oy),num2str(double(round(1000*cost(j,k))/1000)),'FontSize',20);
            end
        end
    end
    end
   % disp([cellstest.n]);
    
    %disp('ok')
   % disp([cellsref.n]); 
    
    bw=uint16(zeros(size(imref,1),size(imref,2)));
    
    for j=1:ntest
       pix=ltest==j;
       bw(pix)=cellsref(j).n;
    end

    obj.image(:,:,pixresults,i)=bw;
  
fprintf('.');
end
fprintf('\n');

objout=obj;

disp('Tracking done !');


function cells=getCells(l)%,rawimage,meanphc,maxphc)
% create cell structure from image

% here 

r=regionprops(l,'Centroid','Area','BoundingBox');

cells=struct('ox',[],'oy',[],'area',[],'n',[],'ac',[]);

%inputSize = classifier.Layers(1).InputSize(1:2);

%layerName = "pool5-7x7_s1"; % googlenet;
%layerName = "avg_pool"; %resnet50 or inceptionresnetv2
%layerName = "pool5"; %resnet101

%layerName="prob";

%rawimage=repmat(rawimage,[1 1 3]);
%rawimage = double(imadjust(rawimage,[meanphc/65535 maxphc/65535],[0 1]))/256;

for i=1:max(l(:))
    
    cells(i).ox=r(i).Centroid(1);
    cells(i).oy=r(i).Centroid(2);
    cells(i).area=r(i).Area;
    cells(i).n=i;%round(mean(l==i));
    
    tmp=round(r(i).BoundingBox);
    
    %meanphc,maxphc,max(rawimage(:))
    
    cells(i).bw=l==i;
    
%     offset=10;%5
%     %figure, imshow(rawimage,[]);
%     bw=imdilate(l==i,strel('Disk',offset));
%     %bw=l==i;
%     imtmp=rawimage;
%     imtmp(~bw)=0;
%     
%     minex=max(1,tmp(2)-offset);
%     maxex=min(size(imtmp,1),tmp(2)+tmp(4)-1+offset);
%     
%     miney=max(1,tmp(1)-offset);
%     maxey=min(size(imtmp,2),tmp(1)+tmp(3)-1+offset);
%     
%     im=imtmp(minex:maxex,miney:maxey);
    
    % figure, imshow(im,[]);
     
    % max(im(:))
%     nsize=100;
%     imout=uint8(zeros(nsize,nsize));
%     % adjust all cell masks into a 100x100 mask to preserve the respective
%     % sizes of images
%     % resize im if odd numbers
%     siz=size(im);
%     im=imresize(im,[siz(1) + mod(siz(1),2) , siz(2) + mod(siz(2),2)]);
%     
%     %size(im)
%     arrx=nsize/2-size(im,1)/2:nsize/2+size(im,1)/2-1;
%     arry=nsize/2-size(im,2)/2:nsize/2+size(im,2)/2-1;
%     imout(arrx,arry)=im;
%     im=imout;

    % adjust the image to fit the network input size (224 x 224 x 3for
    % goooglenet)
    
    %figure, imshow(im,[]);
    
    %im=repmat(im,[1 1 3]);
    %im=imresize(im,inputSize);

    % figure, imshow(im,[]);
    %pause
    
    %cells(i).ac = activations(net,im,layerName,'OutputAs','rows');
    % HERE : take an image of the same size for each cell to be able to compare for different sizes
    % of images , like 224 x 224
   % sum(cells(i).ac)
end




function [newcell,cost]=hungarianTracker(cell0,cell1,iminput0,iminput1,meancellsize,classifier)

% this function performs the tracking of cell contours based on an
% assignment cost matrix and the Hungarian method for assignment

OK=0;
newcell=[];
   
param=struct('cellsize',70,'cellshrink',1,'coefdist',0,'coefsize',1,'filterpos',0);
  
newcell=param;

lastObjectNumber=max([cell0.n]);

% buld weight matrix based on distance and size

%a=[cell0.ox]
n0=length(find([cell0.ox]~=0));
n1=length(find([cell1.ox]~=0));

M=Inf*ones(n0,n1);

vec=[];

ind0=find([cell0.ox]~=0);
ind1=find([cell1.ox]~=0);

display=0;

thr=2;

%areamean=mean([cell0.area]);
%meancellsize=30; % pixels sqrt(areamean/pi);
%thr*meancellsize

%weigth=10;

for i=1:length(ind0)
    
    id=ind0(i);
    
         % anticipate cell motion using previously calculated cell velocity
        % over the last n frames (n=1?)
  
    for j=1:length(ind1)
       
        %if cell1(j).ox==0
        %    continue
        %end
        jd=ind1(j);
        
        % calculate distance between cells
        %sqdist=(cell0(id).ox+cell0(id).vx-cell1(jd).ox)^2+(cell0(id).oy+cell0(id).vy-cell1(jd).oy)^2;
        
        sqdist=(cell0(id).ox-cell1(jd).ox)^2+(cell0(id).oy-cell1(jd).oy)^2;
        
        dist=sqrt(sqdist)./(meancellsize);
        
        %i,j
        codist=pdist([cell0(id).ac;cell1(jd).ac], 'cosine');
        
        if dist > thr %sqrt(sqdist)>param.cellsize % 70 % impossible to join cells that are further than 70 pixels
            continue;
        end
        % HERE : see if dist can be replaced by codist for the threshold

        %M(i,j)= codist*dist;
       % i,j
       % M(i,j)=(param.coefdist*dist+param.coefsize*codist);%+param.coefsize*abs(sizedist)/(areamean));
        [cost imout]=trackingComputeCost(iminput0,iminput1,cell0(id).bw,cell1(jd).bw,classifier,thr*meancellsize);
      % |
      
     % cost 
      
%         if i==4 & j==11
%            % figure, imshow(imout); 
%            % i,j,cost
%             title([num2str(i) ' - ' num2str(j) ' - ' num2str(-log(double(cost)))]);
%         end 
    
        M(i,j)=dist + (1-cost);%-log(cost); % take the loglikelyhood of the probability 
        
        %param.coefdist*dist+param.coefsize*codist;
    end
   
end



[Matching,~] = Hungarian(M);

%Matching

[row,col] = find(Matching);

row=ind0(row);
col=ind1(col);

vec=[row' col'];

ind0=[cell0.n];
ind1=[cell1.n];

%row,max(row)

row2=ind0(row);
col2=ind1(col);

vec2=[row2' col2'];

lostcells=setdiff(ind0(find(ind0)),row2);

vec2=[vec2 ; [lostcells' zeros(length(lostcells),1)]];

newcells=setdiff(ind1(find(ind1)),col2);

vec2=[vec2 ; [zeros(length(newcells),1) newcells']];

newcell=cell1;

%count=max(mapOut(:,2));
%a=[segmentation.cells1.n];
count=lastObjectNumber;

for i=1:length(newcell)
   
   if newcell(i).ox~=0
   ind=newcell(i).n;
   %a=vec(:,2)
   ind=find(vec2(:,2)==ind);
   ind=ind(1);
   
   if vec2(ind,1)~=0
       %vec2(ind,1)
       newcell(i).n=vec2(ind,1);
      % newcell(i).vx=newcell(i).ox-cell0(vec(ind,1)).ox;
      % newcell(i).vy=newcell(i).oy-cell0(vec(ind,1)).oy;
   else
       newcell(i).n=count+1;
       
       count=count+1;
   end
   end
end

cost=M;

OK=1;

% if display
% 
% figure;
% 
% for i=1:length(cell0)
%     if cell0(i).ox~=0
%         line(cell0(i).x,cell0(i).y,'Color','r'); hold on
%         text(cell0(i).ox,cell0(i).oy,num2str(cell0(i).n),'Color','r'); hold on;
%         
%         line(cell0(i).x+cell0(i).vx,cell0(i).y+cell0(i).vy,'Color','m'); 
%        % text(cell0(i).ox,cell0(i).oy,num2str(cell0(i).n),'Color','r');
%         
%         hold on;
%     end
% end
% 
% for i=1:length(cell1)
%     if cell1(i).ox~=0
%         line(cell1(i).x,cell1(i).y,'Color','b'); hold on;
%         text(cell1(i).ox,cell1(i).oy,num2str(cell1(i).n),'Color','b');
%         hold on;
%     end
% end
% 
% for i=1:numel(vec(:,1))
%     line([cell0(vec(i,1)).ox cell1(vec(i,2)).ox],[cell0(vec(i,1)).oy cell1(vec(i,2)).oy],'Color','g');
% end
% 
% axis equal tight
% 
% end




function objout=smartTracker(obj,im)

% im the image with all present objects
% initializes tracker

%tracker=trackerTOMHT; %('FilterInitializationFcn',@initcvekf);
tracker=trackerGNN;
% tracker=trackerJPDA(...
%     'MaxNumTracks', 50, ...
%     'MaxNumSensors', 1, ...
%     'AssignmentThreshold',20, ...
%     'TrackLogic','Integrated',...
%     'DetectionProbability', 0.95); %'MaxNumTracks',100);

% dataLog=[];
% dataLog.Time=[];
% dataLog.Detections={};

cc=1;

% hfig = figure;
% hfig.Position = [614   365   631   529];
% hfig.Visible = 'on';
% hfig.Color = [1 1 1];
% tpaxes = axes(hfig);

 %title(tpaxes,plotTitle);
%      tp = theaterPlot('Parent',tpaxes,'AxesUnits',["m" "m" "m"],'XLimits',[40 90 ], 'YLimits',[40 90]);
% trackP = trackPlotter(tp,'DisplayName','Tracks','HistoryDepth',100,'ColorizeHistory','on','ConnectHistory','on');
% detectionP = detectionPlotter(tp,'DisplayName','Detections','MarkerSize',6,'MarkerFaceColor',[0.85 0.325 0.098],'MarkerEdgeColor','k','History',1000);
%     
%alltracks={};

%tracksid=[];

for i=1:size(im,4)
    fprintf('.');
    
    l=bwlabel(im(:,:,1,i));
    
    %figure, imshow(l,[])
    p=regionprops(l,'Centroid');
    n=numel(p);
    
    if n>0 % objects are present
    
    dataLog.Time(cc)=i;
    
    
    tmp={};
    for k=1:n
      % k,p
      % x=p(k).Centroid(1)
       test=objectDetection(i,[p(k).Centroid(1); p(k).Centroid(2); 0]);
       tmp{end+1}=test;
    end
    
   % dataLog.Detections{cc}=tmp;
    
    [tracks, ~, ~, analysis] = tracker(tmp,i); % updates tracker with new detection
    
%      if i==24
%         tracks
%         analysis
%     end
%     if i==25
%         tracks
%         analysis
%     end

  %  tracks
    
%     for k=1:numel(tracks)
%        tracksid=unique([tracksid tracks(k).TrackID]);
%     end
    
   % alltracks{cc}={analysis};
    
%     scanBuffer = dataLog.Detections{cc};
%     allDets = [scanBuffer{:}];
%     meas = cat(2,allDets.Measurement);
%     measCov = cat(3,allDets.MeasurementNoise);
%     detectionP.plotDetection(meas',measCov);
%     
%     
     [pos,cov] = getTrackPositions(tracks,[1 0 0 0 0 0;0 0 1 0 0 0;0 0 0 0 1 0]);
     %pos
      
      if numel(pos)>0 % if there is an avaiable track for this time 
          
          obj.image(:,:,pixresults,i)=0;
          for j=1:size(pos,1) % loops on track
            
          val=l(round(pos(j,2)),round(pos(j,1)));
          %object corresponding to track
          
          if val>0 % track is located onto an actual object
              testim=l==val;
              
              %class(tracks(j).TrackID+1)
              %class(testim)
              testim=uint32(testim).*(tracks(j).TrackID+1); % assign the number of track to object+1 , because value corresponds to untracked objects;
             % i
             
            % max(testim(:))
             % figure, imshow(testim,[]);
             % return;
              
              obj.image(:,:,pixresults,i)=obj.image(:,:,pixresults,i)+uint16(testim);
              
          end
        %  obj.image(round(pos(j,2))-1:round(pos(j,2))+1,round(pos(j,1))-1:round(pos(j,1))+1,pixresults,i)=4;
        %  to dispay the trajectory on the resulting image
          end
          
          
      end
     
%     [vel,~] = getTrackVelocities(tracks,[0 1 0 0 0 0;0 0 0 1 0 0;0 0 0 0 0 1]);
%     labels = arrayfun(@(x)num2str(x.TrackID),tracks,'UniformOutput',false);
%     trackP.plotTrack(pos,vel,cov,labels);

    cc=cc+1;
    end
    
end

objout=obj;

%tracksid
fprintf('\n')


%[trackSummary, truthSummary, trackMetrics, truthMetrics,timeGNNCV] = helperRunTracker(dataLog,tracker,false);



% function [trackSummary, truthSummary, trackMetrics, truthMetrics, time] = helperRunTracker(dataLog,tracker,showTruth)
% %helperRunTracker  Run the tracker and collect track metrics
% % [trackSummary, truthSummary, trackMetrics, truthMetrics, time] =
% % helperRunTracker(dataLog,tracker,showTruth) runs the tracker on the
% % detections logged in dataLog.
% %
% % tracker must be either a trackerGNN, a trackerJPDA or a trackerTOMHT object.
% % showTruth is a logical flag. If set to true, the display will show the
% % ground truth of the targets at the end of the run.
% 
% %   Copyright 2018-2019 The MathWorks, Inc.
% 
% validateattributes(tracker,{'trackerGNN','trackerTOMHT','trackerJPDA','numeric'},{},mfilename,'tracker');
% trackerType = class(tracker);
% trackerType = trackerType(8:end);
% filterType = func2str(tracker.FilterInitializationFcn);
% filterType = filterType(5:end-6);
% filterType='';
% plotTitle = ['Tracker: ',trackerType,'. Model: ',filterType];
% 
% %% Create Display
% % Create a display to show the true, measured, and tracked positions of the
% % airliners.
% hfig = figure;
% hfig.Position = [614   365   631   529];
% hfig.Visible = 'on';
% hfig.Color = [1 1 1];
% tpaxes = axes(hfig);
% grid(tpaxes,'on')
% title(tpaxes,plotTitle);
% tp = theaterPlot('Parent',tpaxes,'AxesUnits',["km" "km" "km"],'XLimits',[-2000 2000], 'YLimits',[-20500 -17000]);
% trackP = trackPlotter(tp,'DisplayName','Tracks','HistoryDepth',100,'ColorizeHistory','on','ConnectHistory','on');
% detectionP = detectionPlotter(tp,'DisplayName','Detections','MarkerSize',6,'MarkerFaceColor',[0.85 0.325 0.098],'MarkerEdgeColor','k','History',1000);
% hfig.Children(1).Location = "northeast";
% 
% %% Track Metrics
% % Use the trackAssignmentMetrics and the trackErrorMetrics to capture
% % assignment and tracking error values.
% tam = trackAssignmentMetrics('AssignmentThreshold', 3, 'DivergenceThreshold', 5);
% tem = trackErrorMetrics;
% 
% %% Run the tracker
% time = 0;
% numSteps = numel(dataLog.Time);
% i = 0;
% while i < numSteps && ishghandle(hfig)
%     i = i + 1;
%     
%     % Current simulation time
%     simTime = dataLog.Time(i);
%     
%     scanBuffer = dataLog.Detections{i};
%     
%     % Update tracker
%     tic
%     tracks = tracker(scanBuffer,simTime);
%     time = time+toc;
%     
%     % Target poses in the radar's coordinate frame
% %    targets = dataLog.Truth(:,i);
%     
%     % Update track assignment metrics
% %    step(tam, tracks, targets);
%     
%     % Update track error metrics
% %    [trackIDs,truthIDs] = currentAssignment(tam);
% %    tem(tracks,trackIDs,targets,truthIDs);
%     
%     % Update display with current beam position, buffered detections, and
%     % track positions
%     allDets = [scanBuffer{:}];
%     meas = cat(2,allDets.Measurement);
%     measCov = cat(3,allDets.MeasurementNoise);
%     detectionP.plotDetection(meas',measCov);
%     
%     [pos,cov] = getTrackPositions(tracks,[1 0 0 0 0 0;0 0 1 0 0 0;0 0 0 0 1 0]);
%     [vel,~] = getTrackVelocities(tracks,[0 1 0 0 0 0;0 0 0 1 0 0;0 0 0 0 0 1]);
%     labels = arrayfun(@(x)num2str(x.TrackID),tracks,'UniformOutput',false);
%     trackP.plotTrack(pos,vel,cov,labels);
%        
%     drawnow
% end
% 
% if showTruth
%     trajectoryP = trajectoryPlotter(tp,'DisplayName','Trajectory');
%     trajPos{1} = vertcat(dataLog.Truth(1,:).Position);
%     trajPos{2} = vertcat(dataLog.Truth(2,:).Position);
%     trajectoryP.plotTrajectory(trajPos);
% end
% trackSummary = trackMetricsTable(tam);
% truthSummary = truthMetricsTable(tam);
% trackMetrics = [];%cumulativeTrackMetrics(tem);
% truthMetrics = [];%cumulativeTruthMetrics(tem);
% trVarsToRemove = {'DivergenceCount','DeletionStatus','DeletionLength','DivergenceLength','RedundancyStatus','RedundancyCount'...
%     ,'RedundancyLength','FalseTrackLength','FalseTrackStatus','SwapCount'};
% trackSummary = removevars(trackSummary,trVarsToRemove);
% tuVarsToRemove = {'DeletionStatus','BreakStatus','BreakLength','InCoverageArea','EstablishmentStatus'};
% truthSummary = removevars(truthSummary,tuVarsToRemove);

