function loadData_load(parsedData, hprogressbar)
    %% Initialize the progress bar if provided
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0;
        hprogressbar.Message = 'Initializing...';
        drawnow;
    end

    %% Extract basic project information
    [projFolder, projFilename, ~] = fileparts(parsedData.projectPath);
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0.05;
        hprogressbar.Message = 'Extracting basic project information...';
        drawnow;
    end

    % Create the shallow project instance via shallowNew
    shallowObj = shallowNew('path', char(fullfile(projFolder, '/')), 'filename', [char(projFilename) '.mat']);
    if isempty(shallowObj)
         disp('Project creation canceled by the user.');
         return;
    end
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0.10;
        hprogressbar.Message = 'Shallow project created...';
        drawnow;
    end

    %% Build the newdata structure to provide to addData
    newdata.pos = [];
    nPos = numel(parsedData.positions);
    weight_positions = 0.30;  % progress portion allocated to this loop
    for i = 1:nPos
         pos = parsedData.positions(i);
         if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
             hprogressbar.Message = sprintf('Processing position %d/%d...', i, nPos);
             drawnow;
         end
         
         % Determine the number of channels for this position
         if isfield(pos, 'channelsDir') && ~isempty(pos.channelsDir)
             nChannels = numel(pos.channelsDir);
         else
             nChannels = 0;
         end
         
         newdata.pos(i).name = pos.userName;
         newdata.pos(i).contours = [];
         
         % The field pathlist: same folder repeated for each channel
         newdata.pos(i).pathlist = repmat({pos.folder}, 1, nChannels);
         
         % The field filelist: directly the cell array channelsDir
         newdata.pos(i).filelist = pos.channelsDir;
         
         % Determine channel names: if pos.userChanName is defined and consistent, use it;
         % otherwise, base it on pos.channels
         if isfield(pos, 'userChanName') && numel(pos.userChanName) == nChannels
             newdata.pos(i).channelname = pos.userChanName;
         elseif isfield(pos, 'channels') && numel(pos.channels) == nChannels
             newdata.pos(i).channelname = pos.channels;
         else
             newdata.pos(i).channelname = cell(1, nChannels);
             for j = 1:nChannels
                 newdata.pos(i).channelname{j} = sprintf('Channel %d', j-1);
                 if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                     hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: updating channel name', i, nPos, j, nChannels);
                     drawnow;
                 end
             end
         end
         
         % Calculate the number of frames for each channel
         newdata.pos(i).frames = zeros(1, nChannels);
         for j = 1:nChannels
             newdata.pos(i).frames(j) = numel(pos.channelsDir{j});
             if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                 hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: computing frames', i, nPos, j, nChannels);
                 drawnow;
             end
         end
         
         % Determine the interval (frequency)
         if isfield(pos, 'channelFrequencies') && numel(pos.channelFrequencies) >= nChannels
             newdata.pos(i).interval = pos.channelFrequencies(1:nChannels);
         else
             newdata.pos(i).interval = ones(1, nChannels);
         end
         
         % Compute binning for each channel: extract the width from pos.channelSizes and normalize
         newdata.pos(i).binning = zeros(1, nChannels);
         for j = 1:nChannels
             if isfield(pos, 'channelSizes') && numel(pos.channelSizes) >= j && ~isempty(pos.channelSizes{j})
                 dims = sscanf(pos.channelSizes{j}, '%d x %d');
                 if ~isempty(dims)
                     newdata.pos(i).binning(j) = dims(1);
                 else
                     newdata.pos(i).binning(j) = 1;
                 end
             else
                 newdata.pos(i).binning(j) = 1;
             end
             if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                 hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: computing binning', i, nPos, j, nChannels);
                 drawnow;
             end
         end
         if nChannels > 0 && newdata.pos(i).binning(1) ~= 0
             newdata.pos(i).binning = newdata.pos(i).binning ./ newdata.pos(i).binning(1);
         end
         
         % Update the progress for this position
         if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
             progressValue = 0.10 + weight_positions * (i / nPos);
             hprogressbar.Value = progressValue;
             drawnow;
         end
    end

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.45;
         hprogressbar.Message = 'Adding data to the shallow project...';
         drawnow;
    end

    %% Add data to the shallow project
    shallowObj.addData(newdata);
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.50;
         hprogressbar.Message = 'Data added to the project...';
         drawnow;
    end

    %% Add ROIs
    nFov = numel(shallowObj.fov);
    for i = 1:nFov
       if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
             hprogressbar.Message = sprintf('Adding ROIs for FOV %d/%d...', i, nFov);
             drawnow;
       end
       shallowObj.fov(i).roi = roi;
       if numel(parsedData.positions(i).roibb) == 0 % no ROI defined per position
            if numel(parsedData.roibb) == 0 % no global ROI defined, take full frame
               tmp = str2num(parsedData.positions(1).channelSizes{1});
               shallowObj.fov(i).addROI([1 1 tmp(1) tmp(2)], shallowObj.fov(i).id);
            else % full frame is subdivided or there is a single custom ROI
             for j = 1:size(parsedData.roibb, 1)
                 shallowObj.fov(i).addROI(parsedData.roibb(j, :), shallowObj.fov(i).id);
                 if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                     hprogressbar.Message = sprintf('FOV %d/%d: added ROI %d/%d', i, nFov, j, size(parsedData.roibb, 1));
                     drawnow;
                 end
             end
            end 
       else % add ROIs identified per position
            for j = 1:size(parsedData.positions(i).roibb, 1)
                 shallowObj.fov(i).addROI(parsedData.positions(i).roibb(j, :), shallowObj.fov(i).id);
                 if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                     hprogressbar.Message = sprintf('FOV %d/%d: added ROI %d/%d (position)', i, nFov, j, size(parsedData.positions(i).roibb, 1));
                     drawnow;
                 end
            end
       end
       if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
             hprogressbar.Value = 0.50 + 0.10 * (i / nFov);
             drawnow;
       end
    end
