function loadROI(obj, option)
% LOADROI Robustly load image and data for a given ROI handle object.
%   loadROI(OBJ) loads both image and data files associated with the ROI.
%   loadROI(OBJ, 'data') loads only the data file.

    % Validate inputs
    narginchk(1,2);
    validOptions = {'data'};
    if nargin == 2 && ~ismember(option, validOptions)
        error('loadROI:InvalidOption', 'Unknown option "%s".', option);
    end
    resonly = (nargin == 2 && strcmp(option, 'data'));

    % Ensure path is set
    if isempty(obj.path)
        error('loadROI:NoPath', 'ROI path is empty. Extract ROI before loading.');
    end

    % Construct file paths
    imFile   = fullfile(obj.path, sprintf('im_%s.mat', obj.id));
    dataFile = fullfile(obj.path, sprintf('data_%s.mat', obj.id));

    disp(['Loading ROI : ' obj.id]);

    % Load image file if needed
    if ~resonly
        if isfile(imFile)
            try
                S = load(imFile, 'roiobj');
                % Copy roiobj properties into handle object, excluding path and id
                if isfield(S, 'roiobj')
                    setProperties(obj, S.roiobj);
                end
                % Assign image if present
                if isfield(S, 'im')
                    obj.image = S.im;
                end
                obj.log(sprintf('Loaded ROI image from %s.', imFile), 'Loading');
            catch ME
                disp(['Could not load ROI image for: ' obj.id ' (' ME.message ')']);
            end
        end
    end
    disp(['ROI: ' obj.id ' successfully loaded']);

    % Load data file
    if isfile(dataFile)
        try
            disp(['Loading ROI Data : ' obj.id]);
            S = load(dataFile, 'data');
            obj.data = S.data;
            obj.log(sprintf('Loaded ROI data from %s.', dataFile), 'Loading');
            disp(['Data from ROI: ' obj.id ' successfully loaded']);
        catch ME
            disp(['Could not load data for ROI: ' obj.id ' (' ME.message ')']);
        end
    else
        disp(['No ROI Data : ' obj.id ' available']);
    end
end

function setProperties(obj, srcObj)
% SETPROPERTIES Copy matching properties from srcObj to obj (handle), excluding critical ones
    allProps = intersect(properties(obj), properties(srcObj));
    % Exclude properties that should not be overwritten
    exclude = {'path','id'};
    props = setdiff(allProps, exclude);
    for k = 1:numel(props)
        obj.(props{k}) = srcObj.(props{k});
    end
end
