function hLine=score_displayDataPanel(ax, groupIdx, layoutOptions, roiobj)
% Fonction d'affichage d'un panel de données.
% Les données X (frames) sont converties en minutes,
% le titre est affiché en ylabel et un xlabel "Time(min)" est ajouté.
%
% dataIndices : indices des données à afficher (extrait de layout.plotidx{groupIdx})

timeoffset = layoutOptions.timeOffset;
framerate  = layoutOptions.framerate;
fontsize=layoutOptions.fontSize;
scalingFactor=layoutOptions.scalingFactor;


%aa=layoutOptions.dataidx{groupIdx};
dataIndices = layoutOptions.plotidx{groupIdx}; % indices des données à afficher
data = roiobj.data(layoutOptions.dataidx{groupIdx});

ydata = data.data{:, layoutOptions.plotidx{groupIdx}};


groupname=layoutOptions.plotidxgroup{groupIdx};
pix=find(matches(data.groupProperties(:,1),groupname));

plottype=data.groupProperties{pix,2};


ybounds=[]; xbounds=[];
if numel(pix)
    ybounds=data.groupProperties{pix,4};
    xbounds=data.groupProperties{pix,3};
end

% Conversion de l'axe X : on utilise le nombre de points dans ydata et param.framerate
if timeoffset
    % Si timeoffset est activé, on soustrait la première frame de layout.frames
    xdata = ((1:size(ydata,1)) - layoutOptions.frames(1)) * framerate;
            pix=xdata>=0;
          ydata = ydata(pix, :);  % indexation sur les lignes pour préserver les colonnes
          xdata = xdata(pix);
else
    xdata = (1:size(ydata,1)) * framerate;
end


% Extraction des noms de variables pour la légende
varname = data.data.Properties.VariableNames(dataIndices);
str = cell(1, size(ydata,2));

for i = 1:size(ydata,2)
    str{i} = varname{i};
end

