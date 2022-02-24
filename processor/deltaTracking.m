function paramout=deltaTracking(param,obj,frames)

% implements the tracking method as in the lugagne paper Delta 2.0 
% procedure 
% setup processor paramters : "add processor..." 
% training : 

% 1) requires a ground truth dataset with tracked cells to serve as
% groundturth (labeled images + rwa brightfield image)

% 2) set up a new delta teacking classifier  and train it using the ground
% truth data

% 3) run the delta tracking routine 


if nargin==0
    paramout=[];
    
    paramout.raw_channel_name='ch1--'; % raw images
    paramout.seg_channel_name='track_segcell_1'; % segmented data
    paramout.output_channel_name='track_delta'; % output channel 
    paramout.imagesize=151; 
    
  %  paramout.frames='0';
    paramout.classifier_name='delta_3';
    
    return;
else
paramout=param; 
end

display=0;

channelID=obj.findChannelID(param.seg_channel_name);

if numel(channelID)==0 % this channel contains the segmented objects
   disp([' This channel ' param.seg_channel_name ' does not exist ! Quitting ...']) ;
   return;
end

inputchannelID=obj.findChannelID(paramout.raw_channel_name);

if numel(inputchannelID)==0 % this channel contains the raw images used to segment objects or to characterize the object
   disp([' This channel ' paramout.raw_channel_name ' does not exist ! Quitting ...']) ;
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
im=im>0; % binarize cell contours

rawim=obj.image(:,:,inputchannelID,:);

totphc=rawim;
meanphc=0.5*double(mean(totphc(:)));
maxphc=double(meanphc+0.5*(max(totphc(:))-meanphc));


if frames==0
    frames=1:size(im,4);
else
    frames=frames;
end


    disp('Loading classifier....')
    
    varlist=evalin('base','who');

    ok=0;
   for i=1:numel(varlist)
                if strcmp(varlist{i},param.classifier_name)
                   ok=1;
                    break
                end
   end
    
   if ok==1
         classifier=evalin('base',param.classifier_name);
    else
        disp('This classifer is not in the workspace. Please load the classifier using the load method applied to the relevant @classi')
    end
    
%creates an output channel to update results
pixresults=findChannelID(obj,param.output_channel_name);

if numel(pixresults)>0
obj.image(:,:,pixresults,:)=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
   % add channel is necessary 
   matrix=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   rgb=[1 1 1];
   intensity=[0 0 0];
   pixresults=size(obj.image,3)+1;
   obj.addChannel(matrix,param.output_channel_name,rgb,intensity);
end

% % calculate the mean object size during the movie
% area=[];
% 
% disp('Computing mean cell size in mo....')
% for i=1:size(im,4)
%    
%     stats=regionprops(im(:,:,1,i)>0,'Area');
%     tmp=[stats.Area];
%    % size(tmp)
%     area=[area; tmp'];
% end
% 
% area=area';
% areamean=mean(area);
% distancemean=2*sqrt(areamean)*2/pi;

% typical cell size in movie x 2 
%

lref=bwlabel(im(:,:,1,frames(1)));
imrefraw=rawim(:,:,1,frames(1));

imrefraw = double(imadjust(imrefraw,[meanphc/65535 maxphc/65535],[0 1]))/256;
imrefraw=uint8(imrefraw);

obj.image(:,:,pixresults,frames(1))=lref;
%rawim(:,:,1,frames(1);

cellsref=getCells(lref);%,rawim(:,:,1,frames(1)),meanphc,maxphc);

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
    disp([ 'Processing frame ' num2str(i) '; Last frame ' num2str(frames(end))]); 
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
    
    [cellsref,cost]=hungarianTracker(cellsref,cellstest,imrefraw,imtestraw,lref,ltest,classifier,param.imagesize);
    
    %imref
    
    imrefraw=imtestraw;
    imref=imtest;
    
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

    cellsref=getCells(bw);
    lref=bw;
    obj.image(:,:,pixresults,i)=bw;
  
%fprintf('.');
end
fprintf('\n');

objout=obj;

disp('Tracking done !');


function cells=getCells(l)%,rawimage,meanphc,maxphc)
% create cell structure from image


r=regionprops(l,'Centroid','Area','BoundingBox');

cells=struct('ox',[],'oy',[],'area',[],'n',[],'ac',[]);

for i=1:max(l(:))
    
    cells(i).ox=r(i).Centroid(1);
    cells(i).oy=r(i).Centroid(2);
    cells(i).area=r(i).Area;
    cells(i).n=i;%round(mean(l==i));
   
    
  %cells(i).bw=l==i;
    
end


function [newcell,cost]=hungarianTracker(cell0,cell1,iminput0,iminput1,l0,l1,classifier,imagesize)

% this function performs the tracking of cell contours based on an
% assignment cost matrix and the Hungarian method for assignment

OK=0;
newcell=[];
   
param=struct('cellsize',70,'cellshrink',1,'coefdist',0,'coefsize',1,'filterpos',0);
  
newcell=param;

lastObjectNumber=max([cell0.n]);

% buld weight matrix based on distance and size

%a=[cell0.ox]

p0= ([cell0.ox]~=0) & ([cell0.area]~=0);
p1= ([cell1.ox]~=0) & ([cell1.area]~=0);

n0=length(find(p0));
n1=length(find(p1));

M=Inf*ones(n0,n1);

vec=[];

ind0=find(p0);
ind1=find(p1);

display=0;

thr=2;

%areamean=mean([cell0.area]);
%meancellsize=30; % pixels sqrt(areamean/pi);
%thr*meancellsize

for i=1:length(ind0)
    
    id=ind0(i);
    
    
    % M(i,j)=dist + (1-cost);%-log(cost); % take the loglikelyhood of the probability 
    
 %   tic
     vec=deltaComputeCost(iminput0,iminput1,l0,l1,classifier,id,imagesize);
  %   toc
     
     M(i,:)=vec;%-log(cost); % take the loglikelyhood of the probability 
   
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

