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
        if j == 1
            continue; % keep the reference label ROI untouched
        end
        obj.fov(idx).roi(j).path = fullfile(strpath, obj.fov(idx).id);
    end
end

shallowSave(obj);


% Loop over each selected FOV
for idfov = 1:numel(fovid)
    i = fovid(idfov);
    if numel(tmpfov(i).roi) == 0
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

        tmproi = roi;
        bboxCache = cell(1, numel(tmpfov(i).roi));
        for l = 1:numel(tmpfov(i).roi)
            tmproi(l) = tmpfov(i).roi(l);
        end

        for l = 1:numel(tmpfov(i).roi) % loop on all ROIs
            if l == 1
                bboxCache{l} = [];
                continue; % reference label ROI is read-only
            end
            tmproi(l).path = fullfile(strpath, tmpfov(i).id);
            rroi = double(tmproi(l).value);
            bboxInfo = collectTrackedBoundingBoxes(tmproi(l));
            bboxCache{l} = bboxInfo;
            if bboxInfo.hasTracking
                rroi = bboxInfo.globalBox;
            end
            % cropping data
            init = 0;

            targetHeight = uint16(max(1, round(scale * rroi(4))));
            targetWidth = uint16(max(1, round(scale * rroi(3))));



            if ii ~= 1 % if not the first block, reload the 4D image to append data
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

                tmproi(l).load;



                if numel(tmproi(l).image) == 0
                    init = 1;
                else
                    roivalue = double(tmproi(l).value);
                    tm=size(tmproi(l).image);

                    if tm(1) ~= targetHeight || tm(2) ~= targetWidth  || tm(3) ~= ccha %|| ~isequal(roivalue, uint16(scale * rroi))
                    %    tmproi(l).value = uint16(scale * rroi);
                 %   pause
                        init = 1;
                    end
                end
                tmproi(l).display.frame = nframesBlock(1);
            end


            if init == 1 && ~bboxInfo.hasTracking && ~isempty(tmproi(l).image)
                currentSize = size(tmproi(l).image);
                if numel(currentSize) >= 3 && currentSize(1) == targetHeight && currentSize(2) == targetWidth && currentSize(3) > ccha
                    init = 0;
                end
            end

            if init == 1
                frameCapacity = numel(nframestot);
                if bboxInfo.hasTracking && ~isempty(bboxInfo.lastFrame)
                    frameCapacity = min(frameCapacity, bboxInfo.lastFrame);
                end
                tmproi(l).image = uint16(zeros(targetHeight, targetWidth, ccha, frameCapacity));
              %  tmproi(l).value = uint16(scale * rroi);
              %  pause
                tmproi(l).display.channel = {};
                if bboxInfo.hasTracking && ~isempty(bboxInfo.firstFrame)
                    tmproi(l).display.frame = bboxInfo.firstFrame;
                else
                    tmproi(l).display.frame = nframesBlock(1);
                end
                tmproi(l).channelid = [];
                tmproi(l).display.displaylim = [];
                temp = [1 1 1];
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
               % tmproi(l).display.alpha = tmproi(l).display.alpha(1:numel(cha), :);
              %  tmproi(l).display.contour = tmproi(l).display.contour(1:numel(cha), :);
               % tmproi(l).display.width = tmproi(l).display.width(1:numel(cha), :);

                tmproi(l).display.rgb = tmproi(l).display.rgb(1:numel(cha), :);
                tmproi(l).results = [];
                tmproi(l).train = [];
                tmproi(l).save;
            end

            if bboxInfo.hasTracking && ~isempty(bboxInfo.firstFrame)
                tmproi(l).display.frame = bboxInfo.firstFrame;
            end

            % Test ROI value
            if bboxInfo.hasTracking
                canvasHeight = max(1, round(rroi(4)));
                canvasWidth = max(1, round(rroi(3)));
                blankCanvas = zeros(canvasHeight, canvasWidth, ccha, 'like', list);
                for idxFrame = 1:numel(nframesBlock)
                    frameId = nframesBlock(idxFrame);
                    if bboxInfo.hasTracking && ~isempty(bboxInfo.lastFrame) && frameId > bboxInfo.lastFrame
                        continue;
                    end
                    frameCanvas = blankCanvas;

                    if frameId <= size(bboxInfo.frameBoxes, 1)
                        frameBox = bboxInfo.frameBoxes(frameId, :);
                        if all(isfinite(frameBox)) && all(frameBox(3:4) > 0)
                            x1 = max(1, round(frameBox(1)));
                            y1 = max(1, round(frameBox(2)));
                            x2 = min(size(list, 2), round(frameBox(1) + frameBox(3) - 1));
                            y2 = min(size(list, 1), round(frameBox(2) + frameBox(4) - 1));
                            widthFrame = max(0, x2 - x1 + 1);
                            heightFrame = max(0, y2 - y1 + 1);

                            if widthFrame > 0 && heightFrame > 0
                                patch = list(y1:y2, x1:x2, :, idxFrame);
                                colOffset = 0;
                                rowOffset = 0;

                                colRange = colOffset + (1:widthFrame);
                                rowRange = rowOffset + (1:heightFrame);

                                frameCanvas(rowRange, colRange, :) = patch;
                            end
                        end
                    end

                    if scale ~= 1
                        frameCanvas = imresize(frameCanvas, scale);
                    end

                    [frameHeightScaled, frameWidthScaled, ~] = size(frameCanvas);
                    if frameHeightScaled ~= double(targetHeight) || frameWidthScaled ~= double(targetWidth)
                        frameCanvas = imresize(frameCanvas, [double(targetHeight), double(targetWidth)]);
                    end

                    if frameId > size(tmproi(l).image, 4)
                        continue;
                    end

                    tmproi(l).image(:,:,1:ccha,frameId) = frameCanvas;
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
                disp('This is an I/O CRASH: restart ROI extraction with crashrecovery mode set to 1');
                dumprecovery(fovid, framecell, i, ii);
            end
        end
    end
    
    % Restore ROI object structure
    for l = 1:numel(tmpfov(i).roi)
        bboxInfo = bboxCache{l};
        if ~isempty(bboxInfo) && bboxInfo.hasTracking && ~isempty(bboxInfo.lastFrame)
            try
                tmproi(l).load;
                if size(tmproi(l).image,4) > bboxInfo.lastFrame
                    tmproi(l).image = tmproi(l).image(:,:,:,1:bboxInfo.lastFrame);
                    tmproi(l).save;
                end
            catch
                % ignore trimming errors and keep existing data
            end
            tmproi(l).clear;
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
    info = struct('hasTracking', false, 'globalBox', double(roiObj.value), ...
        'frameBoxes', [], 'frameOffsets', [], 'presence', []);

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

    idx = find(arrayfun(@(x) isprop(x, 'groupid') && strcmp(x.groupid, 'cell_presence'), roiObj.data), 1, 'first');
    if isempty(idx)
        return;
    end

    ds = roiObj.data(idx);
    if ~isstruct(ds.userData)
        return;
    end

    requiredFields = {'boundingBoxesGlobal', 'boundingBoxOffsets', 'boundingBoxUnionGlobal', 'boundingBoxUnionRelative'};
    for k = 1:numel(requiredFields)
        if ~isfield(ds.userData, requiredFields{k})
            return;
        end
    end

    frameBoxes = double(ds.userData.boundingBoxesGlobal);
    offsets = double(ds.userData.boundingBoxOffsets);

    if isempty(frameBoxes) || size(frameBoxes, 2) ~= 4
        return;
    end

    if size(offsets, 1) < size(frameBoxes, 1)
        offsets(size(frameBoxes, 1), 2) = NaN;
    end

    presence = all(isfinite(frameBoxes), 2) & frameBoxes(:, 3) > 0 & frameBoxes(:, 4) > 0;

    if ~any(presence)
        info.frameBoxes = frameBoxes;
        info.frameOffsets = offsets;
        info.presence = presence;
        return;
    end

    unionGlobal = double(ds.userData.boundingBoxUnionGlobal);
    if numel(unionGlobal) == 4 && all(isfinite(unionGlobal))
        info.globalBox = unionGlobal;
    end

    info.hasTracking = true;
    info.frameBoxes = frameBoxes;
    info.frameOffsets = offsets;
    info.presence = presence;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function info = collectTrackedBoundingBoxes(roiObj)
    info = struct('hasTracking', false, 'globalBox', double(roiObj.value), ...
        'frameBoxes', [], 'frameOffsets', [], 'presence', [], 'firstFrame', [], 'lastFrame', []);

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

    idx = find(arrayfun(@(x) isprop(x, 'groupid') && strcmp(x.groupid, 'cell_presence'), roiObj.data), 1, 'first');
    if isempty(idx)
        return;
    end

    ds = roiObj.data(idx);
    if ~isstruct(ds.userData)
        return;
    end

    requiredFields = {'boundingBoxesGlobal', 'boundingBoxOffsets', 'boundingBoxUnionGlobal', 'boundingBoxUnionRelative'};
    for k = 1:numel(requiredFields)
        if ~isfield(ds.userData, requiredFields{k})
            return;
        end
    end

    frameBoxes = double(ds.userData.boundingBoxesGlobal);
    offsets = double(ds.userData.boundingBoxOffsets);

    if isempty(frameBoxes) || size(frameBoxes, 2) ~= 4
        return;
    end

    if size(offsets, 1) < size(frameBoxes, 1)
        offsets(size(frameBoxes, 1), 2) = NaN;
    end

    presence = all(isfinite(frameBoxes), 2) & frameBoxes(:, 3) > 0 & frameBoxes(:, 4) > 0;

    if ~any(presence)
        info.frameBoxes = frameBoxes;
        info.frameOffsets = offsets;
        info.presence = presence;
        return;
    end

    unionGlobal = double(ds.userData.boundingBoxUnionGlobal);
    if numel(unionGlobal) == 4 && all(isfinite(unionGlobal))
        info.globalBox = unionGlobal;
    end

    info.hasTracking = true;
    info.frameBoxes = frameBoxes;
    info.frameOffsets = offsets;
    info.presence = presence;
    info.firstFrame = find(presence, 1, 'first');
    info.lastFrame = find(presence, 1, 'last');
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
