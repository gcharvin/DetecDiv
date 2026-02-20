function saveCroppedImages(obj, varargin)
% SAVECROPPEDIMAGES writes the ROIs and applies XY drift correction.
% To avoid memory issues, the extraction is performed by processing
% groups of frames (cut).
%
% Optional arguments:
%    'frames'       : list of frames to process (can be a vector or a cell array,
%                     with one element per FOV)
%    'fov'          : indices of FOVs to process
%    'cut'          : number of frames loaded at once (default 20)
%    'correctdrift' : boolean indicating if drift correction should be applied (default false)
%    'cropdrift'    : cropping factor for drift (default 1)
%    'crashrecovery': crash recovery flag (default 0)
%    'channel'      : indices of channels to process (can be a vector or a cell array,
%                     with one element per FOV)
%    'roi'          : indices of ROIs to process (vector or cell array, per FOV)
%    'scale'        : scaling factor for extraction (default 1)
%    'hprogressbar' : progress bar handle (optional)

disp('Processing raw images. Please wait....');
tic;

% Default values
frames = [];
fovid = 1:numel(obj.fov);  % Process all FOVs by default
cut = 20;
correctdrift = false;
crashrecovery = 0;
cropDrift = 1;
channels = [];
roiSelection = [];
scale = 1;
hprogressbar = [];  % optional progress bar handle

% Process varargin arguments
for i = 1:numel(varargin)
    if strcmp(varargin{i}, 'frames')
        frames = varargin{i+1};
    elseif strcmp(varargin{i}, 'fov')
        fovid = varargin{i+1};
    elseif strcmp(varargin{i}, 'cut')
        cut = varargin{i+1};
    elseif strcmp(varargin{i}, 'correctdrift')
        correctdrift = logical(varargin{i+1});
    elseif strcmp(varargin{i}, 'cropdrift')
        cropDrift = varargin{i+1};
    elseif strcmp(varargin{i}, 'crashrecovery')
        crashrecovery = varargin{i+1};
    elseif strcmp(varargin{i}, 'channel')
        channels = varargin{i+1};
    elseif strcmp(varargin{i}, 'roi')
        roiSelection = varargin{i+1};
    elseif strcmp(varargin{i}, 'scale')
        scale = varargin{i+1};
    elseif strcmp(varargin{i}, 'hprogressbar')
        hprogressbar = varargin{i+1};
    end
end

% If 'frames' is a cell array, check that it has the same number of elements as FOVs to process
if iscell(frames)
    if numel(frames) ~= numel(fovid)
        error('The ''frames'' argument is a cell array whose number of elements must equal the number of FOVs to process.');
    end
end

% If 'channel' is a cell array, check that it has the same number of elements as FOVs to process
if iscell(channels)
    if numel(channels) ~= numel(fovid)
        error('The ''channel'' argument is a cell array whose number of elements must equal the number of FOVs to process.');
    end
end

if iscell(roiSelection)
    if numel(roiSelection) ~= numel(fovid)
        error('The ''roi'' argument is a cell array whose number of elements must equal the number of FOVs to process.');
    end
end


% Create a local copy of the FOVs to process
tmpfov = obj.fov;  % working on a local copy

% Crash recovery management (code unchanged)
if crashrecovery == 1
    if exist(fullfile(userpath, 'tmpcrash.mat'), 'file')
        disp(['A crash log file exists at location: ' userpath]);
        load(fullfile(userpath, 'tmpcrash.mat'));
        fovid = tmpcrash.fovid;
        framecell = tmpcrash.framecell;
        i = tmpcrash.currentfovid;
        pix = find(fovid == i);
        fovid = fovid(pix:end);
        currentframe = tmpcrash.currentframe;
    else
        disp('I could not find any crash recovery file!');
        return;
    end
else
    currentframe = [];
end

strpath = [obj.io.path obj.io.file];

% Update the 'path' field for each FOV
for i = 1:numel(fovid)
    idx = fovid(i);
    tmpfov(idx) = obj.fov(idx);
    for j = 1:numel(obj.fov(idx).roi)
        obj.fov(idx).roi(j).path = fullfile(strpath, obj.fov(idx).id);
    end
end

shallowSave(obj);


