classdef score < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ScoreAppUIFigure                matlab.ui.Figure
        FileMenu                        matlab.ui.container.Menu
        CloseselectedROIMenu            matlab.ui.container.Menu
        SaveselectedroiMenu             matlab.ui.container.Menu
        DisplayMenu                     matlab.ui.container.Menu
        ROIsMenu                        matlab.ui.container.Menu
        DisplaysettingsMenu             matlab.ui.container.Menu
        IntensityquantificationMenu     matlab.ui.container.Menu
        AnnotationMenu                  matlab.ui.container.Menu
        DatasettingsMenu                matlab.ui.container.Menu
        MovieMenu                       matlab.ui.container.Menu
        CopypresetsMenu                 matlab.ui.container.Menu
        PastepresetsMenu                matlab.ui.container.Menu
        SavepresetsasMenu               matlab.ui.container.Menu
        LoadpresetsMenu                 matlab.ui.container.Menu
        AnalysisMenu                    matlab.ui.container.Menu
        ComputemetricsinobjectMenu      matlab.ui.container.Menu
        NewdataseriesMenu               matlab.ui.container.Menu
        NewdatasetMenu                  matlab.ui.container.Menu
        DuplicatedatasetMenu            matlab.ui.container.Menu
        DeleteselecteddataseriesMenu    matlab.ui.container.Menu
        TabGroup                        matlab.ui.container.TabGroup
        ROIslistTab                     matlab.ui.container.Tab
        ROisPanel                       matlab.ui.container.Panel
        UIROITable                      matlab.ui.control.Table
        DisplaySettingsTab              matlab.ui.container.Tab
        DisplaysettingsPanel            matlab.ui.container.Panel
        PanButton                       matlab.ui.control.StateButton
        ResetButton                     matlab.ui.control.Button
        ChannelPanel                    matlab.ui.container.Panel
        LowHighDisplaySlider            matlab.ui.control.RangeSlider
        LevelsLabel                     matlab.ui.control.Label
        OverlayCheckBox                 matlab.ui.control.CheckBox
        SelectedChannelLabel            matlab.ui.control.Label
        ChannelColorPicker              matlab.ui.control.ColorPicker
        WeightSlider                    matlab.ui.control.Slider
        WeightSliderLabel               matlab.ui.control.Label
        FrameEditField                  matlab.ui.control.NumericEditField
        FrameSlider                     matlab.ui.control.Slider
        FrameSliderLabel                matlab.ui.control.Label
        ZoomSlider                      matlab.ui.control.Slider
        ZoomLabel                       matlab.ui.control.Label
        UIChannelTable                  matlab.ui.control.Table
        UIDisplayAxes                   matlab.ui.control.UIAxes
        QuantificationTab               matlab.ui.container.Tab
        IntensityQuantificationPanel    matlab.ui.container.Panel
        ShapeButton                     matlab.ui.control.StateButton
        LineIntensityprofileButton      matlab.ui.control.StateButton
        UIProfileAxes                   matlab.ui.control.UIAxes
        ROIDataTab                      matlab.ui.container.Tab
        DataSettingsPanel               matlab.ui.container.Panel
        FrameEditField_2                matlab.ui.control.NumericEditField
        FrameEditField_2Label           matlab.ui.control.Label
        NewdatasetButton                matlab.ui.control.Button
        NewdataseriesButton             matlab.ui.control.Button
        UIGroupTable                    matlab.ui.control.Table
        NewdatagroupButton              matlab.ui.control.Button
        DeselectallsubdataButton        matlab.ui.control.Button
        DeselectalldataButton           matlab.ui.control.Button
        ClassDropDown                   matlab.ui.control.DropDown
        ClassDropDownLabel              matlab.ui.control.Label
        AssignvalueEditField            matlab.ui.control.EditField
        AssignvalueLabel                matlab.ui.control.Label
        SelecteddataLabel               matlab.ui.control.Label
        UISubDataTable                  matlab.ui.control.Table
        UIDataTable                     matlab.ui.control.Table
        AnnotationsTab                  matlab.ui.container.Tab
        AnnotationPanel                 matlab.ui.container.Panel
        AnnotationSessionPanel          matlab.ui.container.Panel
        ShowPredictionCheckBox          matlab.ui.control.CheckBox
        ApproveAnnotationButton         matlab.ui.control.Button
        ValidateAnnotationButton        matlab.ui.control.Button
        NextIncompleteButton        matlab.ui.control.Button
        MarkFrameReviewedButton         matlab.ui.control.Button
        StartBlankGTButton              matlab.ui.control.Button
        CreateFromPredictionButton      matlab.ui.control.Button
        AnnotationCoverageLabel         matlab.ui.control.Label
        AnnotationStatusLabel           matlab.ui.control.Label
        AnnotationTargetLabel           matlab.ui.control.Label
        SelectedchannelpropertiesPanel  matlab.ui.container.Panel
        DisplayCriterionDropDown        matlab.ui.control.DropDown
        ColorbyLabel                    matlab.ui.control.Label
        ChannelModeButtonGroup          matlab.ui.container.ButtonGroup
        EditButton                      matlab.ui.control.RadioButton
        SemanticButton                  matlab.ui.control.RadioButton
        MulticolorButton                matlab.ui.control.RadioButton
        NormalButton                    matlab.ui.control.RadioButton
        MaskColorPicker                 matlab.ui.control.ColorPicker
        AnnoatationcolorLabel           matlab.ui.control.Label
        Transparency                    matlab.ui.control.Slider
        TransparencyLabel               matlab.ui.control.Label
        SelectedLabel                   matlab.ui.control.Label
        IndexChannelLabel               matlab.ui.control.Label
        isthedefautcolorCheckBox        matlab.ui.control.CheckBox
        DeleteclassButton               matlab.ui.control.Button
        NewclassButton                  matlab.ui.control.Button
        DeleteAnnnotationButton         matlab.ui.control.Button
        NewAnnotationButton             matlab.ui.control.Button
        ObjectspanelPanel               matlab.ui.container.Panel
        CellModelStatusLabel            matlab.ui.control.Label
        SelectedCellStateDropDown       matlab.ui.control.DropDown
        SelectedCellStateDropDownLabel  matlab.ui.control.Label
        SelectedTrackIDEditField        matlab.ui.control.EditField
        SelectedTrackIDEditFieldLabel   matlab.ui.control.Label
        SelectedObjectIDEditField       matlab.ui.control.EditField
        SelectedObjectIDLabel           matlab.ui.control.Label
        ObjectColorsPanel               matlab.ui.container.Panel
        GenealogyLinkColorPicker        matlab.ui.control.ColorPicker
        GenealogyLinkColorPickerLabel   matlab.ui.control.Label
        BudlinkcolorColorPicker         matlab.ui.control.ColorPicker
        BudlinkcolorColorPickerLabel    matlab.ui.control.Label
        SemanticValueColorPicker        matlab.ui.control.ColorPicker
        SemanticValueColorPickerLabel   matlab.ui.control.Label
        SemanticValueDropDown           matlab.ui.control.DropDown
        SemanticValueDropDownLabel      matlab.ui.control.Label
        FamilyColorPicker               matlab.ui.control.ColorPicker
        FamilyColorPickerLabel          matlab.ui.control.Label
        LineageSourceDropDown           matlab.ui.control.DropDown
        LineageSourceDropDownLabel      matlab.ui.control.Label
        MaskProviderDropDown            matlab.ui.control.DropDown
        MaskProviderDropDownLabel       matlab.ui.control.Label
        ObjectFamilyDropDown            matlab.ui.control.DropDown
        ObjectFamilyDropDownLabel       matlab.ui.control.Label
        LineageDisplayButtonGroup       matlab.ui.container.ButtonGroup
        FullGenealogyRadioButton        matlab.ui.control.RadioButton
        BudLinksRadioButton             matlab.ui.control.RadioButton
        NoLineageRadioButton            matlab.ui.control.RadioButton
        MasklabelEditField              matlab.ui.control.NumericEditField
        MasklabelEditFieldLabel         matlab.ui.control.Label
        UIAnnotationTable               matlab.ui.control.Table
        MovieoutputTab                  matlab.ui.container.Tab
        MoviePanel                      matlab.ui.container.Panel
        MarkThroughCurrentButton         matlab.ui.control.Button
        ReviewWhileNavigatingCheckBox    matlab.ui.control.CheckBox
        LineageLinkWidthEditFieldLabel   matlab.ui.control.Label
        LineageLinkWidthEditField        matlab.ui.control.NumericEditField
        MovieeventmarkersEditFieldLabel  matlab.ui.control.Label
        MovieeventmarkersEditField      matlab.ui.control.EditField
        ShowmovieandfolderButton        matlab.ui.control.Button
        MovielegendCheckBox             matlab.ui.control.CheckBox
        MovietrackwindowEditField       matlab.ui.control.EditField
        MovietrackwindowEditFieldLabel  matlab.ui.control.Label
        MoviedatatrackCheckBox          matlab.ui.control.CheckBox
        MovieROItitleCheckBox           matlab.ui.control.CheckBox
        MovieDatacolormapEditField      matlab.ui.control.EditField
        MovieDatacolormapEditFieldLabel  matlab.ui.control.Label
        MovieImagetodataratioEditField  matlab.ui.control.EditField
        MovieImagetodataratioEditFieldLabel  matlab.ui.control.Label
        MoviecolormapEditField          matlab.ui.control.EditField
        MoviecolormapEditFieldLabel     matlab.ui.control.Label
        MovietitleEditField             matlab.ui.control.EditField
        MovietitleEditFieldLabel        matlab.ui.control.Label
        GrenerateMovieButton            matlab.ui.control.Button
        MoviecropEditField              matlab.ui.control.EditField
        MoviecropEditFieldLabel         matlab.ui.control.Label
        MovieminutesperframeEditField   matlab.ui.control.EditField
        MovieminutesperframeEditFieldLabel  matlab.ui.control.Label
        MovieframespersecondEditField   matlab.ui.control.EditField
        MovieframespersecondEditFieldLabel  matlab.ui.control.Label
        MovieoffsettimeCheckBox         matlab.ui.control.CheckBox
        MoviehidetimestampCheckBox      matlab.ui.control.CheckBox
        MoviescaleEditField             matlab.ui.control.EditField
        MoviescaleEditFieldLabel        matlab.ui.control.Label
        MoviefontsizeEditField          matlab.ui.control.EditField
        MoviefontsizeEditFieldLabel     matlab.ui.control.Label
        MovietextcolorEditField         matlab.ui.control.EditField
        MovietextcolorEditFieldLabel    matlab.ui.control.Label
        MoviebackgroundcolorEditField   matlab.ui.control.EditField
        MoviebackgroundcolorEditFieldLabel  matlab.ui.control.Label
        MovieoutputtypeDropDown         matlab.ui.control.DropDown
        MovieoutputtypeDropDownLabel    matlab.ui.control.Label
        SetButton                       matlab.ui.control.Button
        MovieoutputfilenameEditField    matlab.ui.control.EditField
        MovieoutputfilenameEditFieldLabel  matlab.ui.control.Label
        MovieselectcurrentROIonlyCheckBox  matlab.ui.control.CheckBox
        MovieROIArraysizeEditField      matlab.ui.control.EditField
        MovieROIArraysizeEditFieldLabel  matlab.ui.control.Label
        MovieFramesEditField            matlab.ui.control.EditField
        MovieFramesEditFieldLabel       matlab.ui.control.Label
    end


    properties (Access = public)
        content = struct('ROIList',[]); % Description
        SliderTickLabels % Description
        HistogramEdges % Stocke les bords des bins de l'histogramme
        HistogramData  % Stocke les valeurs de l'histogramme pour chaque canal affiché
        HistogramChannels % Stocke les indices des channels affichés dans l'histogramme
        HistogramLines  % Stocke les handles des courbes pour éviter de les redessiner
        HistogramLimits % Stocke les handles des lignes de niveaux (low/high)
        LineIntensityProfileLine   % handle de l'objet imline (initialement [])
        LineProfilePosition        % position mémorisée de la ligne (par exemple, [x1 y1; x2 y2])
        EllipseIntensityProfileObj   % Handle de l'ellipse (initialement [])
        EllipseProfilePosition       % Position mémorisée (rectangle [x y width height])
        OriginalXLim
        OriginalYLim
        BaselineXLim   % Baseline X-limits à 100%
        BaselineYLim   % Baseline Y-limits à 100%
        PreviousZoomFactor
        DisplaySettings % Description
        ImageFigure
        ImageAxes
        OverlayAxes
        SelectedObjectRectangle
        SelectedObjectLabel
        DataFigure % Description
        specialkeys % Description
        keys

        graphicsHandles
        layoutOptions
        displayHandles

        KeepSelection logical = true                  % garder la sélection au refresh
        SelectedObjectChannelIdx double = NaN         % index du canal d’annotation
        SelectedObjectLabelCell double = NaN              % label de l’objet
        SelectedObjectRoiId string = ""               % id de la ROI (pour vérifier qu’on est sur la même)
        SelectedTrackIDCell double = NaN              % persistent human-facing identity
        ShowLineageOverlay logical = false
        ShowBudPairingOverlay logical = true
        AnnotationSession = []
        AnnotationDisplayPreset = struct()
        AnnotationLastValidationValid logical = false
        AnnotationQuickValidationState char = 'idle'
        AnnotationQuickValidationMessage char = ''
        AnnotationReviewDirty logical = false
    end

    properties (Access = private)
        PipelineRunEventListenerId char = ''
    end

    methods (Access = private)

        % Toggle the visibility of a panel and update menu status
        function newVisibility = toggleVisibility(~, menuItem)
            if strcmp(menuItem.Checked, 'on')
                menuItem.Checked = 'off';
                newVisibility = 'off';
            else
                menuItem.Checked = 'on';
                newVisibility = 'on';
            end
        end


        function displayROIs(app)
            % Vérifie si des ROIs sont présentes

            if isempty(app.content.ROIList)
                app.UIROITable.Data = {}; % Vide la table si aucune ROI
                return;
            end

            % Préparer les colonnes : Display, Name, Size
            numROIs = numel(app.content.ROIList);
            previousROIIndex = app.getDisplayedROIIndexExcept(numROIs);
            if ~isempty(previousROIIndex) && previousROIIndex <= numROIs
                app.copyVisibleROIPreset(app.content.ROIList{previousROIIndex}, app.content.ROIList{numROIs});
            end
            tableData = cell(numROIs, 3);

            for i = 1:numROIs
                roi = app.content.ROIList{i};
                % Récupérer l'instance de la ROI

                if i==numROIs
                    tableData{i, 1} = true; % Désactiver l'affichage par défaut
                else
                    tableData{i, 1} = false; % Désactiver l'affichage par défaut
                end

                % Colonne 2 : parent.id / roi.id si FOV, sinon classi.strid

                parentObj = roi.parent;

                if isa(parentObj, 'fov')
                    % Affiche "fovID/roiID"
                    tableData{i,2} = sprintf('%s/%s', parentObj.id, roi.id);
                elseif isa(parentObj, 'classi')

                    % Affiche seulement le strid de la classification parente
                    tableData{i,2} =sprintf('%s/%s', parentObj.strid, roi.id);
                else
                    % Cas de repli : on met juste l'ID de la ROI
                %    'no parent found'
                    tableData{i,2} = roi.id;
                end

                tableData{i, 3} = sprintf('%dx%d', size(roi.image, 1), size(roi.image, 2)); % Taille de l'image
            end

            % Mettre à jour la table
            app.UIROITable.Data = tableData;
            app.UIROITable.ColumnName = {'Display', 'Name', 'Size'};

            % Ajuster les largeurs des colonnes
            app.UIROITable.ColumnWidth = {70, 400, 100};

            % Définir un callback pour gérer les sélections
            app.UIROITable.CellEditCallback = @(src, event) app.handleROITableEdit(event);

            % Vérifier si des ROIs sont présentes dans l'application
            if isempty(app.content.ROIList)
                app.UIChannelTable.Data = {}; % Vide la table si aucune ROI
                return;
            end

            % Trouver l'index de la ROI actuellement sélectionnée
            selectedIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1); % Cherche la première ROI cochée
            if isempty(selectedIndex)
                app.UIChannelTable.Data = {}; % Vide la table si aucune ROI n'est sélectionnée
                return;
            end

            % Récupérer la ROI sélectionnée
            selectedROI = app.content.ROIList{selectedIndex};

            numFrames = size(selectedROI.image, 4);
            if numFrames==1
                app.FrameSlider.Limits = [1 1.1];
            else
                app.FrameSlider.Limits = [1 numFrames];
            end

            % Mettre à jour les limites du slider


            % Réinitialiser la valeur du slider (optionnel)
            app.FrameSlider.Value = selectedROI.display.frame;

           % displayData(app);

            displayROIChannels(app);

             % Réinitialiser la valeur du slider (optionnel)
            app.FrameSlider.Value = selectedROI.display.frame;

            if app.MovieoutputtypeDropDown.Value=="Movie"
             app.MovieoutputfilenameEditField.Value=[selectedROI.path 'output.mp4'];
            end
            if app.MovieoutputtypeDropDown.Value=="Sequence"
             app.MovieoutputfilenameEditField.Value=[selectedROI.path 'output.pdf'];
            end

             app.DisplaySettings.Movie.MovieoutputfilenameEditField=app.MovieoutputfilenameEditField.Value;

           % score_display(app, 'slow');

        end

        function roiobj = refreshROIDataFromDisk(app, roiobj) %#ok<INUSL>
            if ~isa(roiobj, 'roi') || isempty(roiobj.path) || isempty(roiobj.id)
                return;
            end

            dataFile = fullfile(roiobj.path, sprintf('data_%s.mat', roiobj.id));
            if ~isfile(dataFile)
                return;
            end

            try
                roiobj.load('data', 'Silent');
            catch ME
                warning('Score:RefreshROIData', ...
                    'Could not refresh data for ROI %s from disk: %s', roiobj.id, ME.message);
            end
        end

        function onPipelineRunCompleted(app, payload, eventName) %#ok<INUSD>
            if isempty(app) || ~isvalid(app) || isempty(app.content.ROIList) || ...
                    ~isstruct(payload) || exist('detecdiv_refresh_run_mutations', 'file') ~= 2
                return;
            end
            manifest = struct();
            if isfield(payload, 'mutationManifest') && isstruct(payload.mutationManifest)
                manifest = payload.mutationManifest;
            elseif isfield(payload, 'mutation_manifest') && isstruct(payload.mutation_manifest)
                manifest = payload.mutation_manifest;
            end
            if isempty(fieldnames(manifest))
                return;
            end
            try
                rois = [app.content.ROIList{:}];
                refresh = detecdiv_refresh_run_mutations(manifest, ...
                    'RoiList', rois, 'RetryCount', 1, 'RetryPause', 0);
                if refresh.refreshedRois < 1
                    return;
                end
                displayROIChannels(app);
                score_refreshObjectDisplayUI(app);
                score_display(app, 'slow');
            catch ME
                warning('Score:PipelineRunRefresh', ...
                    'Could not refresh Score after pipeline completion: %s', ME.message);
            end
        end

        function roiobj = refreshROIIntensityChannelsFromDisk(app, roiobj) %#ok<INUSL>
            % Score can receive an ROI handle whose image cache predates a
            % pipeline save. Refresh continuous channels before the first
            % table/render, while preserving in-memory indexed annotations.
            if ~isa(roiobj, 'roi') || isempty(roiobj.path) || isempty(roiobj.id)
                return;
            end

            h5File = fullfile(roiobj.path, sprintf('im_%s.h5', roiobj.id));
            if ~isfile(h5File) || ~isstruct(roiobj.display) || ...
                    ~isfield(roiobj.display, 'channel') || isempty(roiobj.display.channel)
                return;
            end

            names = cellstr(string(roiobj.display.channel(:)));
            indexed = false(1, numel(names));
            if isfield(roiobj.display, 'indexed') && ~isempty(roiobj.display.indexed)
                values = logical(roiobj.display.indexed(:)');
                n = min(numel(indexed), numel(values));
                indexed(1:n) = values(1:n);
            end
            names = names(~indexed);
            names = names(~cellfun(@isempty, names));
            if isempty(names)
                return;
            end

            failed = strings(0,1);
            for iName = 1:numel(names)
                try
                    score_loadChannelsForDisplay(roiobj, names(iName), 'Force', true);
                catch
                    % A stale display row can refer to a channel no longer
                    % present in H5. Keep refreshing the remaining rows.
                    failed(end+1,1) = string(names{iName}); %#ok<AGROW>
                end
            end
            if ~isempty(failed)
                warning('Score:RefreshROIImages', ...
                    'Could not refresh channel(s) %s for ROI %s from %s.', ...
                    strjoin(failed, ', '), roiobj.id, h5File);
            end
        end

        function handleROITableEdit(app, event)
      %   profile on
            % Callback pour s'assurer qu'une seule ROI est sélectionnée
            if event.Indices(2) == 1 % Si la colonne "Display" est modifiée
                % Désactiver toutes les cases sauf celle cliquée

              
                 % Optionnel : effectuer des actions basées sur la sélection
                selectedROI = app.content.ROIList{event.Indices(1)};
                previousROIIndex = app.getDisplayedROIIndexExcept(event.Indices(1));
                if ~isempty(previousROIIndex)
                    app.copyVisibleROIPreset(app.content.ROIList{previousROIIndex}, selectedROI);
                end

             %   if  app.UIROITable.Data{ event.Indices(1), 1} == false  % just refresh the display
                    
                
                numROIs = size(app.UIROITable.Data, 1);
                for i = 1:numROIs
                    if i~=event.Indices(1)
                    app.UIROITable.Data{i, 1} = false;
                    else
                    app.UIROITable.Data{i,1}= true;
                    end
                end

                % Activer uniquement la ligne sélectionnée
               % app.UIROITable.Data{event.Indices(1), 1} = true;

                % Mettre à jour la table
            %    app.UIROITable.Data = app.UIROITable.Data;

            %    end

       

                % if numel(selectedROI.image)==0
                %         selectedROI.load;
                % end

                disp(['Selected ROI: ', selectedROI.id]);
                displayROIChannels(app);
                score_refreshObjectDisplayUI(app);
                numFrames =max(2, size(selectedROI.image, 4));


                % Mettre à jour les limites du slider
                app.FrameSlider.Limits = [1 numFrames];

                % Réinitialiser la valeur du slider (optionnel)
                app.FrameSlider.Value = selectedROI.display.frame;

               % score_display(app, 'slow');
        %       profile viewer
            end

        end


        function idx = getDisplayedROIIndexExcept(app, excludedIdx)
            idx = [];
            try
                if isempty(app.UIROITable.Data)
                    return;
                end
                selected = find(cell2mat(app.UIROITable.Data(:, 1)));
                selected = selected(selected ~= excludedIdx);
                if ~isempty(selected)
                    idx = selected(1);
                end
            catch
                idx = [];
            end
        end

        function copyVisibleROIPreset(app, sourceROI, targetROI)
            if isempty(sourceROI) || isempty(targetROI) || isequal(sourceROI, targetROI)
                return;
            end

            app.copyROIChannelPreset(sourceROI, targetROI);
            app.copyROIDataPreset(sourceROI, targetROI);
        end

        function copyROIChannelPreset(~, sourceROI, targetROI)
            try
                score_copyROIChannelPreset(sourceROI, targetROI);
            catch ME
                warning('Score:CopyROIPreset:Channels', ...
                    'Could not copy ROI channel display preset: %s', ME.message);
            end
        end

        function copyROIDataPreset(app, sourceROI, targetROI)
            try
                if ~isprop(sourceROI, 'data') || isempty(sourceROI.data) || ...
                        ~isprop(targetROI, 'data') || isempty(targetROI.data)
                    return;
                end

                for s = 1:numel(sourceROI.data)
                    sourceData = sourceROI.data(s);
                    targetIdx = app.findMatchingDataseries(targetROI.data, sourceData);
                    if isempty(targetIdx)
                        continue;
                    end

                    targetData = targetROI.data(targetIdx);
                    if isprop(sourceData, 'show') && isprop(targetData, 'show')
                        targetData.show = logical(sourceData.show);
                    end
                    targetData = app.copyDataseriesPlotPreset(sourceData, targetData);
                    targetROI.data(targetIdx) = targetData;
                end
            catch ME
                warning('Score:CopyROIPreset:Data', ...
                    'Could not copy ROI data display preset: %s', ME.message);
            end
        end

        function idx = findMatchingDataseries(app, dataList, sourceData) %#ok<INUSL>
            idx = [];
            try
                if isprop(sourceData, 'groupid')
                    sourceId = char(string(sourceData.groupid));
                    ids = arrayfun(@(d) char(string(d.groupid)), dataList, 'UniformOutput', false);
                    idx = find(strcmp(ids, sourceId), 1, 'first');
                end
            catch
                idx = [];
            end
        end

        function targetData = copyDataseriesPlotPreset(app, sourceData, targetData)
            if isprop(sourceData, 'groupProperties') && isprop(targetData, 'groupProperties') && ...
                    ~isempty(sourceData.groupProperties) && ~isempty(targetData.groupProperties)
                targetData.groupProperties = app.copyRowsByName(sourceData.groupProperties, targetData.groupProperties, 1);
            end

            if isprop(sourceData, 'plotGroup') && isprop(targetData, 'plotGroup') && ~isempty(sourceData.plotGroup)
                targetData.plotGroup = sourceData.plotGroup;
            end

            if isprop(sourceData, 'plotProperties') && isprop(targetData, 'plotProperties') && ...
                    ~isempty(sourceData.plotProperties) && ~isempty(targetData.plotProperties)
                targetData.plotProperties = app.copyRowsByName(sourceData.plotProperties, targetData.plotProperties, 2);
            end
        end

        function targetRows = copyRowsByName(app, sourceRows, targetRows, nameColumn) %#ok<INUSL>
            if ~iscell(sourceRows) || ~iscell(targetRows) || ...
                    size(sourceRows, 2) < nameColumn || size(targetRows, 2) < nameColumn
                return;
            end

            nCols = min(size(sourceRows, 2), size(targetRows, 2));
            targetNames = cellstr(string(targetRows(:, nameColumn)));
            for i = 1:size(sourceRows, 1)
                sourceName = char(string(sourceRows{i, nameColumn}));
                idx = find(strcmp(targetNames, sourceName), 1, 'first');
                if ~isempty(idx)
                    targetRows(idx, 1:nCols) = sourceRows(i, 1:nCols);
                end
            end
        end

        function presets = collectDataseriesDisplayPresets(app, roiObj) %#ok<INUSL>
            presets = struct('groupid', {}, 'id', {}, 'show', {}, ...
                'plotProperties', {}, 'plotGroup', {}, 'groupProperties', {});
            try
                if isempty(roiObj) || ~isprop(roiObj, 'data') || isempty(roiObj.data)
                    return;
                end
                for i = 1:numel(roiObj.data)
                    ds = roiObj.data(i);
                    item = struct();
                    item.groupid = '';
                    item.id = '';
                    item.show = true;
                    item.plotProperties = {};
                    item.plotGroup = {};
                    item.groupProperties = {};
                    if isprop(ds, 'groupid'), item.groupid = char(string(ds.groupid)); end
                    if isprop(ds, 'id'), item.id = char(string(ds.id)); end
                    if isprop(ds, 'show'), item.show = logical(ds.show); end
                    if isprop(ds, 'plotProperties'), item.plotProperties = ds.plotProperties; end
                    if isprop(ds, 'plotGroup'), item.plotGroup = ds.plotGroup; end
                    if isprop(ds, 'groupProperties'), item.groupProperties = ds.groupProperties; end
                    presets(end+1) = item; %#ok<AGROW>
                end
            catch ME
                warning('Score:CollectDataPreset', ...
                    'Could not collect dataseries display presets: %s', ME.message);
            end
        end

        function applyDataseriesDisplayPresets(app, roiObj, dataPresets)
            try
                if isempty(roiObj) || isempty(dataPresets) || ...
                        ~isprop(roiObj, 'data') || isempty(roiObj.data)
                    return;
                end
                for i = 1:numel(dataPresets)
                    idx = app.findMatchingDataseriesPreset(roiObj.data, dataPresets(i));
                    if isempty(idx)
                        continue;
                    end
                    ds = roiObj.data(idx);
                    if isfield(dataPresets(i), 'show') && isprop(ds, 'show')
                        ds.show = logical(dataPresets(i).show);
                    end
                    if isfield(dataPresets(i), 'groupProperties') && isprop(ds, 'groupProperties') && ...
                            ~isempty(dataPresets(i).groupProperties)
                        ds.groupProperties = dataPresets(i).groupProperties;
                    end
                    if isfield(dataPresets(i), 'plotGroup') && isprop(ds, 'plotGroup') && ...
                            ~isempty(dataPresets(i).plotGroup)
                        ds.plotGroup = dataPresets(i).plotGroup;
                    end
                    if isfield(dataPresets(i), 'plotProperties') && isprop(ds, 'plotProperties') && ...
                            ~isempty(dataPresets(i).plotProperties)
                        if isempty(ds.plotProperties) || isequal(size(ds.plotProperties), size(dataPresets(i).plotProperties))
                            ds.plotProperties = dataPresets(i).plotProperties;
                        else
                            ds.plotProperties = app.copyRowsByName(dataPresets(i).plotProperties, ds.plotProperties, 2);
                        end
                    end
                    roiObj.data(idx) = ds;
                end
            catch ME
                warning('Score:ApplyDataPreset', ...
                    'Could not apply dataseries display presets: %s', ME.message);
            end
        end

        function idx = findMatchingDataseriesPreset(app, dataList, preset) %#ok<INUSL>
            idx = [];
            try
                if isfield(preset, 'groupid') && strlength(string(preset.groupid)) > 0
                    ids = arrayfun(@(d) char(string(d.groupid)), dataList, 'UniformOutput', false);
                    idx = find(strcmp(ids, char(string(preset.groupid))), 1, 'first');
                end
                if isempty(idx) && isfield(preset, 'id') && strlength(string(preset.id)) > 0
                    ids = arrayfun(@(d) char(string(d.id)), dataList, 'UniformOutput', false);
                    idx = find(strcmp(ids, char(string(preset.id))), 1, 'first');
                end
            catch
                idx = [];
            end
        end

        function roi = getSelectedROI(app)
            roi = [];
            try
                if isempty(app.content.ROIList) || isempty(app.UIROITable.Data)
                    return;
                end
                selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
                if isempty(selectedROIIndex)
                    return;
                end
                roi = app.content.ROIList{selectedROIIndex};
            catch
                roi = [];
            end
        end

        function [roi, channelName, pix, sourceHint] = selectedPaintLineageChannel(app)
            roi = app.getSelectedROI();
            channelName = '';
            pix = [];
            sourceHint = '';
            if isempty(roi) || isempty(app.UIAnnotationTable.Selection)
                return;
            end

            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1)) || isempty(app.UIAnnotationTable.Data)
                return;
            end

            annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
            classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};
            if isempty(classPart)
                channelName = char(string(annotationPart));
            else
                channelName = [char(string(annotationPart)) '_' char(string(classPart))];
            end
            sourceHint = channelName;

            channelIdx = find(strcmp(roi.display.channel, channelName), 1, 'first');
            if isempty(channelIdx)
                channelName = '';
                return;
            end
            pix = roi.findChannelID(roi.display.channel{channelIdx});
            if isempty(pix) || numel(pix) ~= 1 || pix < 1
                channelName = '';
                pix = [];
            end
        end

        function key = syncLineageDisplayForPaintChannel(app)
            key = '';
            roi = app.getSelectedROI();
            if isempty(roi)
                return;
            end

            lineageUI = score_lineageDisplayOptions(app);
            showBud = lineageUI.showBudPairing;
            showGenealogy = lineageUI.showGenealogy;
            app.ShowBudPairingOverlay = showBud;
            app.ShowLineageOverlay = showGenealogy;

            if ~showBud && ~showGenealogy
                app.clearLineageDisplayForROI(roi);
                return;
            end

            [roi, channelName, pix, ~] = app.selectedPaintLineageChannel();
            if isempty(roi) || isempty(channelName)
                key = app.restoreLineageDisplayFromUserData(roi, showBud, showGenealogy);
                if isempty(key)
                    app.clearLineageDisplayForROI(roi);
                end
                return;
            end

            cfg = score_getObjectDisplayConfig(roi, channelName);
            if strcmp(cfg.lineageSource, '<none>')
                app.clearLineageDisplayForROI(roi);
                return;
            end
            key = score_configureLineageDisplay(roi, channelName, pix, cfg, ...
                showBud, showGenealogy);
            if isempty(key)
                key = app.restoreLineageDisplayFromUserData(roi, showBud, showGenealogy);
                if isempty(key)
                    app.clearLineageDisplayForROI(roi);
                end
                return;
            end

            % score_configureLineageDisplay owns the display-only binding.
        end

        function key = restoreLineageDisplayFromUserData(app, roi, showBud, showGenealogy) %#ok<INUSL>
            key = '';
            if isempty(roi)
                return;
            end
            try
                idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(char(string(x.groupid)), 'cell_information'), roi.data), 1, 'first');
                if isempty(idx) || ~isstruct(roi.data(idx).userData)
                    return;
                end
                ud = roi.data(idx).userData;
                if ~isfield(ud, 'lineageSources') || ~isstruct(ud.lineageSources)
                    return;
                end
                sourceKey = '';
                if isfield(ud, 'activeLineageSource') && ~isempty(ud.activeLineageSource) && ...
                        isfield(ud.lineageSources, char(string(ud.activeLineageSource)))
                    sourceKey = char(string(ud.activeLineageSource));
                elseif isfield(ud, 'motherOfSourceKey') && ~isempty(ud.motherOfSourceKey) && ...
                        isfield(ud.lineageSources, char(string(ud.motherOfSourceKey)))
                    sourceKey = char(string(ud.motherOfSourceKey));
                else
                    fields = fieldnames(ud.lineageSources);
                    for i = 1:numel(fields)
                        srcCandidate = ud.lineageSources.(fields{i});
                        if isfield(srcCandidate, 'motherOf') && isa(srcCandidate.motherOf, 'containers.Map') && srcCandidate.motherOf.Count > 0
                            sourceKey = fields{i};
                            break;
                        end
                    end
                end
                if isempty(sourceKey)
                    return;
                end
                src = ud.lineageSources.(sourceKey);
                channelName = '';
                if isfield(src, 'channelName') && ~isempty(src.channelName)
                    channelName = char(string(src.channelName));
                elseif isfield(ud, 'lineageChannelName') && ~isempty(ud.lineageChannelName)
                    channelName = char(string(ud.lineageChannelName));
                end
                if isempty(channelName)
                    return;
                end
                pix = [];
                try
                    pix = roi.findChannelID(channelName);
                catch
                    pix = [];
                end
                if isempty(pix) && isfield(src, 'channelPix') && ~isempty(src.channelPix)
                    pix = double(src.channelPix);
                elseif isempty(pix) && isfield(ud, 'lineageChannelPix') && ~isempty(ud.lineageChannelPix)
                    pix = double(ud.lineageChannelPix);
                end
                if isempty(pix) || numel(pix) ~= 1 || pix < 1
                    return;
                end
                src.show = true;
                ud.lineageSources.(sourceKey) = src;
                ud.activeLineageSource = sourceKey;
                ud.lineageChannelName = string(channelName);
                ud.lineageChannelPix = double(pix);
                ud.activeLineageChannelName = channelName;
                roi.data(idx).userData = ud;

                roi.display.lineage = struct( ...
                    'enabled', true, ...
                    'channelName', channelName, ...
                    'channelPix', double(pix), ...
                    'sourceKey', sourceKey, ...
                    'showBudPairing', logical(showBud), ...
                    'showGenealogy', logical(showGenealogy), ...
                    'budWindowBefore', 0, ...
                    'budWindowAfter', 6);
                key = sourceKey;
            catch ME
                warning('Score:LineageRestore', ...
                    'Could not restore lineage display from userData: %s', ME.message);
                key = '';
            end
        end

        function clearLineageDisplayForROI(app, roi) %#ok<INUSL>
            if isempty(roi)
                return;
            end
            try
                roi.display.lineage = struct( ...
                    'enabled', false, ...
                    'channelName', '', ...
                    'channelPix', [], ...
                    'sourceKey', '', ...
                    'showBudPairing', false, ...
                    'showGenealogy', false, ...
                    'budWindowBefore', 0, ...
                    'budWindowAfter', 6);
            catch
            end
        end

        function LineageDisplayCheckBoxValueChanged(app, event) %#ok<INUSD>
            try
                app.syncLineageDisplayForPaintChannel();
                score_display(app, 'refresh');
            catch ME
                warning('Score:LineageDisplay', ...
                    'Could not refresh lineage display: %s', ME.message);
            end
        end

        function ObjectDisplayModeChanged(app, event)
            score_storeObjectDisplayUI(app);
            app.PaintButtonValueChanged(event);
            score_refreshObjectDisplayUI(app);
        end

        function ObjectDisplaySettingChanged(app, event) %#ok<INUSD>
            try
                score_storeObjectDisplayUI(app);
                app.syncLineageDisplayForPaintChannel();
                score_refreshObjectDisplayUI(app);
                score_display(app, 'refresh');
            catch ME
                warning('Score:ObjectDisplaySetting', ...
                    'Could not apply object display setting: %s', ME.message);
            end
        end

        function ObjectDisplayColorChanged(app, event) %#ok<INUSD>
            try
                score_storeObjectDisplayUI(app);
                score_storeCellModelColors(app);
                app.syncLineageDisplayForPaintChannel();
                score_refreshObjectDisplayUI(app);
                score_display(app, 'refresh');
            catch ME
                warning('Score:ObjectDisplayColor', ...
                    'Could not apply cellular display color: %s', ME.message);
            end
        end

        function ObjectMaskProviderChanged(app, event) %#ok<INUSD>
            try
                score_storeObjectDisplayUI(app);
                score_updateCellModelMaskProvider(app);
                app.syncLineageDisplayForPaintChannel();
                score_refreshObjectDisplayUI(app);
                score_display(app, 'refresh');
            catch ME
                warning('Score:ObjectMaskProvider', ...
                    'Could not change the family mask provider: %s', ME.message);
                score_refreshObjectDisplayUI(app);
            end
        end

        function displayROIChannels(app)

            % Vérifier si des ROIs sont présentes dans l'application
            if isempty(app.content.ROIList)
                app.UIChannelTable.Data = {}; % Vide la table si aucune ROI
                return;
            end

            % Trouver l'index de la ROI actuellement sélectionnée
            selectedIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1); % Cherche la première ROI cochée
            if isempty(selectedIndex)
                app.UIChannelTable.Data = {}; % Vide la table si aucune ROI n'est sélectionnée
                return;
            end

            % Récupérer la ROI sélectionnée
            selectedROI = app.content.ROIList{selectedIndex};

            % Vérifier si la ROI a des canaux disponibles
            if isempty(selectedROI.display.channel)
                app.UIChannelTable.Data = {}; % Vide la table si aucun canal
                return;
            end

            % % Préparer la liste des canaux affichables :
            % % On inclut les canaux dont l'intensité n'est pas nulle et aussi ceux qui correspondent à des images RGB (3 canaux)
             numChannels = numel(selectedROI.display.channel);
            score_applyDefaultChannelSelection(selectedROI);
            % 
            % colorChannels = [];
            % indexedChannels=[];
            % 
            % 
            % for i = 1:numChannels
            %     % Vérifier si le canal correspond à une image RGB
            % 
            %     pix = selectedROI.findChannelID(selectedROI.display.channel{i});
            % 
            %     if numel(pix)==3
            %         % Canal RGB détecté, on l'inclut
            %         colorChannels = [colorChannels i];
            %         selectedROI.display.indexed(i)=false;
            %     else
            %         % Pour les autres canaux, on ne les inclut que si l'intensité n'est pas nulle
            %       %  tmp=sum(selectedROI.display.intensity(i, :)) 
            %         if sum(selectedROI.display.intensity(i, :)) == 0
            %             indexedChannels=[ indexedChannels i];
            %           %  'okk'
            %             selectedROI.display.indexed(i)=true;
            %             % continue;
            % 
            %         else
            %         %    'no'
            %             colorChannels = [colorChannels i];
            %             selectedROI.display.indexed(i)=false;
            %         end
            %     end
            % end

            % --- Assure display.indexed cohérent ---
