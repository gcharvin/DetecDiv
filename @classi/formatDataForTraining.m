function output=formatDataForTraining(classif,varargin) %mov,trapsid,option)
% saves user annotated data to disk- works for Image, Pixel and LSTM
% classification

output=[];

disp('Removing previous labeled datasets from folders...This can take a very long time...');
%classif=obj.processing.classification(classiid);
category=classif.category;
category=category{1};

foldername='trainingdataset';

% remove and recreates all directoires
% mk folder to store ground user trained data


if isfolder(fullfile(classif.path,foldername))
    try
        rmdir(fullfile(classif.path,foldername), 's')
    catch
        disp('Error: did not manage to remove directory !');
    end
end


mkdir(classif.path,foldername)

rois=classif.trainingset;

Frames=[];

for i=1:numel(varargin)
    if strcmp(varargin{i},'Frames')
        
        Frames=varargin{i+1};
        
    end
end

% if nargin<3
% rois=1:numel(classif.roi);
% else
%  rois=option ;  
% end


switch category
    case {'Image','Image Regression'}
       output= formatImageTrainingSet(foldername,classif,rois);    
    case 'LSTM'
       if numel(Frames)
       output= formatLSTMTrainingSet(foldername,classif,rois,'Frames',Frames);
       else
       output= formatLSTMTrainingSet(foldername,classif,rois);     
       end
    case 'Pixel'
        % this is transient : 
       rois=1:numel(classif.roi); % takes all rois to format, only rois in trainingset will be later selected for training
       output=formatPixelTrainingSet(foldername,classif,rois);
    case 'Object'
        output=formatObjectTrainingSet(foldername,classif,rois);
    case 'Pedigree'
     %  output= formatPedigreeTrainingSet(foldername,classif,rois) ;
          output= formatDeltaPedigreeTrainingSet(foldername,classif,rois) ;
    case 'Tracking'
       output= formatTrackingTrainingSet(foldername,classif,rois) ;
    case 'Timeseries'
       output= formatTimeseriesTrainingSet(foldername,classif,rois)  ;
      case 'Delta'
       output= formatDeltaTrainingSet(foldername,classif,rois)  ;
end



