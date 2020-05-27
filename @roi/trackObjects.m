function trackObjects(obj,channelstr,inputchannelstr)

% channelstr: segmented objects channel
% input image channel 

channelID=obj.findChannelID(channelstr);

if numel(channelID)==0
   disp([' This channel ' channelstr ' does not exist ! Quitting ...']) ;
end

inputchannelID=obj.findChannelID(inputchannelstr);

if numel(inputchannelID)==0
   disp([' This channel ' inputchannelstr ' does not exist ! Quitting ...']) ;
end

if numel(obj.image)==0
    obj.load
end

im=obj.image(:,:,channelID,:);

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

imref=im(:,:,1,1);
obj.image(:,:,pixresults,1)=bwlabel(imref);

net=googlenet;

cellsref=getCells(obj.image(:,:,pixresults,1),obj.image(:,:,inputchannelID,1),net);% ,im(:,:,channelID,1);
% HERE : add image information --> googlent activation vector for each cell

for i=2:20%:size(im,4) % loop on all frames
    
    imtest=im(:,:,1,i);
    [ltest,ntest]=bwlabel(imtest);
    
    cellstest=getCells(ltest,obj.image(:,:,inputchannelID,i),net);
    cellsref=hungarianTracker(cellsref,cellstest);
    
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
disp('Tracking done !');


function cells=getCells(l,rawimage,net)
% create cell structure from image


r=regionprops(l,'Centroid','Area','BoundingBox');

cells=struct('ox',[],'oy',[],'area',[],'n',[],'ac',[]);

inputSize = net.Layers(1).InputSize(1:2);
layerName = "pool5-7x7_s1";


%rawimage=repmat(rawimage,[1 1 3]);

for i=1:max(l(:))
    cells(i).ox=r(i).Centroid(1);
    cells(i).oy=r(i).Centroid(2);
    cells(i).area=r(i).Area;
    cells(i).n=i;%round(mean(l==i));
    
    tmp=round(r(i).BoundingBox);
    im=rawimage(tmp(2):tmp(2)+tmp(4)-1,tmp(1):tmp(1)+tmp(3)-1);
    im=repmat(im,[1 1 3]);
   % size(im)
    im=imresize(im,inputSize);
    %size(im)
    
    %figure, imshow(im,[]);
    cells(i).ac = activations(net,im,layerName,'OutputAs','rows');
    % HERE : take an image of the same size for each cell to be able to compare for different sizes
    % of images , like 224 x 224
   % sum(cells(i).ac)
end




function newcell=hungarianTracker(cell0,cell1)

% this function performs the tracking of cell contours based on an
% assignment cost matrix and the Hungarian method for assignment

OK=0;
newcell=[];
   
param=struct('cellsize',70,'cellshrink',1,'coefdist',0.,'coefsize',1,'filterpos',0);
  
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

%areamean=mean([cell0.area]);
meancellsize=30; % pixels sqrt(areamean/pi);


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
        
        if dist > 1 %sqrt(sqdist)>param.cellsize % 70 % impossible to join cells that are further than 70 pixels
            continue;
        end
        
        %calculate size difference
        
       % sizedist=-cell0(id).area+cell1(jd).area;
        
      
%        if param.cellshrink==0
%        if sizedist<0
%            if abs(sizedist)>0.3*cell0(id).area
%                continue
%            end
%        else
%            if abs(sizedist)>cell0(id).area
%              %  'ok'
%                continue
%            end
%        end
%        end
       
%         if cell0(id).area>pi*(param.cellsize/2)^2
%         if sizedist>pi*(param.cellsize/2)^2/2
%             continue
%         end
%         else
%         if sizedist>pi*(param.cellsize/2)^2/2
%             continue
%         end    
%         end
        
        
        % put a penalty for cells close the image edge (likely to
        % dissapear) --> requires image size
        
        %coef=0;
        
        %if  cell0(id).area<1200
        %    coef=0;
        %end
       
      %  coefdist*sqrt(sqdist)/100, coefsize*abs(sizedist)/(areamean)
       % coefdist*sqrt(sqdist)/100,coefsize*abs(sizedist)/(areamean)
       
    %   coefdist*sqrt(sqdist)/meancellsize,coefsize*abs(sizedist)/(areamean)
    
    
       % weight=1;
%        if cell0(id).oy> 700
%            weight=weight+10;
%        end
%        
%        if cell1(jd).oy> 700
%            weight=weight+10;
%        end
       
        M(i,j)=(param.coefdist*dist+param.coefsize*codist);%+param.coefsize*abs(sizedist)/(areamean));
        
    end
end

%M

[Matching,Cost] = Hungarian(M);

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