if ~isfield(selectedROI.display,'indexed') || isempty(selectedROI.display.indexed)
    selectedROI.display.indexed = false(1, numChannels);
elseif numel(selectedROI.display.indexed) < numChannels
    selectedROI.display.indexed(numel(selectedROI.display.indexed)+1:numChannels) = false;
elseif numel(selectedROI.display.indexed) > numChannels
    selectedROI.display.indexed = selectedROI.display.indexed(1:numChannels);
end

colorChannels = [];
indexedChannels = [];

for i = 1:numChannels
    pix = selectedROI.findChannelID(selectedROI.display.channel{i});

    if numel(pix)==3
        colorChannels = [colorChannels i];
        selectedROI.display.indexed(i)=false;
    else
        if selectedROI.display.indexed(i)
            indexedChannels = [indexedChannels i];
        else
            colorChannels = [colorChannels i];
        end
    end
end



            % Préparer les colonnes pour la table : Display, Name, Levels, RGB, Weight, Auto
            app.initializeChannelScaleForScore(selectedROI);
            tableData = cell(numel(colorChannels), 8);


            for i = 1:numel(colorChannels)
                chIndex = colorChannels(i);
                % Colonne "Display" : checkbox indiquant si le canal doit être affiché
                tableData{i, 1} = logical(selectedROI.display.selectedchannel(chIndex));
                % Colonne "Name" : nom du canal
                tableData{i, 2} = selectedROI.display.channel{chIndex};
                if isfield(selectedROI.display, 'channelAlias') && numel(selectedROI.display.channelAlias) >= chIndex && ...
                        strlength(string(selectedROI.display.channelAlias{chIndex})) > 0
                    tableData{i, 2} = char(string(selectedROI.display.channelAlias{chIndex}));
                end
                tableData{i, 3} = logical(selectedROI.display.scale(chIndex));
                % Colonne "Levels" : niveaux d'affichage (convertis en échelle 0-65535)

  nCh = size(selectedROI.image, 3);

needRecompute = ...
    ~isfield(selectedROI.display,'displaylim') || ...
    isempty(selectedROI.display.displaylim) || ...
    size(selectedROI.display.displaylim,1) ~= 2 || ...
    size(selectedROI.display.displaylim,2) ~= nCh;

if ~needRecompute
    dl = selectedROI.display.displaylim;

    low  = dl(1,:);
    high = dl(2,:);

    % channel invalid if: NaN/Inf OR low>=high OR degenerate defaults
    bad = ~isfinite(low) | ~isfinite(high) | (high <= low) | ...
          (low==1 & high==1) | (low==0 & high==0) | (low==0 & high==1);

    needRecompute = any(bad);
end

if needRecompute
    disp('Computing displaylim...')
    selectedROI.computeDisplaylim;
end

% map logical channel -> first sub-channel
subIdx = find(selectedROI.channelid == chIndex, 1, 'first');
if isempty(subIdx)
    subIdx = chIndex; % fallback
end

dl = selectedROI.display.displaylim;
tableData{i, 4} = sprintf('%.0f %.0f', ...
    round(65535 * dl(1, subIdx)), ...
    round(65535 * dl(2, subIdx)));


             %   tableData{i, 3} = sprintf('%.0f %.0f', round(65535 * selectedROI.display.displaylim(1, chIndex)), round(65535 * selectedROI.display.displaylim(2, chIndex)));
                % Colonne "RGB" : affichage de la couleur (pour les images RGB, vous pouvez afficher par exemple 'RGB' ou la valeur si définie)
                if numel(selectedROI.findChannelID(selectedROI.display.channel{chIndex}))==3
                    % Optionnel : vous pouvez afficher "RGB" ou une valeur par défaut
                    tableData{i, 5} = 'RGB';
                else
                    tableData{i, 5} = score_channelColorSpec(selectedROI.display, chIndex);
                end
                % Colonne "Weight" : poids du canal


                tableData{i, 6} = sprintf('%.1f', selectedROI.display.alpha(chIndex));

                % Colonne "Auto" : par défaut, "Auto" est désactivé
                tableData{i, 7} = false;
                tableData{i, 8} = selectedROI.display.log(chIndex);

            end

            % Mettre à jour la table et ses propriétés
            app.UIChannelTable.Data = tableData;
            app.UIChannelTable.ColumnName = {'Display', 'Name', 'Scale', 'Levels', 'RGB', 'Weight', 'Auto','Log'};
            app.UIChannelTable.ColumnWidth = {70, 200, 55, 70, 70, 70, 50, 50};
            % Rendre certaines colonnes éditables (ici Display, Levels, RGB, Weight, Auto)
            app.UIChannelTable.ColumnEditable = [true, true, true, true, true, true, true, true];

            % Définir le callback pour gérer les modifications
            app.UIChannelTable.CellEditCallback = @(src, event) app.handleChannelTableEdit(event, selectedROI, colorChannels);


            nIndexed = numel(indexedChannels);
            tableDataIndex = cell(nIndexed, 3);  % colonnes: Display, Annotation, Class
            for i = 1:nIndexed
                chIndex = indexedChannels(i);
                % Colonne "Display": case à cocher (selon la sélection actuelle)
                tableDataIndex{i, 1} = logical(selectedROI.display.selectedchannel(chIndex));

                % Récupérer le nom complet du canal
                channelName = selectedROI.display.channel{chIndex};
                pos = strfind(channelName, '_');

                if isempty(pos)
                    % Aucun underscore : tout est annotationName
                    annotationName = channelName;
                    className = '';
                else
                    % Chercher le dernier underscore
                    lastUnderscore = pos(end);
                    suffix = channelName(lastUnderscore+1:end);

                    if all(isstrprop(suffix, 'digit'))
                        % Le suffixe est un nombre → on cherche le dernier '_' AVANT ce suffixe numérique
                        % => on prend le premier underscore pour couper
                        firstUnderscore = pos(1);
                        annotationName = channelName(1:firstUnderscore-1);
                        className = channelName(firstUnderscore+1:end);
                    else
                        % Le suffixe n'est pas un nombre → séparer au dernier underscore
                        annotationName = channelName(1:lastUnderscore-1);
                        className = channelName(lastUnderscore+1:end);
                    end
                end


                tableDataIndex{i, 2} = annotationName;
                tableDataIndex{i, 3} = className;

                tableDataIndex{i, 4} = selectedROI.display.alpha(chIndex);
                tableDataIndex{i, 5} = selectedROI.display.contour(chIndex);
                tableDataIndex{i, 6} = selectedROI.display.width(chIndex);

            end


            app.UIAnnotationTable.Data = tableDataIndex;
            app.UIAnnotationTable.ColumnName = {'Display', 'Annotation', 'Class','Weight','Contour', 'Width'};
            app.UIAnnotationTable.ColumnWidth = {70, 200, 100, 70, 70, 70};
            app.UIAnnotationTable.ColumnEditable = [true, true, true,true,true, true];


            app.UIAnnotationTable.CellEditCallback = @(src, event) app.handleIndexedChannelTableEdit(event, selectedROI, indexedChannels);




            displayData(app);

            % Mettre à jour l'affichage des features du channel et redessiner l'image si besoin
            displayChannelFeatures(app);


            %  score_display(app, 'slow'); % unchecked because crashed ellips
            %  mode

        end




        function handleChannelTableEdit(app, event, selectedROI, colorChannels)
            % Callback pour gérer l'édition de la table des canaux
            rowIndex = event.Indices(1); % Index de la ligne modifiée
            colIndex = event.Indices(2); % Index de la colonne modifiée
            chIndex = colorChannels(rowIndex); % Trouver le bon index du channel

            switch colIndex
                case 1 % Modification dans la colonne "Display" (checkbox)
                    selectedROI.display.selectedchannel(chIndex) = event.NewData;

                case 2 % Modification dans la colonne "Name" (alias d'affichage)
                    if ~isfield(selectedROI.display, 'channelAlias') || numel(selectedROI.display.channelAlias) < numel(selectedROI.display.channel)
                        selectedROI.display.channelAlias = selectedROI.display.channel;
                    end
                    selectedROI.display.channelAlias{chIndex} = char(string(event.NewData));

                case 3 % Modification dans la colonne "Scale" (checkbox)
                    selectedROI.display.scale(chIndex) = logical(event.NewData);

case 4
     % Expect: "low high" in uint16 units (0..65535)
    vals = sscanf(event.NewData, '%f');
    if numel(vals) < 2
        uialert(app.ScoreAppUIFigure, ...
            'Displaylim must be two numbers: "low high" (0..65535).', ...
            'Invalid Input');
        app.displayROIChannels();
        return;
    end

    lo16 = max(0, min(65535, vals(1)));
    hi16 = max(0, min(65535, vals(2)));
    if hi16 <= lo16
        hi16 = min(65535, lo16 + 1);
    end

    % Normalize to [0..1]
    low  = lo16 / 65535;
    high = hi16 / 65535;

    % map logical channel -> subchannels
    pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
    subIdx = pix(1);

    selectedROI.display.displaylim(:, subIdx) = [low; high];

    % if RGB, apply to all 3 subchannels
    if numel(pix)==3
        selectedROI.display.displaylim(:, pix) = repmat([low; high], 1, 3);
    end

   % selectedROI.display.displaylim(:, chIndex) = double([lo16; hi16]) / 65535;



                case 5 % Modification dans la colonne "RGB"
                    % Valider l'entrée comme un triplet RGB
                    [ok, message] = score_applyChannelColorSpec(selectedROI, chIndex, event.NewData);

                    if ok
                        disp('Color spec parsed successfully');
                    else
                        disp('Invalid RGB input format');
                    end

                    if ~ok
                        uialert(app.ScoreAppUIFigure, message, 'Invalid Input');
                        app.displayROIChannels();
                        return;
                    end

                case 6 % Modification dans la colonne "Weight"
                    % Valider l'entrée comme un nombre positif
                    weightValue = str2double(event.NewData);
                    if ~isnan(weightValue) && weightValue >= 0
                        selectedROI.display.alpha(chIndex) = min(1,max(0.01,weightValue));

                    else
                        uialert(app.ScoreAppUIFigure, 'Weight must be a positive number.', 'Invalid Input');
                        app.displayROIChannels(); % Réinitialiser la table
                    end

                case 7 % Modification dans la colonne "Auto" (checkbox pour auto-adjust)
                    if event.NewData

                        % Appliquer un auto-ajustement des niveaux
                       selectedROI.computeDisplaylim('Channel', chIndex);
                        app.displayROIChannels();

                    end
                 case 8 % Modification dans la colonne "Log"
                  %  if event.NewData

                 
                        % Appliquer un auto-ajustement des niveaux
                       selectedROI.display.log(chIndex) = event.NewData;
                       % app.displayROIChannels(); % Mettre à jour la table
                  %  end


            end

            displayChannelFeatures(app);
            displayData(app);
            if any(colIndex == [2 3 4 5 6 7 8])
                score_display(app, 'slow');
            end
           % score_display(app, 'slow');

            % event=[];
            % event.Value= log10(selectedROI.display.displaylim(1, chIndex));
            % LowDisplaySliderValueChanging(app, event);
            % event.Value= log10(selectedROI.display.displaylim(2, chIndex));
            % HighDisplaySliderValueChanging(app, event);
        end


        function displayChannelFeatures(app)

           % Vérifier qu'une ROI est sélectionnée
    if isempty(app.content.ROIList)
        return;
    end

    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
    if isempty(selectedROIIndex)
        return;
    end
    selectedROI = app.content.ROIList{selectedROIIndex};

    % Vérifier qu'un canal est sélectionné dans la table des canaux
    selectedChannelIndex = app.UIChannelTable.Selection;
    if isempty(selectedChannelIndex) || isempty(selectedChannelIndex(1))
        return;
    end

    rowIdx = selectedChannelIndex(1);
    if rowIdx > size(app.UIChannelTable.Data, 1)
        return;
    end

    % Récupérer le nom du channel sélectionné
    selectedChannelName = app.UIChannelTable.Data{rowIdx, 2};

    % Trouver l'index logique du channel
    channelIndex = app.resolveDisplayChannelIndex(selectedROI, selectedChannelName);
    if isempty(channelIndex)
        if ~isempty(selectedROI.display.channel)
            channelIndex = 1;
            app.UIChannelTable.Selection = [1, 2];
        else
            return;
        end
    end

    % Map logical channel -> first subchannel index
    subIdx = [];
    try
        pix = selectedROI.findChannelID(selectedROI.display.channel{channelIndex});
        if ~isempty(pix)
            subIdx = pix(1);
        end
    catch
        subIdx = [];
    end
    if isempty(subIdx)
        if isfield(selectedROI.display, 'displaylim') && ~isempty(selectedROI.display.displaylim)
            subIdx = min(channelIndex, size(selectedROI.display.displaylim, 2));
        else
            subIdx = channelIndex;
        end
        if subIdx < 1, subIdx = 1; end
    end

    % Ensure displaylim exists and is valid
    nSub = size(selectedROI.image, 3);
    if isempty(nSub) || nSub == 0
        nSub = max(subIdx, 1);
    end

    needRecompute = ...
        ~isfield(selectedROI.display,'displaylim') || ...
        isempty(selectedROI.display.displaylim) || ...
        size(selectedROI.display.displaylim,1) ~= 2 || ...
        size(selectedROI.display.displaylim,2) < nSub;

    if needRecompute
        try
            selectedROI.computeDisplaylim;
        catch
            selectedROI.display.displaylim = [0; 1];
        end
    end

    dl = selectedROI.display.displaylim;
    if size(dl,2) < subIdx
        dl(:, end+1:subIdx) = repmat([0;1], 1, subIdx - size(dl,2));
        selectedROI.display.displaylim = dl;
    end

    dlim = selectedROI.display.displaylim(:, subIdx);
    if isempty(dlim) || numel(dlim) ~= 2 || any(~isfinite(dlim))
        dlim = [0; 1];
    end

    % clamp + ensure increasing
    dlim(1) = max(0, min(1, dlim(1)));
    dlim(2) = max(0, min(1, dlim(2)));
    if dlim(2) <= dlim(1)
        dlim(2) = min(1, dlim(1) + 1/65535);
    end

    % Slider limits (log scale)
    minVal = 1;
    maxVal = 65535;
    logMin = log10(minVal);
    logMax = log10(maxVal);
    app.LowHighDisplaySlider.Limits = [logMin, logMax];

    lowLevel  = max(65535 * dlim(1), 1);
    highLevel = min(65535 * dlim(2), 65535);

    valLow  = log10(lowLevel);
    valHigh = log10(highLevel);
    if valLow > valHigh
        [valLow, valHigh] = deal(valHigh, valLow);
    end

    % clamp to slider limits
    valLow  = max(logMin, min(logMax, valLow));
    valHigh = max(logMin, min(logMax, valHigh));
    if valHigh < valLow
        valHigh = valLow;
    end

    app.LowHighDisplaySlider.Value = [valLow, valHigh];

    % Color picker
    rgbValues = [1 1 1];
    if isfield(selectedROI.display,'rgb') && size(selectedROI.display.rgb,1) >= channelIndex
        rgbValues = selectedROI.display.rgb(channelIndex, :);
        if numel(rgbValues) ~= 3 || any(~isfinite(rgbValues))
            rgbValues = [1 1 1];
        end
    end
    app.ChannelColorPicker.Value = rgbValues;

    % Weight slider
    weightValue = 1;
    if isfield(selectedROI.display,'alpha') && numel(selectedROI.display.alpha) >= channelIndex
        weightValue = selectedROI.display.alpha(channelIndex);
    end
    weightValue = min(1, max(0, weightValue));
    app.WeightSlider.Value = weightValue;

        end

        function updateChannelTable(app, selectedROI)


            % Vérifier si la table est vide ou si aucun canal n'est affiché
            if isempty(app.UIChannelTable.Data)
                return;
            end

            % Trouver les canaux à afficher (colorChannels)
            numChannels = size(selectedROI.display.rgb, 1);
            colorChannels = [];

            for i = 1:numChannels
                % Vérifier si le canal correspond à une image RGB
                pix = selectedROI.findChannelID(selectedROI.display.channel{i});
                if numel(pix)==3
                    % Canal RGB détecté, on l'inclut
                    colorChannels = [colorChannels i];
                    selectedROI.display.indexed(i)=false;
                else
                    % Pour les autres canaux, on ne les inclut que si l'intensité n'est pas nulle
                    if sum(selectedROI.display.intensity(i, :)) == 0
         
                        %  indexedChannels=[ indexedChannels i];
                        selectedROI.display.indexed(i)=true;
                        % continue;

                    else
                        colorChannels = [colorChannels i];
                        selectedROI.display.indexed(i)=false;
                    end
                end
            end

            % for i = 1:numChannels
            %     if sum(selectedROI.display.intensity(i, :)) == 0
            %         if ~isfield(selectedROI.display,'indexed') || numel(selectedROI.display.indexed)<=i
            %             selectedROI.display.indexed(i)=true;
            %
            %         end
            %         continue; % Skip les canaux indexés (intensity == 0)
            %     end
            %     colorChannels = [colorChannels, i]; % Stocke les indices des canaux affichables
            %     if ~isprop(selectedROI.display,'indexed') || numel(selectedROI.display.indexed)<=i
            %         selectedROI.display.indexed(i)=false;
            %     end
            % end

            % Vérifier qu'on a bien des canaux valides
            if isempty(colorChannels)
                app.UIChannelTable.Data = {}; % Vide la table si aucun canal valide
                return;
            end



            % Récupérer les données actuelles de la table
            tableData = app.UIChannelTable.Data;

            for i = 1:numel(colorChannels)
                chanIndex = colorChannels(i); % Indice réel du canal dans `selectedROI.display`

                % Mettre à jour la colonne "Levels" (conversion en 65535)
                tableData{i, 3} = logical(selectedROI.display.scale(chanIndex));
                tableData{i, 4} = sprintf('%.2f %.2f', ...
                    round(65535 * selectedROI.display.displaylim(1, chanIndex)), ...
                    round(65535 * selectedROI.display.displaylim(2, chanIndex)));

                % Mettre à jour la colonne "RGB" (sans crochets)
                tableData{i, 5} = score_channelColorSpec(selectedROI.display, chanIndex);


                % Mettre à jour la colonne "Weight"
                %   if ~isprop(selectedROI.display,'alpha') || numel(selectedROI.display.alpha)<chanIndex
                %       selectedROI.display.alpha(chanIndex)=1;
                %   end
                tableData{i, 6} = sprintf('%.2f', selectedROI.display.alpha(chanIndex));

                tableData{i, 8} =  selectedROI.display.log(chanIndex);

            end

            % Mettre à jour les données de la table
            app.UIChannelTable.Data = tableData;
            score_display(app, 'refresh');
        end

        function initializeChannelScaleForScore(app, selectedROI) %#ok<INUSD>
            nCh = numel(selectedROI.display.channel);
            if ~isfield(selectedROI.display, 'scale') || isempty(selectedROI.display.scale)
                scale = false(1, nCh);
            else
                scale = logical(selectedROI.display.scale(:)');
                scale = scale(1:min(numel(scale), nCh));
                if numel(scale) < nCh
                    scale(end+1:nCh) = false;
                end
            end

            selectedROI.display.scale = scale;
        end

    function handleIndexedChannelTableEdit(app, event, selectedROI, indexedChannels)
    rowIndex = event.Indices(1); % ligne modifiée
    colIndex = event.Indices(2); % colonne modifiée
    chIndex  = indexedChannels(rowIndex);

    % Récupérer le nom de canal existant et découper avec le DERNIER '_'
    oldChannelName = selectedROI.display.channel{chIndex};
    [currentAnnotation, currentClass] = splitChannelName(oldChannelName);

    switch colIndex
        case 1
            % Colonne "Display" (booléen)
            selectedROI.display.selectedchannel(chIndex) = logical(event.NewData);

        case 2
            % Colonne "Annotation" : conserver la classe telle quelle
            newAnnotation = char(event.NewData);
            selectedROI.display.channel{chIndex} = joinChannelName(newAnnotation, currentClass);

        case 3
            % Colonne "Class" : conserver l’annotation telle quelle
            newClass = char(event.NewData);
            selectedROI.display.channel{chIndex} = joinChannelName(currentAnnotation, newClass);

        case 4
            selectedROI.display.alpha(chIndex)   = event.NewData;
        case 5
            selectedROI.display.contour(chIndex) = event.NewData;
        case 6
            selectedROI.display.width(chIndex)   = event.NewData;
    end

    % Rafraîchir l'affichage
    displayChannelFeatures(app);
    score_display(app, 'slow');

    % ===== Helpers =====
    function [annot, cls] = splitChannelName(name)
        % Découpe sur le DERNIER underscore. Si aucun, cls=''
        if ~ischar(name) && ~isstring(name), name = char(string(name)); end
        name = char(name);
        pos = find(name == '_', 1, 'last');
        if isempty(pos)
            annot = name;
            cls   = '';
        else
            annot = name(1:pos-1);
            cls   = name(pos+1:end);
        end
    end

    function out = joinChannelName(annot, cls)
        % Concatène proprement, sans underscore final si cls vide
        annot = strtrim(string(annot));
        cls   = strtrim(string(cls));
        if strlength(cls) > 0
            out = char(annot + "_" + cls);
        else
            out = char(annot);
        end
    end
end


        % Méthode pour configurer les callbacks des composants "Movie..."
        function setupMovieCallbacks(app)
            % Récupérer la liste de toutes les propriétés de l'app
            allProps = properties(app);
            % Filtrer celles qui commencent par 'Movie'
            movieProps = allProps(startsWith(allProps, 'Movie'));


            app.DisplaySettings = evalin('base', 'DisplaySettings');

            initMovieDisplaySettings(app);
            if ~isfield(app.DisplaySettings.Movie, 'MovieeventmarkersEditField')
                app.DisplaySettings.Movie.MovieeventmarkersEditField = app.MovieeventmarkersEditField.Value;
            end
            app.DisplaySettings.Movie.defaultClass=app.isthedefautcolorCheckBox.Value;
            app.DisplaySettings.Movie.paintChannel=0;
            app.DisplaySettings.Movie.OverlayCheckBox=app.OverlayCheckBox.Value;




            % Pour chaque composant dont le nom commence par "Movie"
            for i = 1:length(movieProps)
                propName = movieProps{i};
                comp = app.(propName);

                % Selon le type de composant, assigner la callback appropriée
                if isa(comp, 'matlab.ui.control.EditField')
                    comp.ValueChangedFcn = @(src, event) movieComponentCallback(app, propName, src, event);
                elseif isa(comp, 'matlab.ui.control.Slider')
                    comp.ValueChangingFcn = @(src, event) movieComponentCallback(app, propName, src, event);
                elseif isa(comp, 'matlab.ui.control.CheckBox')
                    comp.ValueChangedFcn = @(src, event) movieComponentCallback(app, propName, src, event);
                elseif isa(comp, 'matlab.ui.control.DropDown')
                    comp.ValueChangedFcn = @(src, event) movieComponentCallback(app, propName, src, event);
                end
            end

            assignin('base', 'DisplaySettings',app.DisplaySettings);

        end

        function initMovieDisplaySettings(app)
            % S'assurer que la sous-structure DisplaySettings.Movie existe
            if ~isfield(app.DisplaySettings, 'Movie')
                app.DisplaySettings.Movie = struct();

                % Récupérer la liste de toutes les propriétés de l'app commençant par "Movie"
                allProps = properties(app);
                movieProps = allProps(startsWith(allProps, 'Movie'));

                % Parcourir chaque propriété "Movie"
                for i = 1:length(movieProps)
                    propName = movieProps{i};
                    comp = app.(propName);
                    % Vérifier que le composant est valide
                    if isvalid(comp)
                        % Si le composant ne possède pas de propriété 'Value' (ex : Label), on le saute
                        if ~isprop(comp, 'Value')
                            continue;
                        end
                        try
                            % Lire la valeur actuelle (valeur par défaut au démarrage)
                            defaultValue = comp.Value;
                            % Stocker dans la structure DisplaySettings.Movie
                            app.DisplaySettings.Movie.(propName) = defaultValue;
                        catch ME
                            warning('Impossible de lire la valeur par défaut de %s : %s', propName, ME.message);
                        end
                    end
                end

                fprintf('DisplaySettings.Movie initialisé avec les valeurs par défaut.\n');
            end
        end

        % Callback commune pour les composants "Movie..."
        function movieComponentCallback(app, propName, src, event)
            % Récupérer la nouvelle valeur (selon le type du composant)
            if isprop(src, 'Value')
                newVal = src.Value;
            else
                newVal = event.NewData;
            end

            % Stocker la nouvelle valeur dans la sous-structure DisplaySettings.Movie
            app.DisplaySettings.Movie.(propName) = newVal;

            if strcmp(propName,'MovieselectcurrentROIonlyCheckBox')
                if newVal
                    app.MovieROIArraysizeEditField.Value='1 1';
                else
                    % Calcul du nombre de colonnes : on part de la racine carrée de N
                    N=numel(app.content.ROIList);
                    nCols = ceil(sqrt(N));
                    % Calcul du nombre de lignes : on s'assure que le produit rows*cols est au moins N
                    nRows = ceil(N / nCols);
                    app.MovieROIArraysizeEditField.Value=num2str([nCols nRows]);
                end
                app.DisplaySettings.Movie.MovieROIArraysizeEditField=app.MovieROIArraysizeEditField.Value;
            end

            % (Optionnel) Afficher un message dans la console pour debug
            fprintf('Mise à jour de %s : %s\n', propName, mat2str(newVal));
            assignin('base', 'DisplaySettings',app.DisplaySettings);
        end

        function applyMovieDisplaySettings(app)
            % Vérifier que la sous-structure DisplaySettings.Movie existe
            if ~isfield(app.DisplaySettings, 'Movie')
                return;
            end

            movieSettings = app.DisplaySettings.Movie;
            fieldsMovie = fieldnames(movieSettings);

            % Parcourir chaque champ enregistré dans DisplaySettings.Movie
            for i = 1:numel(fieldsMovie)
                propName = fieldsMovie{i};
                newVal = movieSettings.(propName);

                % Vérifier que l'application possède bien une propriété correspondante
                if isprop(app, propName)
                    comp = app.(propName);

                    % Vérifier que le handle est valide
                    if isvalid(comp)
                        % Selon le type de composant, appliquer la nouvelle valeur
                        if isa(comp, 'matlab.ui.control.EditField')
                            comp.Value = newVal;
                        elseif isa(comp, 'matlab.ui.control.Slider')
                            comp.Value = newVal;
                        elseif isa(comp, 'matlab.ui.control.CheckBox')
                            comp.Value = newVal;
                        elseif isa(comp, 'matlab.ui.control.DropDown')
                            comp.Value = newVal;
                        else
                            % Pour d'autres types de composants, essayer de définir la propriété Value
                            try
                                comp.Value = newVal;
                            catch
                                warning('Impossible de mettre à jour la propriété "%s".', propName);
                            end
                        end
                    end
                else
                    %    warning('La propriété "%s" n''existe pas dans l''application.', propName);
                end
            end

            % (Optionnel) Afficher un message de confirmation
            fprintf('DisplaySettings.Movie ont été appliqués sur tous les composants Movie...\n');
        end
    end

    methods (Access = public)

        function setAnnotationSession(app, session)
            % Attach Score to the explicit GT lifecycle owned by a classifier.
            if nargin < 2 || isempty(session)
                app.AnnotationSession = [];
                app.AnnotationDisplayPreset = struct();
                app.AnnotationLastValidationValid = false;
                app.AnnotationQuickValidationState = 'idle';
                app.AnnotationQuickValidationMessage = '';
                app.AnnotationReviewDirty = false;
                app.setManagedAnnotationLayout(false);
                return;
            end
            if ~isa(session, 'annotationManager.Session')
                error('score:InvalidAnnotationSession', ...
                    'Expected an annotationManager.Session instance.');
            end

            session.refresh();
            app.AnnotationSession = session;
            app.AnnotationLastValidationValid = false;
            app.AnnotationQuickValidationState = 'idle';
            app.AnnotationQuickValidationMessage = '';
            app.AnnotationReviewDirty = false;
            context = session.uiContext();
            app.AnnotationDisplayPreset = context.displayPreset;

            % userTraining normally added this ROI already. Replace the
            % cached handle with the session ROI and select it explicitly.
            selected = [];
            for i = 1:numel(app.content.ROIList)
                candidate = app.content.ROIList{i};
                if app.annotationRoiMatchesContext(candidate, context)
                    app.content.ROIList{i} = session.Roi;
                    selected = i;
                    break;
                end
            end
            if isempty(selected)
                if strlength(string(context.legacyScoreOption)) > 0
                    app.addROI(session.Roi, context.legacyScoreOption);
                else
                    app.addROI(session.Roi);
                end
                selected = numel(app.content.ROIList);
            end
            if ~isempty(app.UIROITable.Data) && selected <= size(app.UIROITable.Data, 1)
                tableData = app.UIROITable.Data;
                for i = 1:size(tableData, 1), tableData{i,1} = false; end
                tableData{selected,1} = true;
                app.UIROITable.Data = tableData;
            end

            app.setManagedAnnotationLayout(true);
            app.refreshAnnotationSessionUI();
            app.applyAnnotationDisplayPreset();
            app.selectPanelTab('annotation');
        end

        function notifyAnnotationChanged(app, source, frames, varargin)
            % Called by painting, lineage and keyboard editors after a write.
            if nargin < 3, frames = []; end
            if isempty(app.AnnotationSession) || ~isvalid(app.AnnotationSession)
                return;
            end
            ids = app.annotationComponentIdsForSource(source);
            if isempty(ids), return; end
            try
                app.AnnotationSession.markChanged( ...
                    'Components', ids, 'Frames', frames, varargin{:});
                app.AnnotationLastValidationValid = false;
                app.AnnotationReviewDirty = true;
                quickReport = app.AnnotationSession.quickValidate( ...
                    'Components', ids, 'Frames', frames);
                if quickReport.valid
                    app.AnnotationQuickValidationState = 'valid';
                    app.AnnotationQuickValidationMessage = ...
                        'Edited content passed lightweight checks.';
                else
                    app.AnnotationQuickValidationState = 'invalid';
                    app.AnnotationQuickValidationMessage = char(strjoin( ...
                        cellstr(quickReport.errors), newline));
                end
                app.refreshAnnotationSessionUI();
            catch ME
                warning('score:AnnotationChangeTracking', ...
                    'Could not update annotation review state: %s', ME.message);
            end
        end

        function key = syncLineageDisplayAfterEdit(app)
            % Public bridge for editors implemented outside the app class.
            % The actual display binding remains private to Score.
            key = app.syncLineageDisplayForPaintChannel();
        end

        function refreshAnnotationSessionUI(app)
            if isempty(app.AnnotationSession) || ~isvalid(app.AnnotationSession)
                app.setManagedAnnotationLayout(false);
                return;
            end
            try
                context = app.AnnotationSession.uiContext();
                summary = app.AnnotationSession.summary();
            catch ME
                app.AnnotationStatusLabel.Text = 'Status: unavailable';
                app.AnnotationCoverageLabel.Text = ME.message;
                return;
            end

            app.AnnotationDisplayPreset = context.displayPreset;
            app.AnnotationTargetLabel.Text = sprintf('Target: %s / %s', ...
                context.displayName, context.roiId);
            statusText = char(string(context.status));
            if isempty(statusText), statusText = 'missing'; end
            quickSuffix = '';
            if strcmp(app.AnnotationQuickValidationState, 'valid')
                quickSuffix = '  |  checks OK';
            elseif strcmp(app.AnnotationQuickValidationState, 'invalid')
                quickSuffix = '  |  check issue';
            end
            app.AnnotationStatusLabel.Text = sprintf('Status: %s%s | Train: %s', ...
                upper(statusText), quickSuffix, context.frameBoundsText);
            app.AnnotationStatusLabel.Tooltip = app.AnnotationQuickValidationMessage;
            coverageText = app.annotationCoverageText(summary.coverage.components);
            sourceText = '';
            try, sourceText = char(string(summary.entry.source_id)); catch, end
            if isempty(sourceText)
                app.AnnotationCoverageLabel.Text = coverageText;
                app.AnnotationCoverageLabel.Tooltip = '';
            else
                app.AnnotationCoverageLabel.Text = sprintf('%s\nSource: %s', ...
                    coverageText, sourceText);
                app.AnnotationCoverageLabel.Tooltip = sourceText;
            end

            required = [summary.components.required];
            predictions = [summary.components.predictionExists];
            if isempty(required), required = true(size(predictions)); end
            hasPrediction = any(predictions);
            hasDraft = any(strcmp(statusText, {'draft','approved'}));
            isDraft = strcmp(statusText, 'draft');

            app.CreateFromPredictionButton.Enable = 'on';
            app.StartBlankGTButton.Enable = 'on';
            app.StartBlankGTButton.Visible = 'off';
            app.MarkFrameReviewedButton.Enable = app.onOff(hasDraft);
            app.MarkThroughCurrentButton.Enable = app.onOff(hasDraft);
            app.ReviewWhileNavigatingCheckBox.Enable = app.onOff(hasDraft);
            coverageComponents = summary.coverage.components;
            requiredIds = string({app.AnnotationSession.Spec.components( ...
                [app.AnnotationSession.Spec.components.required]).id});
            requiredCoverage = coverageComponents(ismember( ...
                string({coverageComponents.id}), requiredIds));
            frameCoverage = requiredCoverage(strcmp({requiredCoverage.unit}, 'frame'));
            roiCoverage = requiredCoverage(strcmp({requiredCoverage.unit}, 'roi'));
            framesComplete = isempty(frameCoverage) || all( ...
                [frameCoverage.reviewed] >= [frameCoverage.total]);
            roiIncomplete = ~isempty(roiCoverage) && any( ...
                [roiCoverage.reviewed] < [roiCoverage.total]);
            if framesComplete && roiIncomplete
                app.MarkFrameReviewedButton.Text = 'Confirm ROI reviewed...';
                app.MarkFrameReviewedButton.Tooltip = ...
                    'Confirm ROI-level tracks and lineage after all frames were reviewed.';
            else
                app.MarkFrameReviewedButton.Text = 'Reviewed + next';
                app.MarkFrameReviewedButton.Tooltip = [ ...
                    'Mark the current frame reviewed and open the next incomplete frame. ' ...
                    'Shift+click confirms the complete ROI.'];
            end
            app.NextIncompleteButton.Enable = app.onOff( ...
                hasDraft && summary.coverage.reviewed < summary.coverage.total);
            app.ValidateAnnotationButton.Enable = app.onOff(hasDraft);
            app.ApproveAnnotationButton.Enable = app.onOff( ...
                isDraft && app.AnnotationLastValidationValid);
            app.ShowPredictionCheckBox.Enable = app.onOff(hasPrediction);
            app.setManagedAnnotationLayout(true);
        end

        function applyAnnotationDisplayPreset(app)
            if isempty(app.AnnotationSession) || ~isvalid(app.AnnotationSession)
                return;
            end
            context = app.AnnotationSession.uiContext();
            preset = context.displayPreset;
            roi = app.getSelectedROI();
            if isempty(roi) || ~strcmp(char(string(roi.id)), context.roiId)
                return;
            end

            gtChannels = cellstr(string(preset.editableChannels));
            predictionChannels = cellstr(string(preset.predictionChannels));
            for i = 1:numel(gtChannels)
                idx = find(strcmp(roi.display.channel, gtChannels{i}), 1, 'first');
                if isempty(idx), continue; end
                roi.display.indexed(idx) = true;
                roi.display.selectedchannel(idx) = true;
                roi.display.alpha(idx) = 0.35;
                roi.display.contour(idx) = true;
                roi.display.width(idx) = max(1.5, roi.display.width(idx));

                updates = struct('mode', lower(char(string(preset.channelMode))), ...
                    'criterion', char(string(preset.colorBy)));
                if ~isempty(preset.objectFamilies)
                    updates.objectFamily = char(string(preset.objectFamilies{1}));
                end
                if ~isempty(preset.maskProviders)
                    updates.maskProvider = char(string(preset.maskProviders{1}));
                end
                if strcmpi(char(string(context.editor)), 'lineage')
                    updates.lineageMode = 'genealogy';
                end
                score_setObjectDisplayConfig(roi, gtChannels{i}, updates);
            end
            showPrediction = logical(app.ShowPredictionCheckBox.Value);
            for i = 1:numel(predictionChannels)
                idx = find(strcmp(roi.display.channel, predictionChannels{i}), 1, 'first');
                if isempty(idx), continue; end
                roi.display.indexed(idx) = true;
                roi.display.selectedchannel(idx) = showPrediction;
                roi.display.alpha(idx) = min(0.25, roi.display.alpha(idx));
            end
            % Managed mask editing starts with one intensity image under
            % the indexed overlay. Without it, legacy renderers computed
            % Nchannel == 0 and frame navigation appeared frozen.
            background = find(~logical(roi.display.indexed), 1, 'first');
            if ~isempty(background)
                roi.display.selectedchannel(background) = true;
            elseif ~any(logical(roi.display.selectedchannel)) && ...
                    ~isempty(roi.display.selectedchannel)
                roi.display.selectedchannel(1) = true;
            end

            app.displayROIChannels();
            % Some legacy display records expose a newly appended HDF5
            % channel before the generic annotation table has expanded its
            % row mapping. Materialize the managed target row explicitly so
            % the editor can never remain attached to the prediction row.
            tableData = app.UIAnnotationTable.Data;
            for i = 1:numel(gtChannels)
                existsInTable = false;
                for row = 1:size(tableData, 1)
                    existsInTable = existsInTable || ...
                        strcmp(app.annotationTableChannelName(row), gtChannels{i});
                end
                idx = find(strcmp(roi.display.channel, gtChannels{i}), 1, 'first');
                if ~existsInTable && ~isempty(idx)
                    tableData(end+1,:) = {true, gtChannels{i}, '', ...
                        roi.display.alpha(idx), roi.display.contour(idx), ...
                        roi.display.width(idx)}; %#ok<AGROW>
                    app.UIAnnotationTable.Data = tableData;
                end
            end
            targetRow = [];
            for row = 1:size(app.UIAnnotationTable.Data, 1)
                name = app.annotationTableChannelName(row);
                if any(strcmp(gtChannels, name))
                    targetRow = row;
                    break;
                end
            end
            if ~isempty(targetRow)
                app.UIAnnotationTable.Selection = [targetRow 1];
                app.UIAnnotationTableSelectionChanged([]);
                % The managed preset is authoritative even when an older
                % ROI carries a stale per-channel display configuration.
                switch lower(char(string(preset.channelMode)))
                    case 'edit'
                        app.ChannelModeButtonGroup.SelectedObject = app.EditButton;
                    case 'semantic'
                        app.ChannelModeButtonGroup.SelectedObject = app.SemanticButton;
                    case 'multicolor'
                        app.ChannelModeButtonGroup.SelectedObject = app.MulticolorButton;
                    otherwise
                        app.ChannelModeButtonGroup.SelectedObject = app.NormalButton;
                end
                app.PaintButtonValueChanged([]);
                % score_display may reload a legacy visual preset during
                % PaintButtonValueChanged. Reassert the managed UI mode
                % after that refresh; the paint handler is already wired.
                switch lower(char(string(preset.channelMode)))
                    case 'edit'
                        app.ChannelModeButtonGroup.SelectedObject = app.EditButton;
                    case 'semantic'
                        app.ChannelModeButtonGroup.SelectedObject = app.SemanticButton;
                    case 'multicolor'
                        app.ChannelModeButtonGroup.SelectedObject = app.MulticolorButton;
                    otherwise
                        app.ChannelModeButtonGroup.SelectedObject = app.NormalButton;
                end
            else
                score_setEditMode(app, false);
                score_display(app, 'refresh');
            end
            app.setManagedAnnotationLayout(true);
        end

        function setManagedAnnotationLayout(app, active)
            if ~isprop(app, 'AnnotationSessionPanel') || ...
                    isempty(app.AnnotationSessionPanel) || ~isvalid(app.AnnotationSessionPanel)
                return;
            end
            app.AnnotationSessionPanel.Visible = app.onOff(active);
            genericButtons = {'NewAnnotationButton','DeleteAnnnotationButton', ...
                'NewclassButton','DeleteclassButton'};
            if active
                % Keep the lifecycle controls reachable for data-label
                % editors (CNN/LSTM) as well as mask editors. Their ROI Data
                % panel remains enabled; the user can switch between tabs.
                app.AnnotationPanel.Visible = 'on';
                try
                    app.DisplaySettings.panels.AnnotationPanel = 'on';
                catch
                end
                app.UIAnnotationTable.Position = [13 490 589 175];
                app.StartBlankGTButton.Visible = 'off';
                for i = 1:numel(genericButtons)
                    app.(genericButtons{i}).Visible = 'off';
                end
                locked = {'ChannelModeButtonGroup','DisplayCriterionDropDown', ...
                    'ObjectFamilyDropDown','MaskProviderDropDown','LineageSourceDropDown'};
                for i = 1:numel(locked), app.(locked{i}).Enable = 'off'; end
                app.UIAnnotationTable.ColumnEditable = ...
                    [true false false false false false];
                % Mask labels and object UUIDs are storage details. Managed
                % tracking/lineage annotation exposes one stable identity.
                internalIds = {'MasklabelEditFieldLabel','MasklabelEditField', ...
                    'SelectedObjectIDLabel','SelectedObjectIDEditField'};
                for i = 1:numel(internalIds)
                    app.(internalIds{i}).Visible = 'off';
                end
                app.SelectedTrackIDEditFieldLabel.Text = 'Selected track:';
                app.SelectedTrackIDEditFieldLabel.Position = [8 153 106 22];
                app.SelectedTrackIDEditField.Position = [149 153 100 22];
                app.SelectedCellStateDropDownLabel.Position = [28 113 102 22];
                app.SelectedCellStateDropDown.Position = [145 113 100 22];
                app.CellModelStatusLabel.Position = [16 71 250 22];
            else
                app.UIAnnotationTable.Position = [13 519 589 279];
                positions = {[4 832 95 23],[103 832 109 23], ...
                    [218 832 94 23],[318 832 108 23]};
                for i = 1:numel(genericButtons)
                    app.(genericButtons{i}).Visible = 'on';
                    app.(genericButtons{i}).Position = positions{i};
                end
                app.UIAnnotationTable.ColumnEditable = true(1, 6);
                internalIds = {'MasklabelEditFieldLabel','MasklabelEditField', ...
                    'SelectedObjectIDLabel','SelectedObjectIDEditField'};
                for i = 1:numel(internalIds)
                    app.(internalIds{i}).Visible = 'on';
                end
                app.SelectedTrackIDEditFieldLabel.Text = 'Selected Track ID: ';
                app.SelectedTrackIDEditFieldLabel.Position = [8 71 106 22];
                app.SelectedTrackIDEditField.Position = [149 71 100 22];
                app.SelectedCellStateDropDownLabel.Position = [28 34 102 22];
                app.SelectedCellStateDropDown.Position = [145 34 100 22];
                app.CellModelStatusLabel.Position = [16 7 133 22];
            end
        end

        function ids = annotationComponentIdsForSource(app, source)
            ids = {};
            if isempty(app.AnnotationSession), return; end
            source = char(string(source));
            components = app.AnnotationSession.Spec.components;
            for i = 1:numel(components)
                component = components(i);
                candidates = {char(string(component.id))};
                switch char(string(component.storage))
                    case 'channel'
                        candidates{end+1} = char(string(component.groundTruth.channel)); %#ok<AGROW>
                    case 'dataseries'
                        candidates = [candidates, { ...
                            char(string(component.groundTruth.valueField)), ...
                            char(string(component.groundTruth.idField)), ...
                            [char(string(component.groundTruth.groupId)) '.' ...
                             char(string(component.groundTruth.valueField))]}]; %#ok<AGROW>
                    case 'cell_model_family'
                        candidates{end+1} = char(string(component.groundTruth.family)); %#ok<AGROW>
                        if strcmp(component.kind, 'tracking')
                            candidates = [candidates, { ...
                                char(string(component.groundTruth.maskProvider)), ...
                                'tracking','track','track_identity'}]; %#ok<AGROW>
                        elseif strcmp(component.kind, 'lineage')
                            candidates = [candidates, {'lineage','parentage','parent'}]; %#ok<AGROW>
                        end
                end
                if any(strcmpi(source, candidates))
                    ids{end+1} = char(string(component.id)); %#ok<AGROW>
                end
            end
            ids = unique(ids, 'stable');
        end

        function ids = annotationFrameComponentIds(app)
            ids = {};
            if isempty(app.AnnotationSession), return; end
            components = app.AnnotationSession.Spec.components;
            keep = [components.required] & strcmp({components.coverageUnit}, 'frame');
            ids = {components(keep).id};
        end

        function text = annotationCoverageText(~, components)
            lines = strings(0,1);
            for i = 1:numel(components)
                id = char(string(components(i).id));
                switch id
                    case {'tracked_mask','instances','semantic_mask','mask'}
                        label = 'Segmentation';
                    case {'tracking','tracklets'}
                        label = 'Tracking';
                    case {'parentage','lineage'}
                        label = 'Parentage';
                    otherwise
                        label = strrep(id, '_', ' ');
                        if ~isempty(label), label(1) = upper(label(1)); end
                end
                lines(end+1,1) = sprintf('%s: %d/%d', label, ...
                    components(i).reviewed, components(i).total); %#ok<AGROW>
            end
            text = char(strjoin(lines, newline));
        end

        function reviewFrameBeforeNavigation(app, frame, newFrame)
            if frame == newFrame || isempty(app.AnnotationSession) || ...
                    ~isvalid(app.AnnotationSession)
                return;
            end
            if app.reviewWhileNavigatingEnabled() == false
                return;
            end
            if ~ismember(frame,app.AnnotationSession.trainingFrames())
                return;
            end
            ids = app.annotationFrameComponentIds();
            if isempty(ids), return; end
            app.AnnotationSession.markReviewed('Frames', frame, ...
                'Components', ids, 'Save', false);
            app.AnnotationReviewDirty = true;
            app.AnnotationLastValidationValid = false;
            app.refreshAnnotationSessionUI();
        end

        function tf = reviewWhileNavigatingEnabled(app)
            % Old live Score instances may predate this UI component. A
            % stale/partially rebuilt control must never break navigation.
            tf = false;
            try
                control = app.ReviewWhileNavigatingCheckBox;
                if isempty(control) || ~isgraphics(control)
                    return;
                end
                value = control.Value;
                if (islogical(value) || isnumeric(value)) && isscalar(value)
                    tf = logical(value);
                end
            catch
                tf = false;
            end
        end

        function flushAnnotationReview(app)
            if ~app.AnnotationReviewDirty || isempty(app.AnnotationSession) || ...
                    ~isvalid(app.AnnotationSession)
                return;
            end
            try
                app.AnnotationSession.Roi.save('data', false);
                app.AnnotationReviewDirty = false;
            catch ME
                warning('score:AnnotationReviewSave', ...
                    'Could not save annotation review metadata: %s', ME.message);
            end
        end

        function name = annotationTableChannelName(app, row)
            name = '';
            if isempty(app.UIAnnotationTable.Data) || ...
                    row < 1 || row > size(app.UIAnnotationTable.Data, 1)
                return;
            end
            annotation = char(string(app.UIAnnotationTable.Data{row,2}));
            className = char(string(app.UIAnnotationTable.Data{row,3}));
            if isempty(className), name = annotation;
            else, name = [annotation '_' className];
            end
        end

        function value = onOff(~, tf)
            if tf, value = 'on'; else, value = 'off'; end
        end

        function tf = confirmAnnotationOverwrite(app, message)
            answer = uiconfirm(app.ScoreAppUIFigure, message, ...
                'Replace ground truth', ...
                'Options', {'Replace','Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
            tf = strcmp(answer, 'Replace');
        end

        function replaceAnnotationSessionROI(app)
            if isempty(app.AnnotationSession), return; end
            app.AnnotationSession.refresh();
            context = app.AnnotationSession.uiContext();
            for i = 1:numel(app.content.ROIList)
                if app.annotationRoiMatchesContext(app.content.ROIList{i}, context)
                    app.content.ROIList{i} = app.AnnotationSession.Roi;
                    break;
                end
            end
        end

        function tf = annotationRoiMatchesContext(~, roiObj, context)
            tf = strcmp(char(string(roiObj.id)), context.roiId);
            if ~tf, return; end
            try
                if isa(roiObj.parent, 'classi')
                    tf = strcmp(char(string(roiObj.parent.strid)), ...
                        char(string(context.classifierId)));
                end
            catch
            end
        end

        function frame = nextIncompleteAnnotationFrame(app)
            frame = [];
            if isempty(app.AnnotationSession), return; end
            summary = app.AnnotationSession.summary();
            spec = app.AnnotationSession.Spec;
            roi = app.getSelectedROI();
            if isempty(roi), return; end
            totalFrames = size(roi.image, 4);
            incomplete = false(1, totalFrames);
            reviewFrames = summary.reviewFrames;
            reviewFrames = reviewFrames(reviewFrames >= 1 & ...
                reviewFrames <= totalFrames);
            roiIncomplete = false;
            for i = 1:numel(spec.components)
                if ~spec.components(i).required, continue; end
                reviewIndex = find(strcmp( ...
                    string({summary.entry.review.component_id}), ...
                    string(spec.components(i).id)), 1, 'first');
                if isempty(reviewIndex)
                    if strcmp(spec.components(i).coverageUnit, 'frame')
                        incomplete(reviewFrames) = true;
                    else
                        roiIncomplete = true;
                    end
                    continue;
                end
                review = summary.entry.review(reviewIndex);
                if strcmp(review.unit, 'frame')
                    reviewed = false(1,totalFrames);
                    n = min(totalFrames,numel(review.frames));
                    reviewed(1:n) = logical(review.frames(1:n));
                    incomplete(reviewFrames) = incomplete(reviewFrames) | ...
                        ~reviewed(reviewFrames);
                elseif ~review.complete
                    roiIncomplete = true;
                end
            end
            candidates = find(incomplete);
            if ~isempty(candidates)
                current = roi.display.frame;
                after = candidates(candidates > current);
                if isempty(after), frame = candidates(1); else, frame = after(1); end
            elseif roiIncomplete
                frame = roi.display.frame;
            end
        end

 function redrawSelectedRectangle(app, roi, channelIdx, pix)
% Actualise la bbox de l'objet sélectionné à la frame courante
if ~isprop(app,'SelectedObjectRectangle') || isempty(app.SelectedObjectRectangle) || ~isgraphics(app.SelectedObjectRectangle)
    return;
end
lab = app.SelectedObjectLabelCell;
if isempty(lab) || isnan(lab) || lab<=0, return; end
frm = roi.display.frame;
M = roi.image(:,:,pix,frm);
bw = (M==lab);
if ~any(bw(:)), set(app.SelectedObjectRectangle,'Visible','off'); return; end
S = regionprops(bw,'BoundingBox');
if isempty(S), set(app.SelectedObjectRectangle,'Visible','off'); return; end
set(app.SelectedObjectRectangle,'Position',S(1).BoundingBox,'Visible','on');
end


        function error=addROI(app,roiobj,options,varargin)
         %   profile on

            if nargin < 3, options = ''; end
            p = inputParser;
            p.addParameter('CacheIsFresh', false, ...
                @(x)islogical(x) && isscalar(x));
            p.parse(varargin{:});
            cacheIsFresh = p.Results.CacheIsFresh;
            hasLayoutOption = strlength(string(options)) > 0;

            isPresent = false;
            newindex=[];

            for k = 1:numel(app.content.ROIList)
                roix = app.content.ROIList{k};
                sameID     = strcmp(roix.id, roiobj.id);

                if numel(roiobj.parent)==0 && numel(roix.parent)==0
                    sameClass=true;
                    sameNum=false;
                end
                if numel(roiobj.parent)==0 || numel(roix.parent)==0
                    sameClass=false;
                    sameNum=false;
                end
                if numel(roiobj.parent)~=0 && numel(roix.parent)~=0
                    sameClass  = strcmp(class(roix.parent), class(roiobj.parent));
                    %aa=roix
                    % bb=roiobj.parent.roi
                    if ~ischar(roix.parent) && ~ischar(roiobj.parent)
                 %       aa=roix.parent
                  %      bb=(roiobj.parent)
                        sameNum    = numel(roix.parent.roi) == numel(roiobj.parent.roi);
                    else
                        sameNum=false;
                    end
                end

                sameParent=false;
                if sameClass
                    if isa(roix.parent,'fov')
                        sameParent = strcmp(roix.parent.id, roiobj.parent.id);
                    elseif isa(roix.parent,'classi')
                        sameParent = strcmp(roix.parent.strid, roiobj.parent.strid);
                    else
                        sameParent = false;
                    end
                end
                if sameID && sameClass && sameNum && sameParent
                    isPresent = true;
                    newindex=k;
                    break;
                end
            end

            error=1;

            if isPresent
                disp(['ROI with ID "', roiobj.id, '" is already present. Skipping addition.']);
               
                event.Indices=[newindex 1];
                handleROITableEdit(app,event); %n updates the display of the selected ROI 

                error=0;
                return;
            else

                % Ajouter la ROI à la liste
                loadedFullImage = cacheIsFresh && ~isempty(roiobj.image);
                if numel(roiobj.image)==0
                    roiobj.load;
                    loadedFullImage = ~isempty(roiobj.image);
                end
                if ~loadedFullImage
                    roiobj = app.refreshROIIntensityChannelsFromDisk(roiobj);
                    roiobj = app.refreshROIDataFromDisk(roiobj);
                end

                if numel(roiobj.image)==0
                    errordlg('ROI image is empty;  Maybe it has not been extracted.... Quitting!');
                    error=0;
                    return;
                end

                % update ROI structure
                if ~iscell(roiobj.display.channel)
                    roiobj.display.channel={roiobj.display.channel};
                end
                if ~isfield(roiobj.display,'indexed')  || numel(roiobj.display.indexed)~= numel(roiobj.display.channel)
                    roiobj.display.indexed=zeros(1,numel(roiobj.display.channel));
    
                end
                if ~isfield(roiobj.display,'width') || numel(roiobj.display.width)~= numel(roiobj.display.channel)
                    roiobj.display.width=zeros(1,numel(roiobj.display.channel));
                end
                if ~isfield(roiobj.display,'alpha') || numel(roiobj.display.alpha)~= numel(roiobj.display.channel)

                    roiobj.display.alpha=ones(1,numel(roiobj.display.channel));
                end
                if ~isfield(roiobj.display,'contour') || numel(roiobj.display.contour)~= numel(roiobj.display.channel)
                    roiobj.display.contour=logical(zeros(1,numel(roiobj.display.channel)));
                end
                 if ~isfield(roiobj.display,'log') || numel(roiobj.display.log)~= numel(roiobj.display.channel)
                    roiobj.display.log=logical(zeros(1,numel(roiobj.display.channel)));
                end
                if ~isfield(roiobj.display,'scale') || numel(roiobj.display.scale)~= numel(roiobj.display.channel)
                    roiobj.display.scale=logical(zeros(1,numel(roiobj.display.channel)));
                end

                selectedROI=roiobj;
nCh = size(selectedROI.image, 3);

needRecompute = ...
    ~isfield(selectedROI.display,'displaylim') || ...
    isempty(selectedROI.display.displaylim) || ...
    size(selectedROI.display.displaylim,1) ~= 2 || ...
    size(selectedROI.display.displaylim,2) ~= nCh;

if ~needRecompute
    dl = selectedROI.display.displaylim;

    low  = dl(1,:);
    high = dl(2,:);

    % channel invalid if: NaN/Inf OR low>=high OR degenerate defaults
    bad = ~isfinite(low) | ~isfinite(high) | (high <= low) | ...
          (low==1 & high==1) | (low==0 & high==0) | (low==0 & high==1);

    needRecompute = any(bad);
end

if needRecompute
    disp('Computing displaylim...')
    selectedROI.computeDisplaylim;
end



                app.content.ROIList{end+1} = roiobj;
                disp(['Adding ROI: ', roiobj.id]);

          
                  dataStruct = roiobj.data ; % tableau de structures
                nData = numel(dataStruct);

                for i = 1:nData
    try
        % si méthode:
        if ismethod(dataStruct(i), 'ensurePlotProperties')
            dataStruct(i).ensurePlotProperties();
        end
    catch ME
        warning('PlotProperties rebuild failed for ROI %s data(%d): %s', roiobj.id, i, ME.message);
    end
end


                if ~isfield( app.DisplaySettings,'annotation')
                 app.DisplaySettings.annotation=[];
                 app.DisplaySettings.annotation.state='off';
                end

               if hasLayoutOption % basic layout
                   switch options
                       case 'dataAnnotation'

                app.DisplaySettings.panels.ROisPanel = 'off';
                app.DisplaySettings.panels.DisplaysettingsPanel = 'off';
                app.DisplaySettings.panels.DataSettingsPanel = 'on';
                app.DisplaySettings.panels.AnnotationPanel = 'off';
                app.DisplaySettings.panels.IntensityQuantificationPanel = 'off';
                app.DisplaySettings.panels.MoviePanel = 'off';
               
                app.DisplaySettings.annotation.state='data';


                pix = [];  % IMPORTANT: init pour éviter "Unrecognized variable"

for i = 1:nData
    if isprop(dataStruct(i),'show') && ~isempty(dataStruct(i).show) && dataStruct(i).show
        pix = i;
        break
    end
end

% fallback si rien n'est "show"
if isempty(pix)
    % 1) essaie de prendre le dataseries du classif courant (si groupid match)
    try
        gid = arrayfun(@(d) string(d.groupid), dataStruct);
        hit = find(gid == string(app.DisplaySettings.annotation.groupid), 1, 'first'); % si tu as ça
    catch
        hit = [];
    end

    if ~isempty(hit)
        pix = hit;
    else
        % 2) sinon le 1er dataseries non vide, sinon 1
        pix = 1;
        try
            nonEmpty = find(arrayfun(@(d) ~isempty(d.data), dataStruct), 1, 'first');
            if ~isempty(nonEmpty), pix = nonEmpty; end
        catch
        end
    end
end

app.DisplaySettings.annotation.dataidx = pix;


               
        
               % pix
             %   app.UIDataTable.Selection=[pix 1]; % very important to display the relevant data

                                 %    'ok'group

                       case 'pixelAnnotation'
                app.DisplaySettings.panels.ROisPanel = 'off';
                app.DisplaySettings.panels.DisplaysettingsPanel = 'on';
                app.DisplaySettings.panels.DataSettingsPanel = 'off';
                app.DisplaySettings.panels.AnnotationPanel = 'on';
                app.DisplaySettings.panels.IntensityQuantificationPanel = 'off';
                app.DisplaySettings.panels.MoviePanel = 'off';

                app.DisplaySettings.annotation.state='pixel';
              


                   end
               else

                       % desactivate data rendering
              
                for i = 1:nData
                    dataStruct(i).show=false;
                end

               end


            % Appliquer ces réglages dans l'interface

            app.setAllPanelTabsVisible();
            if hasLayoutOption
                switch options
                    case 'dataAnnotation'
                        app.selectPanelTab('data');
                    case 'pixelAnnotation'
                        app.selectPanelTab('annotation');
                end
            end
           
            % --- Sécuriser l'accès aux réglages de panneaux ---
% S'assurer que la sous-structure 'panels' existe
if ~isfield(app.DisplaySettings, 'panels') || ~isstruct(app.DisplaySettings.panels)
    app.DisplaySettings.panels = struct();
end

% Si le champ MoviePanel n'existe pas encore, on prend la valeur actuelle
% du panel (ou 'off' par défaut), puis on le stocke dans DisplaySettings.
if ~isfield(app.DisplaySettings.panels, 'MoviePanel')
    if isprop(app, 'MoviePanel') && isvalid(app.MoviePanel)
        defaultVis = app.MoviePanel.Visible;   % 'on' ou 'off'
    else
        defaultVis = 'off';
    end
    app.DisplaySettings.panels.MoviePanel = defaultVis;
end

% Maintenant seulement on applique la valeur
app.setAllPanelTabsVisible();

% (optionnel) resynchroniser la variable de base
assignin('base', 'DisplaySettings', app.DisplaySettings);




            app.isthedefautcolorCheckBox.Value=false;

            app.updatePanelsLayout();
            % Mettre à jour le DisplayMenu
            updateDisplayMenu(app);


             % Mettre à jour l'affichage
             app.displayROIs();

             if hasLayoutOption
                switch options
                    case 'pixelAnnotation'
                 score_setEditMode(app, true);
                 
                  pix=roiobj.display.indexed==1;
                  tmp=find(roiobj.display.selectedchannel(pix)==1,1,'first');

              

if isempty(tmp)
    app.UIAnnotationTable.Selection = [];          % rien de sélectionné
else
    rows = tmp(:);                                 % forcer en colonne
    cols = repmat(2, numel(rows), 1);              % colonne de 2
    app.UIAnnotationTable.Selection = [rows cols]; % N×2 numeric
end



                app.PaintButtonValueChanged([]);

                end
            end

               % Récupérer les réglages de visibilité depuis le workspace de base, s'ils existent

     
            % update displa

        %    profile viewer
            end
        end


        function displayData(app)
            % Vérifier qu'une ROI est sélectionnée via la table des ROI
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                app.UIDataTable.Data = {};
                app.UIGroupTable.Data={};
                app.UISubDataTable.Data={};
                score_display(app,'slow');
                return;
            end

            roi = app.content.ROIList{selectedROIIndex};

            % S'assurer que la ROI possède des données (data)
            if ~isprop(roi, 'data') || isempty(roi.data)
                app.UIDataTable.Data = {};
                app.UIGroupTable.Data={};
                app.UISubDataTable.Data={};
                score_display(app,'slow');
                return;
            end

     

            dataStruct = roi.data ;
            % tableau de structures
            nData = numel(dataStruct);

            if nData==1 && numel(dataStruct.groupid)==0 % isempty(dataStruct(1).data) % no data present
                app.UIDataTable.Data = {};
                app.UIGroupTable.Data={};
                app.UISubDataTable.Data={};
                score_display(app,'slow');
                return;
            end

            % Préparer une cellule t avec 5 colonnes :
            % 1: sélection (booléen), 2: groupid, 3: parentid, 4: class, 5: type
            t = cell(nData, 3);

            for i = 1:nData
                % column 1 already a logical, leave as is
                t{i,1} = isprop(dataStruct(i),'show') && dataStruct(i).show;

                % column 2: groupid as char
                if isprop(dataStruct(i),'groupid')
                    t{i,2} = char(dataStruct(i).groupid);
                else
                    t{i,2} = '';
                end

                % column 3: type as char
                if isprop(dataStruct(i),'type')
                    t{i,3} = char(dataStruct(i).type);
                else
                    t{i,3} = '';
                end
            end

            app.UIDataTable.Data = t;

         

           if isfield(app.DisplaySettings, 'annotation')
                  if app.DisplaySettings.annotation.state=="data"
                   pix=app.DisplaySettings.annotation.dataidx;
                    app.UIDataTable.Selection=[pix 1];
                  end
           end

            if isempty(app.UIDataTable.Selection) || app.UIDataTable.Selection(1) > nData
                selectedDataIndex = [];
                try
                    shown = find(cell2mat(t(:,1)), 1, 'first');
                    if ~isempty(shown)
                        selectedDataIndex = shown;
                    end
                catch
                end
                if isempty(selectedDataIndex)
                    selectedDataIndex = find(strcmp(t(:,2), 'cell_information'), 1, 'first');
                end
                if isempty(selectedDataIndex) && nData > 0
                    selectedDataIndex = 1;
                end
                if ~isempty(selectedDataIndex)
                    app.UIDataTable.Selection = [selectedDataIndex 1];
                end
            end

            displaySubData(app);


            %  selectedTableIndex = find(cell2mat(app.UIDataTable.Data(:,1)));

            % %  if numel(selectedTableIndex)
            % for i=1:numel(roi.data) %selectedTableIndex'
            %     h=findobj('Tag',roi.data(i).id);
            %
            %     if numel(h) % plot is present
            %         if numel(find( selectedTableIndex==i))==0 % table is not checked, delete plot
            %             delete(h);
            %         end
            %     end


            % if numel(find( selectedTableIndex==i))~=0
            %  app.DataFigure(i)= roi.data(i).plot();

            %  end

            %  end

    
            score_display(app,'slow');

        end


        function displaySubData(app)
    % Récupérer la sélection dans UIDataTable
    selection = app.UIDataTable.Selection;
    if isempty(selection)
        app.UISubDataTable.Data = {};
        app.UIGroupTable.Data   = {};
        return;
    end

  

    dsIndex = selection(1);   % ligne sélectionnée

    % Sélectionner la ROI courante
    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
    if isempty(selectedROIIndex)
        app.UISubDataTable.Data = {};
        app.UIGroupTable.Data   = {};
        return;
    end
    roi = app.content.ROIList{selectedROIIndex};


    % Charger data si nécessaire
    if ~isprop(roi, 'data') || numel(roi.data) < dsIndex || ~isprop(roi.data(1), 'groupid') || isempty(roi.data(1).groupid)
        roi.load('data');
        if ~isprop(roi, 'data') || numel(roi.data) < dsIndex
            app.UISubDataTable.Data = {};
            app.UIGroupTable.Data   = {};
            return;
        end
    end

    selectedData = roi.data(dsIndex);
 

    % Vérifier que le dataset contient des données
    if ~isprop(selectedData, 'data') || isempty(selectedData.data)
        app.UISubDataTable.Data = {};
        app.UIGroupTable.Data   = {};
        return;
    end



    % Noms de variables
    if istable(selectedData.data)
        varnames = selectedData.data.Properties.VariableNames;
    else
        varnames = fieldnames(selectedData.data);
    end



    % -----------------------------
    % GROUP TABLE (app.UIGroupTable)
    % -----------------------------
    if isprop(selectedData,'groupProperties') && ~isempty(selectedData.groupProperties)
        tG = selectedData.groupProperties;
    else
        % fallback via plotGroup{6} si dispo
        tG = {};
        if ~isprop(selectedData,'plotGroup') || isempty(selectedData.plotGroup) || numel(selectedData.plotGroup) < 6 || isempty(selectedData.plotGroup{6})
            % create default
            tG = cell(1,4);
            tG{1,1} = 'Default';
            tG{1,2} = 'Plot';
            tG{1,3} = 'auto';
            tG{1,4} = 'auto';
        else
            tmp = selectedData.plotGroup{6};
            if ischar(tmp), tmp = {tmp}; end
            tmp = tmp(:)'; % row
            tG  = cell(numel(tmp), 4);
            for i = 1:numel(tmp)
                tG{i,1} = tmp{i};
                tG{i,2} = 'Plot';
                tG{i,3} = 'auto';
                tG{i,4} = 'auto';
            end
        end
    end

    % Appliquer group table + ColumnFormat (SANS [])
    app.UIGroupTable.Data = tG;
    app.UIGroupTable.ColumnFormat = {'char', {'Plot','Traj'}, 'char', 'char'};

    % Sauvegarder dans selectedData
    selectedData.groupProperties = tG;

    % Construire liste de choix de groupes (dropdown)
    groupChoices = {};
    if ~isempty(tG) && size(tG,2) >= 1
        groupChoices = tG(:,1);
        % Ensure dropdown choices are cellstr
for k = 1:numel(groupChoices)
    if isstring(groupChoices{k}), groupChoices{k} = char(groupChoices{k}); end
    if iscategorical(groupChoices{k}), groupChoices{k} = char(string(groupChoices{k})); end
    if isa(groupChoices{k},'missing'), groupChoices{k} = ''; end
end

        if ischar(groupChoices), groupChoices = {groupChoices}; end
        groupChoices = groupChoices(~cellfun(@isempty, groupChoices));
        groupChoices = groupChoices(:)'; % row
    end
    if isempty(groupChoices)
        groupChoices = {'Default'};
    end

    % --------------------------------
    % SUBDATA TABLE (app.UISubDataTable)
    % --------------------------------

    makeDefaultPlotProps = ~isprop(selectedData,'plotProperties') || isempty(selectedData.plotProperties);

    if makeDefaultPlotProps
        nVars = numel(varnames);
        t = cell(nVars, 6);

        for i = 1:nVars
            t{i,1} = false;                 % Plot flag (logical)
            t{i,2} = varnames{i};            % Nom variable
            if istable(selectedData.data)
                t{i,3} = class(selectedData.data.(varnames{i}));
            else
                t{i,3} = class(selectedData.data.(varnames{i}));
            end
            t{i,4} = 'auto';                 % couleur
            t{i,5} = 2;                      % largeur
            % groupe par défaut
            if ~isempty(regexpi(varnames{i},'id','once'))
                t{i,6} = 'id';
            elseif ~isempty(regexpi(varnames{i},'prob','once'))
                t{i,6} = 'prob';
            elseif ~isempty(regexpi(varnames{i},'labels','once'))
                t{i,6} = 'label';
            else
                t{i,6} = '';
            end
        end

        columnformat = {'logical','char','char','char','numeric', groupChoices};

    else
        t = selectedData.plotProperties;

        if isprop(selectedData,'plotGroup') && ~isempty(selectedData.plotGroup)
            columnformat = selectedData.plotGroup;
        else
            columnformat = {'logical','char','char','char','numeric', groupChoices};
        end
    end

    [t, selectedData, groupChoices, columnformat] = app.addLineageSourceRowsToSubDataTable(selectedData, t, groupChoices, columnformat);
    try
        if isprop(selectedData, 'groupProperties') && ~isempty(selectedData.groupProperties)
            app.UIGroupTable.Data = selectedData.groupProperties;
        end
    catch
    end


    % --- SANITIZE ColumnFormat : jamais de [] ---
    nCols = size(t,2);
    if numel(columnformat) < nCols
        columnformat(end+1:nCols) = {'char'};
    elseif numel(columnformat) > nCols
        columnformat = columnformat(1:nCols);
    end

    % defaults par colonne
    defaultFmt = {'logical','char','char','char','numeric', groupChoices};
    if numel(defaultFmt) < nCols
        defaultFmt(end+1:nCols) = {'char'};
    elseif numel(defaultFmt) > nCols
        defaultFmt = defaultFmt(1:nCols);
    end

    for j = 1:nCols
        cf = columnformat{j};

        % 1) Interdire [] (empty matrix)
        if isnumeric(cf) && isempty(cf)
            cf = defaultFmt{j};
        end

        % 2) Si dropdown : doit être une cell non vide de strings/chars
        if iscell(cf)
            if isempty(cf)
                cf = defaultFmt{j};
            else
                % si colonne -> ligne
                if iscolumn(cf), cf = cf(:)'; end
                % enlever vides
                cf = cf(~cellfun(@isempty, cf));
                if isempty(cf)
                    cf = defaultFmt{j};
                end
            end
        end

        % 3) Si char vide, fallback
        if ischar(cf) && isempty(cf)
            cf = defaultFmt{j};
        end

        columnformat{j} = cf;
    end

    % --- SANITIZE t for uitable: each cell must be numeric/logical/char ---