if plottype=="Plot"

    % Tracé des données avec conversion de l'axe X en minutes et récupération des handles

    cmap=eval([layoutOptions.dataColormap '(' num2str(size(ydata,2)) ')']);
    ax.ColorOrder = cmap ;
    ax.NextPlot = 'add';

    cc=1;
    hold(ax, 'on');
    for i=1:size(ydata,2)
        wid=data.plotProperties{dataIndices(i),5};
        col=data.plotProperties{dataIndices(i),4};
        rgb = parseRGBstring(col);

        if col=="k" | col=="auto"
            color=cmap(cc,:);
            cc=cc+1;
        elseif numel(rgb)
            color=rgb;
        else
            color=[0.5 0.5 0.5];
        end
        hLine(i) = plot(ax, xdata, ydata(:,i), 'LineWidth', wid,'Color',color);

    end

    hLine2 = gobjects(0);  % au lieu de hLine2 = [];
    cc=1;
    % Pour chaque élément dans layout.frames, ajouter un gros rond plein sur chaque courbe
    markerSize = 10;  % Taille du marker (ajustable)
    for k = 1:length(layoutOptions.frames)
        fIdx = layoutOptions.frames(k);
        % Vérifier que fIdx est dans les limites de ydata
        if timeoffset
            xMarker = (fIdx - layoutOptions.frames(1)) * framerate;
        else
            xMarker = fIdx * framerate;
        end

        if fIdx <= size(ydata,1)
            % Calcul de la position x pour le marker
            % Pour chaque courbe (chaque colonne de ydata)
            for j = 1:length(hLine)
                yMarker = ydata(fIdx, j);
                % Utilisation de la couleur propre à la courbe p(j)
                %  hLine2(cc)=plot(ax, xMarker, yMarker, 'o', 'MarkerSize', markerSize, 'MarkerFaceColor', hLine(j).Color, 'MarkerEdgeColor', hLine(j).Color);
                hLine2(cc) = plot(ax, xMarker, yMarker, 'o', 'MarkerSize', markerSize, ...
                    'MarkerFaceColor', hLine(j).Color, 'MarkerEdgeColor', hLine(j).Color);
                %aa=hLine(j).Color
                % On lie le marker à sa ligne correspondante
                %   hLine2(cc).UserData.LinkedLine = hLine(j);
                hLine2(cc).UserData = struct('LinkedLine', hLine(j));

                cc=cc+1;
            end
        end
    end

    hLine=[hLine'; hLine2'];
    hold(ax, 'off');

    % Affichage du titre en ylabel (au lieu d'un titre en haut)
    ylabel(ax, layoutOptions.plotidxgroup{groupIdx}, ...
        'FontSize', floor(layoutOptions.fontSize), ...
        'FontName', 'Arial', 'Color', layoutOptions.textColor, 'Interpreter', 'none');

    % Ajout d'un label pour l'axe X
    xlabel(ax, 'Time(min)', 'FontName', 'Arial', ...
        'FontSize', floor(layoutOptions.fontSize), ...
        'Color', layoutOptions.textColor);


    % Création et configuration de la légende
    lgd = legend(ax, str);
    set(lgd, 'Color', layoutOptions.background, ...        % Fond identique à celui de la figure
        'Interpreter', 'none', ...             % Pas d'interprétation en LaTeX
        'TextColor', layoutOptions.textColor);         % Texte de la légende en param.textColor

    % Configuration des axes : affichage uniquement des axes gauche et inférieur
    set(ax, 'XColor', layoutOptions.textColor, 'YColor', layoutOptions.textColor, 'Box', 'off');
    set(ax, 'Color', layoutOptions.background,'FontSize',floor(sqrt(scalingFactor)*layoutOptions.fontSize));

    % setting up x axes
    track=false;
    if layoutOptions.track
        if layoutOptions.mode~="Sequence"
            track=true;
        end
    end


    if track
        amin=xMarker-layoutOptions.trackWindow*framerate;
        amax=xMarker+layoutOptions.trackWindow*framerate;
        ax.UserData.xlim=[amin amax];

    else % no tracking mode

        if numel(xbounds)==0 || xbounds=="auto"
            amin=min(xdata);
            if amin>0
                amin=0.95*amin-0.01;
            else
                amin=1.05*amin-0.01;
            end

            amax=max(xdata);
            if amax>0
                amax=0.95*amax-0.01;
            else
                amax=1.05*amax+0.01;
            end

            ax.UserData.xlim='auto';
    
        else
            xbounds=str2num(xbounds);
            amin= xbounds(1);
            amax=xbounds(2);
            ax.UserData.xlim=[amin amax];
        end
    end


    xlim(ax, [amin amax]);

    % setting up y axes

    if numel(ybounds)==0 | ybounds=="auto" | isnan(str2num(ybounds))
        ax.UserData.ylim='auto';
    else
        ybounds=str2num(ybounds);
        amin= ybounds(1);
        amax=ybounds(2);
        ylim([amin amax])
        ax.UserData.ylim=[amin amax];
    end

    % Seul le plot tout en bas (dernier panel) affiche les étiquettes des X ticks

         xlims = get(ax, 'XLim');
        % [xmin xmax]
        % Créer 5 ticks également espacés
        ticks = niceTicks(xlims(1), xlims(2), 5);
        % Appliquer les ticks
        set(ax, 'XTick', ticks);
        
    if groupIdx < layoutOptions.ngroup
        set(ax, 'XTickLabel', []);
    else
        xticklabels = arrayfun(@(x) sprintf('%.0f', x), ticks, 'UniformOutput', false);
        set(ax, 'XTickLabel', xticklabels);
    end

    set(ax,'box','off');

    % if groupIdx < layoutOptions.ngroup
    %     set(ax, 'XTickLabel', []);
    % else
    %     xlims = get(ax, 'XLim');
    %     ticks = niceTicks(xlims(1), xlims(2), 5);
    %     % Appliquer les ticks
    %     set(ax, 'XTick', ticks);
    %     xticklabels = arrayfun(@(x) sprintf('%.0f', x), ticks, 'UniformOutput', false);
    %     set(ax, 'XTickLabel', xticklabels);
    % end
else  % traj mode

    if timeoffset
            pix=xdata>=0;
            ydata=ydata(pix,:);
            xdata=xdata(pix);
    end

    if numel(ybounds)==0 | ybounds=="auto" | isnan(str2num(ybounds))
        ax.UserData.ylim='auto';
        amin=min(ydata(:));
        amax=max(ydata(:));
    else
        ybounds=str2num(ybounds);
        amin= ybounds(1);
        amax=ybounds(2);
        %  ylim([amin amax])
        ax.UserData.ylim=[amin amax];
    end

     hold(ax, 'on');

    [rgbImage, alphaImage, color] = render_ydata_as_image(ydata, amin, amax , layoutOptions,data, dataIndices);
  
    %    % Conversion de l'axe X : on utilise le nombre de points dans ydata et param.framerate
    % if timeoffset
    %     % Si timeoffset est activé, on soustrait la première frame de layout.frames
    %     xdata = ((1:size(ydata,1)) - layoutOptions.frames(1)) * framerate;
    % else
    %     xdata = (1:size(ydata,1)) * framerate;
    % end


    hLine = imagesc(ax, rgbImage,'AlphaData', alphaImage);
    axis(ax, 'normal');  % clé pour permettre l'étirement
    %ax.PositionConstraint = 'outerposition';  % empêche les marges inutiles
    % Configuration des axes : affichage uniquement des axes gauche et inférieur
    set(ax, 'XColor', layoutOptions.textColor, 'YColor', layoutOptions.background, 'Box', 'off');
    set(ax, 'Color', layoutOptions.background,'FontSize',floor(sqrt(scalingFactor)*layoutOptions.fontSize));


    % Affichage du titre en ylabel (au lieu d'un titre en haut)
    ylabel(ax, layoutOptions.plotidxgroup{groupIdx}, ...
        'FontSize', floor(layoutOptions.fontSize), ...
        'FontName', 'Arial', 'Color', layoutOptions.textColor, 'Interpreter', 'none');

    % Ajout d'un label pour l'axe X
    xlabel(ax, 'Time(min)', 'FontName', 'Arial', ...
        'FontSize', floor(layoutOptions.fontSize), ...
        'Color', layoutOptions.textColor);

    %  xlim(ax, [0.5, imwidth + 0.5]);
    ylim(ax, [-1, size(rgbImage,1) + 1]);

    if numel(xbounds)==0 || xbounds=="auto"
        amin=min(xdata);
        if amin>0
            amin=0.95*amin-0.01;
        else
            amin=1.05*amin-0.01;
        end

        amax=max(xdata);
        if amax>0
            amax=0.95*amax-0.01;
        else
            amax=1.05*amax+0.01;
        end
        ax.UserData.xlim='auto';
    else
        xbounds=str2num(xbounds);
        amin= xbounds(1);
        amax=xbounds(2);
        ax.UserData.xlim=[amin amax];
    end

    xlim([amin amax]/layoutOptions.framerate) ;

     xlims = layoutOptions.framerate*get(ax, 'XLim');
        % [xmin xmax]
        % Créer 5 ticks également espacés
        ticks = niceTicks(xlims(1), xlims(2), 5);
        % Appliquer les ticks
        set(ax, 'XTick', ticks/ layoutOptions.framerate);

    if groupIdx < layoutOptions.ngroup
        set(ax, 'XTickLabel', []);
    else
        xticklabels = arrayfun(@(x) sprintf('%.0f', x), ticks, 'UniformOutput', false);
        set(ax, 'XTickLabel', xticklabels);
    end


    hold on;

    W = 0.15;  % largeur
    H = 0.02; % hauteur

    % Récupérer la position de l'axe
    %drawnow;
    axPos = get(ax, 'Position');  % [left, bottom, width, height]

    % Calculer la position du panel en haut à gauche de l'axe
    panelLeft = axPos(1) + axPos(3) - W;      % bord droit de l'axe - largeur du panel
    panelBottom = axPos(2) + axPos(4) - 1*H;    % bord haut de l'axe - hauteur du panel

    axLegend = addHorizontalColorbarLegend(ax.Parent.Parent, ydata, color, [panelLeft, panelBottom, W, H], layoutOptions);

    hold off;

    % axis(ax, 'off');

    %hLine= imshow(rgbImage,[],'Parent', ax,'InitialMagnification','fit');

end
end


function rgb = parseRGBstring(str)
rgb = [];
try
    val = str2num(str); %#ok<ST2NM>
    if isnumeric(val) && numel(val) == 3 && all(val >= 0) && all(val <= 1)
        rgb = val;
    end
catch
    rgb = [];
end
end

function [rgbImage_rescaled, alphaImage_rescaled, colorsOrColormap] = render_ydata_as_image(ydata, minVal, maxVal, layoutOptions, data, dataIndices)
    % Nombre de séries (colonnes de ydata)
    num_series = size(ydata, 2);
    
    % Récupérer le colormap de base défini dans layoutOptions.dataColormap 
    % utilisé pour les couleurs "auto" ou "k"
    baseCmap = eval([layoutOptions.dataColormap '(' num2str(num_series) ')']);
    cc = 1;
    
    % Pré-allocation pour la couleur de référence et un flag indiquant
    % si l'on doit utiliser directement le colormap spécifié par layoutOptions.colormap
    refColor = zeros(num_series, 3);
    useCustomColormap = false(num_series,1);
    
    % Pour chaque série, on récupère la spécification dans data.plotProperties
    for i = 1:num_series        
        % On vérifie que dataIndices comporte un indice pour cette série
        if i <= numel(dataIndices)
            colSpec = data.plotProperties{dataIndices(i), 4};  
            wid = data.plotProperties{dataIndices(i), 5};  %#ok<NASGU>
        else
            colSpec = "auto";  % Valeur par défaut
        end

        % Si la spécification vaut "colormap", on indique que l'on utilisera
        % directement le colormap MATLAB défini dans layoutOptions.colormap.
        if strcmp(colSpec, "colormap")
            useCustomColormap(i) = true;
            refColor(i,:) = [0 0 0];  % Valeur par défaut, non utilisée ici
        else
            % Tenter de parser la chaîne pour obtenir un vecteur RGB
            rgbVal = parseRGBstring(colSpec);
            % Si la spécification vaut "k" ou "auto", utiliser la couleur du colormap de base
            if strcmp(colSpec, "k") || strcmp(colSpec, "auto")
                refColor(i,:) = baseCmap(cc,:);
                cc = cc + 1;
            elseif numel(rgbVal)==3
                refColor(i,:) = rgbVal;
            else
                refColor(i,:) = [0.5 0.5 0.5];  % Couleur par défaut
            end
        end
    end

    % Cas particulier d'une unique série avec "auto" ou "k"
    if num_series == 1 && (strcmp(data.plotProperties{dataIndices(1), 4}, "k") || strcmp(data.plotProperties{dataIndices(1), 4}, "auto"))
        refColor = eval([layoutOptions.dataColormap '(256)']);  
        % Ce cas sera traité par la suite via le mapping sur le gradient
    end

    % Récupération et parsing de la couleur de fond
    bgColor = parseRGBstring(layoutOptions.background);
    if isempty(bgColor) || numel(bgColor) ~= 3
        bgColor = [0 0 0];  % Fond par défaut noir
    end

    % Construction du gradient pour chaque série
    nSteps = 256;  % Nombre de niveaux dans le gradient
    gradMap = cell(num_series,1);
    for i = 1:num_series
        if useCustomColormap(i)
            % Pour cette série, le gradient est directement celui généré par le
            % colormap MATLAB défini dans layoutOptions.colormap (ex: 'jet', 'lines', etc.)
            gradMap{i} = eval([layoutOptions.colormap '(' num2str(nSteps) ')']);
        else
            % Construction linéaire d'un gradient entre bgColor et la couleur de référence
            gradMap{i} = [linspace(bgColor(1), refColor(i,1), nSteps)', ...
                          linspace(bgColor(2), refColor(i,2), nSteps)', ...
                          linspace(bgColor(3), refColor(i,3), nSteps)'];
        end
    end

    % En sortie, renvoyer le gradient pour chaque série
    colorsOrColormap = gradMap;
    
    % Détermination de fadeFrame en fonction de layoutOptions.mode
    if strcmp(layoutOptions.mode, "Sequence")
        fadeFrame = -1;  % par exemple : layoutOptions.frames(end)+1
    else
        fadeFrame = layoutOptions.frames;
    end

    % Construction de l'image temporaire : ici N représente la hauteur (en pixels)
    N = 60;
    [Nframes, nb_col] = size(ydata);  % Nframes = nombre de "frames" (lignes de ydata), nb_col = nombre de séries
    rgbImage = zeros(N, Nframes, 3);   % Image RGB de taille N x Nframes
    
    % Normalisation des données de ydata dans l'intervalle [0, 1]
    ydataNorm = (ydata - minVal) / (maxVal - minVal);
    ydataNorm = min(max(ydataNorm, 0), 1);  % Clamp

    % Mapping des données sur le gradient de couleur
    if nb_col == 1
        % Cas d'une seule série : utilisation du gradient associé
        grad = gradMap{1};
        idx = round(ydataNorm * (nSteps - 1)) + 1;
        idx = min(max(idx, 1), nSteps);
        for j = 1:Nframes
            rgbImage(:, j, :) = repmat(reshape(grad(idx(j), :), 1, 1, 3), N, 1);
        end
    else
        % Cas multiserie : blending additif des contributions
        for s = 1:nb_col
            grad = gradMap{s};
            for j = 1:Nframes
                idx = round(ydataNorm(j, s) * (nSteps - 1)) + 1;
                idx = min(max(idx, 1), nSteps);
                colorPixel = grad(idx, :);
                rgbImage(:, j, :) = rgbImage(:, j, :) + repmat(reshape(colorPixel, 1, 1, 3), N, 1);
            end
        end
        rgbImage = min(rgbImage, 1);  % Clamp pour éviter de dépasser 1
    end

% Définir les couleurs cibles pour le gradient (à adapter selon vos besoins)
RGBtop    = [0.1, 0.1, 0.1];  % Exemple : couleur vers laquelle on interpole en haut
RGBbottom = [0.8, 0.8, 0.8];  % Exemple : couleur vers laquelle on interpole en bas

% Forcer RGBtop et RGBbottom à être des vecteurs ligne 1×3
RGBtop = reshape(RGBtop, [1, 3]);
RGBbottom = reshape(RGBbottom, [1, 3]);

% Récupérer le nombre de colonnes de l'image (nombre de frames)
numCols = size(rgbImage, 2);

% Définir la répartition verticale : 25 % en haut, 25 % en bas, le reste au milieu
nTop    = round(0.25 * N);
nBottom = round(0.25 * N);
nMiddle = N - nTop - nBottom;

newImg = zeros(size(rgbImage));
for r = 1:N
    % Extraire la ligne r sous forme d'une matrice 2D [numCols x 3]
    rowColors = reshape(rgbImage(r, :, :), [numCols, 3]);
    if r <= nTop
        % Zone supérieure : interpolation entre RGBtop et la couleur originale
        if nTop > 1
            factor = (r - 1) / (nTop - 1);  % factor varie de 0 (pour r=1) à 1 (pour r=nTop)
        else
            factor = 1;
        end
        targetTop = repmat(RGBtop, [numCols, 1]); % Répétition sur numCols lignes
        newLine = (1 - factor) * targetTop + factor * rowColors;
    elseif r <= nTop + nMiddle
        % Zone centrale : conserver la couleur originale
        newLine = rowColors;
    else
        % Zone inférieure : interpolation entre la couleur originale et RGBbottom
        r_blend = r - (nTop + nMiddle);
        if nBottom > 1
            t = (r_blend - 1) / (nBottom - 1);  % t varie de 0 à 1
        else
            t = 1;
        end
        targetBottom = repmat(RGBbottom, [numCols, 1]);
        newLine = (1 - t) * rowColors + t * targetBottom;
    end
    % Remettre la ligne sous forme [1 x numCols x 3] et l'affecter
    newImg(r, :, :) = reshape(newLine, [1, numCols, 3]);
end
rgbImage = newImg;


    
    %---------------------------------------------------------------------
    % Gestion de l'opacité (alpha) en fonction de fadeFrame
    %---------------------------------------------------------------------
    if isempty(fadeFrame) || ~isscalar(fadeFrame) || ~isnumeric(fadeFrame) || fadeFrame < 0
        fadeFrame = Nframes;
    end
    fadeFrame = max(1, min(round(fadeFrame), Nframes));
    alphaVec = ones(1, Nframes);
    if fadeFrame <= Nframes
        alphaVec(fadeFrame:end) = 0.2;
    end
    alphaImage = repmat(alphaVec, N, 1);
    
    % Redimensionnement de l'image finale pour obtenir Nfinal colonnes
    Nfinal = size(ydata, 1);
    rgbImage_rescaled = imresize(rgbImage, [N, Nfinal], 'nearest');
    alphaImage_rescaled = imresize(alphaImage, [N, Nfinal], 'nearest');
end




function axLegend = addHorizontalColorbarLegend(parentFigOrPanel, ydata, cmap, panelPosition,layoutOptions)
% addHorizontalColorbarLegend
% Crée une légende colorée horizontale représentant les valeurs de ydata
% - parentFigOrPanel : figure ou uipanel contenant l'axe
% - ydata : tableau de données (utilisé pour min et max)
% - cmap : colormap utilisée pour l'image principale (Nx3)
% - position : [x y width height] de l'axe légende (en unités normalisées)

% Déterminer les bornes de l’échelle
minVal = min(ydata(:), [], 'omitnan');
maxVal = max(ydata(:), [], 'omitnan');

% Taille en pixels (par défaut 256 niveaux)
nColor = size(cmap, 1);

% Créer une image horizontale avec dégradé linéaire
gradient = linspace(0, 1, nColor);   % de gauche à droite
legendRGB = ind2rgb(round(gradient * (nColor - 1)) + 1, cmap);
legendRGB = reshape(legendRGB, [1, nColor, 3]);  % image 1 x N x 3

% Créer l'axe légende
% Créer le uipanel pour la légende
legendPanel = uipanel('Parent', parentFigOrPanel, ...
    'Units', 'normalized', ...
    'Position', panelPosition, ...
    'BorderType', 'none');

axLegend = axes('Parent', legendPanel, 'Position', [0 0 1 1],'Color',layoutOptions.background);
imagesc([minVal maxVal], [0 1], legendRGB);  % [XData], [YData]
set(axLegend, 'YTick', [], 'XTickMode', 'auto');
set(axLegend, 'YAxisLocation', 'left');
set(axLegend, 'YDir', 'normal');
box(axLegend, 'on');
axis(axLegend, 'tight');
axLegend.XColor=layoutOptions.textColor;
axLegend.YColor=layoutOptions.textColor;


xlabel(axLegend, 'Valeur', 'Color', layoutOptions.textColor);
box(axLegend, 'on');

end

function ticks = niceTicks(xmin, xmax, nticks)
% Trouve des ticks "ronds" entre xmin et xmax (nticks environ)
range = xmax - xmin;
rawStep = range / (nticks - 1);

% Trouve une "belle" taille de pas (10^n * 1, 2, ou 5)
mag = 10^floor(log10(rawStep));
niceSteps = [0,1, 2, 3, 4, 5, 6, 7 ,8, 9,10];
step = mag * niceSteps(find(rawStep <= mag * niceSteps, 1));

% Début et fin arrondis
tmin = floor(xmin / step) * step;
tmax = ceil(xmax / step) * step;

ticks = tmin:step:tmax;
end



