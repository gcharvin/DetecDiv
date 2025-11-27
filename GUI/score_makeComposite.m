function [displayImage, vContours indexedOverlay alphaOverlay]=score_makeComposite(roitmp,fr,param)

channel=param.channel;
% imageSize=param.imageSize;
overlay=param.overlay;

% frames=param.frames;
% snapRate=param.snapRate;
levels=param.levels;
rgb=param.RGB;
weights=param.weights;
paintChannel=param.paintChannel;
defaultClass=param.defaultClass;

%figure, imshow(roitmp.image(:,:,13,1),[]);
imtmp=preProcessROI(roitmp,param);

%figure, imshow(imtmp(:,:,13,1),[]);

% here make a distinction : if image has 3 D , then don't display it as
% overlay , otherwise  do it !

if overlay==false
    displayImage= zeros([size(imtmp,1), size(imtmp,2) 3 numel(channel)], 'uint8');
else
    displayImage= zeros([size(imtmp,1), size(imtmp,2) 3 ], 'uint8');
    comp=displayImage;
end

indexedOverlay = zeros(size(imtmp,1), size(imtmp,2), 3);
alphaOverlay = zeros(size(imtmp,1), size(imtmp,2));
alphamask = zeros(size(alphaOverlay));

vContours = [];

for ch=1:numel(channel)
    %fr
    if iscell(channel)
        currentCha = roitmp.findChannelID(channel{ch});
    else
        pix = find(roitmp.channelid == channel(ch));
        currentCha = pix;
    end

    %  currentCha

    totim =roitmp.image(:,:, currentCha, :); % to get the whole range of map values

    imtmp2 = imtmp(:,:, currentCha, fr);
    % class(imtmp2),max(imtmp2(:))
    % figure, imshow(imtmp2,[]);

    if numel(currentCha)==1 && ~iscell(levels{ch})
        % if ~isequal(levels{ch}, [-1 -1])
        %     if levels{ch}(1)>=levels{ch}(2)
        %         levels{ch}(1)=levels{ch}(2)-1;
        %     end
        %     imtmp2 = imadjust(imtmp2, [levels{ch}(1)/65535, levels{ch}(2)/65535]);
        % end



        logdisplay=false;
        if isprop(roitmp, 'display') && isfield(roitmp.display, 'log') && roitmp.display.log(currentCha) == true

            logdisplay=true;
            imtmp2 = double(imtmp2);  % passage explicite en double pour éviter erreurs
            % Appliquer log dans l'espace double, éviter log(0)
            imtmp2 = log1p(imtmp2);


            % Appliquer levels dans l'espace log
            % On suppose que les niveaux sont donnés dans l'espace linéaire et doivent être logés
            lmin = log1p(double(levels{ch}(1))) / log1p(65535);
            lmax = log1p(double(levels{ch}(2))) / log1p(65535);
            if lmin >= lmax
                lmin = lmax - 1e-3;
            end

            imtmp2 = imtmp2 / log1p(65535);
            imtmp2 = imadjust(imtmp2, [lmin, lmax]);
            imtmp2=uint16(65535*imtmp2);


            % Valeurs de niveaux définies (en linéaire)
            levelMin = levels{ch}(1);
            levelMax =  levels{ch}(2);

            % Convertir en bornes log-normalisées
            lmin = log1p(levelMin) / log1p(65535);
            lmax = log1p(levelMax) / log1p(65535);

            % Définir les ticks en valeurs linéaires arrondies dans l'intervalle
            tickValsLin = [1, 10, 100, 1000, 10000, 65535];
            tickValsLin = tickValsLin(tickValsLin >= levelMin & tickValsLin <= levelMax);

            % Convertir les ticks dans l'échelle log1p normalisée
            tickValsNorm = log1p(tickValsLin) / log1p(65535);

           %  fig = figure('Position', [100, 100, 300, 600], 'Color', 'w');
           % 
           %  % Axe fictif pour le colorbar
           %  axes('Position', [0, 0, 1, 1], 'Visible', 'off');
           % 
           %  % Affichage de la colorbar seule
           %  colormap(parula2green(256));
           % 
           % % colormap(parula(256));
           %  cb = colorbar('eastoutside');
           % 
           %  % Forcer la position et la largeur (plus large que d'habitude)
           %  cb.Position = [0.3, 0.1, 0.3, 0.8];  % [left, bottom, width, height]
           % 
           %  % Échelle + ticks
           %  caxis([lmin lmax]);
           %  cb.Ticks = tickValsNorm;
           %  cb.TickLabels = string(tickValsLin);
           % 
           %  % Taille police augmentée
           %  cb.FontSize = 40;
           % 
           %  % Label vertical
           %  cb.Label.String = 'Fluorescence intensity (a.u.)';
           %  cb.Label.FontSize = 40;
           %  cb.Label.FontWeight = 'bold';
           %  cb.Label.Rotation = 90;
           % 
           %  % Export optionnel
           %  exportgraphics(fig, 'colorbar_log_parula_levels.pdf', 'BackgroundColor', 'none', 'Resolution', 300);

        else
            % Cas normal (linéaire)
            if ~isequal(levels{ch}, [-1 -1])
                if levels{ch}(1) >= levels{ch}(2)
                    levels{ch}(1) = levels{ch}(2) - 1;
                end

                imtmp2 = imadjust(imtmp2 , [levels{ch}(1)/65535, levels{ch}(2)/65535]);

            end
        end


        if overlay
            imtmp2 = cat(3, imtmp2*rgb{ch}(1), imtmp2*rgb{ch}(2), imtmp2*rgb{ch}(3));
            if isempty(weights)
                comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
            else
                comp = imlincomb(1, comp, weights(ch), uint8(double(imtmp2)/256));
            end
        else
            if logdisplay
                % here

                imnorm = double(imtmp2) / 65535;
                imnorm = min(max(imnorm, 0), 1);
                imind = uint8(imnorm * 255);
                cmap = parula2green(256);
                rgbImage = ind2rgb(imind, cmap);
                displayImage(:,:,:,ch) = uint8(rgbImage * 255);

            else
                imtmp2 = cat(3, imtmp2*rgb{ch}(1), imtmp2*rgb{ch}(2), imtmp2*rgb{ch}(3));
                displayImage(:,:,:,ch) = uint8(double(imtmp2)/256);
            end
        end




    elseif numel(currentCha)==1 && iscell(levels{ch})
        imtmp2 = imadjust(imtmp2, [0 1]);

        %   max(imtmp2(:))
        indices = str2num(levels{ch}{1});
        % Traitement des canaux indexés
        listofindexedcha = find(roitmp.display.indexed);
        tmpcha = roitmp.channelid(currentCha);
        currentIndx = find(listofindexedcha == tmpcha);

        if  (paintChannel ~= currentIndx) && paintChannel~=0 % in paint mode, discard other channels
            continue
        end


        if isempty(indices) || (numel(indices)==1 && indices==-1)
            if defaultClass && (paintChannel ~= currentIndx)
                indices = 2:max(imtmp2(:));
            else
                indices = 1:max(imtmp2(:));
            end
        end

        %tmp=levels{ch}{2}

         if paintChannel == currentIndx
        %     uni = unique(totim(:));
        %     uni(uni==0) = [];
        %     nuni = max(numel(uni),numel(indices));
        %     levmap = eval([levels{ch}{2} '(' num2str(nuni) ')']);
        levmap = zeros(numel(indices),3);
for ii = 1:numel(indices)
    levmap(ii,:) = label2color(indices(ii));   % <- mapping stable
end
         else
             levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices), 1]);
         end


        % --- Couleurs stables (0..1) pour chaque ID ---


        wid = levels{ch}{5};
        weiVal = double(levels{ch}{3});
        fillAlpha = min(1, weiVal);

        switch param.mode
            case {"Sequence","Movie"}
                % build vectors
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

            case "Display"

                %  annotationColorImage = zeros(size(indexedOverlay));
                % alphamask = zeros(size(alphaOverlay));

                for iVal = 1:numel(indices)
                    mask = imtmp2 == indices(iVal);
                    %   figure, imshow(mask,[])
                    alphamask = alphamask | mask;


                    for c = 1:3
                        channelOverlay = indexedOverlay(:, :, c);
                        channelOverlay(mask) =levmap(iVal, c);
                        indexedOverlay(:, :, c) = channelOverlay;
                    end

                    if numel(find(mask))
                        alphaOverlay(mask) = fillAlpha;
                    end

                end

                
    % m = ismember(imtmp2, indices);
    % Lsub = imtmp2 .* uint16(m);
    % rgbL = mask2rgb_stable(Lsub);
    % indexedOverlay = rgbL;
    % alphaOverlay   = double(m) * fillAlpha;

        end
    else

        % if ~isequal(levels{ch}, [-1 -1])
        %    imtmp2 = imadjust(imtmp2, [levels{ch}(1)/65535, levels{ch}(2)/65535]);
        % end
        %

        % if isprop(roitmp, 'display') && isfield(roitmp.display, 'log') && roitmp.display.log(currentCha) == true
        % 
        %     imtmp2 = double(imtmp2);  % passage explicite en double pour éviter erreurs
        %     % Appliquer log dans l'espace double, éviter log(0)
        %     imtmp2 = log1p(imtmp2);
        % 
        %     % Appliquer levels dans l'espace log
        %     % On suppose que les niveaux sont donnés dans l'espace linéaire et doivent être logés
        %     lmin = log1p(double(levels{ch}(1))) / log1p(65535);
        %     lmax = log1p(double(levels{ch}(2))) / log1p(65535);
        %     if lmin >= lmax
        %         lmin = lmax - 1e-3;
        %     end
        % 
        %     imtmp2 = imtmp2 / log1p(65535);
        %     imtmp2 = imadjust(imtmp2, [lmin, lmax]);
        %     imtmp2=uint16(65535*imtmp2);
        % 
        % else
            % Cas normal (linéaire)
            if ~isequal(levels{ch}, [-1 -1])
                if levels{ch}(1) >= levels{ch}(2)
                    levels{ch}(1) = levels{ch}(2) - 1;
                end

                imtmp2 = imadjust(imtmp2 , [levels{ch}(1)/65535, levels{ch}(2)/65535]);

            end
      %  end


        if overlay
            if isempty(weights)
                comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
            else
                comp = imlincomb(1, comp, weights(ch), uint8(double(imtmp2)/256));
            end
        else

            displayImage(:,:,:,ch) = uint8(double(imtmp2)/256);
        end
    end


    if overlay
        displayImage =comp;
    end

