function mosaicSequence(obj, varargin)
% mosaicSequence génère une exportation de type "Sequence" où l'image composite
% est obtenue en blendant les channels non indexés (mode overlay) ou en affichant
% les canaux non indexés empilés verticalement (mode non-overlay).
% Les contours vectoriels (issus des channels indexés) et les annotations
% (timestamp, titre ROI) sont ajoutés de façon vectorielle.di
%
% Les ROI sont organisées dans un mosaic dont le layout est défini par ArraySize.
%
% Paramètres optionnels (varargin) : 'Frames', 'Name', 'IPS', 'Framerate',
% 'SnapRate', 'stopDead', 'Rotate', 'ImageSize', 'Flip', 'HideStamp', 'TimeOffset',
% 'NoColor', 'Channel', 'Levels', 'RGB', 'FontSize', 'Training', 'Results',
% 'Classification', 'Title', 'ROITitle', 'RLS', 'contour', 'Output', 'Background',
% 'Text', 'Weights', 'Legend', 'Scale', 'Crop', 'ArraySize', 'DisplayTest',
% 'PaintChannel', 'DefaultClass'.
%
% Le paramètre 'Overlay' (booléen) définit si l'on superpose les canaux (true, par défaut)
% ou si l'on affiche les canaux non indexés empilés verticalement (false).

%% --- INITIALISATION ET PARSING DES PARAMÈTRES ---
tabtitle = 0; stopWhenDead = []; shiftY = []; hideStamp = false; crop = [];
arraySize = []; displayLegend = 0; snapRate = []; scalingFactor = 1; legendX = 0;
name = []; ips = 10; framerate = 5; channel = {}; fontsize = 12; levels = [];
training = []; results = []; titleStr = []; strid = ''; classif = [];
nocolor = 1; rotate = []; imageSize = []; DisplayTest = 0; timeoffset = false;
weights = []; paintChannel = 0; defaultClass = 0;
colr = [0.35, 0.35, 0.35];
roititle = false; rls = 0; Flip = 0; rgb = {}; contour = 0;
sequence = 'Sequence'; background = [0 0 0]; textColor = [1 1 1];
overlayMode = false;  % Par défaut, mode non-overlay

for i = 1:numel(varargin)
    if strcmp(varargin{i}, 'Frames'), frames = varargin{i+1};
    elseif strcmp(varargin{i}, 'Name'), name = varargin{i+1};
    elseif strcmp(varargin{i}, 'IPS'), ips = varargin{i+1};
    elseif strcmp(varargin{i}, 'Framerate'), framerate = varargin{i+1};
    elseif strcmp(varargin{i}, 'SnapRate'), snapRate = varargin{i+1};
    elseif strcmp(varargin{i}, 'stopDead'), stopWhenDead = varargin{i+1};
    elseif strcmp(varargin{i}, 'Rotate'), rotate = varargin{i+1};
    elseif strcmp(varargin{i}, 'ImageSize'), imageSize = varargin{i+1};
    elseif strcmp(varargin{i}, 'Flip'), Flip = 1;
    elseif strcmp(varargin{i}, 'HideStamp'), hideStamp = varargin{i+1}; if hideStamp, shiftY = 1; end
    elseif strcmp(varargin{i}, 'TimeOffset'), timeoffset = varargin{i+1};
    elseif strcmp(varargin{i}, 'NoColor'), nocolor = 1;
    elseif strcmp(varargin{i}, 'Channel')
        channel = varargin{i+1};
        if isempty(channel)
            disp('Channel is not found; quitting!'); return;
        else
            if isempty(stopWhenDead), stopWhenDead = zeros(1, numel(channel)); end
        end
    elseif strcmp(varargin{i}, 'Levels'), levels = varargin{i+1};
    elseif strcmp(varargin{i}, 'RGB'), rgb = varargin{i+1};
    elseif strcmp(varargin{i}, 'FontSize'), fontsize = varargin{i+1};
    elseif strcmp(varargin{i}, 'Training'), training = 1;
    elseif strcmp(varargin{i}, 'Results'), results = 1;
    elseif strcmp(varargin{i}, 'Classification'), classif = varargin{i+1};
    elseif strcmp(varargin{i}, 'Title'), titleStr = varargin{i+1};
    elseif strcmp(varargin{i}, 'ROITitle'), roititle = varargin{i+1};
    elseif strcmp(varargin{i}, 'RLS'), rls = 1;
    elseif strcmp(varargin{i}, 'contour'), contour = 1;
    elseif strcmp(varargin{i}, 'Output'), sequence = varargin{i+1};
    elseif strcmp(varargin{i}, 'Background'), background = varargin{i+1};
    elseif strcmp(varargin{i}, 'Text'), textColor = varargin{i+1}; colr = textColor;
    elseif strcmp(varargin{i}, 'Weights'), weights = varargin{i+1};
    elseif strcmp(varargin{i}, 'Legend'), legendX = varargin{i+1}; displayLegend = 1;
    elseif strcmp(varargin{i}, 'Scale'), scalingFactor = varargin{i+1};
    elseif strcmp(varargin{i}, 'Crop'), crop = varargin{i+1};
    elseif strcmp(varargin{i}, 'ArraySize'), arraySize = varargin{i+1};
    elseif strcmp(varargin{i}, 'DisplayTest'), DisplayTest = 1; frames = obj(1).display.frame;
    elseif strcmp(varargin{i}, 'PaintChannel'), paintChannel = varargin{i+1};
    elseif strcmp(varargin{i}, 'DefaultClass'), defaultClass = varargin{i+1};
    elseif strcmp(varargin{i}, 'Overlay'), overlayMode = varargin{i+1};
    end