%% Extract ROI data
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.65;
    hprogressbar.Message = 'Extracting ROI data...';
    drawnow;
end

selectedPos = find([parsedData.positions.selected]);
if isempty(selectedPos)
    error('No position selected in the table.');
end

% Initialiser les cell arrays pour les frames et les channels
framesCell = {};
channelCell = {};
fovArg = [];

cc = 1;
for idx = 1:numel(selectedPos)
    i = selectedPos(idx);
    pos = parsedData.positions(i);
    % Ne traiter que les positions dont extractROI est true
    if pos.extractROI
        fovArg(end+1) = i;  %#ok<AGROW>
        
        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Extracting frames for FOV %d/%d...', cc, numel(selectedPos));
            drawnow;
        end
        if isfield(pos, 'currentMinFrame') && isfield(pos, 'currentMaxFrame') && ...
                ~isempty(pos.currentMinFrame) && ~isempty(pos.currentMaxFrame)
            framesCell{cc} = pos.currentMinFrame : pos.currentMaxFrame;
        else
            framesCell{cc} = pos.frames;
        end
        
        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Extracting channels for FOV %d/%d...', cc, numel(selectedPos));
            drawnow;
        end
        channelCell{cc} = find(pos.channelsSelected);
        
        cc = cc + 1;
    end
end


   % fovArg = selectedPos;
    if parsedData.correctdrift
         corrDrift = true;
    else
         corrDrift = false;
    end

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.70;
         hprogressbar.Message = 'Saving cropped images...';
         drawnow;
    end

    %% save parsedData in the current project
    shallowObj.parsedData=parsedData;

    
    %% Call saveCroppedImages with the constructed arguments
    if numel(fovArg)
    shallowObj.saveCroppedImages('frames', framesCell, 'fov', fovArg, 'cut', parsedData.maxframeloading, ...
        'correctdrift', corrDrift, 'cropdrift', 1, 'crashrecovery', 0, ...
        'channel', channelCell, 'scale', 1,'hprogressbar',hprogressbar);
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.80;
         hprogressbar.Message = 'Cropped images saved...';
         drawnow;
    end
    end
    

    %% Save the project
    shallowSave(shallowObj);
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.90;
         hprogressbar.Message = 'Project saved...';
         drawnow;
    end

    fullpath = fullfile(char(projFolder), [char(projFilename) '.mat']);
    disp(['Shallow project created and saved: ' fullpath]);

    %% Manage the variable in the workspace
    projName = shallowObj.io.file;
    if evalin('base', sprintf('exist(''%s'', ''var'')', projName))
         evalin('base', sprintf('clear %s', projName));
         disp(['Variable ', projName, ' already existed and has been cleared.']);
    end

    [shallowObj, msg] = shallowLoad(fullpath);
    if ~isempty(msg)
         disp(msg);
    end

    assignin('base', projName, shallowObj);

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.95;
         hprogressbar.Message = 'Loading ROIs';
         drawnow;
    end

    %% loading regions of interest 

    nroimax = parsedData.maxroidisplay;

    if nroimax==0
         if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 1.0;
         hprogressbar.Message = '';
         drawnow;
        end
        return
    end

  figures = findall(0, 'Type', 'figure');
appFigure = findobj(figures, 'Name', 'ScoreApp');

% Nombre maximum de ROIs à afficher


% Initialiser le compteur de ROIs ajoutées
roiCount = 0;

% Parcourir tous les FOV de shallowObj
for f = 1:numel(shallowObj.fov)

    if numel(find(fovArg==f))==0
        continue
    end

    currentFOV = shallowObj.fov(f);
    
    % Tester si ce FOV contient des ROIs
    if isempty(currentFOV.roi) || numel(currentFOV.roi) == 0
        continue;
    end
    
    % Parcourir chacune des ROIs de ce FOV
    for r = 1:numel(currentFOV.roi)
        roiObj = currentFOV.roi(r);
        roiCount = roiCount + 1;
        
        % Si le nombre maximum est atteint, sortir des boucles
        if roiCount > nroimax
            break;
        end
        
        % Si la figure ScoreApp n'existe pas, la créer en passant la première ROI
        if isempty(appFigure)
            appFigure = score(roiObj);
        else
            appFigure.addROI(roiObj);
        end
    end
    
    if roiCount >= nroimax
        break;
    end
end

 if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 1.0;
         hprogressbar.Message = '';
         drawnow;
    end

if roiCount == 0
    disp('Aucune ROI disponible pour l''affichage.');
    return;
end

end
