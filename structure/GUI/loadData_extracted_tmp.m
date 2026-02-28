classdef loadData < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        LoadingAppUIFigure              matlab.ui.Figure
        LoadButton                      matlab.ui.control.Button
        TabGroup                        matlab.ui.container.TabGroup
        ImagesTab                       matlab.ui.container.Tab
        deselectextractROIsforallButton  matlab.ui.control.Button
        selectextractROIsforallButton   matlab.ui.control.Button
        DeselectallpositionsButton      matlab.ui.control.Button
        SelectallpositionsButton        matlab.ui.control.Button
        ROIsettingsCheckBox             matlab.ui.control.CheckBox
        PreviewCheckBox                 matlab.ui.control.CheckBox
        ProjectsettingsCheckBox         matlab.ui.control.CheckBox
        PositionssettingsCheckBox       matlab.ui.control.CheckBox
        InfoLabel                       matlab.ui.control.Label
        PathLabel                       matlab.ui.control.Label
        ChoosefilesButton               matlab.ui.control.Button
        ORLabel                         matlab.ui.control.Label
        PositionsPanel                  matlab.ui.container.Panel
        UIPositionTable                 matlab.ui.control.Table
        ChannelsPanel                   matlab.ui.container.Panel
        applychangestoallpositionsCheckBox  matlab.ui.control.CheckBox
        FramesField                     matlab.ui.control.EditField
        FramesSlider                    matlab.ui.control.RangeSlider
        FramesSliderLabel               matlab.ui.control.Label
        UIChannelTable                  matlab.ui.control.Table
        InvertframesandpositionsCheckBox  matlab.ui.control.CheckBox
        ChoosefolderButton              matlab.ui.control.Button
        ProjectTab                      matlab.ui.container.Tab
        SetProjectButton                matlab.ui.control.Button
        OutputprojectfileEditField      matlab.ui.control.EditField
        OutputprojectfileEditFieldLabel  matlab.ui.control.Label
        PreviewTab                      matlab.ui.container.Tab
        ZoomfactorSlider                matlab.ui.control.Slider
        ZoomfactorSliderLabel           matlab.ui.control.Label
        ZoomButton                      matlab.ui.control.StateButton
        PositionSlider                  matlab.ui.control.Slider
        PositionSliderLabel             matlab.ui.control.Label
        ChannelSlider                   matlab.ui.control.Slider
        ChannelSliderLabel              matlab.ui.control.Label
        FramesSlider_2                  matlab.ui.control.Slider
        FramesSlider_2Label             matlab.ui.control.Label
        ROIsTab                         matlab.ui.container.Tab
        GreenROIsindicateROIstobeaddedLabel  matlab.ui.control.Label
        ROIextractionparametersPanel    matlab.ui.container.Panel
        ScaleEditField                  matlab.ui.control.NumericEditField
        ScaleEditFieldLabel             matlab.ui.control.Label
        MaxROIdisplayEditField          matlab.ui.control.NumericEditField
        MaxROIdisplayEditFieldLabel     matlab.ui.control.Label
        MaxframeloadinginmemoryEditField  matlab.ui.control.NumericEditField
        MaxframeloadinginmemoryLabel    matlab.ui.control.Label
        correctROIdriftCheckBox         matlab.ui.control.CheckBox
        ROIssettingsButtonGroup         matlab.ui.container.ButtonGroup
        CustomROIparametersPanel        matlab.ui.container.Panel
        ThresholdEditField              matlab.ui.control.NumericEditField
        ThresholdEditFieldLabel         matlab.ui.control.Label
        DetectROIsinallpositionsButton  matlab.ui.control.Button
        DetectROIsincurrentposButton    matlab.ui.control.Button
        DimensionsEditField             matlab.ui.control.EditField
        DimensionsEditFieldLabel        matlab.ui.control.Label
        linesandcolumnsLabel            matlab.ui.control.Label
        ROIDivide                       matlab.ui.control.NumericEditField
        CustomROIsButton                matlab.ui.control.RadioButton
        DivideframeintoButton           matlab.ui.control.RadioButton
        FullframeROIsButton             matlab.ui.control.RadioButton
        CancelButton                    matlab.ui.control.Button
    end


    properties (Access = public)
        parsedData % Description
        hPreview % Description
        hCustomROI % Description
        hPreviewFigure % Description
        hPreviewAxes
        OriginalXLim % Description
        OriginalYLim % Description
        shallowObj % Description
        Settings
        mainApp
    end

    properties (Access = private)
        Property2 % Description
    end

    methods (Access = public)

        function updatePositionTable(app)
             % Met à jour la table des positions et les sliders à partir de app.parsedData.
    positions = app.parsedData.positions;  % Array de structures
    nPos = numel(positions);
    % On crée un tableau à 5 colonnes : {Select, File Pos Name, User Name, ROI Count, ?}
    posTableData = cell(nPos, 5);  

    for i = 1:nPos
        % Extraire le nom du dossier à partir du champ folder (pour File Pos Name)
        if isfield(positions(i), 'folder')
            folderValue = positions(i).folder;
            if ischar(folderValue) && ~strcmp(folderValue, '')
                folderPath = folderValue;
            elseif isstring(folderValue) && folderValue ~= ""
                folderPath = char(folderValue);
            else
                folderPath = '';
            end
        else
            folderPath = '';
        end

        if ~isempty(folderPath)
            % Retirer le séparateur final s'il existe
            if folderPath(end)==filesep || folderPath(end)=='/'
                folderPath = folderPath(1:end-1);
            end
            % Extraire le nom du dossier (après le dernier séparateur)
            idx = find(folderPath==filesep | folderPath=='/', 1, 'last');
            if isempty(idx)
                filePosName = folderPath;
            else
                filePosName = folderPath(idx+1:end);
            end
        else
            filePosName = sprintf('Pos%d', i-1);
        end

        % Utiliser le champ 'selected' et 'userName' déjà stocké dans la structure
        posTableData{i, 1} = positions(i).selected;
        if app.InvertframesandpositionsCheckBox.Value==false
            posTableData{i, 2} = filePosName;
        else
            posTableData{i, 2} = 'AllPositions';
        end
        posTableData{i, 3} = positions(i).userName;
        
        % Calcul du nombre de ROI pour la position i
        if ~isempty(app.shallowObj) && isa(app.shallowObj, 'shallow')
            % Supposons que app.shallowObj.fov est un tableau indexé par position
            if numel(app.shallowObj.fov)>=i
            roiArray = app.shallowObj.fov(i).roi;
            count = numel(roiArray);
            if count == 1
                % Si l'array de roi contient un seul élément, on tente d'utiliser le nombre de lignes de roibb
                if isfield(app.parsedData.positions(i), 'roibb') && ~isempty(app.parsedData.positions(i).roibb)
                    count = size(app.parsedData.positions(i).roibb, 1);
                else
                    count = 1;
                end
            end
            else
 count = 1;
            end
            posTableData{i, 4} = num2str(count);
        else
            % Si aucun objet shallow n'est disponible, on met 1 par défaut.
            posTableData{i, 4} = '1';
        end
        
        % Vous pouvez utiliser la colonne 5 pour une autre information (ici on la laisse à true)
        posTableData{i, 5} = app.parsedData.positions(i).extractROI;
    end

    app.UIPositionTable.Data = posTableData;

    % Mise à jour du slider des frames dans le panneau Channels
    posData = positions(1);
    % On arrondit les limites pour s'assurer qu'elles sont entières
    minFrame = round(posData.minFrame)
    maxFrame = round(posData.maxFrame)

    app.FramesSlider.Limits = [minFrame, max(minFrame+1, maxFrame)];

    if isfield(posData, 'currentMinFrame') && ~isempty(posData.currentMinFrame)
        currentMin = round(posData.currentMinFrame);
    else
        currentMin = minFrame;
    end
    if isfield(posData, 'currentMaxFrame') && ~isempty(posData.currentMaxFrame)
        currentMax = round(posData.currentMaxFrame);
    else
        currentMax = maxFrame;
    end
    app.FramesSlider.Value = [currentMin, currentMax];
    app.FramesField.Value = [num2str(currentMin) ' ' num2str(currentMax)];

    % Mise à jour de la table des channels pour la première position par défaut
    updateChannelTable(app, 1);

    % --- Mise à jour des trois nouveaux sliders dans l'onglet ROIs ---
    % 1. PositionSlider: limite [1, nPos] et ticks entiers
    app.PositionSlider.Limits = [1, max(1.1, nPos)];
    app.PositionSlider.MajorTicks = 1:nPos;
    app.PositionSlider.Value = 1;

    % 2. ChannelSlider: limite dépend du nombre de channels de la première position
    if isfield(posData, 'numChannels') && ~isempty(posData.numChannels)
        numChannels = posData.numChannels;
    else
        numChannels = 1;
    end
    app.ChannelSlider.Limits = [1, max(1.1, numChannels)];
    app.ChannelSlider.MajorTicks = 1:numChannels;
    app.ChannelSlider.Value = 1;

%    app.OutputprojectfileEditField.Value = app.parsedData.projectPath;
if isfield(app.parsedData, 'projectPath')
    app.OutputprojectfileEditField.Value = app.parsedData.projectPath;
else
    app.OutputprojectfileEditField.Value = fullfile(app.parsedData.folder, 'tmpProject.mat');
