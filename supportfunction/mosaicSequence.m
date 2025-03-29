function mosaicSequence(obj, varargin)
% mosaicSequence génère une exportation de type "Sequence" où l'image
% composite est obtenue en blendant les channels non indexés,
% et les contours vectoriels sont extraits pour les channels indexés.
% Les annotations textuelles (timestamp, titre ROI) sont ajoutées de façon vectorielle.
%
% Les ROI sont organisées dans un mosaic dont le layout est défini par ArraySize.
%
% Paramètres optionnels (varargin) : 'Frames', 'Name', 'IPS', 'Framerate',
% 'SnapRate', 'stopDead', 'Rotate', 'ImageSize', 'Flip', 'HideStamp', 'TimeOffset',
% 'NoColor', 'Channel', 'Levels', 'RGB', 'FontSize', 'Training', 'Results',
% 'Classification', 'Title', 'ROITitle', 'RLS', 'contour', 'Output', 'Background',
% 'Text', 'Weights', 'Legend', 'Scale', 'Crop', 'ArraySize', 'DisplayTest',
% 'PaintChannel', 'DefaultClass'.

%% --- INITIALISATION ET PARSING DES PARAMÈTRES ---
% (Pour gagner en lisibilité, voici la version condensée du parsing)
tabtitle = 0; stopWhenDead = []; shiftY = []; hideStamp = false; crop = [];
arraySize = []; displayLegend = 0; snapRate = []; scalingFactor = 1; legendX = 0;
name = []; ips = 10; framerate = 5; channel = {}; fontsize = 12; levels = [];
training = []; results = []; titleStr = []; strid = ''; classif = [];
nocolor = 1; rotate = []; imageSize = []; DisplayTest = 0; timeoffset = false;
weights = []; paintChannel = 0; defaultClass = 0;
colr = [0.35, 0.35, 0.35];
roititle = false; rls = 0; Flip = 0; rgb = {}; contour = 0;
sequence = 'Sequence'; background = [0 0 0]; textColor = [1 1 1];

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
    end
end

if numel(snapRate)==0, snapRate = ones(1, numel(channel)); end
if ~exist('frames','var')
    if isa(obj, 'roi')
        frames = 1:size(obj(1).image,4);
    else
        frames = [];
    end
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

%% --- CHARGEMENT DE LA PREMIÈRE ROI POUR RÉFÉRENCE ---
if isa(obj, 'roi')
    img = obj(1).image;
    if isempty(img)
        obj(1).load; img = obj(1).image;
    end
    roitmp = obj(1);
end