end



end



function imtmp=preProcessROI(roitmp,param)

channel=param.channel;
frames=param.frames;
crop=param.crop;
scalingFactor=param.scalingFactor;
imageSize=param.imageSize;
flip=param.flip;

if isempty(roitmp.image), roitmp.load; end

%disp(['ROI ' roitmp.id ' is loaded']);

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

% preprocess images

imtmp = roitmp.image(:,:,:,frames);
if ~isempty(crop)
    for c = 1:size(imtmp,3)
        for f = 1:size(imtmp,4)
            imtmptp(:,:,c,f) = imcrop(imtmp(:,:,c,f), crop);
        end
    end
    imtmp = imtmptp;
end

if scalingFactor~=1
    imtmp = imresize(imtmp, scalingFactor, 'nearest');
end

if ~isempty(imageSize)
    imtmp = imresize(imtmp, imageSize);
end

if flip==1
    imtmp = flip(imtmp,1);
end
end


function cmap = parula2green(n)
% Crée une colormap de type parula, mais dont la couleur max est verte

% Génère un colormap progressif de bleu -> rouge -> vert
% Bleu (faible), rouge (milieu), vert (fort)

    if nargin < 1
        n = 256;
    end

    % Points de contrôle : bleu, rouge, vert
    colors = [ ...
        0     0     1   ;  % bleu
        1     0     0   ;  % rouge
        0     1     0 ];   % vert

    % Interpolation sur n points
    x = linspace(0, 1, size(colors, 1));      % 3 points
    xi = linspace(0, 1, n);                   % n points

    cmap = interp1(x, colors, xi, 'linear');