if istable(t)
    t = table2cell(t);
end

if ~iscell(t)
    % last-resort: convert to cell
    try
        t = num2cell(t);
    catch
        t = {};
    end
end

for r = 1:size(t,1)
    for c = 1:size(t,2)
        v = t{r,c};

        if isstring(v)
            v = char(v);
        elseif iscategorical(v)
            % categorical scalar -> char; undefined -> ''
            if isundefined(v)
                v = '';
            else
                v = char(string(v));
            end
        elseif isa(v,'missing')
            v = '';
        elseif ischar(v) || isnumeric(v) || islogical(v)
            % ok
        else
            % fallback: stringify anything else
            try
                v = char(string(v));
            catch
                try
                    v = char(evalc('disp(v)'));
                catch
                    v = '<unprintable>';
                end
            end
        end

        % Ensure row char (not string array, not char matrix)
        if ischar(v) && size(v,1) > 1
            v = v(1,:);
        end

        t{r,c} = v;
    end
end


    app.UISubDataTable.ColumnFormat = columnformat;
    app.UISubDataTable.Data         = t;

    % Sauvegarder la config dans le dataset
    selectedData.plotGroup      = columnformat;
    selectedData.plotProperties = t;

    roi.data(dsIndex) = selectedData;

    % Gestion annotation
    if isfield(app.DisplaySettings, 'annotation')
        if app.DisplaySettings.annotation.state == "data"
            pix = find(strcmp(t(:,2), 'labels_training'), 1, 'first');
            if ~isempty(pix)
                app.UISubDataTable.Selection = [pix 2];
                app.UISubDataTableSelectionChanged();
            end
        end
    end
end

        function [t, selectedData, groupChoices, columnformat] = addLineageSourceRowsToSubDataTable(app, selectedData, t, groupChoices, columnformat) %#ok<INUSL>
            try
                if ~isprop(selectedData, 'groupid') || ~strcmp(char(string(selectedData.groupid)), 'cell_information')
                    return;
                end
                if ~isprop(selectedData, 'userData') || ~isstruct(selectedData.userData) || ...
                        ~isfield(selectedData.userData, 'lineageSources') || ~isstruct(selectedData.userData.lineageSources)
                    return;
                end

                if ~iscell(t)
                    if istable(t)
                        t = table2cell(t);
                    else
                        t = num2cell(t);
                    end
                end
                if size(t, 2) < 6
                    t(:, end+1:6) = {''};
                end

                % Lineage display is intentionally not driven from ROI Data.
                % It follows the currently selected annotation channel when
                % Paint is enabled, through roi.display.lineage.  Hide both
                % stale lineageSource pseudo-rows and the legacy canonical
                % lineage variable, which otherwise appears as an empty plot.
                isLineageRow = false(size(t,1), 1);
                if size(t,2) >= 3
                    isLineageRow = strcmp(string(t(:,3)), "lineageSource");
                end
                if size(t,2) >= 2
                    isLineageRow = isLineageRow | strcmp(string(t(:,2)), "lineage");
                end
                t(isLineageRow, :) = [];
                groupChoices = groupChoices(~strcmp(string(groupChoices), "lineage"));
                if isempty(groupChoices)
                    groupChoices = {'Default'};
                end
                if numel(columnformat) >= 6
                    columnformat{6} = groupChoices;
                end
                if isprop(selectedData, 'groupProperties') && ~isempty(selectedData.groupProperties)
                    gp = selectedData.groupProperties;
                    try
                        gp(strcmp(string(gp(:,1)), "lineage"), :) = [];
                    catch
                    end
                    selectedData.groupProperties = gp;
                end
                selectedData.plotProperties = t;
                selectedData.plotGroup = columnformat;
            catch ME
                warning('score:LineageSourceRowsFailed', ...
                    'Could not expose lineage sources in score table: %s', ME.message);
            end
        end




        function ImageFigureKeyPress(app, event)
            % Callback pour app.ImageFigure.KeyPressFcn : navigation entre frames
            % via les touches fléchées gauche et droite.

            ScoreAppUIFigureKeyPress(app, event);

            % % Vérifier la touche pressée
            % switch event.Key
            %     case 'rightarrow'
            %         increment = 1;
            %     case 'leftarrow'
            %         increment = -1;
            %     otherwise
            %         return; % Autres touches ignorées
            % end
            %
            % % Récupérer la ROI actuellement sélectionnée via la table des ROIs
            % selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            % if isempty(selectedROIIndex)
            
            %     return;
            % end
            % selectedROI = app.content.ROIList{selectedROIIndex};
            %
            % % Mettre à jour le numéro de frame
            % currentFrame = selectedROI.display.frame;
            % numFrames = size(selectedROI.image, 4);
            % newFrame = max(1, min(currentFrame + increment, numFrames));
            % selectedROI.display.frame = newFrame;
            %
            % % Mettre à jour le slider et le champ d'édition correspondants
            % app.FrameSlider.Value = newFrame;
            % app.FrameEditField.Value = newFrame;
            %
            % % Rafraîchir l'affichage (image et histogramme)
            % score_display(app, 'refresh');
        end

        function checkOrCreateImageFigure(app)
            % Vérifier si app.ImageFigure n'existe pas ou n'est plus valide
            if ~isprop(app, 'ImageFigure') || isempty(app.ImageFigure) || ~ishandle(app.ImageFigure) || ~isvalid(app.ImageFigure)
                % Récupérer la position de la fenêtre principale
                mainPos = app.ScoreAppUIFigure.Position;  % [x, y, width, height]
                imageFigWidth = 800;
                imageFigHeight = 800;
                imageFigX = mainPos(1) + mainPos(3); % À droite de la fenêtre principale
                imageFigY = mainPos(2);

                % Créer la figure d'affichage sans menu ni toolbar
                app.ImageFigure = figure('Name', 'Affichage des images', ...
                    'MenuBar', 'none', 'ToolBar', 'none', ...
                    'Position', [imageFigX, imageFigY, imageFigWidth, imageFigHeight]);
                %app.ImageFigure.Color=[0 0 1];

                %   app.ImageFigure.WindowButtonDownFcn = @(src, event) score_paintOverlay(src, event, app);

                app.ImageFigure.KeyPressFcn = @(src, event) ImageFigureKeyPress(app, event);

                % Créer les axes pour occuper toute la figure
                % app.ImageAxes = axes('Parent', app.ImageFigure, 'Units', 'normalized', 'Position', [0 0 1 1], 'HitTest', 'off');

                % (Si nécessaire, initialiser également un overlay synchronisé)
                % app.OverlayAxes = axes(app.ImageFigure,'Units', 'normalized', 'Position', app.ImageAxes.Position, ...
                %    'Color', 'none', 'XColor', 'none', 'YColor', 'none','HitTest', 'on');

                %uistack(app.OverlayAxes, 'top');

                % Dans votre startupFcn, après avoir créé app.OverlayAxes :
                %app.OverlayAxes.ButtonDownFcn = @(src, event) score_paintOverlay(src, event, app);


                % Synchroniser la position et les limites entre les axes d'image et d'overlay
                % app.OverlayAxes.Position = app.ImageAxes.Position;
                % app.OverlayAxes.Color = 'none';
                % app.OverlayAxes.XColor = 'none';
                % app.OverlayAxes.YColor = 'none';
                % app.OverlayAxes.HitTest = 'off';
                % %app.OverlayAxes.Units = 'pixels';
                % linkaxes([app.ImageAxes, app.OverlayAxes], 'xy');
                % set(app.OverlayAxes, 'Visible', 'on');

            end
        end

      function updateAssignValueControls(app)
    % Récupère la ROI sélectionnée
    if isempty(app.UIROITable.Data) || size(app.UIROITable.Data,1) < 1
        return;
    end

    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
    if isempty(selectedROIIndex)
        return;
    end

    roi = app.content.ROIList{selectedROIIndex};

    % Vérifier que les sélections existent dans UIDataTable et UISubDataTable
    if isempty(app.UIDataTable.Selection) || isempty(app.UISubDataTable.Selection)
        return;
    end

    dsIndex = app.UIDataTable.Selection(1);
    subSel  = app.UISubDataTable.Selection(1);

    if dsIndex > size(app.UIDataTable.Data,1) || subSel > size(app.UISubDataTable.Data,1)
        warning('Sélection invalide.');
        return;
    end

    varName = app.UISubDataTable.Data{subSel,2};
    currentFrame = roi.display.frame;
    selectedData = roi.data(dsIndex);

    if isempty(selectedData.data) || currentFrame > size(selectedData.data, 1)
        app.c.Enable = 'off';
        app.ClassDropDown.Enable = 'off';
        return;
    end

    try
        if istable(selectedData.data)
            if ~any(strcmp(varName, selectedData.data.Properties.VariableNames))
                app.AssignvalueEditField.Enable = 'off';
                app.ClassDropDown.Enable = 'off';
                return;
            end
            val = selectedData.data{currentFrame, varName};
        elseif iscell(selectedData.data)
            header = selectedData.data(1,:);
            colIdx = find(strcmp(header, varName), 1);
            if isempty(colIdx)
                app.AssignvalueEditField.Enable = 'off';
                app.ClassDropDown.Enable = 'off';
                return;
            end
            dataRow = currentFrame + 1;
            if dataRow > size(selectedData.data,1)
                app.AssignvalueEditField.Enable = 'off';
                app.ClassDropDown.Enable = 'off';
                return;
            end
            val = selectedData.data{dataRow, colIdx};
        else
            error('Type de selectedData.data non supporté.');
        end
    catch ME
        warning('Erreur lors de l''extraction de la valeur : %s', ME.message);
        return;
    end