%% --- TRAITEMENT DES CHANNELS POUR CHAQUE ROI ---
numROI = numel(obj);
roiOverlay = repmat(struct('baseImage', [], 'vectorText', [], 'vectorContours', []), 1, numROI);
for cc = 1:numROI
    roitmp = obj(cc);
    if isempty(roitmp.image)
        roitmp.load;
    end
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
    vectorTextCell = cell(1, numFrames);
    vectorContourCell = cell(1, numFrames);
    compositeFrames = zeros([size(baseImg,1), size(baseImg,2), 3, numFrames], 'uint8');

    for i = 1:numFrames
        comp = uint8(zeros(size(imtmp,1), size(imtmp,2), 3));
        vText = [];
        vContours = [];
        for ii = 1:numel(channel)
            totim=  imtmp(:,:, currentCha{ii}, :);

            if numel(totim)==0 % this channel is not present in this ROI
                continue
            end

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
            % Cas canal non indexé (levels{ii} numérique)
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
                % Cas canal indexé (levels{ii} cell array)
            elseif numel(currentCha{ii})==1 && iscell(levels{ii})
                % imtmp2 = imadjust(imtmp2, [0 1]);
                indices = str2num(levels{ii}{1});
                
                listofindexedcha=find(roitmp.display.indexed);
                tmpcha = roitmp.channelid(currentCha{ii});
                currentIndx=find(listofindexedcha==tmpcha);

                if isempty(indices) || (numel(indices)==1 && indices==-1)
                    if defaultClass && paintChannel ~= currentIndx  % if paint mode is chosen, then disable the defulat class setting
                        indices = 2:max(totim(:));
                    else
                        indices = 1:max(totim(:));
                    end
                end

           
                if paintChannel == currentIndx
                    levmap = eval([levels{ii}{2} '(' num2str(max(totim(:))) ')']);  % use given colormap
                    
                else
                    levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices), 1]); % use same rgb triplet to display all contours
                end
                wid = levels{ii}{5}; % largeur du contour
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
                    size(imtmp2),size(comp)
                    comp = imlincomb(1, comp, weights(ii), uint8(double(imtmp2)/256));
                end
            end
        end
        % Ajout du texte vectoriel : titre ROI et timestamp
        if roititle
            if numel(roitmp.id) > 10
                txt = roitmp.id(end-10:end);
            else
                txt = roitmp.id;
            end
            vText = [vText, struct('x', 0.05, 'y', 0.95, 'String', txt, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', colr)];
        end
        if ~hideStamp
            if timeoffset
                ts = [num2str((frames(i)-frames(1))*framerate) 'min'];
            else
                ts = [num2str(frames(i)*framerate) 'min'];
            end
            vText = [vText, struct('x', 0.05, 'y', 0.90, 'String', ts, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor)];
        end
        vectorTextCell{i} = vText;
        vectorContourCell{i} = vContours;
        compositeFrames(:,:,:,i) = comp;
    end
    roiOverlay(cc).baseImage = compositeFrames;
    roiOverlay(cc).vectorText = vectorTextCell;
    roiOverlay(cc).vectorContours = vectorContourCell;
end

% --- AFFICHAGE DU MOSAIC GLOBAL ---
numROI = numel(roiOverlay);
if isempty(arraySize)
    nCols = ceil(sqrt(numROI));
    nRows = ceil(numROI/nCols);
else
    nRows = arraySize(1);
    nCols = arraySize(2);
end
numFrames = size(roiOverlay(1).baseImage,4);

% Créer un tiledlayout global de nRows lignes et (nCols*numFrames) colonnes
totalCols = nCols * numFrames;
hFig = figure('Name', 'Sequences Export (Vectorial)', 'Units', 'pixels');
% Calcul de la taille de la figure
[imgH, imgW, ~, ~] = size(roiOverlay(1).baseImage);
margin = 0; % aucun espacement interne
figWidth = totalCols * imgW;
figHeight = nRows * imgH + 50; % 50 pixels pour le titre
set(hFig, 'Position', [100, 100, figWidth, figHeight], 'Color', background);

% Créer un tiledlayout sans padding ni spacing
tGlobal = tiledlayout(hFig, nRows, totalCols, 'Padding', 'tight', 'TileSpacing', 'none');

% Si un titre global est défini, l'ajouter (en utilisant la propriété Title du tiledlayout)
if ~isempty(titleStr)
    tGlobal.Title.String = titleStr;
    tGlobal.Title.Color = textColor;
    tGlobal.Title.FontSize = floor(sqrt(scalingFactor)*fontsize);
    tGlobal.Title.FontName = 'Arial';
end

% Remplissage du tiledlayout global :
% On parcourt chaque ROI et, pour chaque ROI, chaque frame est placée dans la colonne appropriée.
for roiIdx = 1:numROI
    % Calcul de la position de la ROI dans le mosaic global
    r = ceil(roiIdx / nCols);
    c_roi = mod(roiIdx-1, nCols) + 1;
    for f = 1:numFrames
        colIndex = (c_roi - 1) * numFrames + f;
        % Calcul de l'indice global du tile (en lecture par ligne)
        globalTileIndex = (r - 1) * totalCols + colIndex;
        ax = nexttile(tGlobal, globalTileIndex);
        imshow(roiOverlay(roiIdx).baseImage(:,:,:,f), 'Parent', ax);
      %  set(ax, 'Units', 'normalized', 'Position', get(ax, 'Position'), 'Color', background);
        hold(ax, 'on');
        % Ajout vectoriel du timestamp
        if ~hideStamp
            if timeoffset
                ts = [num2str((frames(f)-frames(1))*framerate) 'min'];
            else
                ts = [num2str(frames(f)*framerate) 'min'];
            end
            text(ax, 0.05, 0.99, ts, 'FontName', 'Arial', ...
                'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor, ...
                'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Interpreter', 'none');
        end
        % Ajout vectoriel des contours pour cette frame
        vc = roiOverlay(roiIdx).vectorContours{f};
        for k = 1:length(vc)
            if ~isempty(vc(k).x) && all(isfinite(vc(k).x)) && all(isfinite(vc(k).y)) && all(vc(k).LineWidth(:) > 0)
                faceColor = double(vc(k).FaceColor);
                if any(faceColor > 1), faceColor = faceColor/255; end
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
end

% Pour garantir l'ordre des tiles, on boucle de 1 à (nRows*totalCols)
% et on stocke les positions (en unités normalisées relatives à tGlobal)
tilePos = zeros(nRows*totalCols,4);
for k = 1:(nRows*totalCols)
    ax = nexttile(tGlobal, k);  % Renvoie l'axe existant pour le tile k
    tilePos(k,:) = get(ax, 'Position'); % Position relative à tGlobal (normalisée)
end

% La position du tiledlayout dans la figure (en unités normalisées) :
globalPos = tGlobal.OuterPosition;  % [x y w h] dans la figure

% Fonction de conversion : positionFigure = [ globalPos(1) + p(1)*globalPos(3), ...
%                                            globalPos(2) + p(2)*globalPos(4), ...
%                                            p(3)*globalPos(3), p(4)*globalPos(4) ]
convertPos = @(p) [ globalPos(1) + p(1)*globalPos(3), ...
                    globalPos(2) + p(2)*globalPos(4), ...
                    p(3)*globalPos(3), p(4)*globalPos(4) ];

% Ajout de lignes verticales de séparation entre chaque frame pour chaque ROI
drawLineWidth = 2*scalingFactor;
% Pour chaque ligne de ROI
for r = 1:nRows
    % Pour chaque ROI dans cette ligne : il y a numFrames par ROI
    for c = 1:nCols
        % Pour chaque frame sauf la dernière de la ROI
        for f = 1:(numFrames)
            % Calculer le tile global correspondant à ce frame
            globalTileIndex = (r-1)*totalCols + (c-1)*numFrames + f;
            % On récupère la position relative à tGlobal
            pRel = tilePos(globalTileIndex, :);
            % Convertir en coordonnées figure
            pFig = convertPos(pRel);
            % La ligne verticale doit être tracée à x = pFig(1)+pFig(3)
            xLine = pFig(1) + pFig(3);
            % Pour la hauteur, on prend l'intervalle vertical du tile
            yBot = pFig(2)
            yTop = pFig(2) + pFig(4)
            % Tracer l'annotation dans la figure (en unités normalisées)
            annotation(hFig, 'line', [xLine xLine], [yBot-0.01 yTop+0.01], 'Color', background, 'LineWidth', drawLineWidth);
        end
    end
end


% Export de la figure principale en PDF vectoriel
[pth, fle] = fileparts(name);
fil = fullfile(pth, [fle, '.pdf']);
exportgraphics(hFig, fil, 'ContentType', 'vector');
disp(['Sequence export successfully saved to : ' fil]);
end