% Loop over each selected FOV
for idfov = 1:numel(fovid)
    i = fovid(idfov);
    roiCountTotal = numel(tmpfov(i).roi);
    if roiCountTotal == 0
        disp('This FOV has no ROI! Quitting....');
        continue;
    end
    if numel(tmpfov(i).roi(1).id) == 0
        disp('This FOV has no ROI! Quitting....');
        continue;
    end
    
    % Update progress bar message if available
    if ~isempty(hprogressbar)
        hprogressbar.Message = sprintf('Processing FOV %d/%d...', idfov, numel(fovid));
        drawnow;
    end

    % Define the channels to process for this FOV
    if iscell(channels)
     
        cha = channels{idfov};  % use the corresponding element for this FOV
    elseif isempty(channels)

        cha = 1:numel(tmpfov(i).channel);
    else

        cha = channels;
    end

  
    

    % Determine which ROIs will be processed for this FOV
    if isempty(roiSelection)
        selectedIndicesForFOV = 1:roiCountTotal;
    elseif iscell(roiSelection)
        if idfov <= numel(roiSelection)
            currentSel = roiSelection{idfov};
        else
            currentSel = [];
        end
        if isempty(currentSel) || ~isnumeric(currentSel)
            selectedIndicesForFOV = [];
        else
            currentSel = currentSel(:)';
            maskSel = currentSel >= 1 & currentSel <= roiCountTotal;
            selectedIndicesForFOV = unique(currentSel(maskSel), 'stable');
        end
    elseif isnumeric(roiSelection)
        currentSel = roiSelection(:)';
        maskSel = currentSel >= 1 & currentSel <= roiCountTotal;
        selectedIndicesForFOV = unique(currentSel(maskSel), 'stable');
    else
        selectedIndicesForFOV = [];
    end

    if isempty(selectedIndicesForFOV)
        disp(['FOV ' tmpfov(i).id ': no ROI selected for extraction. Skipping this FOV.']);
        continue;
    end

    cha = unique(cha, 'stable');

    % Define the frames to process for this FOV
    if iscell(frames)
        nframes = frames{idfov};  % use the corresponding element for this FOV
    elseif isempty(frames)
        nframes = 1:numel(tmpfov(i).srclist{1}); % number of frames from the image list
    else
        nframes = frames;
    end

    % Build a cell array 'framecell' to group frames in blocks of size 'cut'
    framecell = {};
    narr = floor(numel(nframes) / cut);
    id = 1 : narr * cut;
    id = reshape(id, cut, []);
    for iii = 1:narr
        framecell{iii} = nframes(id(:, iii));
    end
    nrest = mod(numel(nframes), cut);
    if nrest > 0
        framecell{end+1} = nframes(narr*cut+1:end);
    end
    nframestot = nframes;

    % Log extraction overview for this FOV
    roiIdList = arrayfun(@(idx) tmpfov(i).roi(idx).id, selectedIndicesForFOV, 'UniformOutput', false);
    if isempty(roiIdList)
        roiIdText = 'none';
    else
        roiIdText = strjoin(roiIdList, ', ');
    end
    channelNamesUsed = arrayfun(@(k) channelDisplayName(tmpfov(i), k), cha, 'UniformOutput', false);
    if isempty(channelNamesUsed)
        channelText = 'none';
    else
        channelText = strjoin(channelNamesUsed, ', ');
    end
    frameCountLog = numel(nframestot);
    if frameCountLog > 0
        frameText = sprintf('%d frame(s) [%d..%d]', frameCountLog, nframestot(1), nframestot(end));
    else
        frameText = '0 frame(s)';
    end
    disp(sprintf('FOV %s: extracting %d ROI(s) (%s) with %s across %d channel(s) (%s).', ...
        tmpfov(i).id, numel(selectedIndicesForFOV), roiIdText, frameText, numel(cha), channelText));

    % Create a specific folder for this FOV if it does not exist
    if ~exist(fullfile(strpath, tmpfov(i).id), 'dir')
        try
            mkdir(strpath, tmpfov(i).id);
        catch
            disp(['Could not create folder: ' tmpfov(i).id ' in ' strpath '; Quitting!']);
            disp('This is an I/O CRASH: restart ROI extraction with crashrecovery mode set to 1');
            return;
        end
    end

    refframe=framecell{1}(1); %Add commentMore actions
    refframeid=refframe;

    % reading data
    try
        refimage=tmpfov(i).readImage(refframe,1);


               if ndims( refimage) == 2
        % Déjà en niveaux de gris
        img_gray = refimage;
    elseif ndims( refimage) == 3 && size( refimage, 3) == 3
        % Image RGB, conversion en niveaux de gris
        img_gray = rgb2gray(refimage);  % utilise les coefficients perceptuels
        % Alternative manuelle : moyenne simple des canaux
        % img_gray = mean(img, 3);  % mais moins fidèle à la perception visuelle
    else
       warning('Image non supportée : doit être 2D (grayscale) ou 3D avec 3 canaux (RGB)');
        end
             refimage=img_gray;

        if numel(refimage)==0
            disp(['Unable to read frame ' num2str(refframe) ' in channel ' num2str(1)]);
            disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
            dumprecovery(fovid,framecell,i,1);
            return;
        end
    catch
        disp(['Unable to read frame ' num2str(refframe) ' in channel ' num2str(1)]);
        disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
        dumprecovery(fovid,framecell,i,1);
        return;
    end

    disp('Loading raw images into memory....');
    if ~isempty(hprogressbar)
        hprogressbar.Message = sprintf('Loading raw images for FOV %s...', tmpfov(i).id);
        drawnow;
    end

    frstart = 1;
    if numel(currentframe) > 0 % crash recovery ongoing, restart from previous error
        frstart = currentframe;
        currentframe = [];
    end

    ccha = 0;
    arrcha = [];
    cccha = 1;
    for k = cha % loop on channels to determine image type
        im = tmpfov(i).readImage(1, k);

    if ndims(im) == 2
        % Déjà en niveaux de gris
        img_gray = im;
    elseif ndims(im) == 3 && size(im, 3) == 3
        % Image RGB, conversion en niveaux de gris
        img_gray = rgb2gray(im);  % utilise les coefficients perceptuels
        % Alternative manuelle : moyenne simple des canaux
        % img_gray = mean(img, 3);  % mais moins fidèle à la perception visuelle
    else
       warning('Image non supportée : doit être 2D (grayscale) ou 3D avec 3 canaux (RGB)');
        end
            im=img_gray;

        ccha = ccha + size(im, 3);
        arrcha(cccha) = size(im, 3);
        cccha = cccha + 1;
    end


    for ii = frstart:numel(framecell) % loop on all blocks of frames for a given FOV
        nframesBlock = framecell{ii};

        im = tmpfov(i).readImage(1,1);

               if ndims(im) == 2
        % Déjà en niveaux de gris
        img_gray = im;
    elseif ndims(im) == 3 && size(im, 3) == 3
        % Image RGB, conversion en niveaux de gris
        img_gray = rgb2gray(im);  % utilise les coefficients perceptuels
        % Alternative manuelle : moyenne simple des canaux
        % img_gray = mean(img, 3);  % mais moins fidèle à la perception visuelle
    else
       warning('Image non supportée : doit être 2D (grayscale) ou 3D avec 3 canaux (RGB)');
    end

            im=img_gray;

        list = uint16(zeros(size(im,1), size(im,2), ccha, numel(nframesBlock)));

        disp(['Reading group of frames: ' num2str(ii) ' / ' num2str(numel(framecell))]);
        if ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Reading group %d/%d for FOV %s...', ii, numel(framecell), tmpfov(i).id);
            drawnow;
        end

        for j = 1:numel(nframesBlock) % read all images for all channels in this block
            disp(['Reading frame: ' num2str(j) ' / ' num2str(numel(nframesBlock)) ' in group ' num2str(ii) ' / ' num2str(numel(framecell)) ' for FOV: ' num2str(tmpfov(i).id)]);
            if ~isempty(hprogressbar)
                hprogressbar.Message = sprintf('FOV %s: reading frame %d/%d in group %d/%d...', tmpfov(i).id, j, numel(nframesBlock), ii, numel(framecell));
                drawnow;
            end

            cccha = 1;
            for k = cha % loop on channels
                frame = nframesBlock(j);
                try
                    im = tmpfov(i).readImage(frame, k);


               if ndims(im) == 2
        % Déjà en niveaux de gris
        img_gray = im;
    elseif ndims(im) == 3 && size(im, 3) == 3
        % Image RGB, conversion en niveaux de gris
        img_gray = rgb2gray(im);  % utilise les coefficients perceptuels
        % Alternative manuelle : moyenne simple des canaux
        % img_gray = mean(img, 3);  % mais moins fidèle à la perception visuelle
    else
       warning('Image non supportée : doit être 2D (grayscale) ou 3D avec 3 canaux (RGB)');
        end
            im=img_gray;

                    
                    if numel(im) == 0
                        disp(['Unable to read frame ' num2str(frame) ' in channel ' num2str(k)]);
                        disp('This is an I/O CRASH: restart ROI extraction with crashrecovery mode set to 1');
                        dumprecovery(fovid, framecell, i, ii);
                        return;
                    end
                catch
                    disp(['Unable to read frame ' num2str(frame) ' in channel ' num2str(k)]);
                    disp('This is an I/O CRASH: restart ROI extraction with crashrecovery mode set to 1');
                    dumprecovery(fovid, framecell, i, ii);
                    return;
                end

                numbcha = size(im, 3);
                if tmpfov(i).display.binning(k) ~= tmpfov(i).display.binning(1)
                    im = imresize(im, tmpfov(i).display.binning(k) / tmpfov(i).display.binning(1));
                end
                list(:,:,cccha:cccha+numbcha-1, j) = im;
                cccha = cccha + numbcha;
            end
        end

        fprintf('\n');

        if correctdrift
            disp('Correcting XY drift in images...');
            if ~isempty(hprogressbar)
                hprogressbar.Message = sprintf('Correcting XY drift for position  %d/%d...', idfov, numel(fovid));
                drawnow;
            end
            method = 'circshift';
            % method = 'subpixel';
            list = tmpfov(i).computeDrift('framesid', nframesBlock, 'refframeid', refframeid, 'method', method, 'refimage', refimage, 'images', list, 'fov', i, 'crop', cropDrift); % compute drift and store in fov.drift
        end

        disp('Cropping ROIs....');
        if ~isempty(hprogressbar)
            hprogressbar.Message =  sprintf('Cropping ROIs for positions  %d/%d...', idfov, numel(fovid));
            drawnow;
        end

        reverseStr = '';

        roiCount = numel(tmpfov(i).roi);
        if roiCount == 0
            continue;
        end

        selectedIndices = selectedIndicesForFOV;
        selectedIndices = selectedIndices(selectedIndices >= 1 & selectedIndices <= roiCount);

        if isempty(selectedIndices)
            continue;
        end

        if numel(selectedIndices) > 10
            indicesPreview = sprintf('%d..%d', selectedIndices(1), selectedIndices(end));
        else
            indicesPreview = strjoin(arrayfun(@num2str, selectedIndices, 'UniformOutput', false), ',');
        end
        disp(sprintf('FOV %s: processing %d ROI index/indices (%s).', ...
            tmpfov(i).id, numel(selectedIndices), indicesPreview));

        roiMask = false(1, roiCount);
        roiMask(selectedIndices) = true;

        tmproi = roi;
        bboxCache = cell(1, roiCount);
        for l = 1:roiCount
            tmproi(l) = tmpfov(i).roi(l);
        end

               for l = selectedIndices
            fprintf('\n[DEBUG ROI %d / %s] ---- START ROI PROCESS ----\n', l, tmproi(l).id);

            tmproi(l).path = fullfile(strpath, tmpfov(i).id);
            rroi = double(tmproi(l).value);

            bboxInfo = collectTrackedBoundingBoxes(tmproi(l));
            maskChannelActive = bboxInfo.hasTracking && ~isempty(bboxInfo.labelMaskUnion) && ~isempty(bboxInfo.labelMaskFrames);

            roiChannelCount = ccha + double(maskChannelActive);

            % essayer de récupérer les frames pertinents pour une ROI trackée
            frameSequence = bboxInfo.frameIndices;
            if isempty(frameSequence)
                frameSequence = bboxInfo.labelMaskFrames;
            end

            if bboxInfo.hasTracking && (isempty(bboxInfo.frameCount) || bboxInfo.frameCount == 0)
                bboxInfo.frameCount = numel(frameSequence);
            end
            bboxCache{l} = bboxInfo;

            if bboxInfo.hasTracking
                rroi = bboxInfo.globalBox;
            end

            % cropping data
            init = 0;

            targetHeight = uint16(max(1, round(scale * rroi(4))));
            targetWidth  = uint16(max(1, round(scale * rroi(3))));

            % ----- DEBUG AVANT LOAD -----
            if isfield(tmproi(l),'display') && isstruct(tmproi(l).display) && isfield(tmproi(l).display,'intensity')
                fprintf('[DEBUG ROI %s] initial display.intensity BEFORE load:\n', tmproi(l).id);
                disp(tmproi(l).display.intensity);
            else
                fprintf('[DEBUG ROI %s] initial display.intensity BEFORE load: <none>\n', tmproi(l).id);
            end

            if ii ~= 1 % if not the first block, reload the 4D image to append data
                fprintf('[DEBUG ROI %s] BLOCK ii ~=1 (append mode)\n', tmproi(l).id);
                try
                    tmproi(l).load;
                    if numel(tmproi(l).image) == 0
                        disp(['Unable to load ROI ' num2str(l)]);
                        disp('Try to recover extraction by reloading with crash recovery set');
                        dumprecovery(fovid, framecell, i, ii);
                    end
                catch
                    disp(['Unable to load ROI ' num2str(l)]);
                    disp('Try to recover extraction by reloading with crash recovery set');
                    dumprecovery(fovid, framecell, i, ii);
                end
            else  % first block of frames, create structure
                fprintf('[DEBUG ROI %s] BLOCK ii ==1 (init / maybe first time)\n', tmproi(l).id);
                tmproi(l).load;

                if numel(tmproi(l).image) == 0
                    fprintf('[DEBUG ROI %s] image is empty -> init=1\n', tmproi(l).id);
                    init = 1;
                else
                    roivalue = double(tmproi(l).value);
                    tm = size(tmproi(l).image);
                    fprintf('[DEBUG ROI %s] loaded existing image size = [%s]\n', tmproi(l).id, num2str(tm));

                    if tm(1) ~= targetHeight || tm(2) ~= targetWidth  || tm(3) ~= roiChannelCount
                        fprintf('[DEBUG ROI %s] size mismatch -> init=1 (targetHeight=%d,targetWidth=%d,roiChannelCount=%d)\n', ...
                            tmproi(l).id, targetHeight, targetWidth, roiChannelCount);
                        init = 1;
                    else
                        fprintf('[DEBUG ROI %s] size OK -> init stays 0\n', tmproi(l).id);
                    end
                end

                if bboxInfo.hasTracking && ~isempty(frameSequence)
                    tmproi(l).display.frame = frameSequence(1);
                else
                    tmproi(l).display.frame = nframesBlock(1);
                end
                fprintf('[DEBUG ROI %s] after setting frame, display.frame = %d\n', tmproi(l).id, tmproi(l).display.frame);
            end

            % ----- DEBUG APRES LOAD AVANT INIT -----
            if isfield(tmproi(l),'display') && isstruct(tmproi(l).display) && isfield(tmproi(l).display,'intensity')
                fprintf('[DEBUG ROI %s] display.intensity AFTER load (before init block):\n', tmproi(l).id);
                disp(tmproi(l).display.intensity);
            else
                fprintf('[DEBUG ROI %s] display.intensity AFTER load (before init block): <none>\n', tmproi(l).id);
            end

            if init == 1 && ~bboxInfo.hasTracking && ~isempty(tmproi(l).image)
                % cas particulier : ROI non trackée mais image pré-existante
                currentSize = size(tmproi(l).image);
                if numel(currentSize) >= 3 && currentSize(1) == targetHeight && currentSize(2) == targetWidth && currentSize(3) > roiChannelCount
                    fprintf('[DEBUG ROI %s] init was 1 but existing image size is acceptable -> reset init=0\n', tmproi(l).id);
                    init = 0;
                end
            end

            fprintf('[DEBUG ROI %s] final init flag before big init block = %d\n', tmproi(l).id, init);

            if init == 1
                fprintf('[DEBUG ROI %s] >>> ENTER big init block\n', tmproi(l).id);

                % determine frameCapacity
                if bboxInfo.hasTracking && bboxInfo.frameCount > 0
                    frameCapacity = bboxInfo.frameCount;
                elseif bboxInfo.hasTracking && ~isempty(bboxInfo.firstFrame) && ~isempty(bboxInfo.lastFrame)
                    frameCapacity = max(1, bboxInfo.lastFrame - bboxInfo.firstFrame + 1);
                else
                    frameCapacity = numel(nframestot);
                end
                frameCapacity = max(1, frameCapacity);
                fprintf('[DEBUG ROI %s] frameCapacity=%d\n', tmproi(l).id, frameCapacity);

                tmproi(l).image = uint16(zeros(targetHeight, targetWidth, roiChannelCount, frameCapacity));

                expectedChannelCount = numel(cha) + double(maskChannelActive);
                temp = [1 1 1];

                % C'est TON critère original :
                existingDisplayValid = isfield(tmproi(l), 'display') && isstruct(tmproi(l).display) && ...
                    isfield(tmproi(l).display, 'channel') && ~isempty(tmproi(l).display.channel) && ...
                    numel(tmproi(l).display.channel) >= expectedChannelCount;

                fprintf('[DEBUG ROI %s] existingDisplayValid=%d (expectedChannelCount=%d)\n', ...
                    tmproi(l).id, existingDisplayValid, expectedChannelCount);

                if ~existingDisplayValid
                    fprintf('[DEBUG ROI %s] --- BRANCH: REBUILD DISPLAY FROM SCRATCH (this will overwrite intensity!!) ---\n', tmproi(l).id);

                    tmproi(l).display.channel = {};
                    tmproi(l).display.displaylim = [];
                    tmproi(l).channelid = [];
                    ck = 1;
                    cumck = 1;
                    for k = cha
                        if numel(tmpfov(i).channel{k}) == 0
                            tmproi(l).display.channel{ck} = ['Channel_' num2str(k)];
                        else
                            tmproi(l).display.channel{ck} = tmpfov(i).channel{k};
                        end

                        if arrcha(ck) == 1
                            tmproi(l).display.intensity(ck, :) = temp;
                            tmproi(l).channelid(ck) = ck;
                        else
                            tmproi(l).display.intensity(ck, :) = [1 1 1];
                            tmproi(l).channelid(cumck:cumck+arrcha(ck)-1) = ck * ones(1, arrcha(ck));
                        end

                        tmproi(l).display.selectedchannel(ck) = 1;
                        tmproi(l).display.alpha(ck) = 1;
                        tmproi(l).display.contour(ck) = 1;
                        tmproi(l).display.width(ck) = 1;
                        tmproi(l).display.rgb(ck, :) = temp;

                        cumck = cumck + arrcha(ck);
                        ck = ck + 1;
                    end

                    tmproi(l).display.selectedchannel = tmproi(l).display.selectedchannel(1:numel(cha));
                    tmproi(l).display.intensity = tmproi(l).display.intensity(1:numel(cha), :);
                    tmproi(l).display.rgb = tmproi(l).display.rgb(1:numel(cha), :);

                else
                    fprintf('[DEBUG ROI %s] --- BRANCH: KEEP EXISTING DISPLAY (should preserve intensity) ---\n', tmproi(l).id);

                    if ischar(tmproi(l).display.channel)
                        tmproi(l).display.channel = cellstr(tmproi(l).display.channel);
                    elseif isstring(tmproi(l).display.channel)
                        tmproi(l).display.channel = cellstr(tmproi(l).display.channel);
                    elseif iscell(tmproi(l).display.channel)
                        tmproi(l).display.channel = cellfun(@char, tmproi(l).display.channel, 'UniformOutput', false);
                    end
                end

                if isempty(tmproi(l).channelid)
                    tmproi(l).channelid = cha;
                end

                if maskChannelActive
                    fprintf('[DEBUG ROI %s] maskChannelActive = 1, trying to add label channel\n', tmproi(l).id);
                    labelName = bboxInfo.labelChannelName;
                    if isempty(labelName)
                        labelName = 'Label Mask';
                    end
                    labelName = char(labelName);
                    if ~iscell(tmproi(l).display.channel)
                        tmproi(l).display.channel = cellstr(string(tmproi(l).display.channel));
                    end
                    hasLabelChannel = any(strcmp(tmproi(l).display.channel, labelName));
                    if ~hasLabelChannel
                        fprintf('[DEBUG ROI %s] adding new label channel "%s"\n', tmproi(l).id, labelName);
                        tmproi(l).display.channel{end+1} = labelName;
                        tmproi(l).display.intensity = [tmproi(l).display.intensity; temp];
                        tmproi(l).display.selectedchannel(end+1) = 1;
                        tmproi(l).display.alpha(end+1) = 1;
                        tmproi(l).display.contour(end+1) = 0;
                        tmproi(l).display.width(end+1) = 1;
                        tmproi(l).display.rgb = [tmproi(l).display.rgb; [1 1 0]];
                        if ~isempty(bboxInfo.labelChannelIndex)
                            tmproi(l).channelid(end+1) = double(bboxInfo.labelChannelIndex);
                        else
                            tmproi(l).channelid(end+1) = roiChannelCount;
                        end
                    else
                        fprintf('[DEBUG ROI %s] label channel already present\n', tmproi(l).id);
                        labelPos = find(strcmp(tmproi(l).display.channel, labelName), 1, 'first');
                        if ~isempty(labelPos)
                            if numel(tmproi(l).display.selectedchannel) < labelPos
                                tmproi(l).display.selectedchannel(labelPos) = 1;
                            end
                            if numel(tmproi(l).display.alpha) < labelPos
                                tmproi(l).display.alpha(labelPos) = 1;
                            end
                            if numel(tmproi(l).display.contour) < labelPos
                                tmproi(l).display.contour(labelPos) = 0;
                            end
                            if numel(tmproi(l).display.width) < labelPos
                                tmproi(l).display.width(labelPos) = 1;
                            end
                            if size(tmproi(l).display.rgb, 1) < labelPos
                                tmproi(l).display.rgb(labelPos, :) = [1 1 0];
                            end
                            if numel(tmproi(l).channelid) < labelPos || tmproi(l).channelid(labelPos) == 0
                                if ~isempty(bboxInfo.labelChannelIndex)
                                    tmproi(l).channelid(labelPos) = double(bboxInfo.labelChannelIndex);
                                else
                                    tmproi(l).channelid(labelPos) = roiChannelCount;
                                end
                            end
                        end
                    end
                end

                tmproi(l).results = [];
                tmproi(l).train = [];

                fprintf('[DEBUG ROI %s] BEFORE SAVE, display.intensity is:\n', tmproi(l).id);
                disp(tmproi(l).display.intensity);

                tmproi(l).save;
                fprintf('[DEBUG ROI %s] ROI saved.\n', tmproi(l).id);
            else
                fprintf('[DEBUG ROI %s] >>> SKIP big init block (init==0)\n', tmproi(l).id);
            end

            % (le reste du code: remplissage images frame par frame etc.)
            % NOTE: on ne le change pas, on laisse ton code d'origine après ce bloc init==1

            if bboxInfo.hasTracking
                if ~isempty(frameSequence)
                    tmproi(l).display.frame = frameSequence(1);
                elseif ~isempty(bboxInfo.firstFrame)
                    tmproi(l).display.frame = bboxInfo.firstFrame;
                end
            end

            % ... PUIS on continue comme dans ta version (copie exacte) ...

            % Test ROI value
            if bboxInfo.hasTracking
                canvasHeight = max(1, round(rroi(4)));
                canvasWidth = max(1, round(rroi(3)));
                maskUnionData = bboxInfo.labelMaskUnion;
                maskFrameList = bboxInfo.labelMaskFrames;
                presenceVec = bboxInfo.presence;
                cumulativePresence = bboxInfo.cumulativePresence;

                for idxFrame = 1:numel(nframesBlock)
                    frameId = nframesBlock(idxFrame);

                    targetIndex = [];
                    if ~isempty(frameSequence)
                        idxInSeq = find(frameSequence == frameId, 1, 'first');
                        if isempty(idxInSeq)
                            continue;
                        end
                        targetIndex = idxInSeq;
                    else
                        if frameId > numel(presenceVec) || presenceVec(frameId) == 0
                            continue;
                        end
                        if frameId <= numel(cumulativePresence)
                            targetIndex = cumulativePresence(frameId);
                        end
                    end

                    if isempty(targetIndex) || targetIndex < 1 || targetIndex > size(tmproi(l).image, 4)
                        continue;
                    end

                    unionStartX = floor(rroi(1));
                    unionStartY = floor(rroi(2));
                    unionEndX = unionStartX + canvasWidth - 1;
                    unionEndY = unionStartY + canvasHeight - 1;

                    srcX1 = max(1, unionStartX);
                    srcY1 = max(1, unionStartY);
                    srcX2 = min(size(list, 2), unionEndX);
                    srcY2 = min(size(list, 1), unionEndY);

                    intensityCanvas = zeros(canvasHeight, canvasWidth, ccha, 'like', list);
                    if srcX1 <= srcX2 && srcY1 <= srcY2
                        destX1 = 1 + (srcX1 - unionStartX);
                        destY1 = 1 + (srcY1 - unionStartY);
                        destX2 = destX1 + (srcX2 - srcX1);
                        destY2 = destY1 + (srcY2 - srcY1);
                        patch = list(srcY1:srcY2, srcX1:srcX2, :, idxFrame);
                        intensityCanvas(destY1:destY2, destX1:destX2, :) = patch;
                    end

                    maskPlane = [];
                    if maskChannelActive
                        maskPlane = zeros(canvasHeight, canvasWidth, 'like', maskUnionData);
                        maskIdx = find(maskFrameList == frameId, 1, 'first');
                        if isempty(maskIdx) && ~isempty(frameSequence) && targetIndex <= numel(frameSequence)
                            maskIdx = find(maskFrameList == frameSequence(targetIndex), 1, 'first');
                        end
                        if ~isempty(maskIdx) && maskIdx <= size(maskUnionData, 3)
                            maskPlane = maskUnionData(:, :, maskIdx);
                        end
                    end

                    if scale ~= 1
                        intensityCanvas = imresize(intensityCanvas, scale);
                        if maskChannelActive
                            maskPlane = imresize(maskPlane, scale, 'nearest');
                        end
                    end

                    [frameHeightScaled, frameWidthScaled, ~] = size(intensityCanvas);
                    if frameHeightScaled ~= double(targetHeight) || frameWidthScaled ~= double(targetWidth)
                        intensityCanvas = imresize(intensityCanvas, [double(targetHeight), double(targetWidth)]);
                    end
                    if maskChannelActive
                        if isempty(maskPlane)
                            maskPlane = zeros(double(targetHeight), double(targetWidth), 'like', maskUnionData);
                        else
                            if size(maskPlane, 1) ~= double(targetHeight) || size(maskPlane, 2) ~= double(targetWidth)
                                maskPlane = imresize(maskPlane, [double(targetHeight), double(targetWidth)], 'nearest');
                            end
                        end
                    end

                    combinedCanvas = zeros(double(targetHeight), double(targetWidth), roiChannelCount, 'like', tmproi(l).image);
                    if ccha > 0
                        combinedCanvas(:, :, 1:ccha) = cast(intensityCanvas, class(tmproi(l).image));
                    end
                    if maskChannelActive
                        combinedCanvas(:, :, roiChannelCount) = cast(maskPlane, class(tmproi(l).image));
                    end

                    tmproi(l).image(:, :, :, targetIndex) = combinedCanvas;
                end
            else
                rroitmp = [];
                rroitmp(1) = max(rroi(1), 1);
                rroitmp(2) = max(rroi(2), 1);
                rroitmp(3) = min(rroi(1) + rroi(3) - 1, size(list, 2));
                rroitmp(4) = min(rroi(2) + rroi(4) - 1, size(list, 1));
                tmpfinal = list(rroitmp(2):rroitmp(4), rroitmp(1):rroitmp(3), :, :);
                if scale ~= 1
                    tmpfinal = imresize(tmpfinal, scale);
                end
                tmproi(l).image(:,:,1:ccha,nframesBlock) = tmpfinal;
            end

            try
                tmproi(l).save;
                tmproi(l).clear;
                disp(['Saved images for ROI ' tmproi(l).id ' in FOV: ' tmpfov(i).id]);
            catch
                disp(['Unable to save ROI ' num2str(l)]);
                disp('This is an I/O CRASH: restart ROI extraction with crash recovery mode set to 1');
                dumprecovery(fovid, framecell, i, ii);
            end

            fprintf('[DEBUG ROI %s] ---- END ROI PROCESS ----\n\n', tmproi(l).id);
        end

    end
    
    % Restore ROI object structure
    for l = 1:roiCount
        if roiMask(l)
            bboxInfo = bboxCache{l};
            if ~isempty(bboxInfo) && bboxInfo.hasTracking && ~isempty(bboxInfo.lastFrame)
                try
                    tmproi(l).load;
                    if isfield(bboxInfo, 'frameCount') && ~isempty(bboxInfo.frameCount) && bboxInfo.frameCount > 0
                        desiredFrames = bboxInfo.frameCount;
                    elseif ~isempty(bboxInfo.firstFrame) && ~isempty(bboxInfo.lastFrame)
                        desiredFrames = max(1, bboxInfo.lastFrame - bboxInfo.firstFrame + 1);
                    else
                        desiredFrames = size(tmproi(l).image, 4);
                    end
                    if size(tmproi(l).image,4) > desiredFrames
                        tmproi(l).image = tmproi(l).image(:,:,:,1:desiredFrames);
                        tmproi(l).save;
                    end
                catch
                    % ignore trimming errors and keep existing data
                end
                tmproi(l).clear;
            end
        end
        tmpfov(i).roi(l) = tmproi(l);
    end