% ==========================================================
% CLASSES (seulement si la valeur est une classe/categorical)
% ==========================================================
userClasses = {};

% Ne calcule les classes que si on est sur une variable "label" / non numérique
% (ça évite categories() sur du double)
isLabelLike = ~isnumeric(val);  % logique cohérente avec ton UI plus bas

if isLabelLike
    % 1) priorité: userData.classes si dispo
    if isprop(selectedData,'userData') && isstruct(selectedData.userData) ...
            && isfield(selectedData.userData,'classes') && ~isempty(selectedData.userData.classes)
        userClasses = selectedData.userData.classes;

    else
        % 2) fallback: categories() si la colonne est categorical
        if istable(selectedData.data) && any(strcmp(varName, selectedData.data.Properties.VariableNames))
            colAll = selectedData.data{:, varName};
            if iscategorical(colAll)
                userClasses = categories(colAll);  % cellstr (souvent colonne)
            end
        end
    end

    % normalisation -> cell row
    if isstring(userClasses), userClasses = cellstr(userClasses); end
    if iscategorical(userClasses), userClasses = cellstr(string(userClasses)); end
    if ischar(userClasses), userClasses = {userClasses}; end
    if isempty(userClasses), userClasses = {}; end
    userClasses = userClasses(:)';  % row

    % ajouter unclassified sans doublon
    if ~any(strcmp(userClasses,'unclassified'))
        userClasses = [userClasses, {'unclassified'}];
    end
    if isempty(userClasses)
        userClasses = {'unclassified'};
    end

    app.ClassDropDown.Items = userClasses;
end



    % Gestion UI
      if isnumeric(val)
        app.AssignvalueEditField.Value  = num2str(val);
        app.AssignvalueEditField.Enable = 'on';
        app.ClassDropDown.Enable        = 'off';

    else
        app.AssignvalueEditField.Enable = 'off';
        app.ClassDropDown.Enable        = 'on';

        % ---- set dropdown VALUE (catégorie courante) ----
        % Convertir val en string "propre"
        if iscategorical(val)
            if any(isundefined(val))
                v = '';
            elseif isscalar(val)
                v = char(val);                 % ex: 'classA'
            else
                v = char(val(1));              % fallback si jamais non-scalar
            end
        elseif isstring(val)
            if any(ismissing(val))
                v = '';
            else
                v = char(val);
            end
        elseif ischar(val)
            v = val;
        elseif isa(val, 'missing')
            v = '';
        else
            s = string(val);
            if any(ismissing(s))
                v = '';
            else
                v = char(s);                   % dernier recours
            end
        end

        % Si la valeur n'est pas dans Items, on la rajoute (optionnel mais robuste)
        if ~any(strcmp(app.ClassDropDown.Items, v))
            app.ClassDropDown.Items = [app.ClassDropDown.Items, {v}];
        end

        % Fixer la valeur affichée
        app.ClassDropDown.Value = v;
    end
