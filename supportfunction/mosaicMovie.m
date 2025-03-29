function mosaicMovie(obj, varargin)
% mosaicMovie génère un movie (rasterisé) en blendant les channels des ROI
% selon l'algorithme original.

% obj        : objet(s) de type @roi (ou @shallow, @classi)
% varargin   : arguments optionnels (Frames, Name, IPS, Framerate, Channel,
%              Levels, RGB, FontSize, Training, Results, Classification, Title,
%              ROITitle, RLS, contour, Output, Background, Text, Weights, Legend,
%              Scale, Crop, ArraySize, DisplayTest, PaintChannel, DefaultClass, etc.)

% --- Initialisation des paramètres par défaut ---
tabtitle = 0;
stopWhenDead = []; % pas d'affichage si la cellule est morte
shiftY = [];
hideStamp = false;
crop = [];
arraySize = [];
displayLegend = 0;
snapRate = [];
scalingFactor = 1;
legendX = 0;
name = [];
ips = 10;
framerate = 5;
channel = {};
fontsize = 12;
levels = [];
training = [];
results = [];
titleStr = [];
strid = '';
classif = [];
nocolor = 1;
rotate = [];
imageSize = [];
DisplayTest = 0;
timeoffset = false;
weights = [];
paintChannel = 0;
defaultClass = 0;

colr = [0.35, 0.35, 0.35];

roititle = false;
rls = 0;
Flip = 0;
rgb = {};
contour = 0;
sequence = 'Movie';
background = [0 0 0];
textColor = [1 1 1];

% --- Parcours des varargin (similaire à votre script original) ---
for i = 1:numel(varargin)
    if strcmp(varargin{i}, 'Frames')
        frames = varargin{i+1};
    elseif strcmp(varargin{i}, 'Name')
        name = varargin{i+1};
    elseif strcmp(varargin{i}, 'IPS')
        ips = varargin{i+1};
    elseif strcmp(varargin{i}, 'Framerate')
        framerate = varargin{i+1};
    elseif strcmp(varargin{i}, 'SnapRate')
        snapRate = varargin{i+1};
    elseif strcmp(varargin{i}, 'stopDead')
        stopWhenDead = varargin{i+1};
    elseif strcmp(varargin{i}, 'Rotate')
        rotate = varargin{i+1};
    elseif strcmp(varargin{i}, 'ImageSize')
        imageSize = varargin{i+1};
    elseif strcmp(varargin{i}, 'Flip')
        Flip = 1;
    elseif strcmp(varargin{i}, 'HideStamp')
        hideStamp = varargin{i+1};
        if hideStamp, shiftY = 1; end
    elseif strcmp(varargin{i}, 'TimeOffset')
        timeoffset = varargin{i+1};
    elseif strcmp(varargin{i}, 'NoColor')
        nocolor = 1;
    elseif strcmp(varargin{i}, 'Channel')
        channel = varargin{i+1};
        if isempty(channel)
            disp('Channel is not found; quitting!');
            return;
        else
            if isempty(stopWhenDead)
                stopWhenDead = zeros(1, numel(channel));
            end
        end
    elseif strcmp(varargin{i}, 'Levels')
        levels = varargin{i+1};
    elseif strcmp(varargin{i}, 'RGB')
        rgb = varargin{i+1};
    elseif strcmp(varargin{i}, 'FontSize')
        fontsize = varargin{i+1};
    elseif strcmp(varargin{i}, 'Training')
        training = 1;
    elseif strcmp(varargin{i}, 'Results')
        results = 1;
    elseif strcmp(varargin{i}, 'Classification')
        classif = varargin{i+1};
    elseif strcmp(varargin{i}, 'Title')
        titleStr = varargin{i+1};
    elseif strcmp(varargin{i}, 'ROITitle')
        roititle = varargin{i+1};
    elseif strcmp(varargin{i}, 'RLS')
        rls = 1;
    elseif strcmp(varargin{i}, 'contour')
        contour = 1;
    elseif strcmp(varargin{i}, 'Output')
        sequence = varargin{i+1};
    elseif strcmp(varargin{i}, 'Background')
        background = varargin{i+1};
    elseif strcmp(varargin{i}, 'Text')
        textColor = varargin{i+1};
        colr = textColor;
    elseif strcmp(varargin{i}, 'Weights')
        weights = varargin{i+1};
    elseif strcmp(varargin{i}, 'Legend')
        legendX = varargin{i+1};
        displayLegend = 1;
    elseif strcmp(varargin{i}, 'Scale')
        scalingFactor = varargin{i+1};
    elseif strcmp(varargin{i}, 'Crop')
        crop = varargin{i+1};
    elseif strcmp(varargin{i}, 'ArraySize')
        arraySize = varargin{i+1};
    elseif strcmp(varargin{i}, 'DisplayTest')
        DisplayTest = 1;
        frames = obj(1).display.frame;
    elseif strcmp(varargin{i}, 'PaintChannel')
        paintChannel = varargin{i+1};
    elseif strcmp(varargin{i}, 'DefaultClass')
        defaultClass = varargin{i+1};
    end
