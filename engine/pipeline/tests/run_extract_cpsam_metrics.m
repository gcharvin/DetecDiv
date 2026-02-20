% run_extract_cpsam_metrics.m
% Minimal smoke script: extract -> CPSAM -> metrics on 1 ROI.
% Requires a shallow project with ROIs and a CPSAM classifier + metrics processor.

% ---- USER CONFIG ----
project = []; % set to your shallow project variable
fovIndex = 1;
roiIndex = 1;
cpsamIndex = 1;   % index in project.processing.classification
metricsIndex = 1; % index in project.processing.processor
frames = [];      % optional, e.g. 1:50
channels = {};    % optional channel names for extraction

% ---- VALIDATION ----
if isempty(project) || ~isa(project, 'shallow')
    error('Set "project" to a valid shallow object before running this script.');
end

% ---- EXTRACT ROI CROPS ----
args = {'FOVIndex', fovIndex, 'ROI', roiIndex};
if ~isempty(frames)
    args = [args {'Frames', frames}];
end
if ~isempty(channels)
    args = [args {'Channels', channels}];
end
project.extractAllROICrops(args{:});

% ---- LOAD ROI ----
roiObj = project.fov(fovIndex).roi(roiIndex);
if isempty(roiObj.image)
    roiObj.load;
end

% ---- CPSAM SEGMENTATION ----
classif = project.processing.classification(cpsamIndex);
classArgs = {'OutputName', 'cpsam_v1'};
if ~isempty(frames)
    classArgs = [classArgs {'Frames', frames}];
end
classifyData(classif, roiObj, classArgs{:});

% ---- METRICS ----
proc = project.processing.processor(metricsIndex);
procArgs = {};
if ~isempty(frames)
    procArgs = {'Frames', frames};
end
processData(proc, roiObj, procArgs{:});

disp('extract -> cpsam -> metrics done');