end

        function updatePanelsLayout(app)
            app.setAllPanelTabsVisible();
            app.updateDisplayMenu();
            return;

            % Liste des panels potentiellement affichables
            panels = {app.ROisPanel, app.DisplaysettingsPanel, app.DataSettingsPanel, app.AnnotationPanel, app.IntensityQuantificationPanel,app.MoviePanel};

            % Filtrer les panels visibles
            visiblePanels = panels(cellfun(@(p) strcmp(p.Visible, 'on'), panels));

            if isempty(visiblePanels)
                return;
            end

            % Récupérer les positions initiales des panels (définies lors de createComponents)
            panelSizes = cellfun(@(p) p.Position, visiblePanels, 'UniformOutput', false);

            % Paramètres de mise en page
            margin = 10;           % marge entre panels
            maxColumnHeight = 800; % hauteur maximum d'une colonne

            currentColumn = 1;
            currentY = maxColumnHeight; % départ en haut de la colonne
            newPositions = cell(size(visiblePanels));

            for i = 1:numel(visiblePanels)
                pos = panelSizes{i};
                panelWidth = pos(3);
                panelHeight = pos(4);

                % Passage à une nouvelle colonne si nécessaire
                if currentY - panelHeight - margin < 0
                    currentColumn = currentColumn + 1;
                    currentY = maxColumnHeight;
                end

                % Calcul de la nouvelle position pour le panel courant
                newX = (currentColumn - 1) * (panelWidth + margin) + margin;
                newY = currentY - panelHeight;
                newPositions{i} = [newX, newY, panelWidth, panelHeight];

                % Mettre à jour la position verticale pour le panel suivant
                currentY = newY - margin;
            end

            % Appliquer les nouvelles positions aux panels visibles
            for i = 1:numel(visiblePanels)
                visiblePanels{i}.Position = newPositions{i};
            end

            % Calculer la largeur totale nécessaire pour la fenêtre principale
            totalWidth = currentColumn * (max(cellfun(@(p) p.Position(3), visiblePanels)) + margin) + margin;
            newMainHeight = maxColumnHeight + 2*margin;

            % Ajuster la taille de la fenêtre principale
            % Window size is controlled by the App Designer tab layout.

            % Si l'image figure existe, l'ajuster pour qu'elle se positionne à droite
            if  isprop(app, 'ImageFigure') && ~isempty(app.ImageFigure) && ishandle(app.ImageFigure)
                % Récupérer la position de la fenêtre principale
                mainPos = app.ScoreAppUIFigure.Position;
                % Conserver la largeur et hauteur actuelles de l'image figure
                imageFigWidth = app.ImageFigure.Position(3);
                imageFigHeight = app.ImageFigure.Position(4);
                % Placer l'image figure à droite de la fenêtre principale, en conservant la même coordonnée Y
                newX = mainPos(1) + mainPos(3);
                newY = mainPos(2);
                % Image figure placement is left unchanged by panel tabs.
            end
        end


        function setAllPanelTabsVisible(app)
            panelNames = {'ROisPanel', 'DisplaysettingsPanel', 'DataSettingsPanel', ...
                'AnnotationPanel', 'IntensityQuantificationPanel', 'MoviePanel'};
            for k = 1:numel(panelNames)
                if isprop(app, panelNames{k})
                    panelObj = app.(panelNames{k});
                    if ~isempty(panelObj) && isvalid(panelObj)
                        panelObj.Visible = 'on';
                    end
                end
            end
        end

        function selectPanelTab(app, tabName)
            if ~isprop(app, 'TabGroup') || isempty(app.TabGroup) || ~isvalid(app.TabGroup)
                return;
            end

            tabObj = [];
            switch lower(char(string(tabName)))
                case {'roi', 'rois', 'roislist'}
                    tabObj = app.ROIslistTab;
                case {'display', 'displaysettings'}
                    tabObj = app.DisplaySettingsTab;
                case {'data', 'roidata'}
                    tabObj = app.ROIDataTab;
                case {'annotation', 'annotations'}
                    tabObj = app.AnnotationsTab;
                case {'quantification', 'intensity'}
                    tabObj = app.QuantificationTab;
                case {'movie', 'movieoutput'}
                    tabObj = app.MovieoutputTab;
            end

            if ~isempty(tabObj) && isvalid(tabObj)
                app.TabGroup.SelectedTab = tabObj;
            end

            app.setAllPanelTabsVisible();
            app.updateDisplayMenu();
        end

        function setupBrushSizeMenu(app)
            if ~isprop(app, 'AnnotationMenu') || isempty(app.AnnotationMenu) || ~isvalid(app.AnnotationMenu)
                return;
            end

            existing = findall(app.AnnotationMenu, 'Tag', 'ScoreBrushSizeMenu');
            if ~isempty(existing)
                delete(existing);
            end

            uimenu(app.AnnotationMenu, ...
                'Text', 'Brush size...', ...
                'Tag', 'ScoreBrushSizeMenu', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) app.openBrushSizeDialog());
        end

        function setupTrainingBoundsMenu(app)
            if ~isprop(app, 'AnnotationMenu') || isempty(app.AnnotationMenu) || ~isvalid(app.AnnotationMenu)
                return;
            end
            existing = findall(app.AnnotationMenu, 'Tag', 'ScoreTrainingBoundsMenu');
            if ~isempty(existing), delete(existing); end

            menu = uimenu(app.AnnotationMenu, ...
                'Text', 'Training frame bounds', ...
                'Tag', 'ScoreTrainingBoundsMenu', ...
                'Separator', 'on');
            startKey = 'W';
            endKey = 'X';
            try
                startKey = upper(char(string(app.specialkeys{2}{1})));
                endKey = upper(char(string(app.specialkeys{2}{2})));
            catch
            end
            uimenu(menu, 'Text', 'Set range...', ...
                'MenuSelectedFcn', @(~,~) app.updateTrainingFrameBounds('range'));
            uimenu(menu, 'Text', sprintf('Set start at current frame (%s)',startKey), ...
                'MenuSelectedFcn', @(~,~) app.updateTrainingFrameBounds('start'));
            uimenu(menu, 'Text', sprintf('Set end at current frame (%s)',endKey), ...
                'MenuSelectedFcn', @(~,~) app.updateTrainingFrameBounds('end'));
            uimenu(menu, 'Text', 'Use all frames', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) app.updateTrainingFrameBounds('all'));
        end

        function updateTrainingFrameBounds(app, action)
            if isempty(app.AnnotationSession) || ~isvalid(app.AnnotationSession)
                uialert(app.ScoreAppUIFigure, ...
                    'Training frame bounds are available from a managed annotation session.', ...
                    'Training frame bounds');
                return;
            end

            selectedROI = app.getSelectedROI();
            context = app.AnnotationSession.uiContext();
            if isempty(selectedROI) || ~strcmp(char(string(selectedROI.id)), context.roiId)
                uialert(app.ScoreAppUIFigure, ...
                    'Select the ROI attached to the current annotation session first.', ...
                    'Training frame bounds');
                return;
            end
            frameCount = annotationManager.frameCount(app.AnnotationSession.Roi);
            currentFrame = round(double(selectedROI.display.frame));
            oldBounds = app.AnnotationSession.frameBounds();

            switch lower(char(string(action)))
                case 'all'
                    app.AnnotationSession.clearFrameBounds();
                case 'range'
                    answer = inputdlg( ...
                        {'Inclusive range (for example 100:500), or all:'}, ...
                        'Training frame bounds', [1 55], ...
                        {trainingBounds.text(oldBounds)});
                    if isempty(answer), return; end
                    try
                        app.AnnotationSession.setFrameBounds( ...
                            trainingBounds.parse(answer{1}, 'FrameCount', frameCount));
                    catch ME
                        uialert(app.ScoreAppUIFigure, ME.message, ...
                            'Invalid training frame bounds');
                        return;
                    end
                case 'start'
                    if isempty(oldBounds)
                        newBounds = [currentFrame frameCount];
                    else
                        newBounds = [currentFrame max(currentFrame, oldBounds(2))];
                    end
                    app.AnnotationSession.setFrameBounds(newBounds);
                case 'end'
                    if isempty(oldBounds)
                        newBounds = [1 currentFrame];
                    else
                        newBounds = [min(oldBounds(1), currentFrame) currentFrame];
                    end
                    app.AnnotationSession.setFrameBounds(newBounds);
                otherwise
                    return;
            end
            app.AnnotationLastValidationValid = false;
            app.AnnotationQuickValidationState = 'idle';
            app.AnnotationQuickValidationMessage = '';
            app.refreshAnnotationSessionUI();
            trainingFrames = app.AnnotationSession.trainingFrames();
            if ~isempty(trainingFrames) && ~ismember(currentFrame,trainingFrames)
                app.showAnnotationFrame(trainingFrames(1));
            end
        end

        function loadBrushSettings(app)
            brush = struct('leftRadius', 7, 'middleRadius', 13, 'rightRadius', 4, 'eraserRadius', 7);

            try
                userprefs = detecdiv_prefs_load();
                if isfield(userprefs, 'painting_left_brush_radius')
                    brush.leftRadius = userprefs.painting_left_brush_radius;
                elseif isfield(userprefs, 'painting_normal_brush_radius')
                    brush.leftRadius = userprefs.painting_normal_brush_radius;
                elseif isfield(userprefs, 'painting_large_brush_size')
                    brush.leftRadius = sqrt(double(userprefs.painting_large_brush_size));
                end

                if isfield(userprefs, 'painting_middle_brush_radius')
                    brush.middleRadius = userprefs.painting_middle_brush_radius;
                elseif isfield(userprefs, 'painting_huge_brush_radius')
                    brush.middleRadius = userprefs.painting_huge_brush_radius;
                elseif isfield(userprefs, 'painting_huge_brush_size')
                    brush.middleRadius = sqrt(double(userprefs.painting_huge_brush_size));
                end

                if isfield(userprefs, 'painting_right_brush_radius')
                    brush.rightRadius = userprefs.painting_right_brush_radius;
                elseif isfield(userprefs, 'painting_large_brush_radius')
                    brush.rightRadius = userprefs.painting_large_brush_radius;
                end

                if isfield(userprefs, 'painting_eraser_brush_radius')
                    brush.eraserRadius = userprefs.painting_eraser_brush_radius;
                elseif isfield(userprefs, 'painting_fine_brush_radius')
                    brush.eraserRadius = userprefs.painting_fine_brush_radius;
                elseif isfield(userprefs, 'painting_small_brush_size')
                    brush.eraserRadius = sqrt(double(userprefs.painting_small_brush_size));
                end
            catch
            end

            app.DisplaySettings.Paint = app.normalizeBrushSettings(brush);
            assignin('base', 'DisplaySettings', app.DisplaySettings);
        end

        function brush = normalizeBrushSettings(app, brush) %#ok<INUSD>
            if ~isstruct(brush)
                brush = struct();
            end
            brush.leftRadius = localRadius({'leftRadius', 'normalRadius'}, 7);
            brush.middleRadius = localRadius({'middleRadius', 'hugeRadius'}, 13);
            brush.rightRadius = localRadius({'rightRadius', 'largeRadius'}, 4);
            brush.eraserRadius = localRadius({'eraserRadius', 'fineRadius'}, 7);

            function r = localRadius(fieldNames, fallback)
                r = fallback;
                try
                    for iName = 1:numel(fieldNames)
                        fieldName = fieldNames{iName};
                        if isfield(brush, fieldName) && ~isempty(brush.(fieldName))
                            v = double(brush.(fieldName));
                            if isfinite(v) && v > 0
                                r = min(50, max(1, round(v)));
                                return;
                            end
                        end
                    end
                catch
                end
            end
        end

        function openBrushSizeDialog(app)
            if ~isfield(app.DisplaySettings, 'Paint') || ~isstruct(app.DisplaySettings.Paint)
                app.loadBrushSettings();
            end
            brush = app.normalizeBrushSettings(app.DisplaySettings.Paint);

            dlg = uifigure('Name', 'Brush size', 'WindowStyle', 'modal', ...
                'Position', [300 300 450 340], 'Resize', 'off');
            grid = uigridlayout(dlg, [6 3]);
            grid.RowHeight = {28, 28, 28, 28, '1x', 34};
            grid.ColumnWidth = {155, 90, '1x'};
            grid.Padding = [12 12 12 12];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 10;

            uilabel(grid, 'Text', 'Left click radius');
            leftSpin = uispinner(grid, 'Limits', [1 50], 'RoundFractionalValues', 'on', ...
                'Value', brush.leftRadius);
            leftSpin.Layout.Row = 1; leftSpin.Layout.Column = 2;
            uilabel(grid, 'Text', 'normal brush');

            uilabel(grid, 'Text', 'Middle click radius');
            middleSpin = uispinner(grid, 'Limits', [1 50], 'RoundFractionalValues', 'on', ...
                'Value', brush.middleRadius);
            middleSpin.Layout.Row = 2; middleSpin.Layout.Column = 2;
            uilabel(grid, 'Text', 'enorme brush');

            uilabel(grid, 'Text', 'Right click radius');
            rightSpin = uispinner(grid, 'Limits', [1 50], 'RoundFractionalValues', 'on', ...
                'Value', brush.rightRadius);
            rightSpin.Layout.Row = 3; rightSpin.Layout.Column = 2;
            uilabel(grid, 'Text', 'gros brush');

            uilabel(grid, 'Text', 'Shift+left eraser radius');
            eraserSpin = uispinner(grid, 'Limits', [1 50], 'RoundFractionalValues', 'on', ...
                'Value', brush.eraserRadius);
            eraserSpin.Layout.Row = 4; eraserSpin.Layout.Column = 2;
            uilabel(grid, 'Text', 'eraser');

            ax = uiaxes(grid);
            ax.Layout.Row = 5;
            ax.Layout.Column = [1 3];
            ax.XTick = [];
            ax.YTick = [];
            ax.Box = 'on';
            axis(ax, 'equal');

            leftSpin.ValueChangedFcn = @(~,~) updatePreview();
            middleSpin.ValueChangedFcn = @(~,~) updatePreview();
            rightSpin.ValueChangedFcn = @(~,~) updatePreview();
            eraserSpin.ValueChangedFcn = @(~,~) updatePreview();

            saveButton = uibutton(grid, 'Text', 'Save', 'ButtonPushedFcn', @(~,~) saveBrush());
            saveButton.Layout.Row = 6; saveButton.Layout.Column = 2;
            cancelButton = uibutton(grid, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) delete(dlg));
            cancelButton.Layout.Row = 6; cancelButton.Layout.Column = 3;

            updatePreview();

            function updatePreview()
                cla(ax);
                hold(ax, 'on');
                drawCircle(leftSpin.Value, [0 0], [0.15 0.45 0.85]);
                drawCircle(middleSpin.Value, [80 0], [0.55 0.25 0.85]);
                drawCircle(rightSpin.Value, [160 0], [0.8 0.25 0.25]);
                drawCircle(eraserSpin.Value, [240 0], [0.1 0.1 0.1]);
                text(ax, 0, -62, 'Left', 'HorizontalAlignment', 'center');
                text(ax, 80, -62, 'Middle', 'HorizontalAlignment', 'center');
                text(ax, 160, -62, 'Right', 'HorizontalAlignment', 'center');
                text(ax, 240, -62, 'Eraser', 'HorizontalAlignment', 'center');
                xlim(ax, [-55 295]);
                ylim(ax, [-75 60]);
                hold(ax, 'off');
            end

            function drawCircle(radius, center, color)
                theta = linspace(0, 2*pi, 80);
                patch(ax, center(1) + radius*cos(theta), center(2) + radius*sin(theta), color, ...
                    'FaceAlpha', 0.25, 'EdgeColor', color, 'LineWidth', 1.5);
            end

            function saveBrush()
                brushOut = app.normalizeBrushSettings(struct( ...
                    'leftRadius', leftSpin.Value, ...
                    'middleRadius', middleSpin.Value, ...
                    'rightRadius', rightSpin.Value, ...
                    'eraserRadius', eraserSpin.Value));
                app.DisplaySettings.Paint = brushOut;
                assignin('base', 'DisplaySettings', app.DisplaySettings);

                try
                    userprefs = detecdiv_prefs_load();
                    userprefs.painting_left_brush_radius = brushOut.leftRadius;
                    userprefs.painting_middle_brush_radius = brushOut.middleRadius;
                    userprefs.painting_right_brush_radius = brushOut.rightRadius;
                    userprefs.painting_eraser_brush_radius = brushOut.eraserRadius;
                    userprefs.painting_normal_brush_radius = brushOut.leftRadius;
                    userprefs.painting_large_brush_radius = brushOut.rightRadius;
                    userprefs.painting_fine_brush_radius = brushOut.eraserRadius;
                    userprefs.painting_large_brush_size = brushOut.leftRadius^2;
                    userprefs.painting_small_brush_size = brushOut.eraserRadius^2;
                    userprefs.painting_huge_brush_size = brushOut.middleRadius^2;
                    detecdiv_prefs_save(userprefs);
                catch ME
                    warning('score:BrushPrefsSaveFailed', 'Could not save brush preferences: %s', ME.message);
                end

                delete(dlg);
            end
        end

        function updateDisplaySettings(app)
            app.setAllPanelTabsVisible();
            app.DisplaySettings.panels.ROisPanel = 'on';
            app.DisplaySettings.panels.DisplaysettingsPanel = 'on';
            app.DisplaySettings.panels.DataSettingsPanel = 'on';
            app.DisplaySettings.panels.AnnotationPanel = 'on';
            app.DisplaySettings.panels.IntensityQuantificationPanel = 'on';
            app.DisplaySettings.panels.MoviePanel = 'on';
            assignin('base', 'DisplaySettings', app.DisplaySettings);
            return;
            % Met à jour la structure en fonction de l'état actuel des panels
            app.DisplaySettings.panels.ROisPanel = app.ROisPanel.Visible;
            app.DisplaySettings.panels.DisplaysettingsPanel = app.DisplaysettingsPanel.Visible;
            app.DisplaySettings.panels.DataSettingsPanel = app.DataSettingsPanel.Visible;
            app.DisplaySettings.panels.AnnotationPanel = app.AnnotationPanel.Visible;
            app.DisplaySettings.panels.IntensityQuantificationPanel = app.IntensityQuantificationPanel.Visible;
            app.DisplaySettings.panels.MoviePanel = app.MoviePanel.Visible;

            % Stocke la structure dans le workspace de base

             assignin('base', 'DisplaySettings', app.DisplaySettings);
        end

        function localMenuState = localMenuChecked(app, selectedTab, tabProp)
            localMenuState = 'off';
            if isprop(app, tabProp)
                tabObj = app.(tabProp);
                if ~isempty(selectedTab) && ~isempty(tabObj) && isvalid(tabObj) && isequal(selectedTab, tabObj)
                    localMenuState = 'on';
                end
            end
        end

        function updateDisplayMenu(app)
            selectedTab = [];
            if isprop(app, 'TabGroup') && ~isempty(app.TabGroup) && isvalid(app.TabGroup)
                selectedTab = app.TabGroup.SelectedTab;
            end

            app.ROIsMenu.Checked = app.localMenuChecked(selectedTab, 'ROIslistTab');
            app.DisplaysettingsMenu.Checked = app.localMenuChecked(selectedTab, 'DisplaySettingsTab');
            app.IntensityquantificationMenu.Checked = app.localMenuChecked(selectedTab, 'QuantificationTab');
            app.AnnotationMenu.Checked = app.localMenuChecked(selectedTab, 'AnnotationsTab');
            app.DatasettingsMenu.Checked = app.localMenuChecked(selectedTab, 'ROIDataTab');
            app.MovieMenu.Checked = app.localMenuChecked(selectedTab, 'MovieoutputTab');
            return;
            % Met à jour le menu "Display" pour refléter l'état de visibilité des panels

            % ROIs panel
            if isprop(app, 'ROisPanel') && strcmp(app.ROisPanel.Visible, 'on')
                app.ROIsMenu.Checked = 'on';
            else
                app.ROIsMenu.Checked = 'off';
            end

            % Display settings panel
            if isprop(app, 'DisplaysettingsPanel') && strcmp(app.DisplaysettingsPanel.Visible, 'on')
                app.DisplaysettingsMenu.Checked = 'on';
            else
                app.DisplaysettingsMenu.Checked = 'off';
            end

            % Intensity quantification panel
            if isprop(app, 'IntensityQuantificationPanel') && strcmp(app.IntensityQuantificationPanel.Visible, 'on')
                app.IntensityquantificationMenu.Checked = 'on';
            else
                app.IntensityquantificationMenu.Checked = 'off';
            end

            % Annotation panel
            if isprop(app, 'AnnotationPanel') && strcmp(app.AnnotationPanel.Visible, 'on')
                app.AnnotationMenu.Checked = 'on';
            else
                app.AnnotationMenu.Checked = 'off';
            end

            % Data settings panel
            if isprop(app, 'DataSettingsPanel') && strcmp(app.DataSettingsPanel.Visible, 'on')
                app.DatasettingsMenu.Checked = 'on';
            else
                app.DatasettingsMenu.Checked = 'off';
            end

            % Data settings panel
            if isprop(app, 'MoviePanel') && strcmp(app.MoviePanel.Visible, 'on')
                app.MovieMenu.Checked = 'on';
            else
                app.MovieMenu.Checked = 'off';
            end

        end

        function quantifyChannelFluo(app)
            %% Récupérer la ROI sélectionnée et le projet parent
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            fovtmp=selectedROI.parent;

            ok = 0;
            if isa(fovtmp, 'fov')
                f = fovtmp.parent;
                if isa(f, 'shallow')
                    shallowObj = f;
                    ok = 1;
                end
            end
            if ok == 0
                uialert(app.ScoreAppUIFigure, 'Could not find parent projet; quitting....', 'Error');
                return;
            end

            %% Création de la progress dialog
            d = uiprogressdlg(app.ScoreAppUIFigure, 'Title', 'Please Wait...', ...
                'Message', 'Starting compute All metrics...');
            d.Value = 0.01;


            % Étape 1 : ROI et projet parent trouvés
            d.Message = 'ROI and parent project found';
            d.Value = 0.05;


            %% Ajouter un channel correspondant à l'ellipse (mask)
            annotationName = 'ellipsoid_shape_mask';
            pix = selectedROI.findChannelID(annotationName);

            % Charger l'image si nécessaire
            if numel(selectedROI.image) == 0
                selectedROI.load;
            end

            d.Message = 'Loading image and checking mask channel';
            d.Value = 0.10;


            if ~isempty(pix)
                % Si le channel existe déjà, récupérer le mask existant
                %  mask = selectedROI.image(:,:,pix,:);
            else
                % Créer un nouveau mask en reprenant la taille de l'image
                sz=size(selectedROI.image);
                mask = uint16(zeros(sz(1),sz(2),1,sz(4)));
                newColor = [1 1 1];
                newIntensity = [0, 0, 0];
                newChannelName = annotationName;
                newClassName = newChannelName;

                % Ajouter le nouveau channel via la méthode addChannel
                selectedROI.addChannel(mask, newChannelName, newColor, newIntensity);

                % Consigner la création dans le log
                %  selectedROI.log(['Added new class "' newClassName '" for annotation "' annotationName '"'], 'Processing');

                % Après ajout, récupérer l'indice du channel créé
                pix = selectedROI.findChannelID(annotationName);
            end

            d.Message = 'Mask channel updated';
            d.Value = 0.20;


            %% Récupérer le masque associé à l'ellipse
            if isempty(app.EllipseIntensityProfileObj) || ~isvalid(app.EllipseIntensityProfileObj)
                uialert(app.ScoreAppUIFigure, 'Could not find the mask of the ellipse....', 'Error');
                close(d);
                return;
            end
            I = selectedROI.image(:,:,1,selectedROI.display.frame);
            mask_with_ellipsoid_pixels = createMask(app.EllipseIntensityProfileObj, I);


            d.Message = 'Ellipse mask computed';
            d.Value = 0.35;

            % Mettre à jour l'image de la ROI avec le masque (en répliquant sur 3 canaux et pour toutes les frames)
            frames = size(selectedROI.image, 4);  % Nombre de frames
            % Répliquer le masque dans la 3ème dimension par 1 (monochrome) et dans la 4ème dimension par frames
            selectedROI.image(:,:,pix,:) = repmat(mask_with_ellipsoid_pixels, [1 1 1 frames]);

            d.Message = 'ROI image updated with ellipse mask';
            d.Value = 0.45;


            %% Identifier ou définir l'objet processObj
            processObj = app.getProcessorByName(shallowObj,'ComputeAllMetrics');
            if isempty(processObj)
                processObj = lifespan_setupPreProcessing(shallowObj, 'ComputeAllMetrics', 12);
            end

            d.Message = 'Processor object configured';
            d.Value = 0.60;


            % Définir le nombre de frames à traiter
            frames = size(selectedROI.image, 4);

            % Construire les arguments pour le processing
            arg = {'Progress', d, 'Frames', frames};

            % Configurer le processObj avec le mask à utiliser pour la quantification
            processObj.processArg.mask1_name = {'ellipsoid_shape_mask', 'ellipsoid_shape_mask'};
            processObj.processArg.mask1_class=1;
            processObj.processArg.mask1_stat = true;
            processObj.processArg.mask2_stat = false;

            % Sélectionner les channels cochés dans la table des channelsDisplaySubData
            selectedChannelIndex = find(cell2mat(app.UIChannelTable.Data(:, 1))==1);
            cc = 1;
            for i = selectedChannelIndex
                name = app.UIChannelTable.Data{i, 2};
                channelIdx = app.resolveDisplayChannelIndex(selectedROI, name);
                if ~isempty(channelIdx)
                    name = selectedROI.display.channel{channelIdx};
                end
                processObj.processArg.(['channel' num2str(cc) '_name']) = {name name};
                cc = cc + 1;
                if cc > 4  % only up to 4 channels are considered
                    break;
                end
            end

            d.Message = 'Starting processing...';
            d.Value = 0.80;

            selectedROI.save;
            processData(processObj, selectedROI, arg{:});


            d.Message = 'Processing complete';
            d.Value = 0.95;

            % draw the new datatable
            displayData(app);
            displaySubData(app);

            % reload roi because process data clears out the data.
            selectedROI.load;

            % Finalisation de la progress dialog
            d.Value = 1;
            pause(0.2);
            close(d);

        end




        % must define a channel for elliptical mask
        % setparameters for processor : channels, segmentation mask etc...



        function procObj = getProcessorByName(app, shallowObj, targetName)
            % getProcessorByName recherche dans app.shallowObj.processing.processor
            % l'instance dont le champ strid, dénué du suffixe "_XX", correspond à targetName.
            %
            % INPUT :
            %   app        - l'objet app contenant app.shallowObj.processing.processor
            %   targetName - le nom de base à rechercher (exemple : 'myProcessor')
            %
            % OUTPUT :
            %   procObj    - l'instance trouvée, ou [] si aucune correspondance n'est trouvée

            procObj = [];
            % Vérifier que la propriété processor existe et n'est pas vide
            if ~isfield(shallowObj.processing, 'processor') || isempty(shallowObj.processing.processor)
                return;
            end

            allProc = shallowObj.processing.processor;
            % Construire un pattern regex pour accepter targetName seul ou suivi de _ et de chiffres
            pattern = ['^', regexptranslate('escape', targetName), '(_\d+)?$'];

            for k = 1:numel(allProc)
                if isprop(allProc(k), 'strid')
                    if ~isempty(regexp(allProc(k).strid, pattern, 'once'))
                        procObj = allProc(k);
                        return;
                    end
                end
            end
        end


        function events = parseMovieEventMarkers(app, rawText) %#ok<INUSL>
            events = {};
            if nargin < 2 || isempty(rawText)
                return;
            end
            if istable(rawText) || iscell(rawText)
                events = rawText;
                return;
            end
            txt = char(string(rawText));
            txt = strrep(txt, newline, ';');
            rows = regexp(txt, '[;\r\n]+', 'split');
            for i = 1:numel(rows)
                row = strtrim(rows{i});
                if isempty(row)
                    continue;
                end
                parts = regexp(row, '\s*,\s*', 'split');
                if numel(parts) == 1 && contains(row, ':')
                    pair = regexp(row, '\s*:\s*', 'split');
                    framePart = pair{1};
                    labelPart = pair{2};
                    frameRange = regexp(framePart, '\s*[-:]\s*', 'split');
                    if numel(frameRange) >= 2
                        parts = {frameRange{1}, frameRange{2}, labelPart};
                    else
                        parts = {framePart, framePart, labelPart};
                    end
                end
                startFrame = str2double(parts{1});
                if numel(parts) >= 2
                    endFrame = str2double(parts{2});
                else
                    endFrame = startFrame;
                end
                if ~isfinite(startFrame)
                    continue;
                end
                if ~isfinite(endFrame)
                    endFrame = startFrame;
                end
                label = "";
                if numel(parts) >= 3 && strlength(string(parts{3})) > 0
                    label = string(parts{3});
                end
                width = '1.5';
                if numel(parts) >= 4 && strlength(string(parts{4})) > 0
                    width = char(string(parts{4}));
                end
                events(end+1, :) = {true, startFrame, endFrame, char(label), width}; %#ok<AGROW>
            end
        end


        function channelIndex = resolveDisplayChannelIndex(app, selectedROI, channelLabel) %#ok<INUSL>
            channelIndex = find(strcmp(selectedROI.display.channel, channelLabel), 1);
            if ~isempty(channelIndex)
                return;
            end
            if isfield(selectedROI.display, 'channelAlias') && ~isempty(selectedROI.display.channelAlias)
                channelIndex = find(strcmp(selectedROI.display.channelAlias, channelLabel), 1);
            end
        end


        function arg=setMovieMosaicArguments(app)

            % Récupérer les paramètres du movie depuis DisplaySettings.Movie
            CopypresetsMenuSelected(app);
            dsM = app.DisplaySettings.Movie;

            % Construction de la liste d'arguments pour mosaic.m
            arg = {};

            % --- Paramètres liés au movie ---
            % 'Frames' : conversion de la chaîne (ex. '1:10') en tableau numérique
            arg = [arg, {'frames', str2num(dsM.MovieFramesEditField)}];
            % 'Output' : type de sortie (ex. 'Movie')
            arg = [arg, {'mode', dsM.MovieoutputtypeDropDown}];
            % 'Name' : nom du fichier de sortie
            arg = [arg, {'name', dsM.MovieoutputfilenameEditField}];
            % 'IPS' : frames per second (conversion de chaîne en nombre)
            arg = [arg, {'IPS', str2num(dsM.MovieframespersecondEditField)}];
            % 'Framerate' : minutes per frame (conversion)
            arg = [arg, {'framerate', str2num(dsM.MovieminutesperframeEditField)}];
            % 'HideStamp' : booléen indiquant s'il faut masquer le timestamp
            arg = [arg, {'hideStamp', dsM.MoviehidetimestampCheckBox}];
            % 'TimeOffset' : ici non défini dans dsM, on met 0 par défaut
            arg = [arg, {'timeOffset', dsM.MovieoffsettimeCheckBox}];
            % 'Background' : couleur de fond (conversion de chaîne en vecteur numérique)
            arg = [arg, {'background', str2num(dsM.MoviebackgroundcolorEditField)}];
            % 'Text' : couleur du texte (conversion)
            arg = [arg, {'textColor', str2num(dsM.MovietextcolorEditField)}];
            % 'FontSize' : taille de la police (conversion)
            arg = [arg, {'fontSize', str2num(dsM.MoviefontsizeEditField)}];
            % 'Title' : si la checkbox est activée, on passe un titre par défaut
            arg = [arg, {'title', dsM.MovietitleEditField}];

            % 'Scale' : facteur d'échelle pour le movie
            arg = [arg, {'scalingFactor', str2num(dsM.MoviescaleEditField)}];
            % 'Crop' : zone de crop (passée telle quelle, peut être vide)
            arg = [arg, {'crop', str2num(dsM.MoviecropEditField)}];
            % 'ROITitle' : ici on active l'affichage du titre des ROIs (modifiable si nécessaire)
            arg = [arg, {'ROITitle', false}];
            % 'ArraySize' : taille de l'array pour disposer les ROIs (conversion)
            arg = [arg, {'arraySize', str2num(dsM.MovieROIArraysizeEditField)}];

            % select how to treat first class
            arg = [arg, {'defaultClass', dsM.defaultClass}];
            % select painting mode
            arg = [arg, {'paintChannel', dsM.paintChannel}];
            tmp=dsM.OverlayCheckBox;
            arg = [arg, {'overlay', dsM.OverlayCheckBox}];
            arg= [arg , {'Nbrick',str2num(app.MovieImagetodataratioEditField.Value)}];
            arg= [arg , {'track',dsM.MoviedatatrackCheckBox}];
            arg= [arg , {'trackWindow',str2num(dsM.MovietrackwindowEditField)}];
            arg= [arg , {'colormap',dsM.MoviecolormapEditField}];
            arg= [arg , {'dataColormap',dsM.MovieDatacolormapEditField}];
            arg= [arg , {'legend',dsM.MovielegendCheckBox}];
            arg= [arg , {'ROITitle',dsM.MovieROItitleCheckBox}];
            if isprop(app, 'MovieeventmarkersEditField') && strlength(string(app.MovieeventmarkersEditField.Value)) > 0
                eventMarkers = app.parseMovieEventMarkers(app.MovieeventmarkersEditField.Value);
            elseif isfield(dsM, 'MovieeventmarkersEditField') && strlength(string(dsM.MovieeventmarkersEditField)) > 0
                eventMarkers = app.parseMovieEventMarkers(dsM.MovieeventmarkersEditField);
            elseif isfield(dsM, 'eventMarkers') && ~isempty(dsM.eventMarkers)
                eventMarkers = dsM.eventMarkers;
            else
                eventMarkers = [];
            end
            arg= [arg , {'eventMarkers', eventMarkers}];

            % Mise en page pour l'affichage des images


            arr=str2num(app.MovieROIArraysizeEditField.Value);
            nRow = arr(1);
            nCol = arr(2);

            arg = [arg, {'Ncol', nCol}];
            arg = [arg, {'Nrow', nRow}];


            % % --- Paramètres liés aux channels ---
            % dsC = app.DisplaySettings.channels;
            % % On ne considère que les channels sélectionnés
            % selCh = find(dsC.selectedchannel);
            % if ~isempty(selCh)
            %     % Récupérer le nom des channels (cell array de chaînes)
            %     channels = dsC.channel(selCh);
            %
            %     % Pour chaque channel, construire un vecteur numérique [low high]
            %     levels = cell(1, numel(selCh));
            %     for i = 1:numel(selCh)
            %         idx = selCh(i);
            %         lowVal  = round(65535 * dsC.displaylim(1, idx));
            %         highVal = round(65535 * dsC.displaylim(2, idx));
            %         levels{i} = [lowVal, highVal];
            %
            %         if dsC.indexed(idx)
            %             levels{i}={};
            %              levels{i}{1}='-1';
            %              levels{i}{2}=dsM.MoviecolormapEditField;
            %              levels{i}{3}=dsC.alpha(idx);
            %              levels{i}{4}=dsC.contour(idx);
            %              levels{i}{5}=dsC.width(idx);
            %         else
            %              levels{i} = [lowVal, highVal];
            %         end
            %     end
            %
            %     % Construire pour chaque channel le vecteur RGB
            %     colors = cell(1, numel(selCh));
            %     for i = 1:numel(selCh)
            %         idx = selCh(i);
            %         colors{i} = dsC.rgb(idx, :);
            %     end
            %
            %     % Construire les poids pour chaque channel en tant que vecteur numérique
            %     weights = dsC.alpha(selCh);  % Extraction directe sous forme numérique
            %
            %     arg = [arg, {'Channel', channels}];
            %     arg = [arg, {'Levels', levels}];
            %     arg = [arg, {'RGB', colors}];
            %     arg = [arg, {'Weights', weights}];
            %
            % end

            % % Ajout de l'option 'DisplayTest' si le second argument est fourni
            % if nargin == 2
            %     arg = [arg, {'DisplayTest'}];
            % end

        end

        function createIntensityLine(app)
            % Bouton activé : afficher la ligne de profil
            if ~isempty(app.LineIntensityProfileLine) && isvalid(app.LineIntensityProfileLine)
                % La ligne existe déjà ; vous pouvez éventuellement la laisser telle quelle
                % ou la mettre au premier plan (par exemple, en la recréant si nécessaire)
            else
                % Déterminer la position initiale de la ligne
                if ~isempty(app.LineProfilePosition)
                    pos = app.LineProfilePosition;  % Utiliser la position mémorisée
                else


                    % Position par défaut : ligne horizontale au milieu de l'axe de l'image
                    % xLimits = app.OverlayAxes.XLim;
                    %yLimits = app.OverlayAxes.YLim;

                    xLimits =  app.graphicsHandles.overlayHandles(1).Parent.XLim;
                    yLimits =  app.graphicsHandles.overlayHandles(1).Parent.YLim;

                    pos = [xLimits(1)+10, mean(yLimits); xLimits(2)-10, mean(yLimits)];
                end
                % Créer la ligne sur l'axe de l'image
                app.LineIntensityProfileLine = imline(app.graphicsHandles.overlayHandles(1).Parent, pos);
                % Ajouter un callback pour mettre à jour le profil quand la ligne est déplacée
                addNewPositionCallback(app.LineIntensityProfileLine, @(newPos) score_updateIntensityProfile(app, newPos));
            end


        end

        function createEllipse(app)
            % Bouton activé : afficher ou créer l'ellipse de profil
            if isempty(app.EllipseIntensityProfileObj) || ~isvalid(app.EllipseIntensityProfileObj)
                % Déterminer la position initiale de l'ellipse
                if ~isempty(app.EllipseProfilePosition)
                    % Utiliser la position mémorisée (format [x y width height])
                    pos = app.EllipseProfilePosition;
                    center = [pos(1) + pos(3)/2, pos(2) + pos(4)/2];
                    semiAxes = [pos(3)/2, pos(4)/2];
                else
                    % Position par défaut : ellipse centrée dans l'axe de l'image
                    xLimits = app.graphicsHandles.overlayHandles(1).Parent.XLim;
                    yLimits = app.graphicsHandles.overlayHandles(1).Parent.YLim;
                    width  = (xLimits(2)-xLimits(1)) * 0.5;
                    height = (yLimits(2)-yLimits(1)) * 0.5;
                    center = [mean(xLimits), mean(yLimits)];
                    semiAxes = [width/4, height/4];
                end
                % Créer l'ellipse en spécifiant 'Center' et 'SemiAxes'
                app.EllipseIntensityProfileObj = drawellipse(app.graphicsHandles.overlayHandles(1).Parent, ...
                    'Center', center, 'SemiAxes', semiAxes);
                % Ajouter des listeners pour mettre à jour le profil en temps réel
                addlistener(app.EllipseIntensityProfileObj, 'MovingROI', @(src,evt) score_updateEllipticalProfile(app, src));
                addlistener(app.EllipseIntensityProfileObj, 'ROIMoved', @(src,evt) score_updateEllipticalProfile(app, src));

                cm = app.EllipseIntensityProfileObj.ContextMenu;

                % Supprimer les items par défaut "Fix Aspect Ratio" et "Delete Ellipse"
                delete(findall(cm, 'Label', 'Delete Ellipse'));

                % Ajouter un nouvel item au menu contextuel avec une callback personnalisée
                uimenu(cm, 'Label', 'Quantify channel fluorescence over time', ...
                    'Callback', @(src, event) quantifyChannelFluo(app));
            end
        end
    end




    % Callbacks that handle component events
    methods (Access = private)

        function SelectedTrackIDEditFieldValueChanged(app, event)
            value = str2double(char(string(event.Value)));
            if ~isfinite(value) || value < 1 || value ~= round(value)
                score_updateSelectedObjectFields(app);
                uialert(app.ScoreAppUIFigure, ...
                    'Track ID must be a positive integer.', 'Assign track');
                return;
            end
            try
                score_assignSelectedTrack(app, value, 'frame');
            catch ME
                score_updateSelectedObjectFields(app);
                uialert(app.ScoreAppUIFigure, ME.message, 'Assign track');
            end
        end

        function CreateFromPredictionButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.AnnotationSession), return; end
            summary = app.AnnotationSession.summary();
            overwrite = any([summary.components.groundTruthExists]);
            try
                catalog = app.AnnotationSession.initializationCatalog();
                if isempty(event)
                    recipe = catalog.defaultRecipe;
                    accepted = true;
                else
                    [recipe, accepted] = annotationInitializationDialog( ...
                        app.ScoreAppUIFigure, catalog, ...
                        'HasExistingGT', overwrite, 'RoiCount', 1);
                end
                if ~accepted, return; end
            catch ME
                uialert(app.ScoreAppUIFigure, ME.message, ...
                    'Initialize ground truth');
                return;
            end
            try
                app.AnnotationSession.initialize(recipe, 'Overwrite', overwrite);
                app.AnnotationLastValidationValid = false;
                app.AnnotationQuickValidationState = 'idle';
                app.AnnotationQuickValidationMessage = '';
                app.replaceAnnotationSessionROI();
                app.refreshAnnotationSessionUI();
                app.applyAnnotationDisplayPreset();
            catch ME
                uialert(app.ScoreAppUIFigure, ME.message, ...
                    'Initialize ground truth');
            end
        end

        function StartBlankGTButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.AnnotationSession), return; end
            summary = app.AnnotationSession.summary();
            overwrite = any([summary.components.groundTruthExists]);
            if overwrite && ~app.confirmAnnotationOverwrite( ...
                    'Erase the current GT and start from a blank annotation?')
                return;
            end
            try
                app.AnnotationSession.startBlank('Overwrite', overwrite);
                app.AnnotationLastValidationValid = false;
                app.AnnotationQuickValidationState = 'idle';
                app.AnnotationQuickValidationMessage = '';
                app.replaceAnnotationSessionROI();
                app.refreshAnnotationSessionUI();
                app.applyAnnotationDisplayPreset();
            catch ME
                uialert(app.ScoreAppUIFigure, ME.message, 'Start blank GT');
            end
        end

        function MarkFrameReviewedButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.AnnotationSession), return; end
            roi = app.getSelectedROI();
            if isempty(roi), return; end
            try
                components = app.AnnotationSession.Spec.components;
                trainingFrames = app.AnnotationSession.trainingFrames();
                if ~ismember(round(double(roi.display.frame)),trainingFrames)
                    frame = app.nextIncompleteAnnotationFrame();
                    if ~isempty(frame), app.showAnnotationFrame(frame); end
                    return;
                end
                required = [components.required];
                frameComponents = {components(required & strcmp( ...
                    {components.coverageUnit}, 'frame')).id};
                roiComponents = {components(required & strcmp( ...
                    {components.coverageUnit}, 'roi')).id};
                summary = app.AnnotationSession.summary();
                coverageComponents = summary.coverage.components;
                requiredCoverage = coverageComponents(ismember( ...
                    string({coverageComponents.id}), string({components(required).id})));
                frameCoverage = requiredCoverage(strcmp({requiredCoverage.unit}, 'frame'));
                roiCoverage = requiredCoverage(strcmp({requiredCoverage.unit}, 'roi'));
                framesComplete = isempty(frameCoverage) || all( ...
                    [frameCoverage.reviewed] >= [frameCoverage.total]);
                roiIncomplete = ~isempty(roiCoverage) && any( ...
                    [roiCoverage.reviewed] < [roiCoverage.total]);

                modifiers = {};
                try
                    modifiers = app.ScoreAppUIFigure.CurrentModifier;
                catch
                end
                markEntireRoi = iscell(modifiers) && any(strcmpi(modifiers, 'shift'));

                if markEntireRoi
                    choice = uiconfirm(app.ScoreAppUIFigure, ...
                        ['Confirm that the complete ROI (masks, tracks and ' ...
                         'lineage) was reviewed?'], ...
                        'Confirm complete ROI', ...
                        'Options', {'Confirm entire ROI','Cancel'}, ...
                        'DefaultOption', 1, 'CancelOption', 2);
                    if strcmp(choice, 'Cancel'), return; end
                    app.AnnotationSession.markReviewed();
                elseif framesComplete && roiIncomplete
                    choice = uiconfirm(app.ScoreAppUIFigure, ...
                        'Confirm that ROI-level tracks and lineage were reviewed?', ...
                        'Confirm tracks and lineage', ...
                        'Options', {'Confirm','Cancel'}, ...
                        'DefaultOption', 1, 'CancelOption', 2);
                    if strcmp(choice, 'Cancel'), return; end
                    app.AnnotationSession.markReviewed('Components', roiComponents);
                else
                    app.AnnotationSession.markReviewed( ...
                        'Frames', roi.display.frame, ...
                        'Components', frameComponents);
                end
                app.AnnotationLastValidationValid = false;
                app.AnnotationReviewDirty = false;
                app.refreshAnnotationSessionUI();
                if ~markEntireRoi && ~(framesComplete && roiIncomplete)
                    frame = app.nextIncompleteAnnotationFrame();
                    if ~isempty(frame) && frame ~= roi.display.frame
                        app.showAnnotationFrame(frame);
                    end
                end
            catch ME
                uialert(app.ScoreAppUIFigure, ME.message, 'Review annotation');
            end
        end

        function MarkThroughCurrentButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.AnnotationSession), return; end
            roi = app.getSelectedROI();
            if isempty(roi), return; end
            frame = round(double(roi.display.frame));
            ids = app.annotationFrameComponentIds();
            if isempty(ids), return; end
            frames = app.AnnotationSession.trainingFrames();
            frames = frames(frames <= frame);
            if isempty(frames)
                uialert(app.ScoreAppUIFigure, ...
                    'The current frame is before the training interval.', ...
                    'Review through current frame');
                return;
            end
            choice = uiconfirm(app.ScoreAppUIFigure, sprintf( ...
                ['Confirm that training frames %d through %d were reviewed ' ...
                 'for all frame-level GT components?'],frames(1),frames(end)), ...
                'Review through current frame', ...
                'Options', {'Confirm training range','Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 2);
            if strcmp(choice, 'Cancel'), return; end
            try
                app.AnnotationSession.markReviewed('Frames', frames, ...
                    'Components', ids, 'Save', false);
                app.AnnotationReviewDirty = true;
                app.AnnotationLastValidationValid = false;
                app.refreshAnnotationSessionUI();
            catch ME
                uialert(app.ScoreAppUIFigure, ME.message, ...
                    'Review through current frame');
            end
        end

        function NextIncompleteButtonPushed(app, event) %#ok<INUSD>
            frame = app.nextIncompleteAnnotationFrame();
            if isempty(frame), return; end
            app.showAnnotationFrame(frame);
        end

        function showAnnotationFrame(app, frame)
            roi = app.getSelectedROI();
            if isempty(roi), return; end
            app.reviewFrameBeforeNavigation(roi.display.frame, frame);
            roi.display.frame = frame;
            app.FrameSlider.Value = frame;
            app.FrameEditField.Value = frame;
            app.FrameEditField_2.Value = frame;
            score_display(app, 'refresh');
        end

        function issue = firstAnnotationParentageIssue(app)
            issue = struct([]);
            if isempty(app.AnnotationSession), return; end
            roi = app.getSelectedROI();
            if isempty(roi), return; end
            try
                components = app.AnnotationSession.Spec.components;
                lineageIndex = find(strcmp({components.kind}, 'lineage') & ...
                    strcmp({components.storage}, 'cell_model_family'), ...
                    1, 'first');
                if isempty(lineageIndex), return; end
                [model, ~] = roi.loadCellModel('MigrateLegacy', true);
                report = annotationManager.validateParentage(model, ...
                    components(lineageIndex).groundTruth.family, ...
                    'Frames', app.AnnotationSession.trainingFrames());
                if isfield(report, 'issues') && ~isempty(report.issues)
                    issue = report.issues(1);
                end
            catch
                issue = struct([]);
            end
        end

        function focusAnnotationParentageIssue(app, issue)
            roi = app.getSelectedROI();
            if isempty(roi) || isempty(issue), return; end
            frame = double(issue.focus_frame);
            if ~isfinite(frame) || frame < 1
                frame = double(issue.event_frame);
            end
            if ~isfinite(frame) || frame < 1, return; end

            [model, ~] = roi.loadCellModel('MigrateLegacy', true);
            [familyIndex, familyId] = cellModel.familyIndex( ...
                model, issue.family_id);
            if isempty(familyIndex), return; end
            provider = char(string(model.families.mask_provider{familyIndex}));
            instance = cellModel.findTrackInstance(model, familyId, frame, ...
                issue.focus_track_id);
            if isempty(instance)
                app.showAnnotationFrame(frame);
                return;
            end

            targetRow = [];
            for row = 1:size(app.UIAnnotationTable.Data, 1)
                if strcmp(app.annotationTableChannelName(row), provider)
                    targetRow = row;
                    break;
                end
            end
            if ~isempty(targetRow)
                app.UIAnnotationTable.Selection = [targetRow 1];
                app.UIAnnotationTableSelectionChanged([]);
            end
            app.showAnnotationFrame(frame);

            pix = roi.findChannelID(provider);
            channelIndex = find(strcmp(roi.display.channel, provider), ...
                1, 'first');
            if isempty(pix) || isempty(channelIndex), return; end
            maskLabel = double(instance.mask_label);
            mask = roi.image(:,:,pix,frame);
            [rows, columns] = find(mask == maskLabel);
            if isempty(rows), return; end

            app.SelectedObjectLabel = maskLabel;
            app.SelectedObjectLabelCell = maskLabel;
            app.SelectedTrackIDCell = double(issue.focus_track_id);
            app.SelectedObjectChannelIdx = channelIndex;
            app.SelectedObjectRoiId = string(roi.id);
            app.KeepSelection = true;
            score_updateSelectedObjectFields(app);

            try
                if ~isempty(app.SelectedObjectRectangle) && ...
                        isgraphics(app.SelectedObjectRectangle)
                    delete(app.SelectedObjectRectangle);
                end
                overlay = findobj(app.ImageFigure, 'Tag', 'IndexedOverlay');
                if isempty(overlay)
                    overlay = findobj(app.ImageFigure, 'Type', 'image');
                end
                if ~isempty(overlay)
                    axesHandle = ancestor(overlay(1), 'axes');
                    bounds = [min(columns)-0.5 min(rows)-0.5 ...
                        max(columns)-min(columns)+1 max(rows)-min(rows)+1];
                    app.SelectedObjectRectangle = rectangle(axesHandle, ...
                        'Position', bounds, 'EdgeColor', [1 1 0], ...
                        'LineWidth', 3, 'LineStyle', '--', ...
                        'HitTest', 'off', 'PickableParts', 'none');
                end
            catch
            end
            app.ImageFigure.Name = sprintf( ...
                'ROI:%s - Frame: %d/%d - Parentage conflict: Track %u', ...
                char(string(roi.id)), frame, size(roi.image,4), ...
                uint64(issue.focus_track_id));
            drawnow limitrate;
        end

        function removeAnnotationParentageIssue(app, issue)
            roi = app.getSelectedROI();
            if isempty(roi) || isempty(issue), return; end
            [model, ~] = roi.loadCellModel('MigrateLegacy', true);
            [model, removal] = cellModel.removeTrack(model, ...
                issue.family_id, issue.missing_track_id, 'Fast', true);
            if removal.relations_removed < 1
                uialert(app.ScoreAppUIFigure, ...
                    'The broken parentage relation is no longer present.', ...
                    'Parentage repair');
                return;
            end
            roi.cellModel = model;
            app.notifyAnnotationChanged('parentage', ...
                double(issue.event_frame), 'Save', false);
            app.AnnotationLastValidationValid = false;
            app.refreshAnnotationSessionUI();
            uialert(app.ScoreAppUIFigure, sprintf([ ...
                '%d broken parentage relation(s) involving missing Track %u ' ...
                'were removed. Save the ROI to persist this repair.'], ...
                removal.relations_removed, issue.missing_track_id), ...
                'Parentage repaired', 'Icon', 'success');
        end

        function ValidateAnnotationButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.AnnotationSession), return; end
            try
                report = app.AnnotationSession.validate();
                app.AnnotationLastValidationValid = logical(report.valid);
                if report.valid
                    app.AnnotationQuickValidationState = 'valid';
                    app.AnnotationQuickValidationMessage = 'Full validation passed.';
                    message = 'GT is valid and can be approved.';
                    titleText = 'Annotation valid';
                    icon = 'success';
                    if ~isempty(report.warnings)
                        message = sprintf('%s\n\nWarnings:\n%s', message, ...
                            strjoin(cellstr(report.warnings), '\n'));
                    end
                else
                    app.AnnotationQuickValidationState = 'invalid';
                    app.AnnotationQuickValidationMessage = char(strjoin( ...
                        cellstr(report.errors), newline));
                    message = sprintf('Validation failed:\n%s', ...
                        strjoin(cellstr(report.errors), '\n'));
                    titleText = 'Annotation validation';
                    icon = 'warning';
                end
                app.refreshAnnotationSessionUI();
                issue = struct([]);
                if ~report.valid
                    issue = app.firstAnnotationParentageIssue();
                end
                if ~isempty(issue) && double(issue.focus_frame) > 0
                    message = sprintf([ ...
                        '%s\n\nMissing Track %u has no mask anywhere in this GT, ' ...
                        'so it cannot be displayed. Score can open frame %u and ' ...
                        'highlight related Track %u, or remove the stale link now.'], ...
                        message, issue.missing_track_id, issue.focus_frame, ...
                        issue.focus_track_id);
                    choice = uiconfirm(app.ScoreAppUIFigure, message, ...
                        titleText, 'Icon', icon, ...
                        'Options', {'Go to related track', ...
                            'Remove broken link','Close'}, ...
                        'DefaultOption', 1, 'CancelOption', 3);
                    if strcmp(choice, 'Go to related track')
                        app.focusAnnotationParentageIssue(issue);
                    elseif strcmp(choice, 'Remove broken link')
                        app.removeAnnotationParentageIssue(issue);
                    end
                else
                    uialert(app.ScoreAppUIFigure, message, titleText, 'Icon', icon);
                end
            catch ME
                app.AnnotationLastValidationValid = false;
                app.refreshAnnotationSessionUI();
                uialert(app.ScoreAppUIFigure, ME.message, 'Annotation validation');
            end
        end

        function ApproveAnnotationButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.AnnotationSession), return; end
            try
                app.AnnotationSession.approve();
                app.AnnotationLastValidationValid = false;
                app.AnnotationReviewDirty = false;
                app.refreshAnnotationSessionUI();
                uialert(app.ScoreAppUIFigure, ...
                    'GT approved and ready for training.', 'Annotation approved', ...
                    'Icon', 'success');
            catch ME
                app.AnnotationLastValidationValid = false;
                app.refreshAnnotationSessionUI();
                uialert(app.ScoreAppUIFigure, ME.message, 'Approve annotation');
            end
        end

        function ShowPredictionCheckBoxValueChanged(app, event) %#ok<INUSD>
            app.applyAnnotationDisplayPreset();
        end

        % Code that executes after component creation
        function startupFcn(app, roiobj, options, varargin)
            if nargin < 3, options = ''; end
            % App Designer owns the layout; runtime wiring remains centralized
            % here so layout synchronization cannot silently drop callbacks.
            if isprop(app, 'ChannelModeButtonGroup') && ...
                    ~isempty(app.ChannelModeButtonGroup) && isvalid(app.ChannelModeButtonGroup)
                app.ChannelModeButtonGroup.SelectionChangedFcn = ...
                    @(src, event) ObjectDisplayModeChanged(app, event); %#ok<NASGU>
            end
            app.DisplayCriterionDropDown.ValueChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.LineageDisplayButtonGroup.SelectionChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.ObjectFamilyDropDown.ValueChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.MaskProviderDropDown.ValueChangedFcn = ...
                @(src, event) ObjectMaskProviderChanged(app, event); %#ok<NASGU>
            app.LineageSourceDropDown.ValueChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.FamilyColorPicker.ValueChangedFcn = ...
                @(src, event) ObjectDisplayColorChanged(app, event); %#ok<NASGU>
            app.SemanticValueDropDown.ValueChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.SemanticValueColorPicker.ValueChangedFcn = ...
                @(src, event) ObjectDisplayColorChanged(app, event); %#ok<NASGU>
            app.BudlinkcolorColorPicker.ValueChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.GenealogyLinkColorPicker.ValueChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.LineageLinkWidthEditField.ValueChangedFcn = ...
                @(src, event) ObjectDisplaySettingChanged(app, event); %#ok<NASGU>
            app.LineageLinkWidthEditField.Tooltip = ...
                'Mother-bud link width in image pixels (1 to 20).';
            app.SelectedCellStateDropDown.ValueChangedFcn = ...
                @(src, event) score_updateSelectedCellState(app); %#ok<NASGU>
            app.SelectedTrackIDEditField.ValueChangedFcn = ...
                @(src, event) SelectedTrackIDEditFieldValueChanged(app, event); %#ok<NASGU>
            app.SelectedTrackIDEditField.Tooltip = ...
                'Edit the selected object track on the current frame.';
            app.CreateFromPredictionButton.Tooltip = ...
                ['Initialize editable GT from the model prediction, an existing ' ...
                 'object family, a segmentation mask, or blank content.'];
            app.MarkFrameReviewedButton.Text = 'Reviewed + next';
            app.MarkFrameReviewedButton.Tooltip = [ ...
                'Mark the current frame reviewed and open the next incomplete frame. ' ...
                'Shift+click confirms the complete ROI.'];
            app.MarkThroughCurrentButton.Tooltip = ...
                'Confirm all frame-level GT components from frame 1 through the current frame.';
            app.ReviewWhileNavigatingCheckBox.Tooltip = [ ...
                'When enabled, leaving a frame with the keyboard or review navigation ' ...
                'marks its frame-level GT components reviewed.'];
            app.AnnotationTargetLabel.Tooltip = ...
                ['After GT creation: double-click a cell, then right-click its ' ...
                 'selection rectangle for track and parent actions.'];
            app.setManagedAnnotationLayout(false);
            % Rendre visibles les panels souhaités

            % Ajouter la ROI à la liste
            % Loading is centralized in addROI so stale image caches are
            % refreshed before the first channel table/render is created.


            checkOrCreateImageFigure(app);

 
                  try
                app.DisplaySettings = evalin('base', 'DisplaySettings');
                catch
                % Sinon, définir des réglages par défaut
                app.DisplaySettings.panels.ROisPanel = 'on';
                app.DisplaySettings.panels.DisplaysettingsPanel = 'on';
                app.DisplaySettings.panels.DataSettingsPanel = 'off';
                app.DisplaySettings.panels.AnnotationPanel = 'off';
                app.DisplaySettings.panels.IntensityQuantificationPanel = 'off';
                app.DisplaySettings.panels.MoviePanel = 'off';

                % Stocker dans le workspace de base
                assignin('base', 'DisplaySettings', app.DisplaySettings);
                  end


            % load shortcut keys
            pth=userpath;
            if ispc
                fle= fullfile(pth,'Detecdiv/userprefs.mat');
            else
                tmpfile=getenv("HOME");
                fle=fullfile(strcat(tmpfile,'/Detecdiv'),'userprefs.mat');
            end

            if exist(fle)
                load(fle) % loads userprefs variable
                keys=textscan(userprefs.roi_view_shortcut_keys,'%s');
                keys=keys{1};
                keys=keys';


                specialkeys={};
                tmp=userprefs.roi_view_corr_shortcut_keys;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{1}=tmp;
                tmp=userprefs.roi_view_bounds_shortcut_keys;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{2}=tmp;
                tmp=userprefs.roi_view_frames_jump_size;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{3}=tmp;
                tmp=userprefs.painting_fill_holes_shortcut;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{4}=tmp;
                tmp=userprefs.painting_transparency_shortcut;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{5}=tmp;

                app.specialkeys=specialkeys;
                app.keys=keys;

            else % structure must me created
                errordlg('Could not file the shortcut preferences; Please reset user preferences before launching this window again!,Error');
                close
                return;
            end

                setupMovieCallbacks(app);
                app.loadBrushSettings();
                app.setupBrushSizeMenu();
                app.setupTrainingBoundsMenu();

            applyMovieDisplaySettings(app);


            error = app.addROI(roiobj, options, varargin{:});

            if error==0
                evalin('base', 'clear DisplaySettings');
                delete(app.ImageFigure);
                delete(app);
                return;
            end

            score_refreshObjectDisplayUI(app);

            if exist('detecdiv_event', 'file') == 2
                try
                    app.PipelineRunEventListenerId = detecdiv_event('subscribe', ...
                        'pipelineRunCompleted', ...
                        @(payload, eventName)app.onPipelineRunCompleted(payload, eventName));
                catch
                    app.PipelineRunEventListenerId = '';
                end
            end

       

            if numel(app.MovieFramesEditField.Value)==0 % set default frames for movie
                % Trouver la ROI actuellement sélectionnée via la table des ROIs
                selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
                if isempty(selectedROIIndex)
                    return;
                end
                selectedROI = app.content.ROIList{selectedROIIndex};

                app.DisplaySettings.Movie.MovieFramesEditField=['1:' num2str(size(selectedROI.image,4))];
                app.MovieFramesEditField.Value= app.DisplaySettings.Movie.MovieFramesEditField;
                app.DisplaySettings.Movie.MovieFramesEditField= app.MovieFramesEditField.Value;
            end

        end

        % Callback function
        function DisplaysettingsMenuSelected(app, event)

        end

        % Callback function
        function ROIsMenuSelected(app, event)

        end

        % Callback function
        function DatasettingsMenuSelected(app, event)

        end

        % Callback function
        function DataMenuSelected(app, event)

        end

        % Callback function
        function DisplaysettingsMenuSelected2(app, event)

        end

        % Menu selected function: ROIsMenu
        function ROIsMenuSelected2(app, event)
            app.selectPanelTab('roi');
            app.updateDisplaySettings();
        end

        % Menu selected function: DatasettingsMenu
        function DatasettingsMenuSelected2(app, event)
            app.selectPanelTab('data');
            app.updateDisplaySettings();
        end

        % Menu selected function: DisplaysettingsMenu
        function DisplaysettingsMenuSelected3(app, event)
            app.selectPanelTab('display');
            updateDisplaySettings(app);
        end

        % Selection changed function: UIChannelTable
        function UIChannelTableSelectionChanged(app, event)
            selection = app.UIChannelTable.Selection;
            % Vérifier si une ROI est sélectionnée
            if isempty(app.content.ROIList)
                app.SelectedChannelLabel.Text = 'Selected Channel: None';
                return;
            end

            % Trouver la ROI actuellement sélectionnée
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                app.SelectedChannelLabel.Text = 'Selected Channel: None';
                return;
            end

            % Vérifier si un canal est sélectionné dans la table
            selectedChannelIndex = app.UIChannelTable.Selection;
            if isempty(selectedChannelIndex) || isempty(selectedChannelIndex(1))
                app.SelectedChannelLabel.Text = 'Selected Channel: None';
                return;
            end

            % Récupérer le nom du canal sélectionné
            selectedChannelName = app.UIChannelTable.Data{selectedChannelIndex(1), 2};

            % Mettre à jour le label avec le nom du canal sélectionné
            app.SelectedChannelLabel.Text = sprintf('Selected Channel: %s', selectedChannelName);

            % Mettre à jour les sliders et le color picker pour refléter les paramètres du canal
            displayChannelFeatures(app);

        end

        % Value changing function: ZoomSlider
        function ZoomSliderValueChanging(app, event)

            % Récupérer la valeur actuelle du slider depuis l'événement (en pourcentage : 100 à 500)
            zoomPercent = event.Value;
            zoomFactor = zoomPercent / 100;  % 1 pour 100%, 5 pour 500%
            app.PreviousZoomFactor=zoomFactor;

            app.ImageAxes=app.graphicsHandles.imgHandles(1).Parent;

            % Si le slider est exactement à 100, on réinitialise la baseline
            if abs(zoomPercent - 100) < 1e-3
                app.OriginalXLim = app.ImageAxes.XLim;
                app.OriginalYLim = app.ImageAxes.YLim;
            end

            % Si la baseline n'est pas encore définie, l'initialiser
            if isempty(app.OriginalXLim) || isempty(app.OriginalYLim)
                app.OriginalXLim = app.ImageAxes.XLim;
                app.OriginalYLim = app.ImageAxes.YLim;
            end

            % Toujours utiliser le centre actuel de l'axe pour le zoom "sur place"

            center = [mean(app.ImageAxes.XLim), mean(app.ImageAxes.YLim)];

            % Définir la dimension de référence (baseline) en se basant sur la vue à 100%
            baselineWidth  = app.OriginalXLim(2) - app.OriginalXLim(1);
            baselineHeight = app.OriginalYLim(2) - app.OriginalYLim(1);

            % Calculer la nouvelle largeur et hauteur selon le facteur de zoom
            newWidth  = baselineWidth / zoomFactor;
            newHeight = baselineHeight / zoomFactor;

            % Calculer les nouvelles limites en centrant la vue autour du centre actuel
            newXLim = [center(1) - newWidth/2, center(1) + newWidth/2];
            newYLim = [center(2) - newHeight/2, center(2) + newHeight/2];

            % Mettre à jour les limites de l'axe de l'image
            set(app.ImageAxes, 'XLim', newXLim, 'YLim', newYLim);

            % Gérer le mode Pan : désactiver si zoomFactor est 1, sinon activer
            if zoomFactor < 1.1
                pan(app.ImageFigure, 'off');
                app.PanButton.Value=0;
            else
                pan(app.ImageFigure, 'on');
                app.PanButton.Value=1;
            end

        end

        % Value changing function: FrameSlider
        function FrameSliderValueChanging(app, event)
            changingValue = event.Value;

            % Récupérer la nouvelle valeur du slider et l'arrondir
            newFrame = round(event.Value);

            % Vérifier qu'une ROI est présente
            if isempty(app.content.ROIList)
                return;
            end

            % Trouver l'index de la ROI actuellement sélectionnée (celle cochée dans la table)
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Obtenir le nombre total de frames pour cette ROI
            numFrames = size(selectedROI.image, 4);
            % S'assurer que newFrame est dans l'intervalle valide
            if newFrame < 1
                newFrame = 1;
            elseif newFrame > numFrames
                newFrame = numFrames;
            end

            % Mettre à jour le numéro de frame dans la ROI
            selectedROI.display.frame = newFrame;
            app.FrameEditField.Value=selectedROI.display.frame;
            app.FrameEditField_2.Value=selectedROI.display.frame;

            % Mettre à jour l'affichage (image et histogramme) en mode "refresh"
            score_display(app, 'refresh');

        end

        % Value changing function: WeightSlider
        function WeightSliderValueChanging(app, event)
            changingValue = event.Value;

            % Vérifier si une ROI est sélectionnée
            if isempty(app.content.ROIList)
                return;
            end

            % Trouver l'index de la ROI actuellement sélectionnée
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                return;
            end

            % Récupérer la ROI sélectionnée
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Vérifier si un canal est sélectionné
            selectedChannelIndex = app.UIChannelTable.Selection;
            if isempty(selectedChannelIndex) || isempty(selectedChannelIndex(1))
                return;
            end

            % Trouver l'index réel du canal dans colorChannels
            channelName = app.UIChannelTable.Data{selectedChannelIndex(1), 2}; % Nom du canal
            channelIndex = app.resolveDisplayChannelIndex(selectedROI, channelName);

            if isempty(channelIndex)
                return;
            end

            % Mettre à jour la valeur du poids dans selectedROI
            newWeight = max(0.01,event.Value); % Récupérer la nouvelle valeur du slider
            selectedROI.display.alpha(channelIndex) = newWeight;

            % Mettre à jour la colonne "Weight" dans la table des channels
            updateChannelTable(app, selectedROI);
            % app.UIChannelTable.Data{selectedChannelIndex(1), 5} = sprintf('%.2f', newWeight);

        end

        % Callback function: ChannelColorPicker
        function ChannelColorPickerValueChanged(app, event)
            value = app.ChannelColorPicker.Value;
            % Vérifier si une ROI est sélectionnée
            if isempty(app.content.ROIList)
                return;
            end

            % Trouver l'index de la ROI actuellement sélectionnée
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                return;
            end

            % Récupérer la ROI sélectionnée
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Vérifier si un canal est sélectionné dans la table des canaux
            selectedChannelIndex = app.UIChannelTable.Selection;
            if isempty(selectedChannelIndex) || isempty(selectedChannelIndex(1))
                return;
            end

            % Trouver l'index réel du canal dans colorChannels
            channelName = app.UIChannelTable.Data{selectedChannelIndex(1), 2}; % Nom du canal
            channelIndex = app.resolveDisplayChannelIndex(selectedROI, channelName);

            if isempty(channelIndex)
                return;
            end

            % Récupérer la nouvelle couleur du color picker
            newRGB = event.Value;

            % Mettre à jour la couleur RGB dans selectedROI
            score_applyChannelColorSpec(selectedROI, channelIndex, sprintf('%.6g %.6g %.6g', newRGB));

            % Mettre à jour la colonne "RGB" dans la table des canaux
            updateChannelTable(app, selectedROI);
            %app.UIChannelTable.Data{selectedChannelIndex(1), 4} = sprintf('%.2f %.2f %.2f', newRGB);
        end

        % Value changed function: FrameEditField
        function FrameEditFieldValueChanged(app, event)

            % Récupérer la nouvelle valeur entrée par l'utilisateur et l'arrondir
            newFrame = round(app.FrameEditField.Value);

            % Vérifier qu'une ROI est présente
            if isempty(app.content.ROIList)
                return;
            end

            % Récupérer la ROI sélectionnée
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Déterminer le nombre de frames disponibles
            numFrames = size(selectedROI.image, 4);

            % Contraindre newFrame à l'intervalle [1, numFrames]
            if newFrame < 1
                newFrame = 1;
            elseif newFrame > numFrames
                newFrame = numFrames;
            end

            % Mettre à jour le slider et la propriété de la ROI
            app.FrameSlider.Value = newFrame;
            selectedROI.display.frame = newFrame;

            % Mettre à jour le champ d'édition (au cas où il ait été ajusté)
            app.FrameEditField.Value = newFrame;

            % Rafraîchir l'affichage (image et histogramme)
            score_display(app, 'refresh');
        end

        % Key press function: ScoreAppUIFigure
        function ScoreAppUIFigureKeyPress(app, event)
            % Gestion de la touche Suppr pour supprimer la ROI en cours

            %profile on
            if strcmp(event.Key, 'delete')

                % Récupérer l'indice de la ROI actuellement sélectionnée
                roiData = app.UIROITable.Data;
                if isempty(roiData)
                    return;
                end
                selectedIndex = find(cell2mat(roiData(:,1)), 1);
                if ~isempty(selectedIndex)
                    % Supprimer la ROI sélectionnée de la liste
                    app.content.ROIList(selectedIndex) = [];

                    % Mettre à jour le tableau des ROI
                    app.displayROIs();

                    % Sélectionner la ROI précédente si elle existe
                    if selectedIndex > 1 && ~isempty(app.UIROITable.Data)
                        newIndex = selectedIndex - 1;
                        % Remettre toutes les cases à false
                        tableData = app.UIROITable.Data;
                        for i = 1:size(tableData,1)
                            tableData{i,1} = false;
                        end
                        tableData{newIndex,1} = true;
                        app.UIROITable.Data = tableData;
                    end
                end

                % Si aucune ROI ne reste, fermer la fenêtre principale (et l'app)
                if isempty(app.content.ROIList)
                    delete(app.ScoreAppUIFigure);
                else
                    % Sinon, rafraîchir l'affichage
                    score_display(app, 'refresh');
                end
                return;  % Ne pas traiter d'autres touches
            end

            specialkeys=app.specialkeys;
            keys=app.keys;


            % Gestion des autres touches (exemple pour les flèches)
            specialevent=false;

            switch event.Key
                case 'rightarrow'
                    increment = 1;
                    specialevent=true;
                case 'leftarrow'
                    increment = -1;
                    specialevent=true;
                case specialkeys{3}{2}
                    increment = 10;
                    specialevent=true;
                case specialkeys{3}{1}
                    increment = -10;
                    specialevent=true;
                otherwise
                    %  return;
            end



            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};
            currentFrame = selectedROI.display.frame;

            % Bounds shortcuts are active only inside a managed annotation
            % session, so the same keys remain available to legacy class
            % annotation workflows.
            hasManagedSession = ~isempty(app.AnnotationSession) && ...
                isvalid(app.AnnotationSession);
            if hasManagedSession && numel(specialkeys) >= 2 && ...
                    numel(specialkeys{2}) >= 2
                if strcmpi(event.Key, specialkeys{2}{1})
                    app.updateTrainingFrameBounds('start');
                    return;
                elseif strcmpi(event.Key, specialkeys{2}{2})
                    app.updateTrainingFrameBounds('end');
                    return;
                end
            end

            if specialevent % frame events
                numFrames = size(selectedROI.image, 4);
                newFrame = max(1, min(currentFrame + increment, numFrames));
                app.reviewFrameBeforeNavigation(currentFrame, newFrame);
                selectedROI.display.frame = newFrame;
                app.FrameSlider.Value = newFrame;
                app.FrameEditField.Value = newFrame;
                score_display(app, 'refresh'); % also refreshes the display of the data
                return;
            else % class allocation key

                   % --- déterminer la classe sélectionnée via la touche ----
    selectedClassIndex = [];
    for i = 1:numel(app.keys)
        if strcmp(event.Key, app.keys{i})
            selectedClassIndex = i;
            break;
        end
    end
    if isempty(selectedClassIndex)
        return;
    end


    % --- vérifications de sélection dans les tables ----
    if isempty(app.UIDataTable.Data) || isempty(app.UISubDataTable.Data) || ...
            isempty(app.UIDataTable.Selection) || isempty(app.UISubDataTable.Selection)
        try
            app.SelecteddataLabel.Text = 'No data selected for class assignment';
        catch
        end
        return;
    end

    % --- indices / variable ciblée ---
    dsIndex = app.UIDataTable.Selection(1);
    subSel  = app.UISubDataTable.Selection(1);
    varName = app.UISubDataTable.Data{subSel, 2};

    % --- dataset / classes disponibles ---
    selectedData = selectedROI.data(dsIndex);
    classList    = app.ClassDropDown.Items;

    if selectedClassIndex > numel(classList)
        warning('selected key does not correspond to a class');
        return;
    end

  
    % --- valeur à affecter en fonction de la variable ciblée ---
    switch string(varName)
        case "id_training"
            newValue = selectedClassIndex;
        case "labels_training"
            newValue = classList{selectedClassIndex};
        otherwise
            % on ne modifie que id_training ou labels_training
            return;
    end

    % --- calcul de la portée (frame courante ou jusqu'à la fin si Shift) ---
    numFrames = size(selectedROI.image, 4);
    currentFrame = selectedROI.display.frame;

   

    isShift = isprop(event,'Modifier') && ~isempty(event.Modifier) ...
              && any(strcmpi(event.Modifier, 'shift'));
    if isShift
        frameRange = currentFrame:numFrames;   % appliquer à toute la suite
    else
        frameRange = currentFrame;             % seulement à la frame courante
    end


    % --- écriture de la/les valeurs sur la/les frame(s) ciblée(s) ---
    for f = frameRange
        % si la variable est catégorielle, convertir proprement
        if iscategorical(selectedData.data{f, varName})
            if ischar(newValue)
                nv = cellstr(newValue);
            else
                nv = newValue;
            end
            selectedData.data{f, varName} = categorical(nv);
        else
            selectedData.data{f, varName} = newValue;
        end
    end

    % --- sauver dans la ROI et rafraîchir l'affichage ---
    selectedROI.data(dsIndex) = selectedData;
    app.notifyAnnotationChanged(varName, frameRange);
    score_display(app, 'refresh');  % met aussi à jour l'affichage des données
            %'ok'
          %   profile viewer
            end
            
        end

        % Value changed function: OverlayCheckBox
        function OverlayCheckBoxValueChanged(app, event)
            value = app.OverlayCheckBox.Value;
            app.LineIntensityprofileButton.Value=false;
            app.ShapeButton.Value=false;
            LineIntensityprofileButtonValueChanged2(app, event);
            ShapeButtonValueChanged(app,event);
            app.DisplaySettings.Movie.OverlayCheckBox=value;
            score_display(app, 'slow');
        end

        % Callback function
        function LineIntensityprofileButtonValueChanged(app, event)



        end

        % Value changed function: LineIntensityprofileButton
        function LineIntensityprofileButtonValueChanged2(app, event)
            value = app.LineIntensityprofileButton.Value;

            if app.LineIntensityprofileButton.Value
                % Désactiver le mode ellipse
                app.ShapeButton.Value = false;
                ShapeButtonValueChanged(app, []);

                createIntensityLine(app);

                % Mise à jour immédiate du profil d'intensité avec la position actuelle de la ligne
                score_updateIntensityProfile(app, getPosition(app.LineIntensityProfileLine));
            else
                % Bouton désactivé : mémoriser la position et supprimer la ligne
                if ~isempty(app.LineIntensityProfileLine) && isvalid(app.LineIntensityProfileLine)
                    app.LineProfilePosition = getPosition(app.LineIntensityProfileLine);
                    delete(app.LineIntensityProfileLine);  % Supprime la ligne
                    app.LineIntensityProfileLine = [];
                end
                % Effacer le plot du profil d'intensité
                cla(app.UIProfileAxes);
            end



        end

        % Value changed function: ShapeButton
        function ShapeButtonValueChanged(app, event)
            value = app.ShapeButton.Value;

            if value
                app.LineIntensityprofileButton.Value = false;
                LineIntensityprofileButtonValueChanged2(app, []);

                createEllipse(app);
                % Mise à jour immédiate du profil avec l'ellipse actuelle
                score_updateEllipticalProfile(app, app.EllipseIntensityProfileObj);
            else
                % Bouton désactivé : mémoriser la position et supprimer l'ellipse
                if ~isempty(app.EllipseIntensityProfileObj) && isvalid(app.EllipseIntensityProfileObj)
                    % Pour récupérer la position, on utilise les propriétés 'Center' et 'SemiAxes'
                    center = app.EllipseIntensityProfileObj.Center;
                    semiAxes = app.EllipseIntensityProfileObj.SemiAxes;
                    app.EllipseProfilePosition = [center(1)-semiAxes(1), center(2)-semiAxes(2), 2*semiAxes(1), 2*semiAxes(2)];
                    delete(app.EllipseIntensityProfileObj);
                    app.EllipseIntensityProfileObj = [];
                end
                % Effacer le plot du profil
                cla(app.UIProfileAxes);

            end


        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            % Récupérer la ROI actuellement sélectionnée via la table des ROIs
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Récupérer la taille de l'image brute
            imgSize = size(selectedROI.image);  % [height, width, channels, frames]
            imgHeight = imgSize(1);
            imgWidth  = imgSize(2);

            % Vérifier si l'overlay est actif
            if app.OverlayCheckBox.Value
                % En mode overlay, on affiche l'image composite qui occupe la taille de l'image
                newOrigXLim = [1, imgWidth];
                newOrigYLim = [1, imgHeight];
            else
                % En mode non-overlay, l'image de chaque canal est affichée empilée verticalement.
                % Déterminer le nombre de canaux affichés via la table (colonne 1)
                if isempty(app.UIChannelTable.Data)
                    newOrigXLim = [1, imgWidth];
                    newOrigYLim = [1, imgHeight];
                else
                    checkboxValues = cell2mat(app.UIChannelTable.Data(:,1));
                    numDisplayed = sum(checkboxValues);
                    if numDisplayed < 1
                        numDisplayed = 1;
                    end
                    newOrigXLim = [1, imgWidth];
                    newOrigYLim = [1, numDisplayed * imgHeight];
                end
            end

            app.ImageAxes=app.graphicsHandles.imgHandles(1).Parent;
            % Réinitialiser l'axe UIImageAxes aux nouveaux paramètres
            set(app.ImageAxes, 'XLim', newOrigXLim, 'YLim', newOrigYLim);

            % Mettre à jour les propriétés de référence du zoom
            app.OriginalXLim = newOrigXLim;
            app.OriginalYLim = newOrigYLim;
            app.PreviousZoomFactor = 1;

            % Réinitialiser le ZoomSlider à 100%
            app.ZoomSlider.Value = 100;

            % Désactiver le mode Pan
            pan(app.ImageFigure, 'off'); % pour activer

            % Optionnel : si vous utilisez un bouton "Restore View" intégré à l'axe,
            % vous pouvez également réinitialiser son état ici.
            score_display(app,'slow');

        end

        % Callback function
        function PanOFFButtonValueChanged(app, event)

        end

        % Value changing function: LowHighDisplaySlider
        function LowHighDisplaySliderValueChanging(app, event)
            changingValue = event.Value;
            % event.Value est un vecteur à 2 éléments : [lowVal, highVal] (en échelle logarithmique)
            lowLogVal = event.Value(1);
            highLogVal = event.Value(2);

            % Convertir en valeurs linéaires en tenant compte que l'échelle est basée sur 65535
            newLow = 10^(lowLogVal) / 65535;
            newHigh = 10^(highLogVal) / 65535;

            % Récupérer la ROI et le canal sélectionné
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Vérifier que l'utilisateur a sélectionné un canal dans la table des channels
            selectedChannelIndex = app.UIChannelTable.Selection;
            if isempty(selectedChannelIndex) || isempty(selectedChannelIndex(1))
                return;
            end
            selectedChannelName = app.UIChannelTable.Data{selectedChannelIndex(1), 2};
            channelIndex = app.resolveDisplayChannelIndex(selectedROI, selectedChannelName);
            if isempty(channelIndex)
                return;
            end

            % Mettre à jour la propriété displaylim pour ce canal avec les nouvelles valeurs
            selectedROI.display.displaylim(:, channelIndex) = [newLow; newHigh];

            % Mettre à jour la table des canaux (pour refléter les nouvelles valeurs)
            updateChannelTable(app, selectedROI);

            % Forcer la mise à jour de l'affichage (image et histogramme)
            score_display(app, 'refresh');
        end

        % Selection changed function: UIAnnotationTable
        function UIAnnotationTableSelectionChanged(app, event)
            % Récupérer la sélection de la table d'annotation
            selection = app.UIAnnotationTable.Selection;

            if isempty(selection)
                app.DisplaySettings.Movie.paintChannel=0;
                score_refreshObjectDisplayUI(app);
                return;
            end

            % Vérifier qu'une ROI est sélectionnée via la table des ROIs
            if isempty(app.content.ROIList)
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Vérifier qu'une ligne est sélectionnée dans la table d'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                return;
            end

            % Récupérer les parties "Annotation" (colonne 2) et "Class" (colonne 3)
            annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
            classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};
            % Reconstruire le nom complet sans suffixe artificiel.
            if isempty(classPart)
                fullChannelName = char(string(annotationPart));
            else
                fullChannelName = [char(string(annotationPart)), '_', ...
                    char(string(classPart))];
            end

            % Trouver l'indice réel du canal dans selectedROI.display.channel
            channelIndex = find(strcmp(selectedROI.display.channel, fullChannelName), 1);
            if isempty(channelIndex)
                return;
            end

            % Mettre à jour le MaskColorPicker avec la couleur associée dans selectedROI.display.rgb
            app.MaskColorPicker.Value = selectedROI.display.rgb(channelIndex, :);

            app.Transparency.Value=selectedROI.display.alpha(channelIndex);

            % Mettre à jour le label avec le nom complet du canal sélectionné
            app.IndexChannelLabel.Text = sprintf(' %s', fullChannelName);

            score_refreshObjectDisplayUI(app);
            app.PaintButtonValueChanged([]);



        end

        % Callback function: MaskColorPicker
        function MaskColorPickerValueChanged(app, event)
            newColor = event.Value;  % La nouvelle couleur sélectionnée, par exemple [R G B]

            % Vérifier qu'une ROI est sélectionnée
            if isempty(app.content.ROIList)
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Vérifier qu'une ligne est sélectionnée dans la table d'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                return;
            end

            % Récupérer les parties "Annotation" et "Class" depuis les colonnes 2 et 3
            annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
            classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};

            % Reconstruire le nom complet du canal
            if isempty(classPart)
            fullChannelName = annotationPart;
            else
            fullChannelName = [annotationPart, '_', classPart];
            end

            % Trouver l'indice réel du canal dans selectedROI.display.channel
            channelIndex = find(strcmp(selectedROI.display.channel, fullChannelName), 1);
            if isempty(channelIndex)
                return;
            end

            % Mettre à jour la couleur du canal dans selectedROI.display.rgb
            selectedROI.display.rgb(channelIndex, :) = newColor;

            % Rafraîchir l'affichage général (image, histogrammes, etc.)
            score_display(app, 'refresh');

        end

        % Value changed function: Transparency
        function TransparencyValueChanged(app, event)
            value = app.Transparency.Value;
            changingValue = value;

            % Vérifier qu'une ROI est sélectionnée
            if isempty(app.content.ROIList)
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Vérifier qu'une ligne est sélectionnée dans la table d'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                return;
            end

            % Récupérer les parties "Annotation" et "Class" depuis les colonnes 2 et 3
            annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
            classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};

              % Reconstruire le nom complet du canal
            if isempty(classPart)
            fullChannelName = annotationPart;
            else
            fullChannelName = [annotationPart, '_', classPart];
            end

            % Trouver l'indice réel du canal dans selectedROI.display.channel
            channelIndex = find(strcmp(selectedROI.display.channel, fullChannelName), 1);
            if isempty(channelIndex)
                return;
            end

            % Mettre à jour la couleur du canal dans selectedROI.display.rgb
            selectedROI.display.alpha(channelIndex) = changingValue;

            tableDataIndex=app.UIAnnotationTable.Data ;

            Indexed = find(selectedROI.display.indexed);

            cc=1;
            for i = Indexed
                chIndex = i;
                if strcmp(selectedROI.display.channel{i}, fullChannelName )
                    tableDataIndex{cc, 4} = changingValue;
                end
                cc=cc+1;

            end

            app.UIAnnotationTable.Data = tableDataIndex;

            % Rafraîchir l'affichage général (image, histogrammes, etc.)
            score_display(app, 'refresh');

        end

        % Value changing function: Transparency
        function TransparencyValueChanging(app, event)
            changingValue = event.Value;

            % Vérifier qu'une ROI est sélectionnée
            if isempty(app.content.ROIList)
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            selectedROI = app.content.ROIList{selectedROIIndex};

            % Vérifier qu'une ligne est sélectionnée dans la table d'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                return;
            end

            % Récupérer les parties "Annotation" et "Class" depuis les colonnes 2 et 3
            annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
            classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};

                   % Reconstruire le nom complet du canal
            if isempty(classPart)
            fullChannelName = annotationPart;
            else
            fullChannelName = [annotationPart, '_', classPart];
            end

            % Trouver l'indice réel du canal dans selectedROI.display.channel
            channelIndex = find(strcmp(selectedROI.display.channel, fullChannelName), 1);
            if isempty(channelIndex)
                return;
            end

            % Mettre à jour la couleur du canal dans selectedROI.display.rgb
            selectedROI.display.alpha(channelIndex) = changingValue;

            tableDataIndex=app.UIAnnotationTable.Data ;
            tableDataIndex{selectedRow(1), 4} = changingValue;

            app.UIAnnotationTable.Data = tableDataIndex;


            % Rafraîchir l'affichage général (image, histogrammes, etc.)
            score_display(app, 'refresh');

        end

        % Menu selected function: IntensityquantificationMenu
        function IntensityquantificationMenuSelected(app, event)
            app.selectPanelTab('quantification');
            updateDisplaySettings(app)
        end

        % Menu selected function: AnnotationMenu
        function AnnotationMenuSelected(app, event)
            app.selectPanelTab('annotation');
            updateDisplaySettings(app)
        end

        % Close request function: ScoreAppUIFigure
        function ScoreAppUIFigureCloseRequest(app, event)
            app.flushAnnotationReview();
            % Supprimer la figure annexe si elle existe et est valide
            if isprop(app, 'ImageFigure') && isvalid(app.ImageFigure)

                delete(app.ImageFigure);
            end

            % Supprimer l'application
            evalin('base', 'clear DisplaySettings');

            delete(app);

        end

        % Value changed function: PanButton
        function PanButtonValueChanged(app, event)
            value = app.PanButton.Value;

            if value
                pan(app.ImageFigure, 'on'); % pour activer
            else
                pan(app.ImageFigure, 'off'); % pour désactiver
            end
        end

        % Menu selected function: CloseselectedROIMenu
        function CloseselectedROIMenuSelected(app, event)
            % Récupérer l'indice de la ROI actuellement sélectionnée
            roiData = app.UIROITable.Data;

            if isempty(roiData)
                return;
            end

            selectedIndex = find(cell2mat(roiData(:,1)), 1);


            if ~isempty(selectedIndex)
                % Supprimer la ROI sélectionnée de la liste
                app.content.ROIList(selectedIndex) = [];

                % Mettre à jour le tableau des ROI
                app.displayROIs();

                % Sélectionner la ROI précédente si elle existe
                if selectedIndex > 1 && ~isempty(app.UIROITable.Data)
                    newIndex = selectedIndex - 1;
                    % Remettre toutes les cases à false
                    tableData = app.UIROITable.Data;
                    for i = 1:size(tableData,1)
                        tableData{i,1} = false;
                    end
                    tableData{newIndex,1} = true;
                    app.UIROITable.Data = tableData;
                end
            end

            % Si aucune ROI ne reste, fermer la fenêtre principale (et l'app)
            if isempty(app.content.ROIList)
                delete(app.ScoreAppUIFigure);
            else
                % Sinon, rafraîchir l'affichage
                score_display(app, 'refresh');
            end
            return;  % Ne pas traiter d'autres touches
        end

        % Value changed function: PaintButton
        function PaintButtonValueChanged(app, event)
            if nargin < 2
                event = []; %#ok<NASGU>
            end
            value = score_isEditMode(app);

            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                errordlg('No channel selected!');
                score_setEditMode(app, false);
                return;
            end

            score_storeObjectDisplayUI(app);


            if value
                if ishandle( app.ImageFigure)
                    %           app.OverlayAxes.ButtonDownFcn = @(src, event) score_paintOverlay(src, event, app);
                    app.ImageFigure.WindowButtonDownFcn = @(src, event) score_paintOverlay(src, event, app);
                    app.MasklabelEditField.Enable="on";

                    paintRank = app.annotationTableChannelName(selectedRow(1));

               app.DisplaySettings.Movie.paintChannel = paintRank;

                end
            else
                if ishandle( app.ImageFigure)
                    app.ImageFigure.WindowButtonDownFcn=[];
                    app.MasklabelEditField.Enable="off";
                    app.DisplaySettings.Movie.paintChannel=0;
                    if isprop(app, 'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
                        delete(app.SelectedObjectRectangle);
                    end
                end
            end

            app.syncLineageDisplayForPaintChannel();
            score_display(app, 'refresh');
        end

        % Value changed function: MasklabelEditField
        function MasklabelEditFieldValueChanged(app, event)
            newVal = app.MasklabelEditField.Value;

            % Récupérer la nouvelle valeur saisie (en chaîne) et la convertir en nombre

            if isnan(newVal) || ~isfinite(newVal) || newVal < 0 || ...
                    newVal ~= round(newVal) || newVal > double(intmax('uint16'))
                uialert(app.ScoreAppUIFigure, 'Veuillez entrer une valeur numérique valide.', 'Erreur');
                return;
            end

            % Vérifier qu'une ROI est présente et récupère la ROI sélectionnée
            if isempty(app.content.ROIList)
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};



            % Récupérer le canal d'annotation sélectionné via la table UIAnnotationTable
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                uialert(app.ScoreAppUIFigure, 'Aucun canal d''annotation sélectionné.', 'Erreur');
                return;
            end
            annotationName = char(string(app.UIAnnotationTable.Data{selectedRow(1), 2}));
            className = char(string(app.UIAnnotationTable.Data{selectedRow(1), 3}));
            if isempty(className)
                selectedChannelName = annotationName;
            else
                selectedChannelName = [annotationName '_' className];
            end

            [~, channelIdx, pix, familyId] = ...
                score_resolveMaskProvider(roi, selectedChannelName);
            if isempty(channelIdx)
                uialert(app.ScoreAppUIFigure, 'Canal d''annotation invalide.', 'Erreur');
                return;
            end

            % Récupérer la valeur actuelle (l'ancien label) de l'objet sélectionné
            oldLabel = app.SelectedObjectLabelCell;
            if isempty(oldLabel) || ~isscalar(oldLabel) || ~isfinite(oldLabel)
                oldLabel = app.SelectedObjectLabel;
            end
            if isempty(oldLabel) || ~isscalar(oldLabel) || ~isfinite(oldLabel)
                uialert(app.ScoreAppUIFigure, 'Aucun objet n''est actuellement sélectionné.', 'Erreur');
                return;
            end

            % Pour le frame courant, remplacer dans le masque toutes les valeurs égales à oldLabel par newVal
            currentFrame = roi.display.frame;
            [model, modelStatus] = score_getCellModel(roi);
            modelChanged = strcmp(modelStatus, 'ok') && ~isempty(familyId);
            if modelChanged && newVal > 0
                [model, ~] = cellModel.relabelFrame(model, familyId, ...
                    currentFrame, oldLabel, newVal, 'merge');
            end
            temp = roi.image(:, :, pix, currentFrame); % masque actuel (par exemple, de type uint16)
            temp(temp == oldLabel) = newVal;
            roi.image(:, :, pix, currentFrame) = temp;
            app.notifyAnnotationChanged(selectedChannelName, currentFrame);
            if modelChanged
                if newVal == 0
                    [model, ~] = cellModel.syncFrame(model, familyId, ...
                        currentFrame, temp, 'TrackPolicy', 'preserve_or_label');
                end
                roi.saveCellModel(model);
                app.syncLineageDisplayForPaintChannel();
            end

            % Mettre à jour l'affichage (ce qui actualisera l'overlay et le composite)
            score_display(app, 'refresh');

            % Stocker le nouveau label dans la propriété de l'application
            app.SelectedObjectLabel = newVal;
            app.SelectedObjectLabelCell = newVal;
            score_updateSelectedObjectFields(app);
        end

        % Button pushed function: NewAnnotationButton
        function NewAnnotationButtonPushed(app, event)
            % Vérifier qu'une ROI est sélectionnée
            if isempty(app.content.ROIList)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};

            % Créer une nouvelle matrice d'annotation vide
            % Dimensions : même hauteur, largeur et nombre de frames que l'image de la ROI, et 1 canal
            [imgH, imgW, ~, numFrames] = size(roi.image);
            newMatrix = zeros(imgH, imgW, 1, numFrames, 'uint16');

            % Déterminer le numéro par défaut pour le nouveau channel d'annotation
            count = 0;
            for i = 1:numel(roi.display.channel)
                % Ici, on considère qu'un channel est une annotation si la somme des intensités vaut 0
                if roi.display.indexed(i)==true %sum(roi.display.intensity(i, :)) == 0
                    count = count + 1;
                end
            end
            % Le nouveau channel portera un nom comme "NewAnnotation1", "NewAnnotation2", etc.
            defaultAnnotationName = ['NewAnnotation', num2str(count+1)];
            defaultClass = 'class1';
            % Concaténer pour obtenir le nom complet du channel. Pour respecter le parsing existant (basé sur le premier '_'),
            % il est préférable que le nom d'annotation n'inclue pas d'underscore.
            fullChannelName = [defaultAnnotationName, '_', defaultClass];

            % Définir la couleur par défaut et l'intensité à 0 pour un channel d'annotation
            defaultRgb = [1 1 1];         % Couleur par défaut (blanc)
            defaultIntensity = [0 0 0];     % Intensité nulle pour indiquer qu'il s'agit d'une annotation

            % Ajouter le nouveau channel via la méthode dédiée
            roi.addChannel(newMatrix, fullChannelName, defaultRgb, defaultIntensity);

            % Mettre à jour la table d'annotations (elle sera reconstruite dans displayROIChannels)
            displayROIChannels(app);

        end

        % Button pushed function: DeleteAnnnotationButton
        function DeleteAnnnotationButtonPushed(app, event)

            % Vérifier qu'une ROI est sélectionnée
            if isempty(app.content.ROIList)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};

            % Vérifier qu'une ligne est sélectionnée dans la table d'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                uialert(app.ScoreAppUIFigure, 'No annotation selected', 'Error');
                return;
            end

            % Récupérer l'annotation sélectionnée (colonne 2)
            selectedAnnotation = app.UIAnnotationTable.Data{selectedRow(1), 2};
            if isempty(selectedAnnotation)
                uialert(app.ScoreAppUIFigure, 'Invalid annotation name', 'Error');
                return;
            end

            % Confirmer la suppression
            choice = questdlg(['Are you sure you want to delete annotation "' selectedAnnotation '" and all its channels?'], ...
                'Delete Annotation', 'Yes', 'No', 'No');
            if ~strcmp(choice, 'Yes')
                return;
            end

            % Identifier tous les channels dont la partie "annotation" (avant le premier underscore)
            % correspond à l'annotation sélectionnée.
            channelsToRemove = {};
            for i = 1:numel(roi.display.channel)
                channelName = roi.display.channel{i};
                pos = strfind(channelName, '_');
                if isempty(pos)
                    annotationPart = channelName;
                else
                    annotationPart = channelName(1:pos(1)-1);
                end
                if strcmp(annotationPart, selectedAnnotation)
                    channelsToRemove{end+1} = channelName;
                end
            end

            if isempty(channelsToRemove)
                uialert(app.ScoreAppUIFigure, 'No annotation channels found for deletion', 'Info');
                return;
            end

            % Supprimer chaque channel en utilisant la méthode removeChannel de roi
            for i = 1:numel(channelsToRemove)
                roi.removeChannel(channelsToRemove{i});
            end

            roi.log(['Deleted annotation "' selectedAnnotation '" with ' num2str(numel(channelsToRemove)) ' channels'], 'Processing');

            % Mettre à jour l'affichage et la table des annotations
            displayROIChannels(app);
            score_display(app, 'slow');

        end

        % Button pushed function: NewclassButton
        function NewclassButtonPushed(app, event)
            % Vérifier qu'une ROI est sélectionnée
            if isempty(app.content.ROIList)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};

            % Vérifier qu'une ligne est sélectionnée dans la table d'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                uialert(app.ScoreAppUIFigure, 'Please select an annotation in the table', 'Error');
                return;
            end

            % Récupérer la partie "annotation" depuis la colonne 2
            annotationName = app.UIAnnotationTable.Data{selectedRow(1), 2};
            if isempty(annotationName)
                uialert(app.ScoreAppUIFigure, 'Invalid annotation name', 'Error');
                return;
            end

            % Parcourir les channels existants pour cette annotation afin de lister les classes déjà utilisées
            existingClasses = {};
            for i = 1:numel(roi.display.channel)
                channelName = roi.display.channel{i};
                pos = strfind(channelName, '_');
                if isempty(pos)
                    annPart = channelName;
                    classPart = '';
                else
                    annPart = channelName(1:pos(1)-1);
                    classPart = channelName(pos(1)+1:end);
                end
                if strcmp(annPart, annotationName)
                    existingClasses{end+1} = classPart; %#ok<AGROW>
                end
            end

            % Trouver le plus petit entier X tel que "classX" n'existe pas déjà
            newClassIndex = 1;
            while any(strcmp(existingClasses, ['class', num2str(newClassIndex)]))
                newClassIndex = newClassIndex + 1;
            end
            newClassName = ['class', num2str(newClassIndex)];

            % Construire le nom complet du nouveau channel
            newChannelName = [annotationName, '_', newClassName];

            % Créer une nouvelle matrice d'annotation vide
            [imgH, imgW, ~, numFrames] = size(roi.image);
            newMatrix = zeros(imgH, imgW, 1, numFrames, 'uint16');

            % Choisir une nouvelle couleur de display différente.
            % On utilise la palette "lines" avec (N+1) couleurs, N étant le nombre de classes existantes.
            cmap = lines(numel(existingClasses)+1);
            newColor = cmap(end, :);

            % Pour une annotation, l'intensité est mise à zéro (indiquant qu'il s'agit d'un channel indexé)
            newIntensity = [0, 0, 0];

            % Appeler la méthode addChannel de la ROI pour ajouter le nouveau channel
            roi.addChannel(newMatrix, newChannelName, newColor, newIntensity);

            % Consigner la création dans le log
            roi.log(['Added new class "' newClassName '" for annotation "' annotationName '"'], 'Processing');

            % Mettre à jour la table d'annotation et rafraîchir l'affichage
            displayROIChannels(app);
            score_display(app, 'slow');
        end

        % Button pushed function: DeleteclassButton
        function DeleteclassButtonPushed(app, event)
            % Vérifier qu'une ROI est sélectionnée
            if isempty(app.content.ROIList)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                uialert(app.ScoreAppUIFigure, 'No ROI selected', 'Error');
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};

            % Vérifier qu'une ligne est sélectionnée dans la table d'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if isempty(selectedRow) || isempty(selectedRow(1))
                uialert(app.ScoreAppUIFigure, 'No class selected', 'Error');
                return;
            end

            % Récupérer la partie "Annotation" (colonne 2) et "Class" (colonne 3)
            annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
            classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};
            if isempty(annotationPart) || isempty(classPart)
                uialert(app.ScoreAppUIFigure, 'Invalid class selection', 'Error');
                return;
            end

            % Construire le nom complet du channel à supprimer
            fullChannelName = [annotationPart, '_', classPart];

            % Confirmer la suppression
            choice = questdlg(['Are you sure you want to delete class "' classPart '" for annotation "' annotationPart '"?'], ...
                'Delete Class', 'Yes', 'No', 'No');
            if ~strcmp(choice, 'Yes')
                return;
            end

            % Supprimer le channel en appelant la méthode removeChannel de la ROI
            roi.removeChannel(fullChannelName);

            % Consigner la suppression dans le log
            roi.log(['Deleted class "' classPart '" from annotation "' annotationPart '"'], 'Processing');

            % Mettre à jour l'affichage et la table des annotations
            displayROIChannels(app);
            score_display(app, 'slow');

            %   uialert(app.ScoreAppUIFigure, ['Class "' classPart '" deleted.'], 'Info');
        end

        % Menu selected function: SaveselectedroiMenu
        function SaveselectedroiMenuSelected(app, event)

    % Vérifier qu'il existe au moins une ROI
    if isempty(app.content.ROIList)
        uialert(app.ScoreAppUIFigure, 'No ROI available to save.', 'Error');
        return;
    end

    % Trouver l'indice de la ROI cochée dans la table des ROI
    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
    if isempty(selectedROIIndex)
        uialert(app.ScoreAppUIFigure, 'Please select a ROI to save.', 'Error');
        return;
    end

    % Récupérer la ROI sélectionnée
    roiObj = app.content.ROIList{selectedROIIndex};

    % Créer une barre de progression
    d = uiprogressdlg(app.ScoreAppUIFigure, ...
        'Title', 'Saving ROI', ...
        'Message', 'Please wait while the ROI is being saved...', ...
        'Indeterminate', 'on');

    try
        % Sauvegarder la ROI via la méthode dédiée
        roiObj.save();
        % Painting reconciles the object model in memory so erasing stays
        % interactive. Flush that cached model together with explicit Save.
        if isstruct(roiObj.cellModel) && ...
                isfield(roiObj.cellModel, 'schema_version')
            roiObj.saveCellModel(roiObj.cellModel);
        end

        % Mise à jour de la barre (optionnelle)
        d.Message = 'ROI successfully saved!';
        pause(0.5); % petite pause pour laisser le message s’afficher

    catch ME
        % Fermer la barre et afficher une erreur
        close(d);
        uialert(app.ScoreAppUIFigure, ...
            sprintf('Error during saving:\n%s', ME.message), ...
            'Save Error');
        rethrow(ME);
    end

    % Fermer la barre de progression
    close(d);

        end

        % Cell edit callback: UIDataTable
        function UIDataTableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;


            % Récupérer l'index du dataset modifié
            dsIndex = indices(1);
            col = indices(2);

            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};
            if ~isprop(roi, 'data') || numel(roi.data) < dsIndex
                return;
            end


       

            % Mettre à jour le dataset en fonction de la colonne éditée
            switch col
                case 1  % Champ de sélection (show)
                    roi.data(dsIndex).show = logical(newData);

                    if newData
                        app.UIDataTable.Selection=[dsIndex 1];
                    else
                        app.UIDataTable.Selection=[];
                    end
                case 2
                    roi.data(dsIndex).groupid=newData;

                    %     roi.data(dsIndex).groupid = newData;
                    % case 3
                    %     roi.data(dsIndex).parentid = newData;
                    % case 4
                    %     roi.data(dsIndex).class = newData;
                    % case 5
                    %     roi.data(dsIndex).type = newData;
            end

            % Réactualiser l'affichage
            displayData(app);

        end

        % Selection changed function: UIDataTable
        function UIDataTableSelectionChanged(app, event)
            selection = app.UIDataTable.Selection;
            displaySubData(app);
        end

        % Cell edit callback: UISubDataTable
        function UISubDataTableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;

            % Récupérer la sélection dans UIDataTable pour identifier le dataset courant
            selection = app.UIDataTable.Selection;
            if isempty(selection)
                return;
            end
            dsIndex = selection(1,1);

            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end

            roi = app.content.ROIList{selectedROIIndex};
            if ~isprop(roi, 'data') || numel(roi.data) < dsIndex
                return;
            end

            % Mettre à jour les plotProperties dans le dataset correspondant
            roi.data(dsIndex).plotProperties = app.UISubDataTable.Data;
            roi.data(dsIndex) = app.syncLineageSourcesFromSubDataTable(roi.data(dsIndex));

            % Optionnel : actualiser le plot si une méthode plot est définie
            %   if isprop(roi.data(dsIndex), 'plot') && ~isempty(roi.data(dsIndex).plot)

            %  end

         
            displayData(app);

        end

        function selectedData = syncLineageSourcesFromSubDataTable(app, selectedData) %#ok<INUSL>
            try
                if ~isprop(selectedData, 'groupid') || ~strcmp(char(string(selectedData.groupid)), 'cell_information')
                    return;
                end
                if ~isprop(selectedData, 'userData') || ~isstruct(selectedData.userData) || ...
                        ~isfield(selectedData.userData, 'lineageSources') || ~isstruct(selectedData.userData.lineageSources)
                    return;
                end
                t = selectedData.plotProperties;
                if istable(t), t = table2cell(t); end
                if ~iscell(t) || size(t,2) < 3
                    return;
                end
                removeRows = strcmp(string(t(:,3)), "lineageSource");
                if size(t,2) >= 2
                    removeRows = removeRows | strcmp(string(t(:,2)), "lineage");
                end
                if any(removeRows)
                    t(removeRows, :) = [];
                    selectedData.plotProperties = t;
                end
            catch ME
                warning('score:LineageSourceSyncFailed', ...
                    'Could not sync lineage source visibility: %s', ME.message);
            end
        end

        % Selection changed function: UISubDataTable
        function UISubDataTableSelectionChanged(app, event)
            selection = app.UISubDataTable.Selection;

            % Récupérer la sélection dans la table de sous-données
            subSel = app.UISubDataTable.Selection;
            % Récupérer la sélection dans la table principale des datasets
            mainSel = app.UIDataTable.Selection;

            % Si aucune série de données n'est sélectionnée, on affiche un message
            if isempty(mainSel)
                app.SelecteddataLabel.Text = 'No dataset selected';
                return;
            end

            % Récupérer le nom de la série de données (colonne 2 dans UIDataTable)
            mainDataName = app.UIDataTable.Data{mainSel(1), 2};

            % Si aucune sous-donnée n'est sélectionnée, afficher un message approprié
            if isempty(subSel)
                app.SelecteddataLabel.Text = sprintf('Dataset: %s | No sub-data selected', mainDataName);
            else
                % Récupérer le nom de la sous-donnée (colonne 2 dans UISubDataTable)
                subDataName = app.UISubDataTable.Data{subSel(1), 2};
                app.SelecteddataLabel.Text = sprintf('Dataset: %s | Variable: %s', mainDataName, subDataName);
            end

            updateAssignValueControls(app);

        end

        % Value changed function: AssignvalueEditField
        function AssignvalueEditFieldValueChanged(app, event)
            newStr = app.AssignvalueEditField.Value;

            % Récupérer la ROI, le dataset et la variable sélectionnée
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};

            if isempty(app.UIDataTable.Selection) || isempty(app.UISubDataTable.Selection)
                return;
            end
            dsIndex = app.UIDataTable.Selection(1);
            subSel = app.UISubDataTable.Selection(1);
            varName = app.UISubDataTable.Data{subSel,2};
            currentFrame = roi.display.frame;

            % Conversion de la chaîne en valeur numérique
            newVal = str2double(newStr);
            if isnan(newVal)
                uialert(app.ScoreAppUIFigure, 'Please enter a valid numeric value', 'Error');
                return;
            end

            % Mettre à jour le dataset
            selectedData = roi.data(dsIndex);
            try
                selectedData.data{currentFrame, varName} = newVal;
            catch ME
                warning('Could not update the value: %s', ME.message);
                return;
            end
            roi.data(dsIndex) = selectedData;
            score_display(app, 'slow');
        end

        % Value changed function: ClassDropDown
        function ClassDropDownValueChanged(app, event)
            newValue = app.ClassDropDown.Value;

            % Récupérer la ROI, le dataset et la variable sélectionnée
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};

            if isempty(app.UIDataTable.Selection) || isempty(app.UISubDataTable.Selection)
                return;
            end
            dsIndex = app.UIDataTable.Selection(1);
            subSel = app.UISubDataTable.Selection(1);
            varName = app.UISubDataTable.Data{subSel,2};
            currentFrame = roi.display.frame;

            % Mettre à jour le dataset
            selectedData = roi.data(dsIndex);
            % Si la donnée est catégorique, convertir newValue en cell array si nécessaire
            if iscategorical(selectedData.data{currentFrame, varName})
                if ischar(newValue)
                    newValue = cellstr(newValue);
                end
                selectedData.data{currentFrame, varName} = categorical(newValue);
            else
                % Sinon, affecter directement (par exemple pour un cell array de chaînes)
                selectedData.data{currentFrame, varName} = newValue;
            end
            roi.data(dsIndex) = selectedData;
            score_display(app, 'refresh');
        end

        % Menu selected function: CopypresetsMenu
        function CopypresetsMenuSelected(app, event)
            % Préparer une structure de presets
            presets = struct();

            % 1) Copier la visibilité des panels
            presets.panels = struct(...
                'ROisPanel', 'on', ...
                'DisplaysettingsPanel', 'on', ...
                'DataSettingsPanel', 'on', ...
                'AnnotationPanel', 'on', ...
                'IntensityQuantificationPanel', 'on', ...
                'MoviePanel', 'on');

            % 2) Copier les réglages des channels
            % On copie le champ display de la ROI sélectionnée (s'il existe)
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if ~isempty(selectedROIIndex)
                roi = app.content.ROIList{selectedROIIndex};
                if isprop(roi, 'display')

                    presets.channels = roi.display;
                else
                    presets.channels = [];
                end
            else
                presets.channels = [];
            end

            % 3) Copier le contenu des tables de données
            presets.dataTable = app.UIDataTable.Data;
            presets.subDataTable = app.UISubDataTable.Data;
            presets.groupTable = app.UIGroupTable.Data;
            if ~isempty(selectedROIIndex)
                presets.dataSeries = app.collectDataseriesDisplayPresets(roi);
            else
                presets.dataSeries = [];
            end

            % 4) Copier d'autres réglages (par exemple, la transparence et éventuellement la table des canaux)
            %   presets.transparency = app.Transparency.Value;
            presets.channelTable = app.UIChannelTable.Data;
            presets.annotationTable=app.UIAnnotationTable;

            % on copie les infos pour les movies
            presets.Movie=app.DisplaySettings.Movie;

            app.DisplaySettings=presets;
            % Sauvegarder la structure dans le workspace de base
            assignin('base', 'DisplaySettings', presets);
            % uialert(app.ScoreAppUIFigure, 'Display presets copied to workspace (DisplaySettings).', 'Copy Presets');

        end

        % Menu selected function: PastepresetsMenu
        function PastepresetsMenuSelected(app, event)
            % Essayer de récupérer la structure DisplaySettings depuis le workspace
            try
                presets = evalin('base', 'DisplaySettings');
                app.DisplaySettings=presets;
            catch
                uialert(app.ScoreAppUIFigure, 'No DisplaySettings found in workspace.', 'Error');
                return;
            end

            % 1) Mise à jour de la visibilité des panels
            if isfield(presets, 'panels')
                app.setAllPanelTabsVisible();
            end

            % 2) Mise à jour des réglages des channels uniquement si les noms correspondent exactement
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if ~isempty(selectedROIIndex) && isfield(presets, 'channels') && ~isempty(presets.channels)
                roi = app.content.ROIList{selectedROIIndex};
                for i = 1:numel(presets.channels.channel)
                    presetName = presets.channels.channel{i}; % ex: 'Channel0' ou 'results_cellsegClassifier_3'
                    % Recherche par correspondance exacte dans roi.display.channel
                    idx = find(strcmp(roi.display.channel, presetName), 1);
                    if ~isempty(idx)
                        % Appliquer les réglages du preset sur le channel correspondant
                        if isfield(presets.channels, 'intensity') && size(presets.channels.intensity,1) >= i
                            roi.display.intensity(idx,:) = presets.channels.intensity(i,:);
                        end
                        if isfield(presets.channels, 'rgb') && size(presets.channels.rgb,1) >= i
                            roi.display.rgb(idx,:) = presets.channels.rgb(i,:);
                        end
                        if isfield(presets.channels, 'displaylim') && size(presets.channels.displaylim,2) >= i
                            roi.display.displaylim(:,idx) = presets.channels.displaylim(:,i);
                        end
                        if isfield(presets.channels, 'selectedchannel') && numel(presets.channels.selectedchannel) >= i
                            roi.display.selectedchannel(idx) = presets.channels.selectedchannel(i);
                        end
                        if isfield(presets.channels, 'indexed') && numel(presets.channels.indexed) >= i
                            roi.display.indexed(idx) = presets.channels.indexed(i);
                        end
                        if isfield(presets.channels, 'alpha') && numel(presets.channels.alpha) >= i
                            roi.display.alpha(idx) = presets.channels.alpha(i);
                        end
                        if isfield(presets.channels, 'contour') && numel(presets.channels.contour) >= i
                            roi.display.contour(idx) = presets.channels.contour(i);
                        end
                          if isfield(presets.channels, 'log') && numel(presets.channels.log) >= i
                            roi.display.log(idx) = presets.channels.log(i);
                        end
                        if isfield(presets.channels, 'scale') && numel(presets.channels.scale) >= i
                            roi.display.scale(idx) = presets.channels.scale(i);
                        end
                        if isfield(presets.channels, 'width') && numel(presets.channels.width) >= i
                            roi.display.width(idx) = presets.channels.width(i);
                        end
                        if isfield(presets.channels, 'colorMode') && numel(presets.channels.colorMode) >= i
                            roi.display.colorMode{idx} = presets.channels.colorMode{i};
                        end
                        if isfield(presets.channels, 'colormapName') && numel(presets.channels.colormapName) >= i
                            roi.display.colormapName{idx} = presets.channels.colormapName{i};
                        end
                        if isfield(presets.channels, 'channelAlias') && numel(presets.channels.channelAlias) >= i
                            roi.display.channelAlias{idx} = presets.channels.channelAlias{i};
                        end

                    else
                        % Aucun channel correspondant exact trouvé : on ignore ce preset
                        disp(['Skipping preset for channel "' presetName '" because no exact match was found.']);
                    end
                end
                % Sauvegarder les mises à jour dans la ROI et rafraîchir la table des channels
                app.content.ROIList{selectedROIIndex} = roi;
                app.DisplaySettings=presets;
                applyMovieDisplaySettings(app);
                displayROIChannels(app);
            end

            % 3) Mise à jour des réglages de Data settings
            if ~isempty(selectedROIIndex) && isfield(presets, 'dataSeries') && ~isempty(presets.dataSeries)
                roi = app.content.ROIList{selectedROIIndex};
                app.applyDataseriesDisplayPresets(roi, presets.dataSeries);
                app.content.ROIList{selectedROIIndex} = roi;
                displayData(app);
            end
            if isfield(presets, 'dataTable') && ~isempty(presets.dataTable) && ~isempty(app.UIDataTable.Data)
                dt = app.UIDataTable.Data;
                presetDT = presets.dataTable;
                n = min(size(dt,1), size(presetDT,1));
                for i = 1:n
                    if strcmp(dt{i,2}, presetDT{i,2})
                        dt{i,1} = presetDT{i,1}; % Mise à jour du flag de sélection
                    end
                end
                app.UIDataTable.Data = dt;
            end
            if isfield(presets, 'subDataTable') && ~isempty(presets.subDataTable) && ~isempty(app.UISubDataTable.Data)
                sd = app.UISubDataTable.Data;
                presetSD = presets.subDataTable;
                n = min(size(sd,1), size(presetSD,1));
                for i = 1:n
                    if strcmp(sd{i,2}, presetSD{i,2})
                        sd{i,1} = presetSD{i,1}; % Mise à jour du flag "Plot"
                    end
                end
                app.UISubDataTable.Data = sd;
            end
            if isfield(presets, 'groupTable') && ~isempty(presets.groupTable)
                app.UIGroupTable.Data = presets.groupTable;
            end

            % 4) Mise à jour des autres réglages
            % if isfield(presets, 'transparency')
            %     app.Transparency.Value = presets.transparency;
            % end
            % IMPORTANT : on n'actualise pas la table des channels à partir de presets.channelTable,
            % car cela écraserait la liste filtrée construite par displayROIChannels.

            % Actualiser les réglages (menus, panels, disposition, etc.)
            updateDisplaySettings(app);
            updateDisplayMenu(app);
            updatePanelsLayout(app);

            % Rafraîchir l'affichage général
            score_display(app, 'slow');

        end

        % Value changed function: isthedefautcolorCheckBox
        function isthedefautcolorCheckBoxValueChanged(app, event)
            value = app.isthedefautcolorCheckBox.Value;
            app.DisplaySettings.Movie.defaultClass=value;

            score_display(app, 'refresh');
        end

        % Button pushed function: DeselectalldataButton
        function DeselectalldataButtonPushed(app, event)
            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end
            roi = app.content.ROIList{selectedROIIndex};
            if ~isprop(roi, 'data')
                return;
            end

            for i=1:numel(roi.data)
                roi.data(i).show = logical(false);
            end

            app.UIDataTable.Selection=[];

            displayData(app);

        end

        % Button pushed function: DeselectallsubdataButton
        function DeselectallsubdataButtonPushed(app, event)


            % Récupérer la sélection dans UIDataTable pour identifier le dataset courant
            selection = app.UIDataTable.Selection;
            if isempty(selection)
                return;
            end
            dsIndex = selection(1);

            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end

            roi = app.content.ROIList{selectedROIIndex};
            if ~isprop(roi, 'data')
                return;
            end

            % Mettre à jour les plotProperties dans le dataset correspondant

            data = app.UISubDataTable.Data;
            data(:,1) = repmat({false}, size(data,1), 1);
            app.UISubDataTable.Data = data;

            roi.data(dsIndex).plotProperties = app.UISubDataTable.Data;

            % Optionnel : actualiser le plot si une méthode plot est définie
            %   if isprop(roi.data(dsIndex), 'plot') && ~isempty(roi.data(dsIndex).plot)

            %  end

            displayData(app);
        end

        % Menu selected function: MovieMenu
        function MovieMenuSelected(app, event)
            app.selectPanelTab('movie');
            app.updateDisplaySettings();
        end

        % Button pushed function: GrenerateMovieButton
        function GrenerateMovieButtonPushed(app, event)

               % --- Progress bar indéterminée ---
    d = uiprogressdlg(app.ScoreAppUIFigure, ...
        'Title', 'Generating movie or sequence', ...
        'Message', 'Rendering frames...', ...
        'Indeterminate', 'on');



            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end


            if numel(app.UIDataTable.Data)==0
                selectedDataIndex=[];
            else
                selectedDataIndex = find(cell2mat(app.UIDataTable.Data(:,1)));
            end


            if app.MovieselectcurrentROIonlyCheckBox.Value % only one ROI
                roilist = app.content.ROIList{selectedROIIndex};
            else
                roilist = [app.content.ROIList{:}];
            end

            arg=setMovieMosaicArguments(app);
            opts = score_collectDisplayOptions(arg{:});
            opts=score_updateLayout(opts,roilist);
             if numel(opts)==0 % layout returned an error, should quit
            disp('Display is aborted due to layout error!')
            return;
             end

            app.layoutOptions=opts;

            displayHandles= score_createDisplayHandles(opts,app.ImageFigure);
            htrash=score_renderFinalFrame(displayHandles , roilist, opts);

            close(d);

        end

        % Button pushed function: SetButton
        function SetButtonPushed(app, event)
            % Ouvrir une boîte de dialogue pour choisir un fichier d'exportation
            [file, path] = uiputfile({'*.mp4;*.avi;*.mat', 'Movie Files (*.mp4, *.avi, *.mat)'}, ...
                'Select Export File');
            if ~isequal(file,0) && ~isequal(path,0)
                % Construire le chemin complet
                fullFilePath = fullfile(path, file);
                % Mettre à jour la valeur de l'edit field
                app.MovieoutputfilenameEditField.Value = fullFilePath;
                app.DisplaySettings.Movie.MovieoutputfilenameEditField= app.MovieoutputfilenameEditField.Value;
                assignin('base','DisplaySettings',app.DisplaySettings);
            end
        end

        % Callback function
        function MovieselectcurrentROIonlyCheckBoxValueChanged(app, event)

        end

        % Button pushed function: NewdatagroupButton
        function NewdatagroupButtonPushed(app, event)
            roiIdx = find(cell2mat(app.UIROITable.Data(:,1)),1);
            if isempty(roiIdx)
                uialert(app.ScoreAppUIFigure, 'Please select a ROI first.', 'Error');
                return;
            end
            roi = app.content.ROIList{roiIdx};

            % 2) Find selected dataseries in UIDataTable
            sel = app.UIDataTable.Selection;
            if isempty(sel)
                uialert(app.ScoreAppUIFigure, 'Please select a dataseries in the Data table.', 'Error');
                return;
            end
            dsIdx = sel(1);
            ds = roi.data(dsIdx);

            answer = inputdlg('Enter new group name:','Add Data group',[1 60]);
            if isempty(answer), return; end
            varName = matlab.lang.makeValidName(answer{1});

            ds.plotGroup{6}=[ds.plotGroup{6} {varName}];
            ds.groupProperties=[ ds.groupProperties ; {varName, 'Plot', 'auto','auto'}];

            app.displayData();

        end

        % Cell edit callback: UIGroupTable
        function UIGroupTableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;

            % Récupérer la sélection dans UIDataTable pour identifier le dataset courant
            selection = app.UIDataTable.Selection;
            if isempty(selection)
                return;
            end
            dsIndex = selection(1);

            selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
            if isempty(selectedROIIndex)
                return;
            end

            roi = app.content.ROIList{selectedROIIndex};
            if ~isprop(roi, 'data') || numel(roi.data) < dsIndex
                return;
            end

            % if group name is changed, then must update plotProperties and
            % plotGroup

            oldgroupname=roi.data(dsIndex).groupProperties{indices(1),indices(2)};

            pp= roi.data(dsIndex).plotProperties(:,6);
            pix=find(matches(pp,oldgroupname));
            roi.data(dsIndex).plotProperties(pix,6)={newData};

            pp= roi.data(dsIndex).plotGroup{6};
            pix=find(matches(pp,oldgroupname));
            roi.data(dsIndex).plotGroup{6}(pix)={newData};

            % Mettre à jour les plotProperties dans le dataset correspondant
            roi.data(dsIndex).groupProperties = app.UIGroupTable.Data;



            % Optionnel : actualiser le plot si une méthode plot est définie
            %   if isprop(roi.data(dsIndex), 'plot') && ~isempty(roi.data(dsIndex).plot)

            %  end

            displayData(app);

            score_display(app,'slow');



        end

        % Value changed function: MovietrackwindowEditField
        function MovietrackwindowEditFieldValueChanged(app, event)
            value = app.MovietrackwindowEditField.Value;

        end

        % Value changed function: MoviedatatrackCheckBox
        function MoviedatatrackCheckBoxValueChanged(app, event)
            value = app.MoviedatatrackCheckBox.Value;

        end

        % Menu selected function: SavepresetsasMenu
        function SavepresetsasMenuSelected(app, event)
            % Ouvrir une boîte de dialogue pour choisir le fichier .mat
            [file, path] = uiputfile('*.mat', 'Save presets as...');
            if isequal(file, 0) || isequal(path, 0)
                return; % l'utilisateur a annulé
            end
            fullFile = fullfile(path, file);

            % Copier les presets courants dans app.DisplaySettings
            app.CopypresetsMenuSelected(event);

            % Sauvegarder la structure dans le fichier
            presets = app.DisplaySettings;
            try
                save(fullFile, 'presets');
                % uialert(app.ScoreAppUIFigure, ...
                %    ['Presets saved to "' fullFile '"'], ...
                %    'Save presets');
            catch ME
                uialert(app.ScoreAppUIFigure, ...
                    ['Error saving presets: ' ME.message], ...
                    'Save presets','Icon','error');
            end
        end

        % Menu selected function: LoadpresetsMenu
        function LoadpresetsMenuSelected(app, event)
            % Ouvrir une boîte de dialogue pour choisir un .mat
            [file, path] = uigetfile('*.mat', 'Load presets...');
            if isequal(file, 0) || isequal(path, 0)
                return; % annulé
            end
            fullFile = fullfile(path, file);

            % Charger la structure 'presets'
            S = load(fullFile, 'presets');
            if ~isfield(S, 'presets')
                uialert(app.ScoreAppUIFigure, ...
                    'Le fichier ne contient pas de variable ''presets''.', ...
                    'Load presets','Icon','error');
                return;
            end

            % Placer dans le workspace et appliquer
            assignin('base', 'DisplaySettings', S.presets);
            app.PastepresetsMenuSelected(event);

            % uialert(app.ScoreAppUIFigure, ...
            %     'Presets loaded and applied.', ...
            %     'Load presets');
        end

        % Button pushed function: NewdataseriesButton
        function NewdataseriesButtonPushed(app, event)
            % 1) Find selected ROI
            roiIdx = find(cell2mat(app.UIROITable.Data(:,1)),1);
            if isempty(roiIdx)
                uialert(app.ScoreAppUIFigure, 'Please select a ROI first.', 'Error');
                return;
            end
            roin = app.content.ROIList{roiIdx};

            % 2) Create a new dataseries with groupid 'newdata'
            ds = dataseries();
            ds.plotProperties = cell(0,6);
            ds.plotGroup = cell(1,6);
            ds.plotGroup{6}={'defaultGroup'};
            ds.groupid  = 'newdata';
            ds.parentid = roin.id;
            ds.class    = 'other';
            ds.type     = 'temporal';
            % leave ds.data empty for now

            % 3) Append into roi.data
            if numel(roin.data)==1 && isempty(roin.data(1).data)
                roin.data(1) = ds;
            else
                roin.data(end+1) = ds;
            end


            % 4) Refresh display
            app.displayData();
        end

        % Button pushed function: NewdatasetButton
        function NewdatasetButtonPushed(app, event)
            % 1) Find selected ROI
            roiIdx = find(cell2mat(app.UIROITable.Data(:,1)),1);
            if isempty(roiIdx)
                uialert(app.ScoreAppUIFigure, 'Please select a ROI first.', 'Error');
                return;
            end
            roi = app.content.ROIList{roiIdx};

            % 2) Find selected dataseries in UIDataTable
            sel = app.UIDataTable.Selection;
            if isempty(sel)
                uialert(app.ScoreAppUIFigure, 'Please select a dataseries in the Data table.', 'Error');
                return;
            end

            dsIdx = sel(1);
            ds = roi.data(dsIdx);

            % 3) Determine number of rows to initialize
            if isempty(ds.data) || height(ds.data)==0
                nRows = size(roi.image,4);
                % make an N×0 table
            else
                nRows = height(ds.data);
            end

            % 4) Ask user for new variable name
            answer = inputdlg('Enter new variable name:','Add Data Set',[1 60]);
            if isempty(answer), return; end
            varName = matlab.lang.makeValidName(answer{1});

            % 5) Ask user for type
            choice = questdlg( ...
                'Type of new dataset?', ...
                'Add Data Set', ...
                'Numeric','Categorical','Numeric');
            if isempty(choice), return; end

            % 6) Depending on type, create numeric zeros or categorical
            switch choice
                case 'Numeric'
                    newCol = zeros(nRows,1);
                    type='double';
                case 'Categorical'
                    catAns = inputdlg( ...
                        'Enter categories separated by spaces:','Categories',[1 100]);
                    if isempty(catAns), return; end
                    cats = strsplit(strtrim(catAns{1}));
                    % initialize all to first category
                    newCol = categorical( repmat(cats(1),nRows,1), cats, cats );
                    type='categorical';
            end

            % 7) Add new variable to ds.data
            ds.addData(newCol, varName);

            pix=find(matches(ds.plotProperties(:,3),type));

            if numel(pix)==0 % must create new group
                varName = ['newGroup' num2str(size(ds.groupProperties,1)+1)];
                ds.plotGroup{6}=[ds.plotGroup{6} {varName}];
                ds.groupProperties=[ ds.groupProperties ; {varName, 'Plot', 'auto','auto'}];
                ds.plotProperties{end,6}=varName;
            else
                group=ds.plotProperties{pix(1),6};
                ds.plotProperties{end,6}=group;
            end

            ds.plotProperties{end,3}=type;


            % check that numerical and categorical data are not part of the ame
            % group


            % 9) Refresh display
            app.displayData();
        end

        % Menu selected function: NewdataseriesMenu
        function NewdataseriesMenuSelected(app, event)

        end

        % Menu selected function: NewdatasetMenu
        function NewdatasetMenuSelected(app, event)

        end

        % Menu selected function: DuplicatedatasetMenu
        function DuplicatedatasetMenuSelected(app, event)

        end

        % Menu selected function: DeleteselecteddataseriesMenu
        function DeleteselecteddataseriesMenuSelected(app, event)
            % 1) Find selected ROI
            roiIdx = find(cell2mat(app.UIROITable.Data(:,1)),1);
            if isempty(roiIdx)
                uialert(app.ScoreAppUIFigure, 'Please select a ROI first.', 'Error');
                return;
            end
            roi = app.content.ROIList{roiIdx};

            % 2) Find selected dataseries in UIDataTable
            sel = app.UIDataTable.Selection;
            if isempty(sel)
                uialert(app.ScoreAppUIFigure, 'Please select a dataseries in the Data table.', 'Error');
                return;
            end

            dsIdx = sel(1);
            ds = roi.data(dsIdx);

            roi.data(dsIdx)=[];
            app.displayData();
            score_display(app,'slow');
        end

        % Value changed function: MovieoutputtypeDropDown
        function MovieoutputtypeDropDownValueChanged(app, event)
            value = app.MovieoutputtypeDropDown.Value;
            
              if numel(app.MovieoutputfilenameEditField.Value)==0
                  str=app.MovieoutputfilenameEditField.Value;
              else
                  str=[selectedROI.path 'output.mp4'];
              end

             [fle, pth, ~]=fileparts(str);

            if value=="Movie"
 app.MovieoutputfilenameEditField.Value=fullfile(pth, [fle '.mp4']);
            end
            if value=="Sequence"