end
if numel(snapRate)==0, snapRate = ones(1, numel(channel)); end
if ~exist('frames','var')
    if isa(obj, 'roi'), frames = 1:size(obj(1).image,4); else, frames = []; end
end

%% --- LAYOUT GLOBAL DES ROI (MOSAIC) ---
nmov = size(obj,2);
if ~isempty(arraySize)
    nRows = arraySize(1);
    nCols = arraySize(2);
    if nmov > nRows*nCols
        disp('Error: the number of ROIs exceeds the allocated space!'); return;
    end
else
    nCols = ceil(sqrt(nmov));
    nRows = ceil(nmov / nCols);
end

% In overlay mode, chaque ROI occupe une ligne ;
% en non-overlay, chaque ROI occupe nChannel lignes, où nChannel est le nombre de canaux non indexés.
if overlayMode
    globalRows = nRows;
else
    nChannel = 0;
    nonIndexedNames = {};
    for j = 1:numel(channel)
        if ~iscell(levels{j})
            nChannel = nChannel + 1;
            if iscell(channel)
                nonIndexedNames{end+1} = channel{j};  %#ok<AGROW>
            else
                nonIndexedNames{end+1} = channel(j);    %#ok<AGROW>
            end
        end
    end
    if nChannel == 0, nChannel = 1; end
    globalRows = nRows * nChannel;
end
globalCols = nCols * numel(frames);

%% --- CHARGEMENT DE LA PREMIÈRE ROI POUR RÉFÉRENCE ---
if isa(obj, 'roi')
    img = obj(1).image;
    if isempty(img)
        obj(1).load; img = obj(1).image;
    end
    roitmp = obj(1);
end

