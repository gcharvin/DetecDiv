function h = plot(data, pos, classif)
    % plot specific subdataset using properties included in the dataseries object
    % if 3rd argument is provided, then it s the annotation mode

    if numel(data.plotProperties) == 0
        h = [];
        return;
    end

    h = findobj('Tag', data.id);

    if isempty(h)
        h = figure('Color', 'w', 'Units', 'normalized', 'Tag', data.id, 'Name', [data.parentid '//' data.groupid '//' data.id]);
        if nargin == 1
            pos = [0.1 0.1 0.25 0.15];
        end
        h.Position = pos;
    else
        % On se contente de rendre la figure active sans la vider
        figure(h);
    end

    % déterminer le nombre de sous-axes à créer
    n = 0;
    groups = data.plotGroup{6};
    plotidx = {};
    plotidxgroup = {};

    for i = 1:numel(groups)
        pix = contains(data.plotProperties(:, end), string(groups{i}));
        pix2 = cellfun(@(x) x(:, 1) == true, data.plotProperties(:, 1));
        pix = find(pix & pix2);  % identifiants des plots à afficher
        if ~isempty(pix)
            n = n + 1;
            plotidx{n} = pix;
            plotidxgroup{n} = groups{i};
        end
    end

    if nargin ~= 3
        h.Position(4) = n * 0.15;
    else
        h.Position(4) = n * 0.25;
    end

    varnames = data.data.Properties.VariableNames;
    toplot = 0;
    frame = [];

    % Récupération du handle ROI pour le repère (frame)
    hroi = findobj('Tag', ['ROI' data.parentid]);
    hf = findobj(hroi, 'Tag', 'frametext');
    if ~isempty(hf)
        frame = str2num(hf.String);
    end

    % Dans le cadre de l'application ScoreApp
    figures = findall(0, 'Type', 'figure');
    appFigure = findobj(figures, 'Name', 'ScoreApp');
    if isprop(appFigure, 'RunningAppInstance')
        app = appFigure.RunningAppInstance;
        selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
        if isempty(selectedROIIndex)
            return;
        end
        selectedROI = app.content.ROIList{selectedROIIndex};
        hroi = app.ImageFigure;
        frame = selectedROI.display.frame;
    end

    txt = '';
    hs = gobjects(n,1);  % pré-allocation des handles d'axes

    for i = 1:numel(plotidx)
        % Création ou récupération de l'axe correspondant
        % On peut utiliser subplot qui, s'il existe déjà un subplot à cet emplacement, le retourne sans le vider
        hs(i) = subplot(n, 1, i);
        hold(hs(i), 'on');
        str = {};

        for j = 1:numel(plotidx{i})
            toplot = toplot + 1;
            varName = varnames{plotidx{i}(j)};
            dat = data.getData(varName);
            % Vérifier si la ligne existe déjà dans cet axe
            hLine = findobj(hs(i), 'Type', 'line', 'Tag', varName);
            if isempty(hLine)
                hLine = plot(hs(i), dat, 'Tag', varName, 'LineWidth', 2, 'UserData', data);
            else
                % mise à jour des données de la ligne
                x = 1:numel(dat);
                set(hLine, 'XData', x, 'YData', dat);
            end
            str{end+1} = varName;
        end

        % Modifier l'étiquette de l'axe y
        ylabel(hs(i), plotidxgroup{i}, 'Interpreter', 'None', 'FontSize', 10);
        if data.type == "temporal"
            xlabel(hs(i), "Time");
        elseif data.type == "generation"
            xlabel(hs(i), "Generations");
        end
        set(hs(i), 'FontSize', 20);

        % Ajout de la ligne de suivi du frame si applicable
        dat = data.getData(varnames{plotidx{i}(1)});
 % Dans le bloc où la ligne track est mise à jour
if ~isempty(hroi) && data.type == "temporal"
    xr = 1:numel(dat);
    yy = ylim(hs(i));
    pix = find(xr == frame);
    if ~isempty(pix)
        % Essayer de récupérer le handle stocké dans l'axe
        hTrack = getappdata(hs(i), 'track_line');
        if isempty(hTrack) || ~isvalid(hTrack)
            % Si le handle n'existe pas ou n'est plus valide, le créer
            hTrack = line(hs(i), [xr(pix) xr(pix)], yy, 'Color', [0.5 0.5 0.5], ...
                          'LineWidth', 1, 'Tag', [data.parentid '_track'], 'UserData', data);
            setappdata(hs(i), 'track_line', hTrack); % Stocker le handle pour les prochaines mises à jour
        else
            % Mise à jour directe de la ligne existante
            set(hTrack, 'XData', [xr(pix) xr(pix)], 'YData', yy);
        end

        if nargin == 3  % mode annotation
            set(gca, 'Tag', 'Axes_track');
            pixdat = numel(find(dat == ""));
            if iscategorical(dat(pix))
                txt = [txt ' ' char(dat(pix))];
            elseif isnumeric(dat(pix))
                txt = [txt ' ' num2str(dat(pix))];
            end
            txt = [txt ' - ' num2str(pixdat) ' frames left to annotate'];
            title(hs(i), txt, 'FontSize', 20, 'Interpreter', 'none');
        end
    end
end


        % Tracer les bornes si elles existent dans userData
        if isfield(data.userData, 'bounds')
            bounds = data.userData.bounds;
            yy = ylim(hs(i));
            for k = 1:numel(bounds)
                tagBound = [data.parentid '_bounds_' num2str(k)];
                hBound = findobj(hs(i), 'Type', 'line', 'Tag', tagBound);
                if isempty(hBound)
                    hBound = line(hs(i), [bounds(k) bounds(k)], yy, 'Color', [1 0 0], 'LineWidth', 2, 'LineStyle', '--', 'Tag', tagBound, 'UserData', data);
                else
                    set(hBound, 'XData', [bounds(k) bounds(k)], 'YData', yy);
                end
                str{end+1} = ['bound:' num2str(bounds(k))];
            end
        end

        legend(hs(i), str, 'Interpreter', 'none', 'FontSize', 10);
        xlim(hs(i), [1 numel(dat)]);
    end

    if toplot == 0
        delete(h);
        return;
    end

    ax = findobj(h, 'Type', 'Axes');
    linkaxes(ax, 'x');

    set(h, 'WindowButtonDownFcn', @(src, event) setFrame(src, event, hroi));

    % Fonction callback pour la mise à jour du frame
    function setFrame(src, event, hroi)
        pt = get(gca, 'CurrentPoint');
        frame = round(pt(1,1));
        if numel(hroi.UserData)
            hroi.UserData.roi.view(frame);
        end

        figures = findall(0, 'Type', 'figure');
        appFigure = findobj(figures, 'Name', 'ScoreApp');
        if isprop(appFigure, 'RunningAppInstance')
            app = appFigure.RunningAppInstance;
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};
            selectedROI.display.frame = frame;
            score_display(app, 'refresh');
        end
    end
end