app.MovieoutputfilenameEditField.Value=fullfile(pth, [fle '.pdf']);
            end


        end

        % Value changed function: FrameEditField_2
        function FrameEditField_2ValueChanged(app, event)
            value = app.FrameEditField_2.Value;
            ivent=[];
            ivent.Value=value;
            FrameSliderValueChanging(app, ivent);
        end

        % Button pushed function: ShowmovieandfolderButton
        function ShowmovieandfolderButtonPushed(app, event)
            % Button pushed function: TestMovieButton

    % Récupérer le chemin saisi dans l’EditField
 

     moviePath = app.DisplaySettings.Movie.MovieoutputfilenameEditField

    % Normaliser en char
    if isstring(moviePath)
        moviePath = char(moviePath);
    end

    % Sécurité : champ vide ?
    if isempty(moviePath)
        uialert(app.ScoreAppUIFigure, ...
            'Aucun chemin de movie n''a été saisi.', ...
            'Movie manquant', ...
            'Icon', 'warning');
        return;
    end

    % Vérifier si le fichier existe
    if exist(moviePath, 'file') ~= 2
        % Fichier introuvable
        msg = sprintf('Le movie demandé n''existe pas :\n%s', moviePath);
        uialert(app.ScoreAppUIFigure, msg, ...
            'Movie introuvable', ...
            'Icon', 'error');

 
        return;
    end

    % Fichier trouvé : séparer dossier / nom
    [folderPath, fileName, fileExt] = fileparts(moviePath);
    if isempty(folderPath)
        folderPath = pwd;
    end

    % (Optionnel) message dans la console pour debug
    fprintf('[score] Movie trouvé : %s\n', [fileName, fileExt]);
    fprintf('[score] Dossier     : %s\n', folderPath);

    % ---------------------------------------------------------------------
    % Ouvrir une fenêtre d’explorateur + ouvrir le movie avec le programme
    % par défaut (Windows / macOS / Linux)
    % ---------------------------------------------------------------------
    try
        if ispc
            % Ouvrir l’explorateur Windows en sélectionnant le fichier
            cmdExplorer = sprintf('explorer /select,"%s"', ...
                strrep(moviePath, '/', '\'));
            system(cmdExplorer);

            % Ouvrir le fichier avec l’application par défaut
            winopen(moviePath);

        elseif ismac
            % macOS : open <dossier> puis open <fichier>
            folderEsc = strrep(folderPath, '"', '\"');
            fileEsc   = strrep(moviePath, '"', '\"');

            system(sprintf('open "%s"', folderEsc));
            system(sprintf('open "%s"', fileEsc));

        else
            % Linux / Unix : xdg-open <dossier> puis xdg-open <fichier>
            folderEsc = strrep(folderPath, '"', '\"');
            fileEsc   = strrep(moviePath, '"', '\"');

            system(sprintf('xdg-open "%s"', folderEsc));
            system(sprintf('xdg-open "%s"', fileEsc));
        end

    catch ME
        warning('Impossible d''ouvrir l''explorateur ou le movie : %s', ME.message);
    end

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ScoreAppUIFigure and hide until all components are created
            app.ScoreAppUIFigure = uifigure('Visible', 'off');
            app.ScoreAppUIFigure.Position = [100 100 656 949];
            app.ScoreAppUIFigure.Name = 'ScoreApp';
            app.ScoreAppUIFigure.CloseRequestFcn = createCallbackFcn(app, @ScoreAppUIFigureCloseRequest, true);
            app.ScoreAppUIFigure.KeyPressFcn = createCallbackFcn(app, @ScoreAppUIFigureKeyPress, true);

            % Create FileMenu
            app.FileMenu = uimenu(app.ScoreAppUIFigure);
            app.FileMenu.Text = 'File';

            % Create CloseselectedROIMenu
            app.CloseselectedROIMenu = uimenu(app.FileMenu);
            app.CloseselectedROIMenu.MenuSelectedFcn = createCallbackFcn(app, @CloseselectedROIMenuSelected, true);
            app.CloseselectedROIMenu.Text = 'Close selected ROI';

            % Create SaveselectedroiMenu
            app.SaveselectedroiMenu = uimenu(app.FileMenu);
            app.SaveselectedroiMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveselectedroiMenuSelected, true);
            app.SaveselectedroiMenu.Text = 'Save selected roi';

            % Create DisplayMenu
            app.DisplayMenu = uimenu(app.ScoreAppUIFigure);
            app.DisplayMenu.Text = 'Display';

            % Create ROIsMenu
            app.ROIsMenu = uimenu(app.DisplayMenu);
            app.ROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @ROIsMenuSelected2, true);
            app.ROIsMenu.Checked = 'on';
            app.ROIsMenu.Text = 'ROIs';

            % Create DisplaysettingsMenu
            app.DisplaysettingsMenu = uimenu(app.DisplayMenu);
            app.DisplaysettingsMenu.MenuSelectedFcn = createCallbackFcn(app, @DisplaysettingsMenuSelected3, true);
            app.DisplaysettingsMenu.Text = 'Display settings';

            % Create IntensityquantificationMenu
            app.IntensityquantificationMenu = uimenu(app.DisplayMenu);
            app.IntensityquantificationMenu.MenuSelectedFcn = createCallbackFcn(app, @IntensityquantificationMenuSelected, true);
            app.IntensityquantificationMenu.Text = 'Intensity quantification';

            % Create AnnotationMenu
            app.AnnotationMenu = uimenu(app.DisplayMenu);
            app.AnnotationMenu.MenuSelectedFcn = createCallbackFcn(app, @AnnotationMenuSelected, true);
            app.AnnotationMenu.Text = 'Annotation';

            % Create DatasettingsMenu
            app.DatasettingsMenu = uimenu(app.DisplayMenu);
            app.DatasettingsMenu.MenuSelectedFcn = createCallbackFcn(app, @DatasettingsMenuSelected2, true);
            app.DatasettingsMenu.Text = 'Data settings';

            % Create MovieMenu
            app.MovieMenu = uimenu(app.DisplayMenu);
            app.MovieMenu.MenuSelectedFcn = createCallbackFcn(app, @MovieMenuSelected, true);
            app.MovieMenu.Text = 'Movie';

            % Create CopypresetsMenu
            app.CopypresetsMenu = uimenu(app.DisplayMenu);
            app.CopypresetsMenu.MenuSelectedFcn = createCallbackFcn(app, @CopypresetsMenuSelected, true);
            app.CopypresetsMenu.Separator = 'on';
            app.CopypresetsMenu.Text = 'Copy presets';

            % Create PastepresetsMenu
            app.PastepresetsMenu = uimenu(app.DisplayMenu);
            app.PastepresetsMenu.MenuSelectedFcn = createCallbackFcn(app, @PastepresetsMenuSelected, true);
            app.PastepresetsMenu.Text = 'Paste presets';

            % Create SavepresetsasMenu
            app.SavepresetsasMenu = uimenu(app.DisplayMenu);
            app.SavepresetsasMenu.MenuSelectedFcn = createCallbackFcn(app, @SavepresetsasMenuSelected, true);
            app.SavepresetsasMenu.Separator = 'on';
            app.SavepresetsasMenu.Text = 'Save presets as...';

            % Create LoadpresetsMenu
            app.LoadpresetsMenu = uimenu(app.DisplayMenu);
            app.LoadpresetsMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadpresetsMenuSelected, true);
            app.LoadpresetsMenu.Text = 'Load presets...';

            % Create AnalysisMenu
            app.AnalysisMenu = uimenu(app.ScoreAppUIFigure);
            app.AnalysisMenu.Text = 'Analysis';

            % Create ComputemetricsinobjectMenu
            app.ComputemetricsinobjectMenu = uimenu(app.AnalysisMenu);
            app.ComputemetricsinobjectMenu.Text = 'Compute metrics in object';

            % Create NewdataseriesMenu
            app.NewdataseriesMenu = uimenu(app.AnalysisMenu);
            app.NewdataseriesMenu.MenuSelectedFcn = createCallbackFcn(app, @NewdataseriesMenuSelected, true);
            app.NewdataseriesMenu.Separator = 'on';
            app.NewdataseriesMenu.Text = 'New dataseries';

            % Create NewdatasetMenu
            app.NewdatasetMenu = uimenu(app.AnalysisMenu);
            app.NewdatasetMenu.MenuSelectedFcn = createCallbackFcn(app, @NewdatasetMenuSelected, true);
            app.NewdatasetMenu.Text = 'New dataset';

            % Create DuplicatedatasetMenu
            app.DuplicatedatasetMenu = uimenu(app.AnalysisMenu);
            app.DuplicatedatasetMenu.MenuSelectedFcn = createCallbackFcn(app, @DuplicatedatasetMenuSelected, true);
            app.DuplicatedatasetMenu.Text = 'Duplicate dataset';

            % Create DeleteselecteddataseriesMenu
            app.DeleteselecteddataseriesMenu = uimenu(app.AnalysisMenu);
            app.DeleteselecteddataseriesMenu.MenuSelectedFcn = createCallbackFcn(app, @DeleteselecteddataseriesMenuSelected, true);
            app.DeleteselecteddataseriesMenu.Text = 'Delete selected dataseries';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.ScoreAppUIFigure);
            app.TabGroup.Position = [13 17 631 923];

            % Create ROIslistTab
            app.ROIslistTab = uitab(app.TabGroup);
            app.ROIslistTab.Title = 'ROIs list';

            % Create ROisPanel
            app.ROisPanel = uipanel(app.ROIslistTab);
            app.ROisPanel.Title = 'ROis';
            app.ROisPanel.FontSize = 10;
            app.ROisPanel.Position = [17 59 608 831];

            % Create UIROITable
            app.UIROITable = uitable(app.ROisPanel);
            app.UIROITable.ColumnName = {'Display'; 'Name'; 'Size'};
            app.UIROITable.ColumnWidth = {70, 400, 100};
            app.UIROITable.RowName = {};
            app.UIROITable.ColumnEditable = [true false false];
            app.UIROITable.FontSize = 10;
            app.UIROITable.Position = [6 18 582 790];


            % Create DisplaySettingsTab
            app.DisplaySettingsTab = uitab(app.TabGroup);
            app.DisplaySettingsTab.Title = 'Display Settings';

            % Create DisplaysettingsPanel
            app.DisplaysettingsPanel = uipanel(app.DisplaySettingsTab);
            app.DisplaysettingsPanel.AutoResizeChildren = 'off';
            app.DisplaysettingsPanel.Title = 'Display settings';
            app.DisplaysettingsPanel.FontSize = 10;
            app.DisplaysettingsPanel.Position = [17 21 608 870];

            % Create UIDisplayAxes
            app.UIDisplayAxes = uiaxes(app.DisplaysettingsPanel);
            xlabel(app.UIDisplayAxes, 'X')
            ylabel(app.UIDisplayAxes, 'Y')
            zlabel(app.UIDisplayAxes, 'Z')
            app.UIDisplayAxes.Position = [15 24 573 306];

            % Create UIChannelTable
            app.UIChannelTable = uitable(app.DisplaysettingsPanel);
            app.UIChannelTable.ColumnName = {'Display'; 'Name'; 'Scale'; 'Levels'; 'RGB'; 'Weight'; 'Auto'; 'Log'};
            app.UIChannelTable.ColumnWidth = {70, 200, 55, 70, 70, 70, 50, 50};
            app.UIChannelTable.RowName = {};
            app.UIChannelTable.SelectionChangedFcn = createCallbackFcn(app, @UIChannelTableSelectionChanged, true);
            app.UIChannelTable.FontSize = 10;
            app.UIChannelTable.Position = [8 511 584 327];

            % Create ZoomLabel
            app.ZoomLabel = uilabel(app.DisplaysettingsPanel);
            app.ZoomLabel.HorizontalAlignment = 'right';
            app.ZoomLabel.FontSize = 10;
            app.ZoomLabel.Position = [11 356 31 22];
            app.ZoomLabel.Text = 'Zoom';

            % Create ZoomSlider
            app.ZoomSlider = uislider(app.DisplaysettingsPanel);
            app.ZoomSlider.Limits = [100 500];
            app.ZoomSlider.MajorTicks = [100 500];
            app.ZoomSlider.ValueChangingFcn = createCallbackFcn(app, @ZoomSliderValueChanging, true);
            app.ZoomSlider.FontSize = 10;
            app.ZoomSlider.Position = [64 374 132 3];
            app.ZoomSlider.Value = 100;

            % Create FrameSliderLabel
            app.FrameSliderLabel = uilabel(app.DisplaysettingsPanel);
            app.FrameSliderLabel.HorizontalAlignment = 'right';
            app.FrameSliderLabel.Position = [204 362 40 22];
            app.FrameSliderLabel.Text = 'Frame';

            % Create FrameSlider
            app.FrameSlider = uislider(app.DisplaysettingsPanel);
            app.FrameSlider.ValueChangingFcn = createCallbackFcn(app, @FrameSliderValueChanging, true);
            app.FrameSlider.FontSize = 10;
            app.FrameSlider.Position = [261 372 128 3];

            % Create FrameEditField
            app.FrameEditField = uieditfield(app.DisplaysettingsPanel, 'numeric');
            app.FrameEditField.ValueChangedFcn = createCallbackFcn(app, @FrameEditFieldValueChanged, true);
            app.FrameEditField.Position = [400 359 38 22];

            % Create ChannelPanel
            app.ChannelPanel = uipanel(app.DisplaysettingsPanel);
            app.ChannelPanel.Title = 'Channel';
            app.ChannelPanel.Position = [6 395 434 97];

            % Create WeightSliderLabel
            app.WeightSliderLabel = uilabel(app.ChannelPanel);
            app.WeightSliderLabel.HorizontalAlignment = 'right';
            app.WeightSliderLabel.FontSize = 10;
            app.WeightSliderLabel.Position = [229 25 36 22];
            app.WeightSliderLabel.Text = 'Weight';

            % Create WeightSlider
            app.WeightSlider = uislider(app.ChannelPanel);
            app.WeightSlider.Limits = [0 1];
            app.WeightSlider.MajorTicks = [0 0.5 1];
            app.WeightSlider.ValueChangingFcn = createCallbackFcn(app, @WeightSliderValueChanging, true);
            app.WeightSlider.MinorTicks = [0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1];
            app.WeightSlider.FontSize = 10;
            app.WeightSlider.Position = [278 35 81 3];
            app.WeightSlider.Value = 1;

            % Create ChannelColorPicker
            app.ChannelColorPicker = uicolorpicker(app.ChannelPanel);
            app.ChannelColorPicker.ValueChangedFcn = createCallbackFcn(app, @ChannelColorPickerValueChanged, true);
            app.ChannelColorPicker.Position = [377 24 38 22];

            % Create SelectedChannelLabel
            app.SelectedChannelLabel = uilabel(app.ChannelPanel);
            app.SelectedChannelLabel.FontSize = 10;
            app.SelectedChannelLabel.Position = [11 50 235 22];

            % Create OverlayCheckBox
            app.OverlayCheckBox = uicheckbox(app.ChannelPanel);
            app.OverlayCheckBox.ValueChangedFcn = createCallbackFcn(app, @OverlayCheckBoxValueChanged, true);
            app.OverlayCheckBox.Text = 'Overlay Channels';
            app.OverlayCheckBox.FontSize = 10;
            app.OverlayCheckBox.Position = [276 48 101 22];

            % Create LevelsLabel
            app.LevelsLabel = uilabel(app.ChannelPanel);
            app.LevelsLabel.HorizontalAlignment = 'right';
            app.LevelsLabel.Position = [5 24 40 22];
            app.LevelsLabel.Text = 'Levels';

            % Create LowHighDisplaySlider
            app.LowHighDisplaySlider = uislider(app.ChannelPanel, 'range');
            app.LowHighDisplaySlider.Limits = [0 4.8];
            app.LowHighDisplaySlider.MajorTicks = [0 1 2 3 4];
            app.LowHighDisplaySlider.MajorTickLabels = {'1', '10', '100', '1000', '10000'};
            app.LowHighDisplaySlider.ValueChangingFcn = createCallbackFcn(app, @LowHighDisplaySliderValueChanging, true);
            app.LowHighDisplaySlider.Position = [67 33 150 3];
            app.LowHighDisplaySlider.Value = [0 4.8];

            % Create ResetButton
            app.ResetButton = uibutton(app.DisplaysettingsPanel, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Position = [81 345 47 22];
            app.ResetButton.Text = 'Reset';

            % Create PanButton
            app.PanButton = uibutton(app.DisplaysettingsPanel, 'state');
            app.PanButton.ValueChangedFcn = createCallbackFcn(app, @PanButtonValueChanged, true);
            app.PanButton.Text = 'Pan';
            app.PanButton.Position = [134 345 49 23];

            % Create QuantificationTab
            app.QuantificationTab = uitab(app.TabGroup);
            app.QuantificationTab.Title = 'Quantification';

            % Create IntensityQuantificationPanel
            app.IntensityQuantificationPanel = uipanel(app.QuantificationTab);
            app.IntensityQuantificationPanel.Title = 'Intensity Quantification';
            app.IntensityQuantificationPanel.FontSize = 10;
            app.IntensityQuantificationPanel.Position = [18 483 450 407];

            % Create UIProfileAxes
            app.UIProfileAxes = uiaxes(app.IntensityQuantificationPanel);
            app.UIProfileAxes.Position = [10 10 403 345];

            % Create LineIntensityprofileButton
            app.LineIntensityprofileButton = uibutton(app.IntensityQuantificationPanel, 'state');
            app.LineIntensityprofileButton.ValueChangedFcn = createCallbackFcn(app, @LineIntensityprofileButtonValueChanged2, true);
            app.LineIntensityprofileButton.Text = 'Line Intensity profile';
            app.LineIntensityprofileButton.Position = [11 358 121 22];

            % Create ShapeButton
            app.ShapeButton = uibutton(app.IntensityQuantificationPanel, 'state');
            app.ShapeButton.ValueChangedFcn = createCallbackFcn(app, @ShapeButtonValueChanged, true);
            app.ShapeButton.Text = 'Shape intensity';
            app.ShapeButton.Position = [138 359 100 22];

            % Create ROIDataTab
            app.ROIDataTab = uitab(app.TabGroup);
            app.ROIDataTab.Title = 'ROI Data';

            % Create DataSettingsPanel
            app.DataSettingsPanel = uipanel(app.ROIDataTab);
            app.DataSettingsPanel.Title = 'Data';
            app.DataSettingsPanel.Position = [15 9 610 881];

            % Create UIDataTable
            app.UIDataTable = uitable(app.DataSettingsPanel);
            app.UIDataTable.ColumnName = {'Sel'; 'Name'; 'Type'};
            app.UIDataTable.RowName = {};
            app.UIDataTable.ColumnEditable = [true true false];
            app.UIDataTable.CellEditCallback = createCallbackFcn(app, @UIDataTableCellEdit, true);
            app.UIDataTable.SelectionChangedFcn = createCallbackFcn(app, @UIDataTableSelectionChanged, true);
            app.UIDataTable.FontSize = 10;
            app.UIDataTable.Position = [14 566 576 260];

            % Create UISubDataTable
            app.UISubDataTable = uitable(app.DataSettingsPanel);
            app.UISubDataTable.ColumnName = {'Plot'; 'PlotName'; 'Type'; 'Color'; 'Width'; 'Plot group'};
            app.UISubDataTable.ColumnWidth = {50, 200, 100, 70, 50, 100};
            app.UISubDataTable.RowName = {};
            app.UISubDataTable.ColumnEditable = [true true false true true true];
            app.UISubDataTable.CellEditCallback = createCallbackFcn(app, @UISubDataTableCellEdit, true);
            app.UISubDataTable.SelectionChangedFcn = createCallbackFcn(app, @UISubDataTableSelectionChanged, true);
            app.UISubDataTable.FontSize = 10;
            app.UISubDataTable.Position = [8 79 586 329];

            % Create SelecteddataLabel
            app.SelecteddataLabel = uilabel(app.DataSettingsPanel);
            app.SelecteddataLabel.Position = [17 41 331 22];
            app.SelecteddataLabel.Text = 'Selected data';

            % Create AssignvalueLabel
            app.AssignvalueLabel = uilabel(app.DataSettingsPanel);
            app.AssignvalueLabel.HorizontalAlignment = 'right';
            app.AssignvalueLabel.Position = [12 15 76 22];
            app.AssignvalueLabel.Text = 'Assign value:';

            % Create AssignvalueEditField
            app.AssignvalueEditField = uieditfield(app.DataSettingsPanel, 'text');
            app.AssignvalueEditField.ValueChangedFcn = createCallbackFcn(app, @AssignvalueEditFieldValueChanged, true);
            app.AssignvalueEditField.Position = [118 15 100 22];

            % Create ClassDropDownLabel
            app.ClassDropDownLabel = uilabel(app.DataSettingsPanel);
            app.ClassDropDownLabel.HorizontalAlignment = 'right';
            app.ClassDropDownLabel.Position = [283 15 35 22];
            app.ClassDropDownLabel.Text = 'Class';

            % Create ClassDropDown
            app.ClassDropDown = uidropdown(app.DataSettingsPanel);
            app.ClassDropDown.ValueChangedFcn = createCallbackFcn(app, @ClassDropDownValueChanged, true);
            app.ClassDropDown.Position = [330 15 100 22];

            % Create DeselectalldataButton
            app.DeselectalldataButton = uibutton(app.DataSettingsPanel, 'push');
            app.DeselectalldataButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectalldataButtonPushed, true);
            app.DeselectalldataButton.Position = [8 831 104 23];
            app.DeselectalldataButton.Text = 'Deselect all data';

            % Create DeselectallsubdataButton
            app.DeselectallsubdataButton = uibutton(app.DataSettingsPanel, 'push');
            app.DeselectallsubdataButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectallsubdataButtonPushed, true);
            app.DeselectallsubdataButton.Position = [117 832 123 23];
            app.DeselectallsubdataButton.Text = 'Deselect all subdata';

            % Create NewdatagroupButton
            app.NewdatagroupButton = uibutton(app.DataSettingsPanel, 'push');
            app.NewdatagroupButton.ButtonPushedFcn = createCallbackFcn(app, @NewdatagroupButtonPushed, true);
            app.NewdatagroupButton.Position = [11 532 100 23];
            app.NewdatagroupButton.Text = 'New data group';

            % Create UIGroupTable
            app.UIGroupTable = uitable(app.DataSettingsPanel);
            app.UIGroupTable.ColumnName = {'GroupName'; 'Type'; 'XLim'; 'YLim'};
            app.UIGroupTable.ColumnWidth = {250, 120, 100, 100};
            app.UIGroupTable.RowName = {};
            app.UIGroupTable.ColumnEditable = [true true true true];
            app.UIGroupTable.CellEditCallback = createCallbackFcn(app, @UIGroupTableCellEdit, true);
            app.UIGroupTable.Position = [8 417 582 106];

            % Create NewdataseriesButton
            app.NewdataseriesButton = uibutton(app.DataSettingsPanel, 'push');
            app.NewdataseriesButton.ButtonPushedFcn = createCallbackFcn(app, @NewdataseriesButtonPushed, true);
            app.NewdataseriesButton.Position = [244 832 100 23];
            app.NewdataseriesButton.Text = 'New dataseries';

            % Create NewdatasetButton
            app.NewdatasetButton = uibutton(app.DataSettingsPanel, 'push');
            app.NewdatasetButton.ButtonPushedFcn = createCallbackFcn(app, @NewdatasetButtonPushed, true);
            app.NewdatasetButton.Position = [348 832 92 23];
            app.NewdatasetButton.Text = 'New dataset';

            % Create FrameEditField_2Label
            app.FrameEditField_2Label = uilabel(app.DataSettingsPanel);
            app.FrameEditField_2Label.HorizontalAlignment = 'right';
            app.FrameEditField_2Label.Position = [336 45 43 22];
            app.FrameEditField_2Label.Text = 'Frame:';

            % Create FrameEditField_2
            app.FrameEditField_2 = uieditfield(app.DataSettingsPanel, 'numeric');
            app.FrameEditField_2.ValueChangedFcn = createCallbackFcn(app, @FrameEditField_2ValueChanged, true);
            app.FrameEditField_2.Position = [387 45 50 22];

            % Create AnnotationsTab
            app.AnnotationsTab = uitab(app.TabGroup);
            app.AnnotationsTab.Title = 'Annotations';

            % Create AnnotationPanel
            app.AnnotationPanel = uipanel(app.AnnotationsTab);
            app.AnnotationPanel.Title = 'Annotation Panel';
            app.AnnotationPanel.FontSize = 10;
            app.AnnotationPanel.Position = [7 9 618 879];

            % Create UIAnnotationTable
            app.UIAnnotationTable = uitable(app.AnnotationPanel);
            app.UIAnnotationTable.ColumnName = {'Display'; 'Name'; 'Class'; 'Weight'; 'Contour'; 'Width'};
            app.UIAnnotationTable.ColumnWidth = {70, 200, 100, 70, 70, 70};
            app.UIAnnotationTable.RowName = {};
            app.UIAnnotationTable.ColumnEditable = [true true true true true true];
            app.UIAnnotationTable.SelectionChangedFcn = createCallbackFcn(app, @UIAnnotationTableSelectionChanged, true);
            app.UIAnnotationTable.FontSize = 10;
            app.UIAnnotationTable.Position = [13 517 589 162];

            % Create ObjectspanelPanel
            app.ObjectspanelPanel = uipanel(app.AnnotationPanel);
            app.ObjectspanelPanel.Title = 'Objects panel';
            app.ObjectspanelPanel.FontSize = 10;
            app.ObjectspanelPanel.Position = [17 13 581 316];

            % Create MasklabelEditFieldLabel
            app.MasklabelEditFieldLabel = uilabel(app.ObjectspanelPanel);
            app.MasklabelEditFieldLabel.HorizontalAlignment = 'right';
            app.MasklabelEditFieldLabel.Position = [10 153 66 22];
            app.MasklabelEditFieldLabel.Text = 'Mask label:';

            % Create MasklabelEditField
            app.MasklabelEditField = uieditfield(app.ObjectspanelPanel, 'numeric');
            app.MasklabelEditField.ValueChangedFcn = createCallbackFcn(app, @MasklabelEditFieldValueChanged, true);
            app.MasklabelEditField.Position = [146 153 100 22];

            % Create LineageDisplayButtonGroup
            app.LineageDisplayButtonGroup = uibuttongroup(app.ObjectspanelPanel);
            app.LineageDisplayButtonGroup.Title = 'Lineage display';
            app.LineageDisplayButtonGroup.Position = [7 193 123 97];

            % Create NoLineageRadioButton
            app.NoLineageRadioButton = uiradiobutton(app.LineageDisplayButtonGroup);
            app.NoLineageRadioButton.Text = 'None';
            app.NoLineageRadioButton.Position = [11 51 51 22];
            app.NoLineageRadioButton.Value = true;

            % Create BudLinksRadioButton
            app.BudLinksRadioButton = uiradiobutton(app.LineageDisplayButtonGroup);
            app.BudLinksRadioButton.Text = 'Recent bud links';
            app.BudLinksRadioButton.Position = [11 29 111 22];

            % Create FullGenealogyRadioButton
            app.FullGenealogyRadioButton = uiradiobutton(app.LineageDisplayButtonGroup);
            app.FullGenealogyRadioButton.Text = 'Full genealogy';
            app.FullGenealogyRadioButton.Position = [11 7 100 22];

            % Create ObjectFamilyDropDownLabel
            app.ObjectFamilyDropDownLabel = uilabel(app.ObjectspanelPanel);
            app.ObjectFamilyDropDownLabel.HorizontalAlignment = 'right';
            app.ObjectFamilyDropDownLabel.Position = [145 265 78 22];
            app.ObjectFamilyDropDownLabel.Text = 'Object family:';

            % Create ObjectFamilyDropDown
            app.ObjectFamilyDropDown = uidropdown(app.ObjectspanelPanel);
            app.ObjectFamilyDropDown.Items = {'<auto>'};
            app.ObjectFamilyDropDown.Position = [235 265 100 22];
            app.ObjectFamilyDropDown.Value = '<auto>';

            % Create MaskProviderDropDownLabel
            app.MaskProviderDropDownLabel = uilabel(app.ObjectspanelPanel);
            app.MaskProviderDropDownLabel.HorizontalAlignment = 'right';
            app.MaskProviderDropDownLabel.Position = [137 232 84 22];
            app.MaskProviderDropDownLabel.Text = 'Mask provider:';

            % Create MaskProviderDropDown
            app.MaskProviderDropDown = uidropdown(app.ObjectspanelPanel);
            app.MaskProviderDropDown.Items = {'<family default>'};
            app.MaskProviderDropDown.Position = [236 232 100 22];
            app.MaskProviderDropDown.Value = '<family default>';

            % Create LineageSourceDropDownLabel
            app.LineageSourceDropDownLabel = uilabel(app.ObjectspanelPanel);
            app.LineageSourceDropDownLabel.HorizontalAlignment = 'right';
            app.LineageSourceDropDownLabel.Position = [133 201 89 22];
            app.LineageSourceDropDownLabel.Text = 'Lineage Source';

            % Create LineageSourceDropDown
            app.LineageSourceDropDown = uidropdown(app.ObjectspanelPanel);
            app.LineageSourceDropDown.Items = {'<family default>', ''};
            app.LineageSourceDropDown.Position = [237 201 100 22];
            app.LineageSourceDropDown.Value = '<family default>';

            % Create ObjectColorsPanel
            app.ObjectColorsPanel = uipanel(app.ObjectspanelPanel);
            app.ObjectColorsPanel.Title = 'Object Colors';
            app.ObjectColorsPanel.Position = [354 44 218 245];

            % Create FamilyColorPickerLabel
            app.FamilyColorPickerLabel = uilabel(app.ObjectColorsPanel);
            app.FamilyColorPickerLabel.HorizontalAlignment = 'right';
            app.FamilyColorPickerLabel.Position = [35 184 70 22];
            app.FamilyColorPickerLabel.Text = 'Family color';

            % Create FamilyColorPicker
            app.FamilyColorPicker = uicolorpicker(app.ObjectColorsPanel);
            app.FamilyColorPicker.Position = [120 184 38 22];

            % Create SemanticValueDropDownLabel
            app.SemanticValueDropDownLabel = uilabel(app.ObjectColorsPanel);
            app.SemanticValueDropDownLabel.HorizontalAlignment = 'right';
            app.SemanticValueDropDownLabel.Position = [12 147 87 22];
            app.SemanticValueDropDownLabel.Text = 'Semantic value';

            % Create SemanticValueDropDown
            app.SemanticValueDropDown = uidropdown(app.ObjectColorsPanel);
            app.SemanticValueDropDown.Position = [120 147 84 22];

            % Create SemanticValueColorPickerLabel
            app.SemanticValueColorPickerLabel = uilabel(app.ObjectColorsPanel);
            app.SemanticValueColorPickerLabel.HorizontalAlignment = 'right';
            app.SemanticValueColorPickerLabel.Position = [17 111 88 22];
            app.SemanticValueColorPickerLabel.Text = 'Semantic Value';

            % Create SemanticValueColorPicker
            app.SemanticValueColorPicker = uicolorpicker(app.ObjectColorsPanel);
            app.SemanticValueColorPicker.Position = [120 111 38 22];

            % Create BudlinkcolorColorPickerLabel
            app.BudlinkcolorColorPickerLabel = uilabel(app.ObjectColorsPanel);
            app.BudlinkcolorColorPickerLabel.HorizontalAlignment = 'right';
            app.BudlinkcolorColorPickerLabel.Position = [41 77 77 22];
            app.BudlinkcolorColorPickerLabel.Text = 'Bud link color';

            % Create BudlinkcolorColorPicker
            app.BudlinkcolorColorPicker = uicolorpicker(app.ObjectColorsPanel);
            app.BudlinkcolorColorPicker.Value = [1 0.8196 0.051];
            app.BudlinkcolorColorPicker.Position = [121 77 38 22];

            % Create GenealogyLinkColorPickerLabel
            app.GenealogyLinkColorPickerLabel = uilabel(app.ObjectColorsPanel);
            app.GenealogyLinkColorPickerLabel.HorizontalAlignment = 'right';
            app.GenealogyLinkColorPickerLabel.Position = [-1 46 114 22];
            app.GenealogyLinkColorPickerLabel.Text = 'Genealogy link color';

            % Create GenealogyLinkColorPicker
            app.GenealogyLinkColorPicker = uicolorpicker(app.ObjectColorsPanel);
            app.GenealogyLinkColorPicker.Value = [0.051 0.749 1];
            app.GenealogyLinkColorPicker.Position = [119 46 38 22];

            % Create LineageLinkWidthEditFieldLabel
            app.LineageLinkWidthEditFieldLabel = uilabel(app.ObjectColorsPanel);
            app.LineageLinkWidthEditFieldLabel.HorizontalAlignment = 'right';
            app.LineageLinkWidthEditFieldLabel.Position = [12 9 101 22];
            app.LineageLinkWidthEditFieldLabel.Text = 'Link width (px)';

            % Create LineageLinkWidthEditField
            app.LineageLinkWidthEditField = uieditfield(app.ObjectColorsPanel, 'numeric');
            app.LineageLinkWidthEditField.Limits = [1 20];
            app.LineageLinkWidthEditField.RoundFractionalValues = 'on';
            app.LineageLinkWidthEditField.Position = [121 9 62 22];
            app.LineageLinkWidthEditField.Value = 1;
            % Create SelectedObjectIDLabel
            app.SelectedObjectIDLabel = uilabel(app.ObjectspanelPanel);
            app.SelectedObjectIDLabel.HorizontalAlignment = 'right';
            app.SelectedObjectIDLabel.Position = [7 113 108 22];
            app.SelectedObjectIDLabel.Text = 'Selected Object ID:';

            % Create SelectedObjectIDEditField
            app.SelectedObjectIDEditField = uieditfield(app.ObjectspanelPanel, 'text');
            app.SelectedObjectIDEditField.Editable = 'off';
            app.SelectedObjectIDEditField.Position = [149 113 100 22];

            % Create SelectedTrackIDEditFieldLabel
            app.SelectedTrackIDEditFieldLabel = uilabel(app.ObjectspanelPanel);
            app.SelectedTrackIDEditFieldLabel.HorizontalAlignment = 'right';
            app.SelectedTrackIDEditFieldLabel.Position = [8 71 106 22];
            app.SelectedTrackIDEditFieldLabel.Text = 'Selected Track ID: ';

            % Create SelectedTrackIDEditField
            app.SelectedTrackIDEditField = uieditfield(app.ObjectspanelPanel, 'text');
            app.SelectedTrackIDEditField.Position = [149 71 100 22];

            % Create SelectedCellStateDropDownLabel
            app.SelectedCellStateDropDownLabel = uilabel(app.ObjectspanelPanel);
            app.SelectedCellStateDropDownLabel.HorizontalAlignment = 'right';
            app.SelectedCellStateDropDownLabel.Position = [28 34 102 22];
            app.SelectedCellStateDropDownLabel.Text = 'Selected cell state';

            % Create SelectedCellStateDropDown
            app.SelectedCellStateDropDown = uidropdown(app.ObjectspanelPanel);
            app.SelectedCellStateDropDown.Position = [145 34 100 22];

            % Create CellModelStatusLabel
            app.CellModelStatusLabel = uilabel(app.ObjectspanelPanel);
            app.CellModelStatusLabel.Position = [16 7 133 22];
            app.CellModelStatusLabel.Text = 'No cellular object model';

            % Create NewAnnotationButton
            app.NewAnnotationButton = uibutton(app.AnnotationPanel, 'push');
            app.NewAnnotationButton.ButtonPushedFcn = createCallbackFcn(app, @NewAnnotationButtonPushed, true);
            app.NewAnnotationButton.Position = [158 687 95 23];
            app.NewAnnotationButton.Text = 'New Annotation';

            % Create DeleteAnnnotationButton
            app.DeleteAnnnotationButton = uibutton(app.AnnotationPanel, 'push');
            app.DeleteAnnnotationButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteAnnnotationButtonPushed, true);
            app.DeleteAnnnotationButton.Position = [257 687 109 23];
            app.DeleteAnnnotationButton.Text = 'Delete Annnotation';

            % Create NewclassButton
            app.NewclassButton = uibutton(app.AnnotationPanel, 'push');
            app.NewclassButton.ButtonPushedFcn = createCallbackFcn(app, @NewclassButtonPushed, true);
            app.NewclassButton.Position = [372 687 94 23];
            app.NewclassButton.Text = 'New class';

            % Create DeleteclassButton
            app.DeleteclassButton = uibutton(app.AnnotationPanel, 'push');
            app.DeleteclassButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteclassButtonPushed, true);
            app.DeleteclassButton.Position = [472 687 108 23];
            app.DeleteclassButton.Text = 'Delete class';

            % Create isthedefautcolorCheckBox
            app.isthedefautcolorCheckBox = uicheckbox(app.AnnotationPanel);
            app.isthedefautcolorCheckBox.ValueChangedFcn = createCallbackFcn(app, @isthedefautcolorCheckBoxValueChanged, true);
            app.isthedefautcolorCheckBox.Text = '''1'' is the defaut color';
            app.isthedefautcolorCheckBox.Position = [18 685 131 22];

            % Create SelectedchannelpropertiesPanel
            app.SelectedchannelpropertiesPanel = uipanel(app.AnnotationPanel);
            app.SelectedchannelpropertiesPanel.Title = 'Selected channel properties';
            app.SelectedchannelpropertiesPanel.Position = [16 343 582 163];

            % Create IndexChannelLabel
            app.IndexChannelLabel = uilabel(app.SelectedchannelpropertiesPanel);
            app.IndexChannelLabel.Position = [65 109 333 22];
            app.IndexChannelLabel.Text = 'IndexChannelLabel';

            % Create SelectedLabel
            app.SelectedLabel = uilabel(app.SelectedchannelpropertiesPanel);
            app.SelectedLabel.Position = [9 109 55 22];
            app.SelectedLabel.Text = 'Selected:';

            % Create TransparencyLabel
            app.TransparencyLabel = uilabel(app.SelectedchannelpropertiesPanel);
            app.TransparencyLabel.HorizontalAlignment = 'right';
            app.TransparencyLabel.Position = [3 82 78 22];
            app.TransparencyLabel.Text = 'Transparency';

            % Create Transparency
            app.Transparency = uislider(app.SelectedchannelpropertiesPanel);
            app.Transparency.Limits = [0 1];
            app.Transparency.ValueChangedFcn = createCallbackFcn(app, @TransparencyValueChanged, true);
            app.Transparency.ValueChangingFcn = createCallbackFcn(app, @TransparencyValueChanging, true);
            app.Transparency.Position = [101 90 150 3];
            app.Transparency.Value = 0.5;

            % Create AnnoatationcolorLabel
            app.AnnoatationcolorLabel = uilabel(app.SelectedchannelpropertiesPanel);
            app.AnnoatationcolorLabel.HorizontalAlignment = 'right';
            app.AnnoatationcolorLabel.Position = [269 79 34 22];
            app.AnnoatationcolorLabel.Text = 'Color';

            % Create MaskColorPicker
            app.MaskColorPicker = uicolorpicker(app.SelectedchannelpropertiesPanel);
            app.MaskColorPicker.ValueChangedFcn = createCallbackFcn(app, @MaskColorPickerValueChanged, true);
            app.MaskColorPicker.Position = [318 80 38 22];

            % Create ChannelModeButtonGroup
            app.ChannelModeButtonGroup = uibuttongroup(app.SelectedchannelpropertiesPanel);
            app.ChannelModeButtonGroup.Title = 'Channel mode';
            app.ChannelModeButtonGroup.Position = [419 14 107 119];

            % Create NormalButton
            app.NormalButton = uiradiobutton(app.ChannelModeButtonGroup);
            app.NormalButton.Text = 'Normal';
            app.NormalButton.Position = [13 73 61 22];
            app.NormalButton.Value = true;

            % Create MulticolorButton
            app.MulticolorButton = uiradiobutton(app.ChannelModeButtonGroup);
            app.MulticolorButton.Text = 'Multicolor';
            app.MulticolorButton.Position = [13 49 73 22];

            % Create SemanticButton
            app.SemanticButton = uiradiobutton(app.ChannelModeButtonGroup);
            app.SemanticButton.Text = 'Semantic';
            app.SemanticButton.Position = [13 26 72 22];

            % Create EditButton
            app.EditButton = uiradiobutton(app.ChannelModeButtonGroup);
            app.EditButton.Text = 'Edit';
            app.EditButton.Position = [13 4 43 22];

            % Create ColorbyLabel
            app.ColorbyLabel = uilabel(app.SelectedchannelpropertiesPanel);
            app.ColorbyLabel.Position = [248 19 53 22];
            app.ColorbyLabel.Text = 'Color by:';

            % Create DisplayCriterionDropDown
            app.DisplayCriterionDropDown = uidropdown(app.SelectedchannelpropertiesPanel);
            app.DisplayCriterionDropDown.Items = {'Channel color', 'Track', 'Frame instance', 'Family', 'New bud', 'Cell state'};
            app.DisplayCriterionDropDown.Position = [310 20 100 22];
            app.DisplayCriterionDropDown.Value = 'Channel color';

            % Create AnnotationSessionPanel
            app.AnnotationSessionPanel = uipanel(app.AnnotationPanel);
            app.AnnotationSessionPanel.Visible = 'off';
            app.AnnotationSessionPanel.Title = 'Annotation Session';
            app.AnnotationSessionPanel.Position = [11 680 599 175];

            % Create AnnotationTargetLabel
            app.AnnotationTargetLabel = uilabel(app.AnnotationSessionPanel);
            app.AnnotationTargetLabel.Position = [13 124 210 22];
            app.AnnotationTargetLabel.Text = 'Annotation Target';

            % Create AnnotationStatusLabel
            app.AnnotationStatusLabel = uilabel(app.AnnotationSessionPanel);
            app.AnnotationStatusLabel.Position = [13 101 220 22];
            app.AnnotationStatusLabel.Text = 'Status';

            % Create AnnotationCoverageLabel
            app.AnnotationCoverageLabel = uilabel(app.AnnotationSessionPanel);
            app.AnnotationCoverageLabel.WordWrap = 'on';
            app.AnnotationCoverageLabel.Position = [13 38 220 60];
            app.AnnotationCoverageLabel.Text = 'Coverage';

            % Create CreateFromPredictionButton
            app.CreateFromPredictionButton = uibutton(app.AnnotationSessionPanel, 'push');
            app.CreateFromPredictionButton.ButtonPushedFcn = createCallbackFcn(app, @CreateFromPredictionButtonPushed, true);
            app.CreateFromPredictionButton.Position = [247 124 154 23];
            app.CreateFromPredictionButton.Text = 'Initialize GT...';

            % Create StartBlankGTButton
            app.StartBlankGTButton = uibutton(app.AnnotationSessionPanel, 'push');
            app.StartBlankGTButton.Visible = 'off';
            app.StartBlankGTButton.ButtonPushedFcn = createCallbackFcn(app, @StartBlankGTButtonPushed, true);
            app.StartBlankGTButton.Position = [251 95 145 23];
            app.StartBlankGTButton.Text = 'Start blank GT';

            % Create MarkFrameReviewedButton
            app.MarkFrameReviewedButton = uibutton(app.AnnotationSessionPanel, 'push');
            app.MarkFrameReviewedButton.ButtonPushedFcn = createCallbackFcn(app, @MarkFrameReviewedButtonPushed, true);
            app.MarkFrameReviewedButton.Position = [253 66 143 23];
            app.MarkFrameReviewedButton.Text = 'Mark frame reviewed';

            % Create NextIncompleteButton
            app.NextIncompleteButton = uibutton(app.AnnotationSessionPanel, 'push');
            app.NextIncompleteButton.ButtonPushedFcn = createCallbackFcn(app, @NextIncompleteButtonPushed, true);
            app.NextIncompleteButton.Position = [421 124 170 23];
            app.NextIncompleteButton.Text = 'Next Incomplete';

            % Create ValidateAnnotationButton
            app.ValidateAnnotationButton = uibutton(app.AnnotationSessionPanel, 'push');
            app.ValidateAnnotationButton.ButtonPushedFcn = createCallbackFcn(app, @ValidateAnnotationButtonPushed, true);
            app.ValidateAnnotationButton.Position = [423 95 100 23];
            app.ValidateAnnotationButton.Text = 'Validate';

            % Create ApproveAnnotationButton
            app.ApproveAnnotationButton = uibutton(app.AnnotationSessionPanel, 'push');
            app.ApproveAnnotationButton.ButtonPushedFcn = createCallbackFcn(app, @ApproveAnnotationButtonPushed, true);
            app.ApproveAnnotationButton.Position = [424 66 100 23];
            app.ApproveAnnotationButton.Text = 'Approve GT';

            % Create MarkThroughCurrentButton
            app.MarkThroughCurrentButton = uibutton(app.AnnotationSessionPanel, 'push');
            app.MarkThroughCurrentButton.ButtonPushedFcn = createCallbackFcn(app, @MarkThroughCurrentButtonPushed, true);
            app.MarkThroughCurrentButton.Position = [247 36 154 23];
            app.MarkThroughCurrentButton.Text = 'Review 1 -> current...';

            % Create ReviewWhileNavigatingCheckBox
            app.ReviewWhileNavigatingCheckBox = uicheckbox(app.AnnotationSessionPanel);
            app.ReviewWhileNavigatingCheckBox.Text = 'Review while navigating';
            app.ReviewWhileNavigatingCheckBox.Position = [421 36 166 22];
            app.ReviewWhileNavigatingCheckBox.Value = false;
            % Create ShowPredictionCheckBox
            app.ShowPredictionCheckBox = uicheckbox(app.AnnotationSessionPanel);
            app.ShowPredictionCheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowPredictionCheckBoxValueChanged, true);
            app.ShowPredictionCheckBox.Text = 'Show Prediction Overlay';
            app.ShowPredictionCheckBox.Position = [256 5 153 22];

            % Create MovieoutputTab
            app.MovieoutputTab = uitab(app.TabGroup);
            app.MovieoutputTab.Title = 'Movie output';

            % Create MoviePanel
            app.MoviePanel = uipanel(app.MovieoutputTab);
            app.MoviePanel.Title = 'Movie';
            app.MoviePanel.Position = [11 411 598 480];

            % Create MovieFramesEditFieldLabel
            app.MovieFramesEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieFramesEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieFramesEditFieldLabel.Position = [11 395 84 22];
            app.MovieFramesEditFieldLabel.Text = 'Movie Frames:';

            % Create MovieFramesEditField
            app.MovieFramesEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieFramesEditField.Position = [110 395 100 22];

            % Create MovieROIArraysizeEditFieldLabel
            app.MovieROIArraysizeEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieROIArraysizeEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieROIArraysizeEditFieldLabel.Position = [243 395 118 22];
            app.MovieROIArraysizeEditFieldLabel.Text = 'Movie ROI Array size';

            % Create MovieROIArraysizeEditField
            app.MovieROIArraysizeEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieROIArraysizeEditField.Position = [378 395 56 22];
            app.MovieROIArraysizeEditField.Value = '1 1';

            % Create MovieselectcurrentROIonlyCheckBox
            app.MovieselectcurrentROIonlyCheckBox = uicheckbox(app.MoviePanel);
            app.MovieselectcurrentROIonlyCheckBox.Text = 'Movie select current ROI only';
            app.MovieselectcurrentROIonlyCheckBox.Position = [14 426 179 22];
            app.MovieselectcurrentROIonlyCheckBox.Value = true;

            % Create MovieoutputfilenameEditFieldLabel
            app.MovieoutputfilenameEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieoutputfilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieoutputfilenameEditFieldLabel.Position = [12 359 122 22];
            app.MovieoutputfilenameEditFieldLabel.Text = 'Movie output filename';

            % Create MovieoutputfilenameEditField
            app.MovieoutputfilenameEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieoutputfilenameEditField.Position = [149 356 243 25];

            % Create SetButton
            app.SetButton = uibutton(app.MoviePanel, 'push');
            app.SetButton.ButtonPushedFcn = createCallbackFcn(app, @SetButtonPushed, true);
            app.SetButton.Position = [397 358 43 23];
            app.SetButton.Text = 'Set...';

            % Create MovieoutputtypeDropDownLabel
            app.MovieoutputtypeDropDownLabel = uilabel(app.MoviePanel);
            app.MovieoutputtypeDropDownLabel.HorizontalAlignment = 'right';
            app.MovieoutputtypeDropDownLabel.Position = [216 429 100 22];
            app.MovieoutputtypeDropDownLabel.Text = 'Movie output type';

            % Create MovieoutputtypeDropDown
            app.MovieoutputtypeDropDown = uidropdown(app.MoviePanel);
            app.MovieoutputtypeDropDown.Items = {'Movie', 'Sequence'};
            app.MovieoutputtypeDropDown.ValueChangedFcn = createCallbackFcn(app, @MovieoutputtypeDropDownValueChanged, true);
            app.MovieoutputtypeDropDown.Position = [331 429 100 22];
            app.MovieoutputtypeDropDown.Value = 'Movie';

            % Create MoviebackgroundcolorEditFieldLabel
            app.MoviebackgroundcolorEditFieldLabel = uilabel(app.MoviePanel);
            app.MoviebackgroundcolorEditFieldLabel.HorizontalAlignment = 'right';
            app.MoviebackgroundcolorEditFieldLabel.Position = [12 264 132 22];
            app.MoviebackgroundcolorEditFieldLabel.Text = 'Movie background color';

            % Create MoviebackgroundcolorEditField
            app.MoviebackgroundcolorEditField = uieditfield(app.MoviePanel, 'text');
            app.MoviebackgroundcolorEditField.Position = [159 264 51 22];
            app.MoviebackgroundcolorEditField.Value = '0 0 0';

            % Create MovietextcolorEditFieldLabel
            app.MovietextcolorEditFieldLabel = uilabel(app.MoviePanel);
            app.MovietextcolorEditFieldLabel.HorizontalAlignment = 'right';
            app.MovietextcolorEditFieldLabel.Position = [55 233 89 22];
            app.MovietextcolorEditFieldLabel.Text = 'Movie text color';

            % Create MovietextcolorEditField
            app.MovietextcolorEditField = uieditfield(app.MoviePanel, 'text');
            app.MovietextcolorEditField.Position = [159 233 51 22];
            app.MovietextcolorEditField.Value = '1 1 1';

            % Create MoviefontsizeEditFieldLabel
            app.MoviefontsizeEditFieldLabel = uilabel(app.MoviePanel);
            app.MoviefontsizeEditFieldLabel.HorizontalAlignment = 'right';
            app.MoviefontsizeEditFieldLabel.Position = [59 203 85 22];
            app.MoviefontsizeEditFieldLabel.Text = 'Movie font size';

            % Create MoviefontsizeEditField
            app.MoviefontsizeEditField = uieditfield(app.MoviePanel, 'text');
            app.MoviefontsizeEditField.Position = [159 203 51 22];
            app.MoviefontsizeEditField.Value = '10';

            % Create MoviescaleEditFieldLabel
            app.MoviescaleEditFieldLabel = uilabel(app.MoviePanel);
            app.MoviescaleEditFieldLabel.HorizontalAlignment = 'right';
            app.MoviescaleEditFieldLabel.Position = [75 174 68 22];
            app.MoviescaleEditFieldLabel.Text = 'Movie scale';

            % Create MoviescaleEditField
            app.MoviescaleEditField = uieditfield(app.MoviePanel, 'text');
            app.MoviescaleEditField.Position = [158 174 51 22];
            app.MoviescaleEditField.Value = '1';

            % Create MoviehidetimestampCheckBox
            app.MoviehidetimestampCheckBox = uicheckbox(app.MoviePanel);
            app.MoviehidetimestampCheckBox.Text = 'Movie hide timestamp';
            app.MoviehidetimestampCheckBox.Position = [272 276 139 22];

            % Create MovieoffsettimeCheckBox
            app.MovieoffsettimeCheckBox = uicheckbox(app.MoviePanel);
            app.MovieoffsettimeCheckBox.Text = 'Movie offset time';
            app.MovieoffsettimeCheckBox.Position = [273 252 112 22];

            % Create MovieframespersecondEditFieldLabel
            app.MovieframespersecondEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieframespersecondEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieframespersecondEditFieldLabel.Position = [236 183 140 22];
            app.MovieframespersecondEditFieldLabel.Text = 'Movie frames per second';

            % Create MovieframespersecondEditField
            app.MovieframespersecondEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieframespersecondEditField.Position = [382 183 55 22];
            app.MovieframespersecondEditField.Value = '20';

            % Create MovieminutesperframeEditFieldLabel
            app.MovieminutesperframeEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieminutesperframeEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieminutesperframeEditFieldLabel.Position = [229 144 137 22];
            app.MovieminutesperframeEditFieldLabel.Text = 'Movie minutes per frame';

            % Create MovieminutesperframeEditField
            app.MovieminutesperframeEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieminutesperframeEditField.Position = [381 144 56 22];
            app.MovieminutesperframeEditField.Value = '10';

            % Create MoviecropEditFieldLabel
            app.MoviecropEditFieldLabel = uilabel(app.MoviePanel);
            app.MoviecropEditFieldLabel.HorizontalAlignment = 'right';
            app.MoviecropEditFieldLabel.Position = [281 110 64 22];
            app.MoviecropEditFieldLabel.Text = 'Movie crop';

            % Create MoviecropEditField
            app.MoviecropEditField = uieditfield(app.MoviePanel, 'text');
            app.MoviecropEditField.Position = [360 110 77 22];

            % Create GrenerateMovieButton
            app.GrenerateMovieButton = uibutton(app.MoviePanel, 'push');
            app.GrenerateMovieButton.ButtonPushedFcn = createCallbackFcn(app, @GrenerateMovieButtonPushed, true);
            app.GrenerateMovieButton.Position = [269 8 171 80];
            app.GrenerateMovieButton.Text = 'Grenerate Movie';

            % Create MovietitleEditFieldLabel
            app.MovietitleEditFieldLabel = uilabel(app.MoviePanel);
            app.MovietitleEditFieldLabel.HorizontalAlignment = 'right';
            app.MovietitleEditFieldLabel.Position = [13 293 59 22];
            app.MovietitleEditFieldLabel.Text = 'Movie title';

            % Create MovietitleEditField
            app.MovietitleEditField = uieditfield(app.MoviePanel, 'text');
            app.MovietitleEditField.Position = [87 293 123 22];
            app.MovietitleEditField.Value = 'My movie';

            % Create MoviecolormapEditFieldLabel
            app.MoviecolormapEditFieldLabel = uilabel(app.MoviePanel);
            app.MoviecolormapEditFieldLabel.HorizontalAlignment = 'right';
            app.MoviecolormapEditFieldLabel.Position = [52 145 90 22];
            app.MoviecolormapEditFieldLabel.Text = 'Movie colormap';

            % Create MoviecolormapEditField
            app.MoviecolormapEditField = uieditfield(app.MoviePanel, 'text');
            app.MoviecolormapEditField.Position = [157 145 52 22];
            app.MoviecolormapEditField.Value = 'lines';

            % Create MovieImagetodataratioEditFieldLabel
            app.MovieImagetodataratioEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieImagetodataratioEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieImagetodataratioEditFieldLabel.Position = [2 115 140 22];
            app.MovieImagetodataratioEditFieldLabel.Text = 'Movie Image to data ratio';

            % Create MovieImagetodataratioEditField
            app.MovieImagetodataratioEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieImagetodataratioEditField.Position = [157 115 53 22];
            app.MovieImagetodataratioEditField.Value = '3';

            % Create MovieDatacolormapEditFieldLabel
            app.MovieDatacolormapEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieDatacolormapEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieDatacolormapEditFieldLabel.Position = [24 82 118 22];
            app.MovieDatacolormapEditFieldLabel.Text = 'Movie Data colormap';

            % Create MovieDatacolormapEditField
            app.MovieDatacolormapEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieDatacolormapEditField.Position = [157 82 53 22];
            app.MovieDatacolormapEditField.Value = 'lines';

            % Create MovieROItitleCheckBox
            app.MovieROItitleCheckBox = uicheckbox(app.MoviePanel);
            app.MovieROItitleCheckBox.Text = 'Movie ROI title';
            app.MovieROItitleCheckBox.Position = [273 228 101 22];

            % Create MoviedatatrackCheckBox
            app.MoviedatatrackCheckBox = uicheckbox(app.MoviePanel);
            app.MoviedatatrackCheckBox.ValueChangedFcn = createCallbackFcn(app, @MoviedatatrackCheckBoxValueChanged, true);
            app.MoviedatatrackCheckBox.Text = 'Movie data track';
            app.MoviedatatrackCheckBox.Position = [157 47 110 22];

            % Create MovietrackwindowEditFieldLabel
            app.MovietrackwindowEditFieldLabel = uilabel(app.MoviePanel);
            app.MovietrackwindowEditFieldLabel.HorizontalAlignment = 'right';
            app.MovietrackwindowEditFieldLabel.Position = [31 21 110 22];
            app.MovietrackwindowEditFieldLabel.Text = 'Movie track window';

            % Create MovietrackwindowEditField
            app.MovietrackwindowEditField = uieditfield(app.MoviePanel, 'text');
            app.MovietrackwindowEditField.ValueChangedFcn = createCallbackFcn(app, @MovietrackwindowEditFieldValueChanged, true);
            app.MovietrackwindowEditField.Position = [156 20 45 22];
            app.MovietrackwindowEditField.Value = '20';

            % Create MovielegendCheckBox
            app.MovielegendCheckBox = uicheckbox(app.MoviePanel);
            app.MovielegendCheckBox.Text = 'Movie legend';
            app.MovielegendCheckBox.Position = [273 204 93 22];

            % Create MovieeventmarkersEditFieldLabel
            app.MovieeventmarkersEditFieldLabel = uilabel(app.MoviePanel);
            app.MovieeventmarkersEditFieldLabel.HorizontalAlignment = 'right';
            app.MovieeventmarkersEditFieldLabel.Position = [230 169 105 22];
            app.MovieeventmarkersEditFieldLabel.Text = 'Movie events fr';

            % Create MovieeventmarkersEditField
            app.MovieeventmarkersEditField = uieditfield(app.MoviePanel, 'text');
            app.MovieeventmarkersEditField.Position = [350 169 150 22];
            app.MovieeventmarkersEditField.Value = '';
            % Create ShowmovieandfolderButton
            app.ShowmovieandfolderButton = uibutton(app.MoviePanel, 'push');
            app.ShowmovieandfolderButton.ButtonPushedFcn = createCallbackFcn(app, @ShowmovieandfolderButtonPushed, true);
            app.ShowmovieandfolderButton.Position = [301 325 140 23];
            app.ShowmovieandfolderButton.Text = 'Show movie and folder ';

            % Show the figure after all components are created
            app.ScoreAppUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = score(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.ScoreAppUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.ScoreAppUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            app.flushAnnotationReview();

            try
                if ~isempty(app.PipelineRunEventListenerId) && exist('detecdiv_event', 'file') == 2
                    detecdiv_event('unsubscribe', app.PipelineRunEventListenerId);
                    app.PipelineRunEventListenerId = '';
                end
            catch
            end

            % Delete UIFigure when app is deleted
            delete(app.ScoreAppUIFigure)
        end
    end
end