%% --- CONSTRUCTION DE roiOverlay POUR CHAQUE ROI ---
numROI = numel(obj);
roiOverlay = repmat(struct('baseImage', [], 'vectorText', [], 'vectorContours', []), 1, numROI);
for cc = 1:numROI
    roitmp = obj(cc);
    if isempty(roitmp.image), roitmp.load; end
    disp(['ROI ' roitmp.id ' is loaded']);
    % Recalculer les indices de canaux pour cette ROI
    currentCha = cell(1, numel(channel));
    for j = 1:numel(channel)
        if iscell(channel)
            currentCha{j} = roitmp.findChannelID(channel{j});
        else
            pix = find(roitmp.channelid == channel(j));
            currentCha{j} = pix;
        end
    end

    imtmp = roitmp.image(:,:,:,frames);
    if ~isempty(crop)
        for c = 1:size(imtmp,3)
            for f = 1:size(imtmp,4)
                imtmptp(:,:,c,f) = imcrop(imtmp(:,:,c,f), crop);
            end
        end
        imtmp = imtmptp;
    end


    imtmp = imresize(imtmp, scalingFactor, 'nearest');

    if ~isempty(imageSize)
        imtmp = imresize(imtmp, imageSize);
    end
    baseImg = uint8(double(imtmp)/256); % image de base (8 bits)
    numFrames = size(imtmp,4);
    if overlayMode
        compositeFrames = zeros([size(baseImg,1), size(baseImg,2), 3, numFrames], 'uint8');
    else
        nChannel = 0;
        for ii = 1:numel(channel)
            if ~iscell(levels{ii})
                nChannel = nChannel + 1;
            end
        end
        if nChannel == 0, nChannel = 1; end
        compositeFrames = zeros([size(baseImg,1)*nChannel, size(baseImg,2), 3, numFrames], 'uint8');
    end
    vectorTextCell = cell(1, numFrames);
    vectorContourCell = cell(1, numFrames);

    for i = 1:numFrames
        if overlayMode
            comp = uint8(zeros(size(imtmp,1), size(imtmp,2), 3));
        else
            comp = []; % concaténation verticale
        end
        vText = [];
        vContours = [];


        if overlayMode
            % Mode overlay : blending classique de tous les canaux
            for ii = 1:numel(channel)
                totim = imtmp(:,:, currentCha{ii}, :);
                if numel(totim)==0, continue; end
                if mod(i-1, snapRate(ii))==0
                    if frames(i) < 9999
                        imtmp2 = imtmp(:,:, currentCha{ii}, i);
                    else
                        imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                    end
                else
                    imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                end
                if Flip==1, imtmp2 = flip(imtmp2,1); end
                if numel(currentCha{ii})==1 && ~iscell(levels{ii})
                    if isequal(levels{ii}, [-1 -1])
                        if i==1
                            tmptimelapse = imtmp(:,:, currentCha{ii}, :);
                            med = median(tmptimelapse(:));
                            stddev = std(double(tmptimelapse(:)));
                            stretchlim(:,ii) = [max(0, double(med)-4*stddev); min(65535, double(med)+4*stddev)]/65535;
                        end
                        imtmp2 = imadjust(imtmp2, stretchlim(:,ii));
                    else
                        imtmp2 = imadjust(imtmp2, [levels{ii}(1)/65535, levels{ii}(2)/65535]);
                    end
                    imtmp2 = cat(3, imtmp2*rgb{ii}(1), imtmp2*rgb{ii}(2), imtmp2*rgb{ii}(3));
                    if isempty(weights)
                        comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
                    else
                        comp = imlincomb(1, comp, weights(ii), uint8(double(imtmp2)/256));
                    end
                elseif numel(currentCha{ii})==1 && iscell(levels{ii})
                    imtmp2 = imadjust(imtmp2, [0 1]);
                    indices = str2num(levels{ii}{1});
                    % Traitement des canaux indexés
                    listofindexedcha = find(roitmp.display.indexed);
                    tmpcha = roitmp.channelid(currentCha{ii});
                    currentIndx = find(listofindexedcha == tmpcha);
                    if isempty(indices) || (numel(indices)==1 && indices==-1)
                        if defaultClass && (paintChannel ~= currentIndx)
                            indices = 2:max(imtmp2(:));
                        else
                            indices = 1:max(imtmp2(:));
                        end
                    end
                    if paintChannel == currentIndx
                        uni = unique(totim(:));
                        uni(uni==0) = [];
                        nuni = numel(uni);
                        levmap = eval([levels{ii}{2} '(' num2str(nuni) ')']);
                    else
                        levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices), 1]);
                    end
                    wid = levels{ii}{5};
                    weiVal = double(levels{ii}{3});
                    fillAlpha = min(1, weiVal);
                    for iii = 1:numel(indices)
                        bw = imtmp2 == indices(iii);
                        B = bwboundaries(bw);
                        for kB = 1:length(B)
                            b = B{kB};
                            patchStruct = struct();
                            patchStruct.x = b(:,2);
                            patchStruct.y = b(:,1);
                            patchStruct.FaceColor = levmap(iii,:);
                            patchStruct.FaceAlpha = fillAlpha;
                            if roitmp.display.contour(tmpcha) == 1
                                patchStruct.EdgeColor = levmap(iii,:);
                                patchStruct.LineWidth = wid;
                            else
                                patchStruct.EdgeColor = 'none';
                                patchStruct.LineWidth = [];
                            end
                            vContours = [vContours, patchStruct];
                        end
                    end
                else
                    if isempty(weights)
                        comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
                    else
                        comp = imlincomb(1, comp, weights(ii), uint8(double(imtmp2)/256));
                    end
                end
            end
        else
            channelImages = {};
            vContoursTotal = {};  % Pour accumuler les contours de chaque canal
            for ii = 1:numel(channel)
                  totim = imtmp(:,:, currentCha{ii}, :);

                if numel(totim)==0, continue; end
                if mod(i-1, snapRate(ii))==0
                    if frames(i) < 9999
                        imtmp2 = imtmp(:,:, currentCha{ii}, i);
                    else
                        imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                    end
                else
                    imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                end
                if Flip==1, imtmp2 = flip(imtmp2,1); end

                 if numel(currentCha{ii})==1 && ~iscell(levels{ii})
                    if mod(i-1, snapRate(ii))==0
                        if frames(i) < 9999
                            imtmp2 = imtmp(:,:, currentCha{ii}, i);
                        else
                            imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                        end
                    else
                        imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                    end
                    if Flip==1, imtmp2 = flip(imtmp2,1); end
                    if isequal(levels{ii}, [-1 -1])
                        if i==1
                            tmptimelapse = imtmp(:,:, currentCha{ii}, :);
                            med = median(tmptimelapse(:));
                            stddev = std(double(tmptimelapse(:)));
                            stretchlim(:,ii) = [max(0, double(med)-4*stddev); min(65535, double(med)+4*stddev)]/65535;
                        end
                        imtmp2 = imadjust(imtmp2, stretchlim(:,ii));
                    else
                        imtmp2 = imadjust(imtmp2, [levels{ii}(1)/65535, levels{ii}(2)/65535]);
                    end
                    imtmp2 = cat(3, imtmp2*rgb{ii}(1), imtmp2*rgb{ii}(2), imtmp2*rgb{ii}(3));
                    if size(imtmp2,3) ~= 3
                        imtmp2 = repmat(imtmp2, [1,1,3]);
                    end
                    channelImages{end+1} = uint8(double(imtmp2)/256);  %#ok<AGROW>

                    elseif numel(currentCha{ii})==1 && iscell(levels{ii})
                    imtmp2 = imadjust(imtmp2, [0 1]);
                    indices = str2num(levels{ii}{1});
                    % Traitement des canaux indexés
                    listofindexedcha = find(roitmp.display.indexed);
                    tmpcha = roitmp.channelid(currentCha{ii});
                    currentIndx = find(listofindexedcha == tmpcha);
                    if isempty(indices) || (numel(indices)==1 && indices==-1)
                        if defaultClass && (paintChannel ~= currentIndx)
                            indices = 2:max(imtmp2(:));
                        else
                            indices = 1:max(imtmp2(:));
                        end
                    end
                    if paintChannel == currentIndx
                        uni = unique(totim(:));
                        uni(uni==0) = [];
                        nuni = numel(uni);
                        levmap = eval([levels{ii}{2} '(' num2str(nuni) ')']);
                    else
                        levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices), 1]);
                    end
                    wid = levels{ii}{5};
                    weiVal = double(levels{ii}{3});
                    fillAlpha = min(1, weiVal);
                    for iii = 1:numel(indices)
                        bw = imtmp2 == indices(iii);
                        B = bwboundaries(bw);
                        for kB = 1:length(B)
                            b = B{kB};
                            patchStruct = struct();
                            patchStruct.x = b(:,2);
                            patchStruct.y = b(:,1);
                            patchStruct.FaceColor = levmap(iii,:);
                            patchStruct.FaceAlpha = fillAlpha;
                            if roitmp.display.contour(tmpcha) == 1
                                patchStruct.EdgeColor = levmap(iii,:);
                                patchStruct.LineWidth = wid;
                            else
                                patchStruct.EdgeColor = 'none';
                                patchStruct.LineWidth = [];
                            end
                            vContours = [vContours, patchStruct];
                        end
                    end
                else
                    if isempty(weights)
                        comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
                    else
                        comp = imlincomb(1, comp, weights(ii), uint8(double(imtmp2)/256));
                    end
                 end
            end

             if ~isempty(channelImages)
                    comp = vertcat(channelImages{:});
                else
                    comp = zeros(size(imtmp,1), size(imtmp,2), 3, 'uint8');
             end


        end

        if overlayMode
            if roititle
                if numel(roitmp.id) > 10, txt = roitmp.id(end-10:end); else, txt = roitmp.id; end
                vText = [vText, struct('x', 0.05, 'y', 0.95, 'String', txt, 'FontName', 'Arial', ...
                    'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', colr)];
            end
            if ~hideStamp
                if timeoffset
                    ts = [num2str((frames(i)-frames(1))*framerate) 'min'];
                else
                    ts = [num2str(frames(i)*framerate) 'min'];
                end
                vText = [vText, struct('x', 0.05, 'y', 0.90, 'String', ts, 'FontName', 'Arial', ...
                    'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor)];
            end
        else
            if i==1 && ~hideStamp
                ts = [num2str(frames(i)*framerate) 'min'];
                vText = [vText, struct('x', 0.05, 'y', 0.99, 'String', ts, 'FontName', 'Arial', ...
                    'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor)];
            end
        end

        vectorTextCell{i} = vText;
        vectorContourCell{i} = vContours;
        compositeFrames(:,:,:,i) = comp;
    end
    roiOverlay(cc).baseImage = compositeFrames;
    roiOverlay(cc).vectorText = vectorTextCell;
    roiOverlay(cc).vectorContours = vectorContourCell;
end

%% --- AFFICHAGE DU MOSAIC GLOBAL ---
if isempty(arraySize)
    nCols = ceil(sqrt(numROI));
    nRows = ceil(numROI/nCols);
else
    nRows = arraySize(1);
    nCols = arraySize(2);
end
numFrames = size(roiOverlay(1).baseImage,4);

if overlayMode
    [tileH, tileW, ~, ~] = size(roiOverlay(1).baseImage);
    globalRows = nRows;
else
    [fullH, tileW, ~, ~] = size(roiOverlay(1).baseImage)
    nChannel = 0;
    for j = 1:numel(channel)
        if ~iscell(levels{j})
            nChannel = nChannel + 1;
        end
    end
    if nChannel == 0, nChannel = 1; end
    tileH = fullH / nChannel;
    globalRows = nRows * nChannel;
end
globalCols = nCols * numel(frames);

margin = 5;
extraMargin = 50;
figWidth = globalCols * tileW + (globalCols+1)*margin;
figHeight = globalRows * tileH + (globalRows+1)*margin + extraMargin;
hFig = figure('Name', 'Sequences Export (Vectorial)', 'Units', 'pixels', 'Position', [100, 100, figWidth, figHeight]);
set(hFig, 'Color', background);

tGlobal = tiledlayout(hFig, globalRows, globalCols, 'Padding', 'none', 'TileSpacing', 'none');
if ~isempty(titleStr)
    tGlobal.Title.String = titleStr;
    tGlobal.Title.Color = textColor;
    tGlobal.Title.FontSize = floor(sqrt(scalingFactor)*fontsize);
    tGlobal.Title.FontName = 'Arial';
end

% Remplissage du tiledlayout global
for roiIdx = 1:numROI
    if overlayMode
        r = ceil(roiIdx / nCols);
        c_roi = mod(roiIdx-1, nCols) + 1;
        for f = 1:numel(frames)
            colIndex = (c_roi - 1)*numel(frames) + f;
            globalTileIndex = (r - 1)*globalCols + colIndex;
            ax = nexttile(tGlobal, globalTileIndex);
            imshow(roiOverlay(roiIdx).baseImage(:,:,:,f), 'Parent', ax);
            set(ax, 'Color', background);
            hold(ax, 'on');
            if ~hideStamp
                if timeoffset
                    ts = [num2str((frames(f)-frames(1))*framerate) 'min'];
                else
                    ts = [num2str(frames(f)*framerate) 'min'];
                end
                text(ax, 0.01, 0.99, ts, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize),...
                    'Color', textColor, 'Units', 'normalized', 'HorizontalAlignment', 'left',...
                    'VerticalAlignment', 'top', 'Interpreter', 'none');
            end
            vc = roiOverlay(roiIdx).vectorContours{f};
            for k = 1:length(vc)
                if ~isempty(vc(k).x) && all(isfinite(vc(k).x)) && all(isfinite(vc(k).y)) && all(vc(k).LineWidth(:) > 0)
                    faceColor = double(vc(k).FaceColor); if any(faceColor > 1), faceColor = faceColor/255; end
                    faceAlpha = double(vc(k).FaceAlpha);
                    patchArgs = {'XData', vc(k).x, 'YData', vc(k).y, 'FaceColor', faceColor, 'FaceAlpha', faceAlpha};
                    if ~(ischar(vc(k).EdgeColor) && strcmp(vc(k).EdgeColor, 'none')) && ~isempty(vc(k).LineWidth)
                        edgeColor = double(vc(k).EdgeColor); if any(edgeColor > 1), edgeColor = edgeColor/255; end
                        patchArgs = [patchArgs, {'EdgeColor', edgeColor, 'LineWidth', double(vc(k).LineWidth)}];
                    else
                        patchArgs = [patchArgs, {'LineStyle', 'none'}];
                    end
                    patch(ax, patchArgs{:});
                end
            end
            hold(ax, 'off');
        end
    else
        nChannel = 0;
        for j = 1:numel(channel)
            if ~iscell(levels{j})
                nChannel = nChannel + 1;
            end
        end
        if nChannel == 0, nChannel = 1; end
        r = ceil(roiIdx / nCols);
        c_roi = mod(roiIdx-1, nCols) + 1;
        for ch = 1:nChannel
            for f = 1:numel(frames)
                globalRow = (r-1)*nChannel + ch;
                colIndex = (c_roi - 1)*numel(frames) + f;
                globalTileIndex = (globalRow-1)*globalCols + colIndex;
                ax = nexttile(tGlobal, globalTileIndex);
                imgFull = roiOverlay(roiIdx).baseImage;  % taille : [M*nChannel x N x 3 x numFrames]
                M_total = size(imgFull,1);
                M = M_total / nChannel;
                rowStart = round((ch-1)*M) + 1;
                rowEnd = round(ch*M);
                imgChannel = imgFull(rowStart:rowEnd, :, :, f);
                if size(imgChannel,3) ~= 3
                    imgChannel = repmat(imgChannel, [1,1,3]);
                end
                imshow(imgChannel, 'Parent', ax);
                set(ax, 'Color', background);
                hold(ax, 'on');
                if ch==1 && ~hideStamp
                    if timeoffset
                        ts = [num2str((frames(f)-frames(1))*framerate) 'min'];
                    else
                        ts = [num2str(frames(f)*framerate) 'min'];
                    end
                    text(ax, 0.02, 0.99, ts, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize),...
                        'Color', textColor, 'Units', 'normalized', 'HorizontalAlignment', 'left',...
                        'VerticalAlignment', 'top', 'Interpreter', 'none');
                end
                vc = roiOverlay(roiIdx).vectorContours{f};
                for k = 1:length(vc)
                    if ~isempty(vc(k).x) && all(isfinite(vc(k).x)) && all(isfinite(vc(k).y)) && all(vc(k).LineWidth(:) > 0)
                        faceColor = double(vc(k).FaceColor); if any(faceColor > 1), faceColor = faceColor/255; end
                        faceAlpha = double(vc(k).FaceAlpha);
                        patchArgs = {'XData', vc(k).x, 'YData', vc(k).y, 'FaceColor', faceColor, 'FaceAlpha', faceAlpha};
                        if ~(ischar(vc(k).EdgeColor) && strcmp(vc(k).EdgeColor, 'none')) && ~isempty(vc(k).LineWidth)
                            edgeColor = double(vc(k).EdgeColor); if any(edgeColor > 1), edgeColor = edgeColor/255; end
                            patchArgs = [patchArgs, {'EdgeColor', edgeColor, 'LineWidth', double(vc(k).LineWidth)}];
                        else
                            patchArgs = [patchArgs, {'LineStyle', 'none'}];
                        end

                        patch(ax, patchArgs{:});
                    end
                end


                hold(ax, 'off');
                if f==1
                    ylabel(ax, nonIndexedNames{ch}, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor);
                end
            end
        end
    end
end

% Ajout de lignes verticales de séparation entre chaque tile
drawLineWidth = 2*scalingFactor;
tilePos = zeros(nRows*globalCols, 4);
for k = 1:(globalRows*globalCols)
    ax = nexttile(tGlobal, k);
    tilePos(k,:) = get(ax, 'Position');
end
globalPos = tGlobal.OuterPosition;
convertPos = @(p) [ globalPos(1) + p(1)*globalPos(3), globalPos(2) + p(2)*globalPos(4), p(3)*globalPos(3), p(4)*globalPos(4) ];
for k = 1:(globalRows*globalCols)
    pRel = tilePos(k,:);
    pFig = convertPos(pRel);
    xLine = pFig(1) + pFig(3)-0.005;
    yBot = pFig(2);
    yTop = pFig(2) + pFig(4);
    annotation(hFig, 'line', [xLine xLine], [yBot-0.01 yTop+0.01], 'Color', background, 'LineWidth', drawLineWidth);
end

[pth, fle] = fileparts(name);
fil = fullfile(pth, [fle, '.pdf']);

% % Création d'une copie de la figure pour l'export PDF
% hFigCopy = copyobj(hFig, 0);
% 
% %% --- Modification des annotations de type ligne ---
% % On récupère tous les objets annotations
% annoObjs = findall(hFigCopy, 'Type', 'lineshape');
% for i = 1:length(annoObjs)
%     % Ici, on souhaite modifier uniquement ceux créés avec l'argument 'line'
%     % Pour cela, on vérifie s'ils possèdent une propriété 'Color' et si leur couleur est noire
%     if isprop(annoObjs(i), 'Color') && isequal(annoObjs(i).Color, [0 0 0])
%         annoObjs(i).Color = [1 1 1];  % passage en blanc
%     end
% end
% 
% %% --- Modification du titre du tiledlayout (ou des textes) ---
% % On recherche les tiled layouts dans la figure copiée
% tiledLayouts = hFigCopy.Children;
%     if isprop(tiledLayouts, 'Title') & ~isempty(tiledLayouts.Title)
%         titleObj = tiledLayouts.Title;
%         if isequal(titleObj.Color, [1 1 1])
%             titleObj.Color = [0 0 0];  % passage en noir
%         end
%     end
% 
% % On peut aussi vérifier parmi les objets Text, si le titre a été ajouté autrement
% textObjs = findall(hFigCopy, 'Type', 'Text');
% for i = 1:length(textObjs)
%     % On teste ici uniquement si la chaîne correspond au titre de la figure et que la couleur est blanche
%     if isprop(textObjs(i), 'String')
%         if isequal(textObjs(i).Color, [1 1 1])
%             textObjs(i).Color = [0 0 0];
%         end
%     end
% end

%% --- Exportation ---
exportgraphics(hFig, fil, 'ContentType', 'vector','BackgroundColor',background);
%close(hFig);  % On ferme la copie pour ne pas perturber l'affichage initial

disp(['Sequence export successfully saved to : ' fil]);


end