end

if numel(snapRate)==0
                snapRate=ones(1,numel(channel));%freq=1 for all channel
end


if ~exist('frames','var')
    if isa(obj, 'roi')
        frames = 1:size(obj(1).image,4);
    else
        frames = [];
    end
end

% --- Disposition des ROI (calcul du layout le plus carré possible) ---
nmov = size(obj,2);
if ~isempty(arraySize)
    nsize = arraySize;
    if nmov > arraySize(1)*arraySize(2)
        disp('Error: the number of ROIs exceeds the allocated space!');
        return;
    end
else
    if nmov <= 9
        layout = [1 1; 1 2; 1 3; 2 2; 2 3; 2 3; 3 3; 3 3; 3 3];
        nsize = layout(nmov,:);
    else
        n = floor(sqrt(nmov-1)) + 1;
        nsize = [n n];
    end
end

% --- Chargement de l'image modèle (première ROI) ---
if isa(obj, 'roi')
    img = obj(1).image;
    if isempty(img)
        obj(1).load;
        img = obj(1).image;
    end
    roitmp = obj(1);
end

nframesref = size(roitmp.image,4);

% --- Traitement des channels ---
cha = cell(1, numel(channel));
if isempty(rgb)
    rgb = cell(numel(channel),1);
end
if isempty(levels)
    levels = cell(numel(channel),1);
end
for i = 1:numel(channel)
    if iscell(channel)
        cha{i} = roitmp.findChannelID(channel{i});
    else
        pix = find(roitmp.channelid==channel(i));
        cha{i} = pix;
    end
    if isempty(rgb{i})
        rgb{i} = [1 1 1];
    end
    if isempty(levels{i})
        levels{i} = [-1 -1];
    end
end

% --- Calcul des marges d'affichage supplémentaires ---
shiftx = 0;
if ~isempty(training)
    wid = ceil(7*sqrt(scalingFactor)) + 5;
    shiftx = wid;
    shiftx = floor(shiftx*sqrt(scalingFactor));
end
if ~isempty(results)
    wid = ceil(7*sqrt(scalingFactor)) + 5;
    shiftx = shiftx + wid;
    shiftx = floor(shiftx*sqrt(scalingFactor));
end
if ~isempty(results) || ~isempty(training)
    legendX = ceil(legendX*sqrt(scalingFactor));
    shiftx = shiftx + legendX;
end
shifty = 0;
if roititle || rls>0 || ~isempty(shiftY)
    shifty = 16;
    shifty = floor(shifty*sqrt(scalingFactor));
end

% --- Application du crop et redimensionnement ---
if ~isempty(crop)
    for c = 1:size(img,3)
        for f = 1:size(img,4)
            imgtp(:,:,c,f) = imcrop(img(:,:,c,f), crop);
        end
    end
    img = imgtp;
end
img = imresize(img, scalingFactor);
if ~isempty(imageSize)
    img = imresize(img, imageSize);
end

h = size(img,1) + shifty;
w = size(img,2) + shiftx;
imgout = uint16(65535*ones(nsize(1)*h, nsize(2)*w, 3, numel(frames)));
imgout(:,:,1,:) = uint16(double(imgout(:,:,1,:)) * background(1));
imgout(:,:,2,:) = uint16(double(imgout(:,:,2,:)) * background(2));
imgout(:,:,3,:) = uint16(double(imgout(:,:,3,:)) * background(3));