end

function cmap = getPalette(n)
% Palette qualitative de 16 couleurs bien distinctes, sans gris clair.
% Remplacement du gris (0.498,0.498,0.498) par un or vif (1.000,0.835,0.000).

base = [ ...
    0.121 0.466 0.705;  % bleu
    1.000 0.498 0.054;  % orange
    0.172 0.627 0.172;  % vert
    0.839 0.152 0.156;  % rouge
    0.580 0.404 0.741;  % violet
    0.549 0.337 0.294;  % brun
    0.890 0.466 0.760;  % rose
    1.000 0.835 0.000;  % OR vif (remplace le gris)
    0.737 0.741 0.133;  % olive
    0.090 0.745 0.811;  % cyan
    0.650 0.810 0.890;  % bleu clair
    1.000 0.733 0.470;  % orange clair
    0.596 0.874 0.541;  % vert clair
    1.000 0.596 0.588;  % rouge clair
    0.770 0.690 0.835;  % violet clair
    0.900 0.770 0.580]; % beige/tan

if n <= size(base,1)
    cmap = base(1:n,:);
else
    reps = ceil(n/size(base,1));
    cmap = repmat(base, reps, 1);
    cmap = cmap(1:n, :);
end
end


function col = label2color(id)
pal = getPalette(16);
idx = 1 + mod(max(1,round(id))-1, size(pal,1));
col = pal(idx,:);
end

function rgb = mask2rgb_stable(L)
L = double(L);
[H,W] = size(L);
rgb = zeros(H,W,3,'double');
ids = unique(L); ids(ids==0) = [];
for id = ids(:).'
    c = label2color(id);
    m = (L==id);
    rgb(:,:,1) = rgb(:,:,1) + m.*c(1);
    rgb(:,:,2) = rgb(:,:,2) + m.*c(2);
    rgb(:,:,3) = rgb(:,:,3) + m.*c(3);
end
end



