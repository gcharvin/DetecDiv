function output = formatDataForTraining(classif, varargin)
    % Saves user annotated data to disk - works for Image, Pixel, and LSTM
    % classification

    output = [];

    Frames = [];
    Keep = 0;
    rois = [];

    for i = 1:numel(varargin)
        if strcmp(varargin{i}, 'Frames')
            Frames = varargin{i + 1};
        end
        if strcmp(varargin{i}, 'Rois')
            rois = varargin{i + 1};
        end
        if strcmp(varargin{i}, 'Keep') % Keep existing images in folder
            Keep = 1;
        end
    end

    category = classif.category;
    category = category{1};
    foldername = 'trainingdataset';

    if Keep == 0
        disp('Removing previous labeled datasets from folders... This can take a very long time...');

        % Remove and recreate all directories
        if isfolder(fullfile(classif.path, foldername))
            try
                rmdir(fullfile(classif.path, foldername), 's');
            catch
                disp('Error: did not manage to remove directory!');
            end
        end

        mkdir(classif.path, foldername);
    end

    if numel(rois) == 0
        rois = classif.trainingset;
        valrois=setxor(1:numel(classif.roi),rois);
    end

    switch category
        case {'Image', 'Image Regression'}
            output = formatImageTrainingSet(foldername, classif, rois);
        case 'LSTM'
            if numel(Frames)
                output = formatLSTMTrainingSet(foldername, classif, rois, 'Frames', Frames);
            else
                output = formatLSTMTrainingSet(foldername, classif, rois);
            end
        case 'Pixel'
            if isprop(classif, 'description')
                if iscell(classif.description{1}) && strcmp(classif.description{1}{1}, 'YOLO instance segmentation')
                    output = formatPixelTrainingSetYOLO(foldername, classif, rois,valrois);
                elseif ischar(classif.description{1}) && strcmp(classif.description{1}, 'YOLO instance segmentation')
                    output = formatPixelTrainingSetYOLO(foldername, classif, rois,valrois);
                else
                    output = formatPixelTrainingSet(foldername, classif, rois);
                end
            else
                output = formatPixelTrainingSet(foldername, classif, rois);
            end
        case 'Object'
            output = formatObjectTrainingSet(foldername, classif, rois);
        case 'Pedigree'
            output = formatDeltaPedigreeTrainingSet(foldername, classif, rois);
        case 'Tracking'
            output = formatTrackingTrainingSet(foldername, classif, rois);
        case 'Timeseries'
            output = formatTimeseriesTrainingSet(foldername, classif, rois);
        case 'Delta'
            if numel(Frames)
                output = formatDeltaTrainingSet(foldername, classif, rois, 'Frames', Frames);
            else
                output = formatDeltaTrainingSet(foldername, classif, rois);
            end
        otherwise
            disp('Unknown category. No action taken.');
    end
end
