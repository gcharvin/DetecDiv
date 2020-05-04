function trackObjects(obj,channelstr)


channelID=obj.findChannelID(channelstr);



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


% initializes tracker

tracker=trackerTOMHT; %('FilterInitializationFcn',@initcvekf);
%tracker=trackerGNN;

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
      
      if numel(pos)>0 % if there is an avaiable track for this time 
          
          for j=1:size(pos,1) % loops on track
            
          val=l(round(pos(j,1)),round(pos(j,2))); %object corresponding to track
          
          if val>0 % track is located onto an actual object
              testim=l==val;
              
              %class(tracks(j).TrackID+1)
              %class(testim)
              testim=uint32(testim).*(tracks(j).TrackID+1); % assign the number of track to object+1 , because value corresponds to untracked objects;
             % i
             
            % max(testim(:))
             % figure, imshow(testim,[]);
             % return;
              
              obj.image(:,:,pixresults,i)=uint16(testim);
          end
          end
          
          
      end
     
%     [vel,~] = getTrackVelocities(tracks,[0 1 0 0 0 0;0 0 0 1 0 0;0 0 0 0 0 1]);
%     labels = arrayfun(@(x)num2str(x.TrackID),tracks,'UniformOutput',false);
%     trackP.plotTrack(pos,vel,cov,labels);

    cc=cc+1;
    end
    
end

%tracksid
fprintf('\n')


%[trackSummary, truthSummary, trackMetrics, truthMetrics,timeGNNCV] = helperRunTracker(dataLog,tracker,false);

fprintf('\n')


function [trackSummary, truthSummary, trackMetrics, truthMetrics, time] = helperRunTracker(dataLog,tracker,showTruth)
%helperRunTracker  Run the tracker and collect track metrics
% [trackSummary, truthSummary, trackMetrics, truthMetrics, time] =
% helperRunTracker(dataLog,tracker,showTruth) runs the tracker on the
% detections logged in dataLog.
%
% tracker must be either a trackerGNN, a trackerJPDA or a trackerTOMHT object.
% showTruth is a logical flag. If set to true, the display will show the
% ground truth of the targets at the end of the run.

%   Copyright 2018-2019 The MathWorks, Inc.

validateattributes(tracker,{'trackerGNN','trackerTOMHT','trackerJPDA','numeric'},{},mfilename,'tracker');
trackerType = class(tracker);
trackerType = trackerType(8:end);
filterType = func2str(tracker.FilterInitializationFcn);
filterType = filterType(5:end-6);
filterType='';
plotTitle = ['Tracker: ',trackerType,'. Model: ',filterType];

%% Create Display
% Create a display to show the true, measured, and tracked positions of the
% airliners.
hfig = figure;
hfig.Position = [614   365   631   529];
hfig.Visible = 'on';
hfig.Color = [1 1 1];
tpaxes = axes(hfig);
grid(tpaxes,'on')
title(tpaxes,plotTitle);
tp = theaterPlot('Parent',tpaxes,'AxesUnits',["km" "km" "km"],'XLimits',[-2000 2000], 'YLimits',[-20500 -17000]);
trackP = trackPlotter(tp,'DisplayName','Tracks','HistoryDepth',100,'ColorizeHistory','on','ConnectHistory','on');
detectionP = detectionPlotter(tp,'DisplayName','Detections','MarkerSize',6,'MarkerFaceColor',[0.85 0.325 0.098],'MarkerEdgeColor','k','History',1000);
hfig.Children(1).Location = "northeast";

%% Track Metrics
% Use the trackAssignmentMetrics and the trackErrorMetrics to capture
% assignment and tracking error values.
tam = trackAssignmentMetrics('AssignmentThreshold', 3, 'DivergenceThreshold', 5);
tem = trackErrorMetrics;

%% Run the tracker
time = 0;
numSteps = numel(dataLog.Time);
i = 0;
while i < numSteps && ishghandle(hfig)
    i = i + 1;
    
    % Current simulation time
    simTime = dataLog.Time(i);
    
    scanBuffer = dataLog.Detections{i};
    
    % Update tracker
    tic
    tracks = tracker(scanBuffer,simTime);
    time = time+toc;
    
    % Target poses in the radar's coordinate frame
%    targets = dataLog.Truth(:,i);
    
    % Update track assignment metrics
%    step(tam, tracks, targets);
    
    % Update track error metrics
%    [trackIDs,truthIDs] = currentAssignment(tam);
%    tem(tracks,trackIDs,targets,truthIDs);
    
    % Update display with current beam position, buffered detections, and
    % track positions
    allDets = [scanBuffer{:}];
    meas = cat(2,allDets.Measurement);
    measCov = cat(3,allDets.MeasurementNoise);
    detectionP.plotDetection(meas',measCov);
    
    [pos,cov] = getTrackPositions(tracks,[1 0 0 0 0 0;0 0 1 0 0 0;0 0 0 0 1 0]);
    [vel,~] = getTrackVelocities(tracks,[0 1 0 0 0 0;0 0 0 1 0 0;0 0 0 0 0 1]);
    labels = arrayfun(@(x)num2str(x.TrackID),tracks,'UniformOutput',false);
    trackP.plotTrack(pos,vel,cov,labels);
       
    drawnow
end

if showTruth
    trajectoryP = trajectoryPlotter(tp,'DisplayName','Trajectory');
    trajPos{1} = vertcat(dataLog.Truth(1,:).Position);
    trajPos{2} = vertcat(dataLog.Truth(2,:).Position);
    trajectoryP.plotTrajectory(trajPos);
end
trackSummary = trackMetricsTable(tam);
truthSummary = truthMetricsTable(tam);
trackMetrics = [];%cumulativeTrackMetrics(tem);
truthMetrics = [];%cumulativeTruthMetrics(tem);
trVarsToRemove = {'DivergenceCount','DeletionStatus','DeletionLength','DivergenceLength','RedundancyStatus','RedundancyCount'...
    ,'RedundancyLength','FalseTrackLength','FalseTrackStatus','SwapCount'};
trackSummary = removevars(trackSummary,trVarsToRemove);
tuVarsToRemove = {'DeletionStatus','BreakStatus','BreakLength','InCoverageArea','EstablishmentStatus'};
truthSummary = removevars(truthSummary,tuVarsToRemove);

