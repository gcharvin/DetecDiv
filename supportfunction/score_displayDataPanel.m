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

%groupIdx
%aa=layoutOptions.dataidx{groupIdx};
dataIndices = layoutOptions.plotidx{groupIdx} ; % indices des données à afficher
data = roiobj.data(layoutOptions.dataidx{groupIdx});
ydata = data.data{:, layoutOptions.plotidx{groupIdx}};

% Conversion de l'axe X : on utilise le nombre de points dans ydata et param.framerate
if timeoffset
    % Si timeoffset est activé, on soustrait la première frame de layout.frames
    xdata = ((1:size(ydata,1)) - layoutOptions.frames(1)) * framerate;
else
    xdata = (1:size(ydata,1)) * framerate;
end

% Extraction des noms de variables pour la légende
varname = data.data.Properties.VariableNames(dataIndices);
str = cell(1, size(ydata,2));
for i = 1:size(ydata,2)
    str{i} = varname{i};
end

% Tracé des données avec conversion de l'axe X en minutes et récupération des handles
hLine = plot(ax, xdata, ydata, 'LineWidth', 2);
hold(ax, 'on');

hLine2=[];
cc=1;
% Pour chaque élément dans layout.frames, ajouter un gros rond plein sur chaque courbe
markerSize = 10;  % Taille du marker (ajustable)
for k = 1:length(layoutOptions.frames)
    fIdx = layoutOptions.frames(k);
    % Vérifier que fIdx est dans les limites de ydata
    if fIdx <= size(ydata,1)
        % Calcul de la position x pour le marker
        if timeoffset
            xMarker = (fIdx - layoutOptions.frames(1)) * framerate;
        else
            xMarker = fIdx * framerate;
        end
        % Pour chaque courbe (chaque colonne de ydata)
        for j = 1:length(hLine)
            yMarker = ydata(fIdx, j);
            % Utilisation de la couleur propre à la courbe p(j)
            hLine2(cc)=plot(ax, xMarker, yMarker, 'o', 'MarkerSize', markerSize, 'MarkerFaceColor', hLine(j).Color, 'MarkerEdgeColor', hLine(j).Color);
            cc=cc+1;
        end
    end
end


hLine=[hLine; hLine2'];
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

xlim(ax,  [amin amax]);

% Seul le plot tout en bas (dernier panel) affiche les étiquettes des X ticks
if groupIdx < layoutOptions.ngroup
    set(ax, 'XTickLabel', []);
end
end