% --- Assemblage des ROI en mode "Movie" (blending rasterisé) ---
cc = 1;
for k = 1:nsize(1)
    for j = 1:nsize(2)
        if cc > numel(obj)
            continue;
        end
        roitmp = obj(cc);
        if isempty(roitmp.image)
            roitmp.load;
        end
        disp(['ROI ' roitmp.id ' is loaded']);
        if numel(intersect(1:size(roitmp.image,4), frames)) < numel(frames)
            disp('This ROI does not have enough frames, you must provide a compatible frames argument');
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
        
        frameEnd = 9999*ones(1, numel(cha));
        if ~isempty(find(stopWhenDead==1,1))
            if ~isempty(classif)
                rlsresults = roitmp.results.(classif.strid).RLS;
                frameEnd(find(stopWhenDead==1)) = rlsresults.frameEnd;
            else
                error('You want to hide a channel when cell is dead. You need to indicate a classi with Classification argument');
            end
        end
        
        imComposite = uint16(zeros(size(imtmp,1), size(imtmp,2), 3, size(imtmp,4)));
        
        for i = 1:size(imtmp,4)
            imgRGBsum = uint16(zeros(size(imtmp,1), size(imtmp,2), 3));
            for ii = 1:numel(cha)
                 totim=imtmp(:,:,cha{ii}, :);
                if mod(i-1, snapRate(ii)) == 0
                    if frames(i) < frameEnd(ii)
                        imtmp2 = imtmp(:,:,cha{ii}, i);
                    else
                        imtmp2 = uint16(zeros(size(imtmp(:,:,cha{ii}, i))));
                    end
                else
                    imtmp2 = uint16(zeros(size(imtmp(:,:,cha{ii}, i))));
                end
                if Flip == 1
                    imtmp2 = flip(imtmp2,1);
                end
                if numel(cha{ii}) == 1
                    if numel(levels{ii}) == 2
                        if isequal(levels{ii}, [-1 -1])
                            if i==1
                                tmptimelapse = imtmp(:,:,cha{ii}, 1:end);
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
                            imgRGBsum = imlincomb(1, imgRGBsum, 1, imtmp2);
                        else
                            imgRGBsum = imlincomb(1, imgRGBsum, weights(ii), imtmp2);
                        end
                    else
                        % Channel indexé : utiliser insertObjectMask pour dessiner les surfaces
                        indices = str2num(levels{ii}{1});
                        if isempty(indices) || (numel(indices)==1 && indices == -1)
                            if defaultClass
                                indices = 2:max(totim(:));
                            else
                                indices = 1:max(totim(:));
                            end
                            if paintChannel ~= 0
                             %   max(totim(:))
                                levmap = eval([levels{ii}{2} '(' num2str(max(totim(:))) ')']);
                            else
                                tmpcha = roitmp.channelid(cha{ii});
                                levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices),1]);
                            end
                        else
                            levmap = eval(levels{ii}{2});
                        end
                        wid = levels{ii}{5};
                        wei = levels{ii}{3};
                        for iii = 1:numel(indices)
                            bw = imtmp2==indices(iii);
                            if levels{ii}{4}
                                lineopac = min(1, wei);
                                opac = 0;
                            else
                                lineopac = 0;
                                opac = min(1, wei);
                            end
                            wid = max(1, wid);
                            imgRGBsum = insertObjectMask(imgRGBsum, bw, 'MaskColor', uint8(255*levmap(iii,:)), 'Opacity', opac, 'LineOpacity', lineopac, 'LineWidth', wid);
                        end
                    end
                end
                if numel(cha{ii})==3
                    if isempty(weights)
                        imgRGBsum = imlincomb(1, imgRGBsum, 1, imtmp2);
                    else
                        imgRGBsum = imlincomb(1, imgRGBsum, weights(ii), imtmp2);
                    end
                end
            end
            if ~isempty(rotate)
                imgRGBsum = imrotate(imgRGBsum, rotate);
            end
            imComposite(:,:,:,i) = imgRGBsum;
        end
        
        % Ajout des marges de fond
        imblack = uint16(65535*ones(size(imtmp,1), shiftx, 3, size(imtmp,4)));
        imblack(:,:,1,:) = imblack(:,:,1,:) * background(1);
        imblack(:,:,2,:) = imblack(:,:,2,:) * background(2);
        imblack(:,:,3,:) = imblack(:,:,3,:) * background(3);
        imComposite = cat(2, imblack, imComposite);
        imblack2 = uint16(65535*ones(shifty, size(imComposite,2), 3, size(imComposite,4)));
        for ci = 1:3
            imblack2(:,:,ci,:) = imblack2(:,:,ci,:) * background(ci);
        end
        imComposite = cat(1, imblack2, imComposite);
        
        framesize = 2;
        for ci = 1:3
            imComposite(1:framesize,:,ci,:) = 65535*background(ci);
            imComposite(end-framesize+1:end,:,ci,:) = 65535*background(ci);
            imComposite(:,1:framesize,ci,:) = 65535*background(ci);
            imComposite(:,end-framesize+1:end,ci,:) = 65535*background(ci);
        end
        
        % Insertion d'annotations textuelles (titres, horodatages) sur l'image composite
        if roititle || rls>0
            str = '';
            if roititle
                if numel(roitmp.id) > 10
                    str = roitmp.id(end-10:end);
                else
                    str = roitmp.id;
                end
            end
            for i = 1:numel(frames)
                if rls == 1
                    str = '';
                    pir = sum(frames(i)>= rlsresults.framediv);
                    if pir < 10
                        str = [str, num2str(pir), '  - '];
                    else
                        str = [str, num2str(pir), ' - '];
                    end
                    if isempty(training)
                        str = [num2str(pir), ' divisions'];
                    end
                    if training == 1
                        pit = sum(frames(i) >= rlst.framediv);
                        if pit < 10
                            strt = [blanks(numel(str)), ' ', num2str(pit), ' div'];
                        else
                            strt = [blanks(numel(str)), num2str(pit), ' div'];
                        end
                    end
                end
                if training==1
                    imComposite(:,:,:,i) = insertText(imComposite(:,:,:,i), [legendX, shifty/2+2], str, 'Font', 'Consolas Bold', 'FontSize', floor(12*sqrt(scalingFactor)), 'BoxColor', background, 'BoxOpacity', 0.0, 'TextColor', colr*65535, 'AnchorPoint', 'LeftCenter');
                    imComposite(:,:,:,i) = insertText(imComposite(:,:,:,i), [legendX, shifty/2+2], strt, 'Font', 'Consolas Bold', 'FontSize', floor(12*sqrt(scalingFactor)), 'BoxColor', background, 'BoxOpacity', 0.0, 'TextColor', 65535*textColor, 'AnchorPoint', 'LeftCenter');
                elseif isempty(training)
                    imComposite(:,:,:,i) = insertText(imComposite(:,:,:,i), [-2, shifty/2+3], str, 'Font', 'Consolas Bold', 'FontSize', floor(12*sqrt(scalingFactor)), 'BoxColor', 255*background, 'BoxOpacity', 0.0, 'TextColor', 65535*textColor, 'AnchorPoint', 'LeftCenter');
                end
            end
        end
   
        % Assemblage de l'image composite dans le mosaic final
        imgout(1+(k-1)*h : k*h, 1+(j-1)*w : j*w, :, :) = imComposite;
        cc = cc + 1;
    end
end

imgout = uint8(double(imgout)/256);

if DisplayTest == 1
    disp('test movie output');
    hTest = findobj('Tag','MovieTest');
    if isempty(hTest)
        hTest = figure('Tag','MovieTest','Name','Preview figure for movie export');
    end
    pos = hTest.Position;
    figure(hTest);
    imshow(imgout,[]);
    set(hTest,'Position',pos);
    return;
end

switch sequence
    case 'Movie'
        if ispc
            v = VideoWriter(name, 'MPEG-4');
        else
            v = VideoWriter(name, 'Motion JPEG AVI');
        end
        v.FrameRate = ips;
        v.Quality = 100;
        open(v);
        writeVideo(v, imgout);
        close(v);
        disp(['Movie successfully exported to : ' name]);
    case 'Mat'
        [pth, fle] = fileparts(name);
        fil = fullfile(pth, [fle, '.mat']);
        save(fil, 'imgout');
        disp(['Mat file with matrix successfully exported to : ' fil]);
end
end