end

% Restore obj structure
for i = fovid
    obj.fov(i) = tmpfov(i);
end

disp('Saving project...');
shallowSave(obj);

if exist(fullfile(userpath, 'tmpcrash.mat'), 'file') % remove temporary crash file if it exists
    disp('Removing crash log file...');
    load(fullfile(userpath, 'tmpcrash.mat'));
    delete(fullfile(userpath, 'tmpcrash.mat'));
end

toc;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function info = collectTrackedBoundingBoxes(roiObj)

    info = struct( ...
        'hasTracking',          false, ...
        'globalBox',            double(roiObj.value), ...
        'frameBoxes',           [], ...
        'frameOffsets',         [], ...
        'presence',             [], ...
        'firstFrame',           [], ...
        'lastFrame',            [], ...
        'frameIndices',         [], ...
        'frameCount',           0, ...
        'cumulativePresence',   [], ...
        'labelMaskUnion',       [], ...
        'labelMaskFrames',      [], ...
        'labelChannelIndex',    [], ...
        'labelChannelName',     '', ...
        'sourceROI',            '' ...
    );

    % Charger les dataseries si besoin
    try
        if isempty(roiObj.data) || (numel(roiObj.data) == 1 && isempty(roiObj.data(1).data))
            roiObj.load('data');
        end
    catch
        return;
    end

    if isempty(roiObj.data)
        return;
    end

    % On cherche la dataseries 'cell_presence'
    idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_presence'), roiObj.data), 1, 'first');
    if isempty(idx)
        return;
    end

    ds = roiObj.data(idx);
    if ~isstruct(ds.userData)
        return;
    end

    % Vérification que toutes les infos nécessaires sont présentes
    requiredFields = { ...
        'boundingBoxesGlobal', ...
        'boundingBoxOffsets', ...
        'boundingBoxUnionGlobal', ...
        'boundingBoxUnionRelative' ...
    };

    for k = 1:numel(requiredFields)
        if ~isfield(ds.userData, requiredFields{k})
            % si un champ critique manque, on arrête proprement
            return;
        end
    end

    % Extraction des infos principales de tracking
    frameBoxes = double(ds.userData.boundingBoxesGlobal);
    offsets    = double(ds.userData.boundingBoxOffsets);

    if isempty(frameBoxes) || size(frameBoxes,2) ~= 4
        return;
    end

    % Sécurité: offsets doit avoir au moins autant de lignes que frameBoxes
    if size(offsets,1) < size(frameBoxes,1)
        offsets(size(frameBoxes,1),2) = NaN;
    end

    % Présence de la cellule à chaque frame
    presence = all(isfinite(frameBoxes),2) & frameBoxes(:,3) > 0 & frameBoxes(:,4) > 0;

    if ~any(presence)
        % rien de vraiment tracké
        info.frameBoxes   = frameBoxes;
        info.frameOffsets = offsets;
        info.presence     = presence;
        return;
    end

    % BBox globale (union)
    unionGlobal = double(ds.userData.boundingBoxUnionGlobal);
    if numel(unionGlobal) == 4 && all(isfinite(unionGlobal))
        info.globalBox = unionGlobal;
    end

    % Liste des frames utilisées
    framesList = [];
    if isfield(ds.userData,'frames')
        framesList = double(ds.userData.frames(:)');
    end
    if isempty(framesList)
        framesList = find(presence)'; % fallback
    end

    % Frames qui ont un masque binaire (labelMaskUnion)
    maskFrames = [];
    if isfield(ds.userData,'labelMaskFrames')
        maskFrames = double(ds.userData.labelMaskFrames(:)');
    end

    % On remplit la struct finale
    info.hasTracking        = true;
    info.frameBoxes         = frameBoxes;
    info.frameOffsets       = offsets;
    info.presence           = presence;
    info.cumulativePresence = cumsum(double(presence));
    info.frameIndices       = framesList;
    info.frameCount         = numel(framesList);

    if ~isempty(framesList)
        info.firstFrame = framesList(1);
        info.lastFrame  = framesList(end);
    else
        info.firstFrame = find(presence,1,'first');
        info.lastFrame  = find(presence,1,'last');
    end

    if isempty(info.frameCount) || info.frameCount == 0
        info.frameCount = nnz(presence);
    end

    % Infos annexes si présentes
    if isfield(ds.userData,'sourceROI')
        info.sourceROI = ds.userData.sourceROI;
    end
    if isfield(ds.userData,'labelChannelIndex')
        info.labelChannelIndex = double(ds.userData.labelChannelIndex);
    end
    if isfield(ds.userData,'labelChannelName')
        info.labelChannelName = ds.userData.labelChannelName;
    end
    if isfield(ds.userData,'labelMaskUnion')
        info.labelMaskUnion = ds.userData.labelMaskUnion;
    end

    if ~isempty(maskFrames)
        info.labelMaskFrames = maskFrames;
    elseif ~isempty(framesList)
        info.labelMaskFrames = framesList;
    end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function newObj = propValues(newObj, orgObj)
    pl = properties(orgObj);
    for k = 1:length(pl)
        if isprop(newObj, pl{k})
            newObj.(pl{k}) = orgObj.(pl{k});
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dumprecovery(fovid, framecell, currentfovid, currentframe)
    tmpcrash = [];
    tmpcrash.fovid = fovid;
    tmpcrash.framecell = framecell;
    tmpcrash.currentfovid = currentfovid;
    tmpcrash.currentframe = currentframe;
    save(fullfile(userpath, 'tmpcrash.mat'), 'tmpcrash');

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function name = channelDisplayName(fovObj, channelIndex)
    name = sprintf('Channel_%d', channelIndex);
    if isempty(channelIndex) || ~isfinite(channelIndex)
        return;
    end
    channelIndex = round(channelIndex);
    if isfield(fovObj, 'channel') && numel(fovObj.channel) >= channelIndex && channelIndex >= 1
        rawName = fovObj.channel{channelIndex};
        if ~isempty(rawName)
            name = char(rawName);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%