end

    app.InfoLabel.Text = [num2str(numel(app.parsedData.positions)) ' Positions '];
    app.applychangestoallpositionsCheckBox.Value = app.parsedData.allpositions;
    app.correctROIdriftCheckBox.Value = app.parsedData.correctdrift;
    app.MaxROIdisplayEditField.Value = app.parsedData.maxroidisplay;
    app.ScaleEditField.Value=app.parsedData.scale;

    % 3. FramesSlider_2: limites [minFrame, maxFrame] et ticks "ronds"
    app.FramesSlider_2.Limits = [minFrame, max(minFrame+1, maxFrame)];
    % Calcul d'un tick spacing "nice" pour avoir environ 10 ticks
    rangeVal = maxFrame - minFrame;
    if rangeVal == 0
        tickSpacing = 1;
    else
        rawSpacing = rangeVal / 10;
        exponent = floor(log10(rawSpacing));
        fraction = rawSpacing / 10^exponent;
        if fraction <= 1
            niceFraction = 1;
        elseif fraction <= 2
            niceFraction = 2;
        elseif fraction <= 5
            niceFraction = 5;
        else
            niceFraction = 10;
        end
        tickSpacing = niceFraction * 10^exponent;
    end
    ticks = minFrame:tickSpacing:maxFrame;
    % Limiter à environ 10 ticks
    if numel(ticks) > 10
        ticks = ticks(1:10);
    end
    app.FramesSlider_2.MajorTicks = ticks;
    % Pour la valeur par défaut, utiliser minFrame (ou 1 si minFrame < 1)
    if minFrame < 1
        app.FramesSlider_2.Value = 1;
    else
        app.FramesSlider_2.Value = minFrame;
    end

    switch app.parsedData.roitype
        case 'full'
            app.ROIssettingsButtonGroup.SelectedObject = app.FullframeROIsButton;
        case 'divide'
            app.ROIssettingsButtonGroup.SelectedObject = app.ROIDivide;
        case 'custom'
            app.ROIssettingsButtonGroup.SelectedObject = app.CustomROIsButton;
            app.DimensionsEditField.Value = num2str(app.parsedData.roibb);
    end

    if app.parsedData.advancedMode
        app.PositionssettingsCheckBox.Value = true;
        % Advanced mode activé : réinsérer les onglets "Project" et "ROIs" dans le TabGroup,
        % si ils ne s'y trouvent pas déjà.
        if isempty(app.ProjectTab.Parent)
            app.ProjectTab.Parent = app.TabGroup;
        end
        if isempty(app.PreviewTab.Parent)
            app.PreviewTab.Parent = app.TabGroup;
        end
        app.PositionsPanel.Visible = "on";
        app.ChannelsPanel.Visible = "on";
    end

    % if app.parsedData.extractROI
    %     app.ROIextractionparametersPanel.Enable = "on";
    % else
    %     app.ROIextractionparametersPanel.Enable = "off";
    % end
        end





        function updateChannelTable(app, posIndex)
            % Met à jour la table des channels et le slider pour la position spécifiée.
            % Si posIndex n'est pas fourni, la première position est utilisée.

            if nargin < 2 || isempty(posIndex)
                posIndex = 1;
            end

            positions = app.parsedData.positions;
            posData = positions(posIndex);
            numChannels = posData.numChannels;

            % Préparer la table des channels avec 5 colonnes :
            % {Select, File Chan. Name, User Name, Frequency, Size}
            chanTableData = cell(numChannels, 5);
            for i = 1:numChannels
                chanIndex = i - 1;  % Numérotation à partir de 0
                chanTableData{i, 1} = posData.channelsSelected(i);            % Utilise le champ channelsSelected
                chanTableData{i, 2} = num2str(chanIndex);                       % File Chan. Name
                chanTableData{i, 3} = posData.userChanName{i};                  % User Name (champ userChanName)
                chanTableData{i, 4} = num2str(posData.channelFrequencies(i));   % Frequency
                chanTableData{i, 5} = posData.channelSizes{i};                  % Size
            end
            app.UIChannelTable.Data = chanTableData;

            % Mise à jour du slider des frames pour la position sélectionnée.
            if isfield(posData, 'minFrame')
                minFrame = posData.minFrame;
            else
                minFrame = min(posData.frames);
            end
            if isfield(posData, 'maxFrame')
                maxFrame = posData.maxFrame;
            else
                maxFrame = max(posData.frames);
            end

            if isfield(posData, 'currentMinFrame') && ~isempty(posData.currentMinFrame)
                currentMin = posData.currentMinFrame;
            else
                currentMin = minFrame;
            end
            if isfield(posData, 'currentMaxFrame') && ~isempty(posData.currentMaxFrame)
                currentMax = posData.currentMaxFrame;
            else
                currentMax = maxFrame;
            end

            currentMin=round(currentMin);
            currentMax=round(currentMax);

            app.FramesSlider.Limits = [minFrame, max(minFrame+1,maxFrame)];
            app.FramesSlider.Value = [currentMin, currentMax];
            app.FramesField.Value = [num2str(currentMin) ' ' num2str(currentMax)];
        end

        function updatePreview(app, forceUpdate)

               if ~isfield(app.parsedData,'positions') || numel(app.parsedData.positions)==0
                 return;
               end

            if nargin < 2
                forceUpdate = false;
            end
            posIndex = round(app.PositionSlider.Value);
            channelIndex = round(app.ChannelSlider.Value);
            sliderFrame = round(app.FramesSlider_2.Value);

            % Mise à jour des sliders (si besoin)
            app.PositionSlider.Value = posIndex;
            app.ChannelSlider.Value = channelIndex;
            app.FramesSlider_2.Value = sliderFrame;

            % Vérifier si la figure de prévisualisation existe ; sinon la créer
            if isempty(app.hPreviewFigure) || ~isvalid(app.hPreviewFigure)
                % Récupérer la position de l'UIFigure de l'application
                mainPos = app.LoadingAppUIFigure.Position;  % [left, bottom, width, height]
                % Placer la figure de prévisualisation à droite de l'UIFigure
                newFigLeft = mainPos(1) + mainPos(3);
                newFigBottom = mainPos(2);
                % Créer la figure sans menu ni barre d'outils et avec une taille de 1000x1000 pixels
                app.hPreviewFigure = figure('Name', 'Preview', ...
                    'NumberTitle', 'off', ...
                    'MenuBar', 'none', ...
                    'ToolBar', 'none', ...
                    'Position', [newFigLeft, newFigBottom, 1000, 1000]);
                % Activer le zoom
                %   zoom(app.hPreviewFigure, 'on');
                % Créer un axe dans cette figure
                app.hPreviewAxes = axes('Parent', app.hPreviewFigure);
            end

            % Appeler la fonction de rafraîchissement en passant l'axe de la figure séparée
            app.hPreview = loadData_preview(app, app.parsedData, posIndex, channelIndex, sliderFrame, app.hPreviewAxes, app.hPreview, forceUpdate);


          

            % Mettre à jour la cellule correspondante dans app.UIPositionTable.
            % On suppose ici que la 4ème colonne affiche le nombre de ROIs détectées.
            data = app.UIPositionTable.Data;

            for i=1:numel(app.parsedData.positions)
                if numel(app.parsedData.positions(i).roibb)>0
                    nrois=size(app.parsedData.positions(i).roibb,1);
                    data{i, 4} = num2str(nrois);

                else
                    if numel(app.parsedData.roibb)>0
                        data{i, 4} = num2str(size(app.parsedData.roibb,1));
                    else
                        data{i, 4} = num2str(1);
                    end
                end
            end

            app.UIPositionTable.Data = data;



        end


        function customROIPositionChanged(app, pos)
            % pos est [left, bottom, width, height]
            app.parsedData.roibb = round(pos);
            img = get(app.hPreview, 'CData');

            if numel(img)==0
               updatePreview(app);
            end

            app.parsedData.roipattern = imcrop(img, pos);
            app.DimensionsEditField.Value = sprintf('%d %d %d %d', round(pos(1)), round(pos(2)), round(pos(3)), round(pos(4)));
        end

    end



    methods (Access = private)


       
   

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, varargin)
         % Par défaut, n'afficher que l'onglet "Images"
    app.ProjectTab.Parent = [];
    app.PreviewTab.Parent = [];
    app.ROIsTab.Parent = [];
    
    % Cas 1 : aucun argument extra (seul app est fourni)
    if nargin == 1
        % L'interface démarre avec uniquement l'onglet "Images" visible.
        % Les autres onglets seront affichés en fonction des checkboxes (Positions,
        % Project, Preview, ROI settings) par leurs callbacks respectifs.
        return;
    end
    
    % Cas 2 : un objet shallowObj est fourni (nargin>=2)
    shallowObj = varargin{1};
  %  app.parsedData = shallowObj.parsedData;
    app.parsedData = loadData_rebuildParsedDataFromProject(shallowObj);
  %  assignin('base', 'parsedData', app.parsedData);
    app.shallowObj = shallowObj;

    % Mise à jour de la table des positions ou affectation du chemin de projet
    if numel(app.parsedData)
         app.PathLabel.Text=app.parsedData.folder;
        app.updatePositionTable;
    %   ll =app.PositionSlider.Limits
    else
        app.OutputprojectfileEditField.Value = fullfile(shallowObj.io.path, [shallowObj.io.file '.mat']);
        app.parsedData.projectPath = app.OutputprojectfileEditField.Value;
    end
    
    % Si un second argument est passé, il peut activer un mode spécial
    if nargin >= 3
           posIndex = varargin{2}; % Conversion en char si nécessaire

        if strcmp( class(posIndex),'double')
     
            % Mode "preview" : on affiche uniquement l'onglet "Preview"
            % et on masque le bouton "Load"
            app.ImagesTab.Parent = [];
            app.ProjectTab.Parent = [];
            app.ROIsTab.Parent = [];

            if isempty(app.PreviewTab.Parent)
                app.PreviewTab.Parent = app.TabGroup;
            end

            app.LoadButton.Visible= 'off';
             app.PositionSlider.Value=posIndex;
             app.updatePreview();

             return;
       else
            % Mode "noROIextraction" : décocher et désactiver la checkbox extractROIs
          %  app.extractROIsCheckBox.Value = false;
          %  app.parsedData.extractROI = false;
        %    app.extractROIsCheckBox.Enable = 'off'

           app.mainApp=posIndex;
        end
    end

              app.PositionsPanel.Visible="on";
            app.ChannelsPanel.Visible="on";

            app.PositionssettingsCheckBox.Value=true;
            app.PreviewCheckBox.Value=true;
            app.ROIsettingsCheckBox.Value=true;
            app.ProjectsettingsCheckBox.Value=true;

            app.PreviewTab.Parent = app.TabGroup;
            app.ROIsTab.Parent = app.TabGroup;
            app.ProjectTab.Parent = app.TabGroup;


        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, event)

                      if ~isempty(app.mainApp)
               app.mainApp.shallowObj=[];
            uiresume(app.mainApp.LifespanizerUIFigure);
                      end

            if ~isempty(app.hPreviewFigure) && isvalid(app.hPreviewFigure)
                delete(app.hPreviewFigure);
            end
            delete(app);  % Ferme l'application

        end

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, event)
            % Vérifier que des données ont été chargées
        
            
            if isempty(app.parsedData)
                uialert(app.LoadingAppUIFigure, 'Aucune donnée chargée.', 'Erreur');

                   if ~isempty(app.mainApp)
               app.mainApp.shallowObj=[];
            uiresume(app.mainApp.LifespanizerUIFigure);
                   end

                return;
            end

            d = uiprogressdlg(app.LoadingAppUIFigure, 'Title', 'Please Wait', ...
                'Message', 'Loading Images...', 'Indeterminate', 'on');


            shallowObj=loadData_load(app.parsedData,d);
       
   
           if ~isempty(app.mainApp)
               app.mainApp.shallowObj=shallowObj;
            uiresume(app.mainApp.LifespanizerUIFigure);
           end
     
            close(d);

            if ~isempty(app.hPreviewFigure) && isgraphics(app.hPreviewFigure)
                delete(app.hPreviewFigure);
            end
             delete(app);

        end

        % Value changing function: FramesSlider
        function FramesSliderValueChanging(app, event)

            changingValue = event.Value;  % Vecteur 1x2 [min max]
            minSliderPos = changingValue(1);
            maxSliderPos = changingValue(2);

            % Mise à jour du champ de texte
            app.FramesField.Value = [num2str(round(minSliderPos)) ' ' num2str(round(maxSliderPos))];

            % Déterminer quelles positions mettre à jour
            if app.applychangestoallpositionsCheckBox.Value
                posIndices = 1:numel(app.parsedData.positions);
            else
                if ~isempty(app.UIPositionTable.Selection)
                    posIndices = app.UIPositionTable.Selection(1);
                else
                    posIndices = 1;
                end
            end

 
            % Mise à jour des champs currentMinFrame/currentMaxFrame pour chaque position concernée
            for posIndex = posIndices
                app.parsedData.positions(posIndex).currentMinFrame = minSliderPos;
                app.parsedData.positions(posIndex).currentMaxFrame = maxSliderPos;

            end

          
            % Actualiser l'affichage de la table des channels pour la position actuellement sélectionnée
            if ~isempty(app.UIPositionTable.Selection)
                currentPos = app.UIPositionTable.Selection(1);
            else
                currentPos = 1;
            end
            updateChannelTable(app, currentPos);

        end

        % Value changed function: FramesField
        function FramesFieldValueChanged(app, event)
            % Convertir la valeur du champ de texte en nombre
            value = str2num(app.FramesField.Value);  %#ok<ST2NM>
            lim = app.FramesSlider.Limits;
            newVal = [max(lim(1), value(1)) , min(lim(2), value(2))];

            % Mettre à jour le slider
            app.FramesSlider.Value = newVal;

            % Déterminer quelles positions mettre à jour
            if app.applychangestoallpositionsCheckBox.Value
                posIndices = 1:numel(app.parsedData.positions);
            else
                if ~isempty(app.UIPositionTable.Selection)
                    posIndices = app.UIPositionTable.Selection(1);
                else
                    posIndices = 1;
                end
            end

            % Mise à jour des champs currentMinFrame/currentMaxFrame pour chaque position concernée
            for posIndex = posIndices
                app.parsedData.positions(posIndex).currentMinFrame = newVal(1);
                app.parsedData.positions(posIndex).currentMaxFrame = newVal(2);
            end

            % Actualiser l'affichage de la table des channels pour la position actuellement sélectionnée
            if ~isempty(app.UIPositionTable.Selection)
                currentPos = app.UIPositionTable.Selection(1);
            else
                currentPos = 1;
            end
            updateChannelTable(app, currentPos);

        end

        % Value changed function: PositionssettingsCheckBox
        function PositionssettingsCheckBoxValueChanged(app, event)
             value = app.PositionssettingsCheckBox.Value;
    app.parsedData.advancedMode = value;
    
    if value
        % Afficher le panneau des positions et des canaux
        app.PositionsPanel.Visible = 'on';
        app.ChannelsPanel.Visible = 'on';
    else
        % Masquer le panneau des positions et des canaux
        app.PositionsPanel.Visible = 'off';
        app.ChannelsPanel.Visible = 'off';
    end

        end

        % Button pushed function: ChoosefolderButton
        function ChoosefolderButtonPushed(app, event)
 % Demander à l'utilisateur de sélectionner un dossier
    % Demander à l'utilisateur de sélectionner un dossier
    files = {};
    folder = uigetdir;
    if folder ~= 0  % Vérifier que l'utilisateur n'a pas annulé
        % Mettre à jour le label avec le chemin du dossier sélectionné
        app.PathLabel.Text = folder;
    else
        return;
    end

    d = uiprogressdlg(app.LoadingAppUIFigure, 'Title', 'Please Wait',...
        'Message', 'Parsing files in the selected directory...');
    d.Value = 0.25;
    pause(0.2);
    d.Value = 0.5;

    % Désactiver l'inversion (par défaut)
    app.InvertframesandpositionsCheckBox.Value = false;

    % Conserver le chemin de projet déjà défini si présent
    if ~isempty(app.parsedData) && isfield(app.parsedData, 'projectPath')
        storePath = app.parsedData.projectPath;
    else
        storePath = fullfile(folder, "tmpProject.mat");
    end

    % Charger les nouvelles données à partir du dossier
    newParsed = loadData_parse(files, folder, app.InvertframesandpositionsCheckBox.Value);
    newParsed.projectPath = storePath;  % Conserver ou définir le chemin du projet

    % Fusionner les nouvelles positions avec celles existantes
    if ~isempty(app.parsedData) &&  isfield(app.parsedData, 'positions')
        % Fusionner le champ "positions" s'il existe dans les deux structures
        if isfield(app.parsedData, 'positions') && isfield(newParsed, 'positions')
            existingPositions = app.parsedData.positions;
            newPositions = newParsed.positions;
            % Récupérer l'union des noms de champs
            allFields = union(fieldnames(existingPositions), fieldnames(newPositions));
            % Compléter chaque structure existante avec les champs manquants
            for i = 1:numel(existingPositions)
                missingFields = setdiff(allFields, fieldnames(existingPositions(i)));
                for j = 1:numel(missingFields)
                    existingPositions(i).(missingFields{j}) = [];
                end
            end
            % Compléter chaque nouvelle structure avec les champs manquants
            for i = 1:numel(newPositions)
                missingFields = setdiff(allFields, fieldnames(newPositions(i)));
                for j = 1:numel(missingFields)
                    newPositions(i).(missingFields{j}) = [];
                end
            end
            % Concaténer les positions
            app.parsedData.positions = [existingPositions, newPositions];
        else
            app.parsedData.positions = newParsed.positions;
        end
        
        % Fusionner également la liste des fichiers si le champ existe dans newParsed
        if isfield(newParsed, 'files')
            if isfield(app.parsedData, 'files')
                app.parsedData.files = [app.parsedData.files, newParsed.files];
            else
                app.parsedData.files = newParsed.files;
            end
        end
        
        % Mise à jour du nombre total de positions et du dossier
        app.parsedData.numPositions = numel(app.parsedData.positions);
        app.parsedData.folder = folder;
    else
        app.parsedData = newParsed;
    end

    % % Gestion de l'extraction des ROI selon l'état de la checkbox
    % if strcmp(app.extractROIsCheckBox.Enable, 'off')
    %     app.parsedData.extractROI = false;
    % else
    %     app.parsedData.extractROI = true;
    % end

    % Mise à jour du label d'information avec le nombre total de positions
    app.InfoLabel.Text = [num2str(numel(app.parsedData.positions)) ' Positions '];

      if ~isempty(app.shallowObj) && isa(app.shallowObj, 'shallow')
        app.MaxROIdisplayEditField.Value=0;
        app.parsedData.maxroidisplay=0;
      end

    % Mettre à jour la variable parsedData dans l'espace de travail de base
   % assignin('base', 'parsedData', app.parsedData);

    d.Value = 1;
    pause(0.2);
    close(d);
    app.updatePositionTable;


        end

        % Selection changed function: UIPositionTable
        function UIPositionTableSelectionChanged(app, event)
            selection = app.UIPositionTable.Selection;
            % La sélection renvoie un tableau d'indices [row, column]
            if ~isempty(selection)
                posIndex = selection(1);  % Utiliser la première ligne sélectionnée comme indice
                updateChannelTable(app, posIndex);
            end


        end

        % Cell edit callback: UIPositionTable
        function UIPositionTableCellEdit(app, event)
            indices = event.Indices;  % [row, column]
            newData = event.NewData;
            row = indices(1);
            col = indices(2);

            % Mettre à jour la structure de la position correspondante selon la colonne éditée
            switch col
                case 1  % Colonne Select (checkbox)
                    app.parsedData.positions(row).selected = newData;
                case 2  % Colonne File Pos Name
                    app.parsedData.positions(row).filePosName = newData;
                case 3  % Colonne User Name
                    app.parsedData.positions(row).userName = newData;
                case 5
                     app.parsedData.positions(row).extractROI = newData;
            end


        end

        % Cell edit callback: UIChannelTable
        function UIChannelTableCellEdit(app, event)
          indices = event.Indices;  % [row, column]
    newData = event.NewData;
    channelRow = indices(1);  % index du channel (ligne)
    col = indices(2);         % index de la colonne éditée

    % Vérifier si la checkbox "apply changes to all positions" est activée
    if app.applychangestoallpositionsCheckBox.Value
        posIndices = 1:numel(app.parsedData.positions);
    else
        if ~isempty(app.UIPositionTable.Selection)
            posIndices = app.UIPositionTable.Selection(1);
        else
            posIndices = 1;
        end
    end

    for posIndex = posIndices
        posData = app.parsedData.positions(posIndex);
        switch col
            case 1  % Colonne "Select"
                posData.channelsSelected(channelRow) = newData;
            case 3  % Colonne "User Name"
                % Supprimer les espaces et tirets du nouveau nom
                newData = regexprep(newData, '[ -]', '');
                % Initialiser userChanName s'il n'existe pas ou est trop court
                if ~isfield(posData, 'userChanName') || numel(posData.userChanName) < posData.numChannels
                    posData.userChanName = repmat({['Channel' num2str(channelRow-1)]}, 1, posData.numChannels);
                end
                posData.userChanName{channelRow} = newData;
                % On ne traite pas les autres colonnes
        end
        % Mise à jour incrémentale dans la structure globale
        app.parsedData.positions(posIndex) = posData;
    end

    % Mettre à jour l'affichage de la table des channels pour la position actuellement sélectionnée
    if ~isempty(app.UIPositionTable.Selection)
        currentPos = app.UIPositionTable.Selection(1);
    else
        currentPos = 1;
    end
    updateChannelTable(app, currentPos);

  %  assignin('base', 'parsedData', app.parsedData);

        end

        % Callback function
        function applychangestoallpositionsCheckBoxValueChanged(app, event)
            value = app.applychangestoallpositionsCheckBox.Value;

        end

        % Button pushed function: SetProjectButton
        function SetProjectButtonPushed(app, event)
            [file, location]= uiputfile({'.mat'});
            if numel(file)~=0  % Vérifier que l'utilisateur n'a pas annulé
                % Mettre à jour le champ de texte avec le chemin du dossier sélectionné
                app.OutputprojectfileEditField.Value=fullfile(location,file);

            else
                app.OutputprojectfileEditField.Value=fullfile(app.parsedData.folder,'tmpProject.mat');
                return;
            end

            app.parsedData.projectPath=app.OutputprojectfileEditField.Value;


        end

        % Value changed function: InvertframesandpositionsCheckBox
        function InvertframesandpositionsCheckBoxValueChanged(app, event)
            value = app.InvertframesandpositionsCheckBox.Value;


            folder=app.PathLabel.Text;

            if ~strcmp(folder,'Path')

                d = uiprogressdlg(app.LoadingAppUIFigure,'Title','Please Wait',...
                    'Message','Parsing files in the selected directory...');
                d.Value=0.25;
                pause(0.2);
                d.Value=0.5;

                files=app.parsedData.files ;
                folder=app.parsedData.folder;
                app.parsedData = loadData_parse(files, folder,app.InvertframesandpositionsCheckBox.Value);
                app.parsedData.files=files;
                app.parsedData.folder=folder;

                if ~isfield(app.parsedData,'projectPath')
                    app.parsedData.projectPath=fullfile(folder, "tmpProject.mat");
                    app.OutputprojectfileEditField.Value=app.parsedData.projectPath;
                end

                d.Value=1;
                pause(0.2);
                close(d);

                app.updatePositionTable;
           %     assignin('base','parsedData', app.parsedData);
            end

        end

        % Button pushed function: ChoosefilesButton
        function ChoosefilesButtonPushed(app, event)


    % 1. Sélection des fichiers
    [files, folder] = uigetfile({'*.*','All files'}, 'Select files', 'MultiSelect', 'on');
    if isequal(files, 0)
        % user cancelled
        return;
    end

    d = uiprogressdlg(app.LoadingAppUIFigure, 'Title', 'Please Wait',...
        'Message', 'Parsing files in the selected directory...');
    d.Value = 0.25;
    pause(0.2);
    d.Value = 0.5;

    % 2. Conserver le chemin du projet existant s'il est déjà défini
    if ~isempty(app.parsedData) && isfield(app.parsedData,'projectPath') && ~isempty(app.parsedData.projectPath)
        storePath = app.parsedData.projectPath;
    else
        storePath = fullfile(folder, "tmpProject.mat");
    end

    % 3. Parser les NOUVEAUX fichiers sélectionnés
    newParsed = loadData_parse(files, folder, app.InvertframesandpositionsCheckBox.Value);
    newParsed.projectPath = storePath;

    % newParsed.positions est un tableau de structures décrivant
    % les nouvelles positions détectées dans ces fichiers.

    % 4. Fusionner newParsed dans app.parsedData SANS ÉCRASER
    % -------------------------------------------------------

    % Si app.parsedData est vide (aucune donnée en mémoire pour l'instant),
    % on prend juste newParsed tel quel.
    if isempty(app.parsedData)
        app.parsedData = newParsed;

    else
        % On a déjà des positions (par ex. venant du projet existant via rebuildParsedData...)
        % On doit concaténer app.parsedData.positions et newParsed.positions,
        % en harmonisant les champs.

        % a) Récupérer les positions actuelles et nouvelles
        if isfield(app.parsedData,'positions') && ~isempty(app.parsedData.positions)
            existingPositions = app.parsedData.positions;
        else
            existingPositions = struct([]); % rien
        end

        if isfield(newParsed,'positions') && ~isempty(newParsed.positions)
            newPositions = newParsed.positions;
        else
            newPositions = struct([]); % rien
        end

        % b) Construire l'union des champs de position
        allFields = union(fieldnames(existingPositions), fieldnames(newPositions));

        % c) Compléter chaque structure existante avec les champs manquants
        for iPos = 1:numel(existingPositions)
            missingFields = setdiff(allFields, fieldnames(existingPositions(iPos)));
            for mf = 1:numel(missingFields)
                existingPositions(iPos).(missingFields{mf}) = [];
            end
        end

        % d) Compléter chaque nouvelle structure avec les champs manquants
        for iPos = 1:numel(newPositions)
            missingFields = setdiff(allFields, fieldnames(newPositions(iPos)));
            for mf = 1:numel(missingFields)
                newPositions(iPos).(missingFields{mf}) = [];
            end
        end

        % e) Concaténer
        mergedPositions = [existingPositions , newPositions];

        % f) Réinjecter dans app.parsedData
        app.parsedData.positions = mergedPositions;

        % g) Mettre à jour les infos globales d'app.parsedData
        %    On garde les réglages utilisateur déjà présents
        %    (roitype, scale, etc.) et on met à jour uniquement ce qui est spécifique
        %    aux nouveaux fichiers : folder, files, frames globales...
        %
        %    projectPath reste storePath
        app.parsedData.projectPath = storePath;

        % h) Fusion du champ 'files'
        if isfield(app.parsedData,'files') && ~isempty(app.parsedData.files)
            oldFiles = app.parsedData.files;
        else
            oldFiles = {};
        end
        % newParsed.files peut être string, char, ou cell -> on normalise en cell
        if isfield(newParsed,'files') && ~isempty(newParsed.files)
            if iscell(newParsed.files)
                newFilesList = newParsed.files;
            else
                newFilesList = {newParsed.files};
            end
        else
            newFilesList = {};
        end
        app.parsedData.files = [oldFiles , newFilesList];

        % i) folder
        %    Attention : app.parsedData.folder doit pointer vers le dernier folder choisi ?
        %    On peut garder l'ancien dossier comme "racine projet" si déjà défini,
        %    sinon on prend celui du nouveau parse.
        if isfield(app.parsedData,'folder') && ~isempty(app.parsedData.folder)
            % garder l'ancien si déjà là, ne pas l'écraser systématiquement
            % sauf si c'était vide
            if isempty(app.parsedData.folder)
                app.parsedData.folder = folder;
            end
        else
            app.parsedData.folder = folder;
        end

        % j) numPositions et bornes temporelles globales (minFrame / maxFrame)
        app.parsedData.numPositions = numel(app.parsedData.positions);

        % recalcul minFrame / maxFrame globaux à partir des positions concaténées
        globalFrames = [];
        for pp = 1:numel(app.parsedData.positions)
            if isfield(app.parsedData.positions(pp),'frames') && ~isempty(app.parsedData.positions(pp).frames)
                globalFrames = [globalFrames(:); app.parsedData.positions(pp).frames(:)]; %#ok<AGROW>
            end
        end
        if ~isempty(globalFrames)
            app.parsedData.minFrame = min(globalFrames);
            app.parsedData.maxFrame = max(globalFrames);
        else
            app.parsedData.minFrame = NaN;
            app.parsedData.maxFrame = NaN;
        end

        % currentMinFrame / currentMaxFrame : on prend l'enveloppe globale
        app.parsedData.currentMinFrame = app.parsedData.minFrame;
        app.parsedData.currentMaxFrame = app.parsedData.maxFrame;

        % k) ne surtout pas toucher aux autres champs globaux
        %    (roitype, roibb, roipattern, scale, etc.) :
        %    on les laisse tels qu'ils étaient déjà dans app.parsedData.
        %    Si tu veux être très sûr qu'ils existent, tu peux faire des
        %    defaults ici mais SANS les écraser s'ils existent déjà.
        defaultGlobalFields = { ...
            'roitype','roibb','roipattern','maxframeloading','scale', ...
            'correctdrift','maxroidisplay','allpositions','advancedMode' ...
            };
        defaultValues = { ...
            'full',[],[],20,1,false,10,true,false ...
            };
        for df = 1:numel(defaultGlobalFields)
            fld = defaultGlobalFields{df};
            if ~isfield(app.parsedData,fld) || isempty(app.parsedData.(fld))
                app.parsedData.(fld) = defaultValues{df};
            end
        end

    end % if isempty(app.parsedData) else

    % 5. Réinitialiser l'option "invert frames/positions" (ton comportement actuel)
    app.InvertframesandpositionsCheckBox.Value = false;

    % 6. Mettre à jour l'IHM
    app.PathLabel.Text = folder;
    app.InfoLabel.Text = [num2str(numel(app.parsedData.positions)) ' Positions '];

    % Mets à jour la variable de base (debug convenience)
  %  assignin('base', 'parsedData', app.parsedData);

    % Rafraîchir tables / sliders / preview
    app.updatePositionTable;

    d.Value = 1;
    pause(0.2);
    close(d);





        end

        % Value changed function: FramesSlider_2
        function FramesSlider_2ValueChanged(app, event)
            value = app.FramesSlider_2.Value;
            app.FramesSlider_2.Value = round(app.FramesSlider_2.Value);
            updatePreview(app);

        end

        % Value changed function: ChannelSlider
        function ChannelSliderValueChanged(app, event)
            value = app.ChannelSlider.Value;
            app.ChannelSlider.Value = round(app.ChannelSlider.Value);
            updatePreview(app);

        end

        % Value changed function: PositionSlider
        function PositionSliderValueChanged(app, event)
            value = app.PositionSlider.Value;
            app.PositionSlider.Value = round(app.PositionSlider.Value);
            updatePreview(app);

        end

        % Button down function: PreviewTab
        function PreviewTabButtonDown(app, event)
            updatePreview(app);
        end

        % Key press function: LoadingAppUIFigure
        function LoadingAppUIFigureKeyPress(app, event)
            key = event.Key;
            % Gestion des flèches gauche et droite pour faire défiler les frames.
            switch event.Key
                case 'leftarrow'
                    newVal = max(app.FramesSlider_2.Limits(1), round(app.FramesSlider_2.Value) - 1);
                    app.FramesSlider_2.Value = newVal;
                    updatePreview(app);
                case 'rightarrow'
                    newVal = min(app.FramesSlider_2.Limits(2), round(app.FramesSlider_2.Value) + 1);
                    app.FramesSlider_2.Value = newVal;
                    updatePreview(app);
            end
        end

        % Selection changed function: ROIssettingsButtonGroup
        function ROIssettingsButtonGroupSelectionChanged(app, event)
            % Récupérer le bouton radio sélectionné
            selectedButton = app.ROIssettingsButtonGroup.SelectedObject;
            disp(['ROI mode sélectionné: ' selectedButton.Text]);


            switch selectedButton.Text
                case 'Custom ROIs'
                    app.parsedData.roitype='custom';

                    app.CustomROIparametersPanel.Visible="on";
                    app.parsedData.roibb=[];

                case 'Divide frame into'
                    app.parsedData.roitype='divide';
                    app.CustomROIparametersPanel.Visible="off";

                    for i=1:numel(app.parsedData.positions)
                        app.parsedData.positions(i).roibb=[];
                    end

                case 'Full frame ROIs'
                    app.parsedData.roitype='full';
                    app.CustomROIparametersPanel.Visible="off";

                    for i=1:numel(app.parsedData.positions)
                        app.parsedData.positions(i).roibb=[];
                    end
            end

            % Forcer une mise à jour de la prévisualisation (même si les indices n'ont pas changé)
            updatePreview(app, true);

        end

        % Value changed function: ROIDivide
        function ROIDivideValueChanged(app, event)
            value = app.ROIDivide.Value;
            disp(['ROIDivide value changed: ' num2str(value)]);
            updatePreview(app, true);

        end

        % Button pushed function: DetectROIsincurrentposButton
        function DetectROIsincurrentposButtonPushed(app, event)

            % Déterminer la position actuellement affichée
            if ~isempty(app.UIPositionTable.Selection)
                currentPos = app.UIPositionTable.Selection(1);
            else
                currentPos = 1;
            end

            % Vérifier que le pattern custom est défini dans parsedData.roipattern.
            if ~isfield(app.parsedData, 'roipattern') || isempty(app.parsedData.roipattern)
                uialert(app.LoadingAppUIFigure, 'Veuillez définir un pattern de ROI custom.', 'Erreur');
                return;
            end
            pattern = app.parsedData.roipattern;
            thr = app.ThresholdEditField.Value;

            if isempty(app.hPreview) || ~ishandle(app.hPreview)
                uialert(app.LoadingAppUIFigure, 'Aucune image affichée.', 'Erreur');
                return;
            end
            img = get(app.hPreview, 'CData');
            if isempty(img)
                uialert(app.LoadingAppUIFigure, 'L''image affichée est vide.', 'Erreur');
                return;
            end

            % Créer une progress bar pour la détection
            d = uiprogressdlg(app.LoadingAppUIFigure, 'Title', 'Please Wait', ...
                'Message', ['Detecting ROIs for position ' num2str(currentPos) '...'], 'Indeterminate', 'on');
            drawnow;  % S'assurer que la progress bar apparaît
            [detPositions, scores] = loadData_findTraps(img, pattern, thr);
            n = size(detPositions, 1);
            d.Message=['Found : '  num2str(n)  ' ROIs in image for position ' num2str(currentPos)];
            d.Value = 1;
            pause(0.4);
            close(d);

            if isempty(detPositions)
                uialert(app.LoadingAppUIFigure, 'Aucune ROI détectée.', 'Information');
                return;
            end

            % Convertir les coordonnées retournées par findTraps au format [left, bottom, width, height].
            % Ici, on suppose que findTraps renvoie [miney, maxey, minex, maxex] pour chaque ROI.

            rois = zeros(n, 4);
            for i = 1:n
                miney = detPositions(i,1);
                maxey = detPositions(i,2);
                minex = detPositions(i,3);
                maxex = detPositions(i,4);
                rois(i,:) = [minex, miney, maxex - minex, maxey - miney];
            end



            % Stocker les ROIs détectées dans la position courante
            app.parsedData.positions(currentPos).roibb = rois;

            % % Mettre à jour la cellule correspondante dans app.UIPositionTable.
            % % On suppose ici que la 4ème colonne affiche le nombre de ROIs détectées.
            % data = app.UIPositionTable.Data;
            % data{currentPos, 4} = num2str(size(rois, 1));
            % app.UIPositionTable.Data = data;

            % Forcer la mise à jour de l'affichage pour redessiner les ROIs (loadData_preview affichera les patchs magenta)
            updatePreview(app, true);

        end

        % Button pushed function: DetectROIsinallpositionsButton
        function DetectROIsinallpositionsButtonPushed(app, event)
            % Vérifier que le pattern custom est défini globalement
            if ~isfield(app.parsedData, 'roipattern') || isempty(app.parsedData.roipattern)
                uialert(app.LoadingAppUIFigure, 'Veuillez définir un pattern de ROI custom.', 'Erreur');
                return;
            end
            pattern = app.parsedData.roipattern;

            thr = app.ThresholdEditField.Value;

            % Récupérer les indices des positions sélectionnées dans la table.
            if isempty(app.UIPositionTable.Selection)
                posIndices = 1:numel(app.parsedData.positions);
            else
                posIndices = app.UIPositionTable.Selection;
            end

            posIndices

            % Créer une progress bar
            d = uiprogressdlg(app.LoadingAppUIFigure, 'Title', 'Please Wait', ...
                'Message', 'Detecting ROIs in all selected positions...', 'Indeterminate', 'on');
            drawnow;

            % Pour chaque position sélectionnée
            for idx = 1:length(posIndices)

                idx
                posIndex = posIndices(idx);
                posData = app.parsedData.positions(posIndex);
                % Utiliser par exemple le premier canal et la première frame pour la détection.
                if isempty(posData.channelsDir) || numel(posData.channelsDir) < 1
                    continue;
                end
                channelFiles = posData.channelsDir{1};
                if isempty(channelFiles)
                    continue;
                end
                effectiveFrame = 1;
                fileDetail = channelFiles(effectiveFrame);
                filePath = fullfile(fileDetail.folder, fileDetail.name);
                try
                    img = imread(filePath);
                catch ME
                    warning('Erreur lors de la lecture du fichier %s: %s', filePath, ME.message);
                    continue;
                end
                % Ajuster le contraste
                if ~isempty(img)
                    if size(img,3)==1
                        lims = stretchlim(img, [0.01 0.99]);
                        img = imadjust(img, lims, []);
                    elseif size(img,3)==3
                        for c = 1:3
                            lims = stretchlim(img(:,:,c), [0.01 0.99]);
                            img(:,:,c) = imadjust(img(:,:,c), lims, []);
                        end
                    end
                end

                % Détection avec loadData_findTraps (qui utilise normxcorr2, etc.)
                [detPositions, scores] = loadData_findTraps(img, pattern, thr);

                n = size(detPositions, 1);
                d.Message=['Found : '  num2str(n)  ' ROIs in image for position ' num2str(idx) ' / ' num2str(length(posIndices))];
                %d.Value = 1;
                pause(0.2);
                %close(d);

                if isempty(detPositions)
                    app.parsedData.positions(posIndex).roibb = [];
                else
                    % Convertir les coordonnées retournées par loadData_findTraps
                    % Supposons que findTraps retourne [miney, maxey, minex, maxex] pour chaque ROI.
                    n = size(detPositions, 1);
                    rois = zeros(n, 4);
                    for i = 1:n
                        miney = detPositions(i,1);
                        maxey = detPositions(i,2);
                        minex = detPositions(i,3);
                        maxex = detPositions(i,4);
                        rois(i,:) = [minex, miney, maxex - minex, maxey - miney];
                    end
                    % Stocker dans la position courante
                    app.parsedData.positions(posIndex).roibb = rois;
                end
                % Mettre à jour la progress bar
                d.Value = idx / length(posIndices);
                drawnow;
            end
            pause(0.1);
            close(d);

            % Forcer la mise à jour de l'affichage pour la position actuellement sélectionnée
            if ~isempty(app.UIPositionTable.Selection)
                currentPos = app.UIPositionTable.Selection(1);
            else
                currentPos = 1;
            end
            updatePreview(app, true);


        end

        % Value changed function: DimensionsEditField
        function DimensionsEditFieldValueChanged(app, event)
            % Attendre une chaîne de 4 nombres séparés par des espaces : left bottom width height
            newText = app.DimensionsEditField.Value;
            vals = str2num(newText);  %#ok<ST2NM>
            if numel(vals) ~= 4
                uialert(app.LoadingAppUIFigure, 'Veuillez entrer 4 valeurs: left bottom width height', 'Erreur');
                return;
            end
            % Mettre à jour le rectangle custom s'il existe
            if isprop(app, 'hCustomROI') && ~isempty(app.hCustomROI) && isvalid(app.hCustomROI)
                app.hCustomROI.Position = vals;
            else
                % Si aucun rectangle n'existe et que Custom ROIs est sélectionné, le créer avec drawrectangle

                app.hCustomROI = drawrectangle(app.UIAxes, 'Position', vals, 'Color', 'b');
                % Ajouter un listener pour mettre à jour la ROI lors de son déplacement
                addlistener(app.hCustomROI, 'ROIMoved', @(src, evt) customROIPositionChanged(app, src.Position));
            end
            % Mettre à jour parsedData
            app.parsedData.roibb = vals;
            img = get(app.hPreview, 'CData');
            if ~isempty(img)
                app.parsedData.roipattern = imcrop(img, vals);
            end
            updatePreview(app, true);

        end

        % Value changed function: ThresholdEditField
        function ThresholdEditFieldValueChanged(app, event)
            value = app.ThresholdEditField.Value;

        end

        % Value changed function: MaxframeloadinginmemoryEditField
        function MaxframeloadinginmemoryEditFieldValueChanged(app, event)
            value = app.MaxframeloadinginmemoryEditField.Value;
            app.parsedData.maxframeloading=value;

        end

        % Value changed function: correctROIdriftCheckBox
        function correctROIdriftCheckBoxValueChanged(app, event)
            value = app.correctROIdriftCheckBox.Value;
            app.parsedData.correctdrift=false;
        end

        % Value changed function: ZoomButton
        function ZoomButtonValueChanged(app, event)
            if app.ZoomButton.Value
                % Activer le mode zoom sur la figure de prévisualisation
                zoom(app.hPreviewFigure, 'on');
            else
                % Désactiver le mode zoom
                zoom(app.hPreviewFigure, 'off');
            end

        end

        % Value changing function: ZoomfactorSlider
        function ZoomfactorSliderValueChanging(app, event)
            % Récupérer la valeur du slider (par exemple de 1 [zoom d'origine] à 10)
            zoomFactor = event.Value;

            % Obtenir l'axe de la figure de prévisualisation
            ax = app.hPreviewAxes;

            % Stocker les limites initiales si ce n'est pas déjà fait
            if ~isprop(app, 'OriginalXLim') || isempty(app.OriginalXLim)
                app.OriginalXLim = get(ax, 'XLim');
                app.OriginalYLim = get(ax, 'YLim');
            end
            origXLim = app.OriginalXLim;
            origYLim = app.OriginalYLim;

            % Calculer le centre de l'image
            centerX = mean(origXLim);
            centerY = mean(origYLim);

            % Calculer les nouvelles limites en fonction du facteur de zoom
            halfWidth = diff(origXLim) / (2 * zoomFactor);
            halfHeight = diff(origYLim) / (2 * zoomFactor);
            newXLim = [centerX - halfWidth, centerX + halfWidth];
            newYLim = [centerY - halfHeight, centerY + halfHeight];

            % Mettre à jour les limites de l'axe pour appliquer le zoom
            set(ax, 'XLim', newXLim, 'YLim', newYLim);

        end

        % Value changed function: MaxROIdisplayEditField
        function MaxROIdisplayEditFieldValueChanged(app, event)
            value = app.MaxROIdisplayEditField.Value;

            app.parsedData.maxroidisplay=value;
        end

        % Value changed function: applychangestoallpositionsCheckBox
        function applychangestoallpositionsCheckBoxValueChanged2(app, event)
            value = app.applychangestoallpositionsCheckBox.Value;
         %   app.allpositions=value;
        end

        % Close request function: LoadingAppUIFigure
        function LoadingAppUIFigureCloseRequest(app, event)
        
                 if ~isempty(app.mainApp)
               app.mainApp.shallowObj=[];
            uiresume(app.mainApp.LifespanizerUIFigure);
                 end

           if ~isempty(app.hPreviewFigure) && isvalid(app.hPreviewFigure)
                delete(app.hPreviewFigure);
            end
            delete(app);  % Ferme l'application

        end

        % Value changed function: ROIsettingsCheckBox
        function ROIsettingsCheckBoxValueChanged(app, event)
            value = app.ROIsettingsCheckBox.Value;
    
    if value
        % Ajouter l'onglet ROIs s'il n'est pas déjà visible
        if isempty(app.ROIsTab.Parent)
            app.ROIsTab.Parent = app.TabGroup;
        end
    else
        % Retirer l'onglet ROIs
        app.ROIsTab.Parent = [];
    end
            
        end

        % Value changed function: PreviewCheckBox
        function PreviewCheckBoxValueChanged(app, event)
              value = app.PreviewCheckBox.Value;
    
    if value
        % Ajouter l'onglet Preview s'il n'est pas déjà visible
        if isempty(app.PreviewTab.Parent)
            app.PreviewTab.Parent = app.TabGroup;
        end
    else
        % Retirer l'onglet Preview
        app.PreviewTab.Parent = [];
    end
            
        end

        % Value changed function: ProjectsettingsCheckBox
        function ProjectsettingsCheckBoxValueChanged(app, event)
            value = app.ProjectsettingsCheckBox.Value;
         
    
    if value
        % Ajouter l'onglet Project s'il n'est pas déjà visible
        if isempty(app.ProjectTab.Parent)
            app.ProjectTab.Parent = app.TabGroup;
        end
    else
        % Retirer l'onglet Project
        app.ProjectTab.Parent = [];
    end
        end

        % Button down function: ROIsTab
        function ROIsTabButtonDown(app, event)
            updatePreview(app);
        end

        % Value changed function: OutputprojectfileEditField
        function OutputprojectfileEditFieldValueChanged(app, event)
            value = app.OutputprojectfileEditField.Value;
            app.parsedData.projectPath=app.OutputprojectfileEditField.Value;
            %   assignin('base', 'parsedData', app.parsedData);
            
        end

        % Value changed function: ScaleEditField
        function ScaleEditFieldValueChanged(app, event)
            value = app.ScaleEditField.Value;

            app.parsedData.scale=value;
            
        end

        % Button pushed function: SelectallpositionsButton
        function SelectallpositionsButtonPushed(app, event)
                % Nombre total de positions
    nPos = numel(app.parsedData.positions);
    % Récupérer les données actuelles de la table
    tableData = app.UIPositionTable.Data;
    
    % Parcourir toutes les positions et mettre à jour le champ 'selected'
    for i = 1:nPos
        app.parsedData.positions(i).selected = true;
        tableData{i, 1} = true;  % Mise à jour de la colonne "Select"
    end
    % Réaffecter les nouvelles données à la table
    app.UIPositionTable.Data = tableData;
        end

        % Button pushed function: DeselectallpositionsButton
        function DeselectallpositionsButtonPushed(app, event)
               nPos = numel(app.parsedData.positions);
    tableData = app.UIPositionTable.Data;
    
    for i = 1:nPos
        app.parsedData.positions(i).selected = false;
        tableData{i, 1} = false;  % Mise à jour de la colonne "Select"
    end
    app.UIPositionTable.Data = tableData;
        end

        % Button pushed function: selectextractROIsforallButton
        function selectextractROIsforallButtonPushed(app, event)
             nPos = numel(app.parsedData.positions);
    tableData = app.UIPositionTable.Data;
    
    for i = 1:nPos
        app.parsedData.positions(i).extractROI = true;
        tableData{i, 5} = true;  % Mise à jour de la colonne "extract ROI"
    end
    app.UIPositionTable.Data = tableData;
        end

        % Button pushed function: deselectextractROIsforallButton
        function deselectextractROIsforallButtonPushed(app, event)
            nPos = numel(app.parsedData.positions);
    tableData = app.UIPositionTable.Data;
    
    for i = 1:nPos
        app.parsedData.positions(i).extractROI = false;
        tableData{i, 5} = false;  % Mise à jour de la colonne "extract ROI"
    end
    app.UIPositionTable.Data = tableData;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create LoadingAppUIFigure and hide until all components are created
            app.LoadingAppUIFigure = uifigure('Visible', 'off');
            app.LoadingAppUIFigure.Position = [100 100 658 782];
            app.LoadingAppUIFigure.Name = 'LoadingApp';
            app.LoadingAppUIFigure.CloseRequestFcn = createCallbackFcn(app, @LoadingAppUIFigureCloseRequest, true);
            app.LoadingAppUIFigure.KeyPressFcn = createCallbackFcn(app, @LoadingAppUIFigureKeyPress, true);

            % Create CancelButton
            app.CancelButton = uibutton(app.LoadingAppUIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Position = [420 10 230 28];
            app.CancelButton.Text = 'Cancel';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.LoadingAppUIFigure);
            app.TabGroup.Position = [10 46 640 723];

            % Create ImagesTab
            app.ImagesTab = uitab(app.TabGroup);
            app.ImagesTab.Title = 'Images';

            % Create ChoosefolderButton
            app.ChoosefolderButton = uibutton(app.ImagesTab, 'push');
            app.ChoosefolderButton.ButtonPushedFcn = createCallbackFcn(app, @ChoosefolderButtonPushed, true);
            app.ChoosefolderButton.Position = [13 643 273 43];
            app.ChoosefolderButton.Text = 'Choose folder....';

            % Create InvertframesandpositionsCheckBox
            app.InvertframesandpositionsCheckBox = uicheckbox(app.ImagesTab);
            app.InvertframesandpositionsCheckBox.ValueChangedFcn = createCallbackFcn(app, @InvertframesandpositionsCheckBoxValueChanged, true);
            app.InvertframesandpositionsCheckBox.Text = 'Invert frames and positions';
            app.InvertframesandpositionsCheckBox.Position = [468 563 165 22];

            % Create ChannelsPanel
            app.ChannelsPanel = uipanel(app.ImagesTab);
            app.ChannelsPanel.Title = 'Channels';
            app.ChannelsPanel.Visible = 'off';
            app.ChannelsPanel.Position = [13 4 615 270];

            % Create UIChannelTable
            app.UIChannelTable = uitable(app.ChannelsPanel);
            app.UIChannelTable.ColumnName = {'Select'; 'File Chan. Name'; 'User Name'; 'Frequency'; 'Size'};
            app.UIChannelTable.RowName = {};
            app.UIChannelTable.ColumnEditable = [true false true];
            app.UIChannelTable.CellEditCallback = createCallbackFcn(app, @UIChannelTableCellEdit, true);
            app.UIChannelTable.Position = [13 86 589 153];

            % Create FramesSliderLabel
            app.FramesSliderLabel = uilabel(app.ChannelsPanel);
            app.FramesSliderLabel.HorizontalAlignment = 'right';
            app.FramesSliderLabel.Position = [16 53 46 22];
            app.FramesSliderLabel.Text = 'Frames';

            % Create FramesSlider
            app.FramesSlider = uislider(app.ChannelsPanel, 'range');
            app.FramesSlider.ValueChangingFcn = createCallbackFcn(app, @FramesSliderValueChanging, true);
            app.FramesSlider.Position = [84 62 414 3];

            % Create FramesField
            app.FramesField = uieditfield(app.ChannelsPanel, 'text');
            app.FramesField.ValueChangedFcn = createCallbackFcn(app, @FramesFieldValueChanged, true);
            app.FramesField.Position = [519 52 82 22];

            % Create applychangestoallpositionsCheckBox
            app.applychangestoallpositionsCheckBox = uicheckbox(app.ChannelsPanel);
            app.applychangestoallpositionsCheckBox.ValueChangedFcn = createCallbackFcn(app, @applychangestoallpositionsCheckBoxValueChanged2, true);
            app.applychangestoallpositionsCheckBox.Text = 'apply changes to all positions';
            app.applychangestoallpositionsCheckBox.Position = [18 5 179 22];
            app.applychangestoallpositionsCheckBox.Value = true;

            % Create PositionsPanel
            app.PositionsPanel = uipanel(app.ImagesTab);
            app.PositionsPanel.Title = 'Positions';
            app.PositionsPanel.Visible = 'off';
            app.PositionsPanel.Position = [15 280 613 251];

            % Create UIPositionTable
            app.UIPositionTable = uitable(app.PositionsPanel);
            app.UIPositionTable.ColumnName = {'Select'; 'Position'; 'User Name'; '# ROIs'; 'extract ROI'};
            app.UIPositionTable.RowName = {};
            app.UIPositionTable.ColumnEditable = [true false true false true];
            app.UIPositionTable.CellEditCallback = createCallbackFcn(app, @UIPositionTableCellEdit, true);
            app.UIPositionTable.SelectionChangedFcn = createCallbackFcn(app, @UIPositionTableSelectionChanged, true);
            app.UIPositionTable.Tooltip = {'Select the position that you want to import in the project. For each position, seelct whether to extract ROIs or not'};
            app.UIPositionTable.Position = [9 10 596 213];

            % Create ORLabel
            app.ORLabel = uilabel(app.ImagesTab);
            app.ORLabel.Position = [312 653 25 22];
            app.ORLabel.Text = 'OR';

            % Create ChoosefilesButton
            app.ChoosefilesButton = uibutton(app.ImagesTab, 'push');
            app.ChoosefilesButton.ButtonPushedFcn = createCallbackFcn(app, @ChoosefilesButtonPushed, true);
            app.ChoosefilesButton.Position = [359 643 265 43];
            app.ChoosefilesButton.Text = 'Choose files...';

            % Create PathLabel
            app.PathLabel = uilabel(app.ImagesTab);
            app.PathLabel.Position = [22 617 606 22];
            app.PathLabel.Text = 'Path';

            % Create InfoLabel
            app.InfoLabel = uilabel(app.ImagesTab);
            app.InfoLabel.Position = [24 589 603 22];
            app.InfoLabel.Text = 'Info';

            % Create PositionssettingsCheckBox
            app.PositionssettingsCheckBox = uicheckbox(app.ImagesTab);
            app.PositionssettingsCheckBox.ValueChangedFcn = createCallbackFcn(app, @PositionssettingsCheckBoxValueChanged, true);
            app.PositionssettingsCheckBox.Text = 'Positions settings';
            app.PositionssettingsCheckBox.Position = [23 566 115 22];

            % Create ProjectsettingsCheckBox
            app.ProjectsettingsCheckBox = uicheckbox(app.ImagesTab);
            app.ProjectsettingsCheckBox.ValueChangedFcn = createCallbackFcn(app, @ProjectsettingsCheckBoxValueChanged, true);
            app.ProjectsettingsCheckBox.Text = 'Project settings';
            app.ProjectsettingsCheckBox.Position = [163 566 104 22];

            % Create PreviewCheckBox
            app.PreviewCheckBox = uicheckbox(app.ImagesTab);
            app.PreviewCheckBox.ValueChangedFcn = createCallbackFcn(app, @PreviewCheckBoxValueChanged, true);
            app.PreviewCheckBox.Text = 'Preview';
            app.PreviewCheckBox.Position = [285 566 65 22];

            % Create ROIsettingsCheckBox
            app.ROIsettingsCheckBox = uicheckbox(app.ImagesTab);
            app.ROIsettingsCheckBox.ValueChangedFcn = createCallbackFcn(app, @ROIsettingsCheckBoxValueChanged, true);
            app.ROIsettingsCheckBox.Text = 'ROI settings';
            app.ROIsettingsCheckBox.Position = [374 565 88 22];

            % Create SelectallpositionsButton
            app.SelectallpositionsButton = uibutton(app.ImagesTab, 'push');
            app.SelectallpositionsButton.ButtonPushedFcn = createCallbackFcn(app, @SelectallpositionsButtonPushed, true);
            app.SelectallpositionsButton.Position = [19 536 114 23];
            app.SelectallpositionsButton.Text = 'Select all positions';

            % Create DeselectallpositionsButton
            app.DeselectallpositionsButton = uibutton(app.ImagesTab, 'push');
            app.DeselectallpositionsButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectallpositionsButtonPushed, true);
            app.DeselectallpositionsButton.Position = [142 536 128 23];
            app.DeselectallpositionsButton.Text = 'Deselect all positions';

            % Create selectextractROIsforallButton
            app.selectextractROIsforallButton = uibutton(app.ImagesTab, 'push');
            app.selectextractROIsforallButton.ButtonPushedFcn = createCallbackFcn(app, @selectextractROIsforallButtonPushed, true);
            app.selectextractROIsforallButton.Position = [280 536 149 23];
            app.selectextractROIsforallButton.Text = 'select extract ROIs for all';

            % Create deselectextractROIsforallButton
            app.deselectextractROIsforallButton = uibutton(app.ImagesTab, 'push');
            app.deselectextractROIsforallButton.ButtonPushedFcn = createCallbackFcn(app, @deselectextractROIsforallButtonPushed, true);
            app.deselectextractROIsforallButton.Position = [436 536 162 23];
            app.deselectextractROIsforallButton.Text = 'deselect extract ROIs for all';

            % Create ProjectTab
            app.ProjectTab = uitab(app.TabGroup);
            app.ProjectTab.Title = 'Project';

            % Create OutputprojectfileEditFieldLabel
            app.OutputprojectfileEditFieldLabel = uilabel(app.ProjectTab);
            app.OutputprojectfileEditFieldLabel.HorizontalAlignment = 'right';
            app.OutputprojectfileEditFieldLabel.Position = [11 666 102 22];
            app.OutputprojectfileEditFieldLabel.Text = 'Output project file:';

            % Create OutputprojectfileEditField
            app.OutputprojectfileEditField = uieditfield(app.ProjectTab, 'text');
            app.OutputprojectfileEditField.ValueChangedFcn = createCallbackFcn(app, @OutputprojectfileEditFieldValueChanged, true);
            app.OutputprojectfileEditField.Position = [130 666 383 22];

            % Create SetProjectButton
            app.SetProjectButton = uibutton(app.ProjectTab, 'push');
            app.SetProjectButton.ButtonPushedFcn = createCallbackFcn(app, @SetProjectButtonPushed, true);
            app.SetProjectButton.Position = [532 666 58 22];
            app.SetProjectButton.Text = 'Set...';

            % Create PreviewTab
            app.PreviewTab = uitab(app.TabGroup);
            app.PreviewTab.Title = 'Preview';
            app.PreviewTab.ButtonDownFcn = createCallbackFcn(app, @PreviewTabButtonDown, true);

            % Create FramesSlider_2Label
            app.FramesSlider_2Label = uilabel(app.PreviewTab);
            app.FramesSlider_2Label.HorizontalAlignment = 'right';
            app.FramesSlider_2Label.Position = [21 552 46 22];
            app.FramesSlider_2Label.Text = 'Frames';

            % Create FramesSlider_2
            app.FramesSlider_2 = uislider(app.PreviewTab);
            app.FramesSlider_2.ValueChangedFcn = createCallbackFcn(app, @FramesSlider_2ValueChanged, true);
            app.FramesSlider_2.Position = [88 561 533 3];

            % Create ChannelSliderLabel
            app.ChannelSliderLabel = uilabel(app.PreviewTab);
            app.ChannelSliderLabel.HorizontalAlignment = 'right';
            app.ChannelSliderLabel.Position = [15 601 50 22];
            app.ChannelSliderLabel.Text = 'Channel';

            % Create ChannelSlider
            app.ChannelSlider = uislider(app.PreviewTab);
            app.ChannelSlider.ValueChangedFcn = createCallbackFcn(app, @ChannelSliderValueChanged, true);
            app.ChannelSlider.Position = [86 612 533 3];

            % Create PositionSliderLabel
            app.PositionSliderLabel = uilabel(app.PreviewTab);
            app.PositionSliderLabel.HorizontalAlignment = 'right';
            app.PositionSliderLabel.Position = [16 656 48 22];
            app.PositionSliderLabel.Text = 'Position';

            % Create PositionSlider
            app.PositionSlider = uislider(app.PreviewTab);
            app.PositionSlider.ValueChangedFcn = createCallbackFcn(app, @PositionSliderValueChanged, true);
            app.PositionSlider.Position = [85 665 534 3];

            % Create ZoomButton
            app.ZoomButton = uibutton(app.PreviewTab, 'state');
            app.ZoomButton.ValueChangedFcn = createCallbackFcn(app, @ZoomButtonValueChanged, true);
            app.ZoomButton.Text = 'Zoom';
            app.ZoomButton.Position = [24 473 102 33];

            % Create ZoomfactorSliderLabel
            app.ZoomfactorSliderLabel = uilabel(app.PreviewTab);
            app.ZoomfactorSliderLabel.HorizontalAlignment = 'right';
            app.ZoomfactorSliderLabel.Position = [146 483 69 22];
            app.ZoomfactorSliderLabel.Text = 'Zoom factor';

            % Create ZoomfactorSlider
            app.ZoomfactorSlider = uislider(app.PreviewTab);
            app.ZoomfactorSlider.Limits = [1 5];
            app.ZoomfactorSlider.MajorTicks = [1 5];
            app.ZoomfactorSlider.ValueChangingFcn = createCallbackFcn(app, @ZoomfactorSliderValueChanging, true);
            app.ZoomfactorSlider.Position = [236 492 150 3];
            app.ZoomfactorSlider.Value = 1;

            % Create ROIsTab
            app.ROIsTab = uitab(app.TabGroup);
            app.ROIsTab.Title = 'ROIs';
            app.ROIsTab.ButtonDownFcn = createCallbackFcn(app, @ROIsTabButtonDown, true);

            % Create ROIssettingsButtonGroup
            app.ROIssettingsButtonGroup = uibuttongroup(app.ROIsTab);
            app.ROIssettingsButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ROIssettingsButtonGroupSelectionChanged, true);
            app.ROIssettingsButtonGroup.Title = 'ROIs settings';
            app.ROIssettingsButtonGroup.Position = [17 115 610 278];

            % Create FullframeROIsButton
            app.FullframeROIsButton = uiradiobutton(app.ROIssettingsButtonGroup);
            app.FullframeROIsButton.Text = 'Full frame ROIs';
            app.FullframeROIsButton.Position = [10 233 105 22];
            app.FullframeROIsButton.Value = true;

            % Create DivideframeintoButton
            app.DivideframeintoButton = uiradiobutton(app.ROIssettingsButtonGroup);
            app.DivideframeintoButton.Text = 'Divide frame into';
            app.DivideframeintoButton.Position = [9 208 112 22];

            % Create CustomROIsButton
            app.CustomROIsButton = uiradiobutton(app.ROIssettingsButtonGroup);
            app.CustomROIsButton.Text = 'Custom ROIs';
            app.CustomROIsButton.Position = [9 179 94 22];

            % Create ROIDivide
            app.ROIDivide = uieditfield(app.ROIssettingsButtonGroup, 'numeric');
            app.ROIDivide.ValueChangedFcn = createCallbackFcn(app, @ROIDivideValueChanged, true);
            app.ROIDivide.Position = [121 210 34 22];
            app.ROIDivide.Value = 3;

            % Create linesandcolumnsLabel
            app.linesandcolumnsLabel = uilabel(app.ROIssettingsButtonGroup);
            app.linesandcolumnsLabel.Position = [161 210 101 22];
            app.linesandcolumnsLabel.Text = 'lines and columns';

            % Create CustomROIparametersPanel
            app.CustomROIparametersPanel = uipanel(app.ROIssettingsButtonGroup);
            app.CustomROIparametersPanel.Title = 'Custom ROI parameters';
            app.CustomROIparametersPanel.Position = [11 12 588 156];

            % Create DimensionsEditFieldLabel
            app.DimensionsEditFieldLabel = uilabel(app.CustomROIparametersPanel);
            app.DimensionsEditFieldLabel.HorizontalAlignment = 'right';
            app.DimensionsEditFieldLabel.Position = [8 106 71 22];
            app.DimensionsEditFieldLabel.Text = 'Dimensions:';

            % Create DimensionsEditField
            app.DimensionsEditField = uieditfield(app.CustomROIparametersPanel, 'text');
            app.DimensionsEditField.ValueChangedFcn = createCallbackFcn(app, @DimensionsEditFieldValueChanged, true);
            app.DimensionsEditField.Position = [91 106 128 22];

            % Create DetectROIsincurrentposButton
            app.DetectROIsincurrentposButton = uibutton(app.CustomROIparametersPanel, 'push');
            app.DetectROIsincurrentposButton.ButtonPushedFcn = createCallbackFcn(app, @DetectROIsincurrentposButtonPushed, true);
            app.DetectROIsincurrentposButton.Position = [7 50 154 23];
            app.DetectROIsincurrentposButton.Text = 'Detect ROIs in current pos';

            % Create DetectROIsinallpositionsButton
            app.DetectROIsinallpositionsButton = uibutton(app.CustomROIparametersPanel, 'push');
            app.DetectROIsinallpositionsButton.ButtonPushedFcn = createCallbackFcn(app, @DetectROIsinallpositionsButtonPushed, true);
            app.DetectROIsinallpositionsButton.Position = [166 50 159 23];
            app.DetectROIsinallpositionsButton.Text = 'Detect ROIs in all positions';

            % Create ThresholdEditFieldLabel
            app.ThresholdEditFieldLabel = uilabel(app.CustomROIparametersPanel);
            app.ThresholdEditFieldLabel.HorizontalAlignment = 'right';
            app.ThresholdEditFieldLabel.Position = [21 79 58 22];
            app.ThresholdEditFieldLabel.Text = 'Threshold';

            % Create ThresholdEditField
            app.ThresholdEditField = uieditfield(app.CustomROIparametersPanel, 'numeric');
            app.ThresholdEditField.ValueChangedFcn = createCallbackFcn(app, @ThresholdEditFieldValueChanged, true);
            app.ThresholdEditField.Position = [91 80 70 22];
            app.ThresholdEditField.Value = 0.5;

            % Create ROIextractionparametersPanel
            app.ROIextractionparametersPanel = uipanel(app.ROIsTab);
            app.ROIextractionparametersPanel.Title = 'ROI extraction parameters';
            app.ROIextractionparametersPanel.Position = [17 409 606 203];

            % Create correctROIdriftCheckBox
            app.correctROIdriftCheckBox = uicheckbox(app.ROIextractionparametersPanel);
            app.correctROIdriftCheckBox.ValueChangedFcn = createCallbackFcn(app, @correctROIdriftCheckBoxValueChanged, true);
            app.correctROIdriftCheckBox.Text = 'correct ROI drift';
            app.correctROIdriftCheckBox.Position = [210 151 107 22];

            % Create MaxframeloadinginmemoryLabel
            app.MaxframeloadinginmemoryLabel = uilabel(app.ROIextractionparametersPanel);
            app.MaxframeloadinginmemoryLabel.HorizontalAlignment = 'right';
            app.MaxframeloadinginmemoryLabel.Position = [27 121 166 22];
            app.MaxframeloadinginmemoryLabel.Text = 'Max frame loading in memory:';

            % Create MaxframeloadinginmemoryEditField
            app.MaxframeloadinginmemoryEditField = uieditfield(app.ROIextractionparametersPanel, 'numeric');
            app.MaxframeloadinginmemoryEditField.ValueChangedFcn = createCallbackFcn(app, @MaxframeloadinginmemoryEditFieldValueChanged, true);
            app.MaxframeloadinginmemoryEditField.Position = [208 121 100 22];
            app.MaxframeloadinginmemoryEditField.Value = 20;

            % Create MaxROIdisplayEditFieldLabel
            app.MaxROIdisplayEditFieldLabel = uilabel(app.ROIextractionparametersPanel);
            app.MaxROIdisplayEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxROIdisplayEditFieldLabel.Position = [94 85 100 22];
            app.MaxROIdisplayEditFieldLabel.Text = 'Max #ROI display';

            % Create MaxROIdisplayEditField
            app.MaxROIdisplayEditField = uieditfield(app.ROIextractionparametersPanel, 'numeric');
            app.MaxROIdisplayEditField.ValueChangedFcn = createCallbackFcn(app, @MaxROIdisplayEditFieldValueChanged, true);
            app.MaxROIdisplayEditField.Position = [209 85 100 22];
            app.MaxROIdisplayEditField.Value = 10;

            % Create ScaleEditFieldLabel
            app.ScaleEditFieldLabel = uilabel(app.ROIextractionparametersPanel);
            app.ScaleEditFieldLabel.HorizontalAlignment = 'right';
            app.ScaleEditFieldLabel.Position = [158 49 35 22];
            app.ScaleEditFieldLabel.Text = 'Scale';

            % Create ScaleEditField
            app.ScaleEditField = uieditfield(app.ROIextractionparametersPanel, 'numeric');
            app.ScaleEditField.ValueChangedFcn = createCallbackFcn(app, @ScaleEditFieldValueChanged, true);
            app.ScaleEditField.Position = [208 49 100 22];
            app.ScaleEditField.Value = 1;

            % Create GreenROIsindicateROIstobeaddedLabel
            app.GreenROIsindicateROIstobeaddedLabel = uilabel(app.ROIsTab);
            app.GreenROIsindicateROIstobeaddedLabel.Position = [23 667 484 22];
            app.GreenROIsindicateROIstobeaddedLabel.Text = 'Green ROIs indicate new ROIs to be added . Red ROIs indicaes ROIs that already exist.';

            % Create LoadButton
            app.LoadButton = uibutton(app.LoadingAppUIFigure, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);
            app.LoadButton.Position = [16 10 394 28];
            app.LoadButton.Text = 'Load';

            % Show the figure after all components are created
            app.LoadingAppUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = loadData(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.LoadingAppUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.LoadingAppUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.LoadingAppUIFigure)
        end
    end
end