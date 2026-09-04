classdef roiImporterGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        ImportROIsfromdiskButton        matlab.ui.control.Button
        SelectROIstoimportLabel         matlab.ui.control.Label
        ImportedROIsclassesmappingPanel  matlab.ui.container.Panel
        ClassesinthesourceROIEditField  matlab.ui.control.EditField
        ClassesinthesourceROIEditFieldLabel  matlab.ui.control.Label
        ClassesinthedestinationROIEditField  matlab.ui.control.EditField
        ClassesinthedestinationROIEditFieldLabel  matlab.ui.control.Label
        Preserveannotations             matlab.ui.control.CheckBox
        ImportedROIschannelnameselectionandmappingPanel  matlab.ui.container.Panel
        ApplymappingtoallFOVsCheckBox   matlab.ui.control.CheckBox
        ChannelMappingTable             matlab.ui.control.Table
        DeselectallButton               matlab.ui.control.Button
        SelectallButton                 matlab.ui.control.Button
        UITable                         matlab.ui.control.Table
        CancelButton                    matlab.ui.control.Button
        ProceedButton                   matlab.ui.control.Button
    end


    properties (Access = private)
        Data % Description
        channelMap = {}
        channelMapEdited = false(1,0)
        lastEditedChannelMapIndex = 0
        displayedChannelMapIndex = 0
        globalChannelMap = []
    end

    methods (Access = private)


        function  displayChannels(app)
            classiObj=app.Data.mainApp.Data.classiObj;
            app.ImportedROIschannelnameselectionandmappingPanel.Enable="on";

            selection = app.UITable.Selection;

            if numel(selection)==0
                return
            end

            pixtable=selection(1,1);

            target=app.Data.target{pixtable};

            targetChannel=app.Data.targetChannel{pixtable};

            if numel(classiObj.channelName)
                app.sourceChannelList.Items= classiObj.channelName;

            else
                app.sourceChannelList.Items={};
                app.ImportedROIschannelnameselectionandmappingPanel.Enable="off";
            end

            if numel(app.sourceChannelList.Value)==0
                if numel(app.sourceChannelList.Items)
                    app.sourceChannelList.Value= app.sourceChannelList.Items{1};
                else
                    app.sourceChannelList.Value={};
                end
            end

            str=target.roi(1).display.channel;
            if numel(str)
                if ischar(str)
                    str={str};
                end
                app.sourceChannelList_2.Items=str;
            else
                app.sourceChannelList_2.Items={};
            end


            selectedChannel=find(matches(app.sourceChannelList.Items,app.sourceChannelList.Value));


            val={};

            if numel(targetChannel)~=0 && numel(targetChannel{1})==0
                pix=find(matches(str,app.sourceChannelList.Value));
                if numel(pix)
                    val=str{pix};
                else

                end
            else

                %aa=app.Data.targetChannel
                % selectedChannel
                if numel(selectedChannel)~=0
                    val=  app.Data.targetChannel{pixtable}{selectedChannel};
                end
            end
            if numel(val)==0
                val=app.sourceChannelList_2.Items{1};
            end

            if ischar(val)
                val={val};
            end

            if numel(val)
                app.sourceChannelList_2.Value=val;
                if numel(selectedChannel)
                    app.Data.targetChannel{pixtable}{selectedChannel}=app.sourceChannelList_2.Value;
                end
            end

            %             nrois=classiObj.roi;
            %             if nrois==1 && numel(classiObj.roi(1).id)==0
            %                 nrois=0;
            %             end
            %             if nrois==0

            % end
        end

        function  displayAnnotations(app)


            selection = app.UITable.Selection;

            if numel(selection)==0
                return
            end

            pix=selection(1,1);

            if numel(pix)==0
                return
            end
            %   dat = app.ChoosePositionClassiferDropDown.Value;
            %   pix=contains(app.Data.displaystr,dat);

            va=app.Data.varstr{pix};
            tmp=evalin('base',va);

            cla=false;

            if isa(tmp,'classi')
                aa=tmp.classes;

                if numel(aa)
                    cla=true;
                end

            end



            if isa(tmp,'classi')
                app.Preserveannotations.Enable='on';

                if app.Data.preserve{pix}==true
                    app.Preserveannotations.Value=true;
                else
                    app.Preserveannotations.Value=false;
                end
            else
                app.Preserveannotations.Enable='off';
                app.Preserveannotations.Value=false;
                app.Data.preserve{pix}=false;
            end

            value = app.Preserveannotations.Value;


            %  aa=tmp.classes

            if value && cla % preserve training
                app.ClassesinthedestinationROIEditField.Enable='on';
                app.ClassesinthesourceROIEditField.Enable='on';

                if  numel(app.Data.convert{pix})==0
                    str=[];
                    for i=1:numel(tmp.classes)
                        str=[str ' ' tmp.classes{i}];
                    end

                    str2=[];
                    for i=1:numel(app.Data.mainApp.Data.classiObj.classes)
                        str2=[str2 ' ' app.Data.mainApp.Data.classiObj.classes{i}];
                    end

                    app.ClassesinthesourceROIEditField.Value=str;
                    app.ClassesinthedestinationROIEditField.Value=str2;
                    app.Data.convert{pix}={str,str2};
                else
                    app.ClassesinthesourceROIEditField.Value=app.Data.convert{pix}{1};
                    app.ClassesinthedestinationROIEditField.Value=app.Data.convert{pix}{2};
                end

            else
                app.ClassesinthedestinationROIEditField.Enable='off';
                app.ClassesinthesourceROIEditField.Enable='off';
                app.Data.convert{pix}={};
            end

        end



        function displayROIs(app,option)

            if nargin==1
                option=[];
            end

            s=app.Data.st;
            cc=1;
            store=[];
            displaystr={};
            annotate={};
            channels={};

            mainApp=app.Data.mainApp;


            for i=1:numel(s.Project)

                proj = s.Project{i};
                shallowObj = evalin('base',proj);

                if numel(s.Projectpos)
                    for k=1:numel(s.Projectpos{i})

                        tmp = evalin('base',[proj '.fov(' num2str(k) ')']);

                        if numel(tmp.roi) > 0 && numel(tmp.roi(1).id) > 0
                            varstr{cc} = [proj '.fov(' num2str(k) ')'];
                            displaystr{cc} = [proj '  //  ' s.Projectpos{i}{k} ' - ' num2str(numel(tmp.roi)) ' ROIs available'];
                            displaystr2{cc,1} = proj;
                            displaystr2{cc,2} = s.Projectpos{i}{k};
                            displaystr2{cc,3} = ['1:' num2str(numel(tmp.roi)) ];
                            app.Data.convert{cc} = {};
                            app.Data.preserve{cc} = true;
                            app.Data.targetChannel{cc} = cell(1,numel(mainApp.Data.classiObj.channelName));
                            app.Data.target{cc} = tmp;

                            % � Parcourt toutes les ROIs pour collecter tous les channels
                            allChannels = {};
                            for r = 1:numel(tmp.roi)
                                ch = roiImporterChannelNames( ...
                                    tmp.roi(r).display.channel);
                                allChannels = [allChannels, ch];
                            end
                            app.Data.channelsToImport{cc} = unique(allChannels, 'stable');

                            if isempty(store)
                                store = numel(tmp.roi);
                            end
                            cc = cc + 1;
                        end
                    end
                end

                if numel(s.Projectclassi)
                    for k=1:numel(s.Projectclassi{i})
                        val = k;
                        if nargin == 3
                            mp = evalin('base',proj);
                            for l = 1:numel(mp.processing.classification)
                                if strcmp(mp.processing.classification(l).strid,option)
                                    break
                                end
                            end
                            val = l;
                        end

                        tmp = evalin('base',[proj '.processing.classification(' num2str(val) ')']);

                        if numel(tmp.roi) > 0 && numel(tmp.roi(1).id) > 0
                            varstr{cc} = [proj '.processing.classification(' num2str(val) ')'];
                            displaystr{cc} = [proj '  //  ' s.Projectclassi{i}{k} ' - ' num2str(numel(tmp.roi)) ' ROIs available'];
                            displaystr2{cc,1} = proj;
                            displaystr2{cc,2} = s.Projectclassi{i}{k};
                            displaystr2{cc,3} = ['1:' num2str(numel(tmp.roi)) ];
                            app.Data.convert{cc} = {};
                            app.Data.preserve{cc} = true;
                            app.Data.targetChannel{cc} = cell(1,numel(mainApp.Data.classiObj.channelName));
                            app.Data.target{cc} = tmp;

                            % � Collecte des channels sur toutes les ROIs
                            allChannels = {};
                            for r = 1:numel(tmp.roi)
                                ch = roiImporterChannelNames( ...
                                    tmp.roi(r).display.channel);
                                allChannels = [allChannels, ch];
                            end
                            app.Data.channelsToImport{cc} = unique(allChannels, 'stable');

                            if isempty(store)
                                store = numel(tmp.roi);
                            end
                            cc = cc + 1;
                        end
                    end
                end
            end

            for i = 1:numel(s.Classifier)
                clas = s.Classifier{i};

                % Sauter les entrées vides
                if isempty(clas)
                    continue;
                end

                % Normaliser en char
                if isstring(clas)
                    if ~isscalar(clas)
                        % on prend le premier élément si jamais c'est un string array
                        clas = clas(1);
                    end
                    clas = char(clas);
                end

                % Si ce n'est toujours pas une char, on saute
                if ~ischar(clas)
                    warning('displayROIs:ClassifierType',...
                        'Entrée s.Classifier{%d} non textuelle, ignorée.', i);
                    continue;
                end

                % Essayer de récupérer la variable dans le base workspace
                try
                    tmp = evalin('base', clas);
                catch ME
                    warning('displayROIs:EvalinFailed',...
                        'Impossible de trouver la variable "%s" dans le workspace (idx %d).', clas, i);
                    continue;
                end

                if numel(tmp.roi) > 0 && numel(tmp.roi(1).id) > 0
                    varstr{cc}      = clas;
                    displaystr{cc}  = [clas ' - ' num2str(numel(tmp.roi)) ' ROIs available'];
                    displaystr2{cc,1} = '';
                    displaystr2{cc,2} = clas;
                    displaystr2{cc,3} = ['1:' num2str(numel(tmp.roi)) ];
                    app.Data.convert{cc}        = {};
                    app.Data.preserve{cc}       = true;
                    app.Data.targetChannel{cc}  = cell(1, numel(mainApp.Data.classiObj.channelName));
                    app.Data.target{cc}         = tmp;

                    % � Collecte des channels sur toutes les ROIs
                    allChannels = {};
                    for r = 1:numel(tmp.roi)
                        ch = roiImporterChannelNames( ...
                            tmp.roi(r).display.channel);
                        allChannels = [allChannels, ch]; %#ok<AGROW>
                    end
                    app.Data.channelsToImport{cc} = unique(allChannels, 'stable');

                    if isempty(store)
                        store = numel(tmp.roi);
                    end
                    cc = cc + 1;
                end
            end



            app.Data.channelsAvailable=app.Data.channelsToImport;

            %app.ChoosePositionClassiferDropDown.Items=displaystr';
            app.Data.varstr=varstr; % list of classifier variables in the workspace
            app.Data.displaystr=displaystr;

            %  app.TypeROIindicestoimportEditField.Value=['1:' num2str(store)];

            %   ChoosePositionClassiferDropDownValueChanged(app)
            % displayChannels(app)

            t=app.UITable;
            t.Data=[];

            %t.ColumnName={'Select for training','Select for test',' ROI index','ROI Id'};

            t.ColumnWidth={50, 250, 200, 'auto' };
            t.ColumnEditable=[true false false true];
            d=t.Data;

            for i=1:size(displaystr2,1)
                d{i,1}=false;

                if numel(option) && i==1% when subselecting a target classi, preselect it
                    d{i,1}=true;
                end

                d{i,2}=displaystr2{i,1};
                d{i,3}=displaystr2{i,2};
                d{i,4}=displaystr2{i,3};
            end

            t.Data=d;

            app.Data.displaystr2=displaystr2;

            if nargin==3 % incase a classiObj is targeted

                app.UITable.Selection=[1 4];
                UITableSelectionChanged(app)
            end

        end


        function updateChannelMappingTable(app)
            % Remplit la table de mapping pour la ligne sélectionnée dans app.UITable,
            % en utilisant l'union des channels sur TOUTES les ROIs du target.

            persistVisibleChannelMapping(app);

            selection = app.UITable.Selection;
            if isempty(selection)
                app.ChannelMappingTable.Data = {};
                app.displayedChannelMapIndex = 0;
                return;
            end

            pixtable = selection(1,1);

            % Objet source (classi ou fov) pour cette ligne
            target = app.Data.target{pixtable};
            if isempty(target) || ~isprop(target,'roi') || isempty(target.roi)
                app.ChannelMappingTable.Data = {};
                app.displayedChannelMapIndex = 0;
                return;
            end

            rois = target.roi(:);
            nROI = numel(rois);

            % ---------- 1) Union de tous les noms de channels ----------
            allNames = {};
            for r = 1:nROI
                ch = roiImporterChannelNames(rois(r).display.channel);
                allNames = [allNames, ch]; %#ok<AGROW>
            end
            chNames = unique(allNames,'stable');
            nCh = numel(chNames);

            % ---------- 2) Type des channels : grayscale / rgb / indexed ----------
            chTypes = cell(1,nCh);

            for i = 1:nCh
                name = chNames{i};

                isIndexed = false;
                nSubsList = [];

                for r = 1:nROI
                    ch = roiImporterChannelNames(rois(r).display.channel);

                    idx = find(strcmp(ch, name), 1);   % index logique dans cette ROI
                    if isempty(idx)
                        continue;
                    end

                    roiR = rois(r);

                    % indexed ?
                    if isfield(roiR.display,'indexed') ...
                            && numel(roiR.display.indexed) >= idx ...
                            && roiR.display.indexed(idx)
                        isIndexed = true;
                    end

                    % nombre de sous-canaux pour ce channel logique
                    if ~isempty(roiR.channelid)
                        nSubsList(end+1) = sum(roiR.channelid == idx); %#ok<AGROW>
                    end
                end

                if isIndexed
                    chTypes{i} = 'indexed';
                elseif ~isempty(nSubsList)
                    nSubs = mode(nSubsList);   % on prend le mode si ça varie un peu
                    if nSubs == 1
                        chTypes{i} = 'grayscale';
                    elseif nSubs == 3
                        chTypes{i} = 'rgb';
                    else
                        chTypes{i} = sprintf('%d-sub', nSubs);
                    end
                else
                    chTypes{i} = 'unknown';
                end
            end

            % ---------- 3) Options I/O : input(s) + output ----------
            classiObj = app.Data.mainApp.Data.classiObj;

            ioOptions = {'-'};   % défaut = aucun mapping
            if isprop(classiObj,'channelName') && ~isempty(classiObj.channelName)
                ioOptions = [ioOptions, classiObj.channelName(:)'];
            end
            % on ajoute toujours le canal d'output (annotations potentielles)
            ioOptions{end+1} = 'Classifier annotation';

            % ---------- 4) Rechargement du mapping existant (par nom) ----------
            oldMap = [];
            if app.ApplymappingtoallFOVsCheckBox.Value && ...
                    ~isempty(app.globalChannelMap)
                oldMap = roiImporterProjectChannelMap( ...
                    app.globalChannelMap, chNames);
                app.channelMap{pixtable} = oldMap;
            elseif numel(app.channelMap) >= pixtable && ...
                    ~isempty(app.channelMap{pixtable})
                oldMap = app.channelMap{pixtable};
            end

            % ---------- 5) Construction des lignes ----------
            data = cell(nCh,5);

            for i = 1:nCh
                srcName = chNames{i};
                typ     = chTypes{i};

                importVal = true;
                destName  = srcName;
                ioVal     = '-';

                % auto-match I/O sur les channelName si possible
                if ~isempty(classiObj.channelName)
                    k = find(strcmp(classiObj.channelName, srcName), 1);
                    if ~isempty(k)
                        ioVal = classiObj.channelName{k};
                    end
                end

                % recherche d'un ancien mapping basé sur le nom de source
                if ~isempty(oldMap)
                    oldIdx = find(strcmp({oldMap.sourceName}, srcName), 1);
                    if ~isempty(oldIdx)
                        m = oldMap(oldIdx);
                        importVal = m.import;
                        if ~isempty(m.destName)
                            destName = m.destName;
                        end
                        if ~isempty(m.ioChannel)
                            ioVal = m.ioChannel;
                        end
                    end
                end

                data{i,1} = importVal;  % Import (checkbox)
                data{i,2} = srcName;    % Source channel
                data{i,3} = typ;        % Type
                data{i,4} = destName;   % Destination name
                data{i,5} = ioVal;      % I/O mapping
            end

            app.ChannelMappingTable.Data = data;
            app.ChannelMappingTable.ColumnFormat = { ...
                'logical', ... % Import
                'char',    ... % Source channel
                'char',    ... % Type
                'char',    ... % Destination name
                ioOptions  ... % I/O channel popup
                };
            app.ChannelMappingTable.ColumnEditable = [true false false true true];

            % Persist the complete table immediately, including unchecked
            % rows. Relying only on CellEditCallback meant that a table could
            % look configured while buildMappingForImport still received no
            % explicit selection and therefore imported every channel.
            app.channelMap{pixtable} = channelMapFromTableData(app, data);
            app.displayedChannelMapIndex = pixtable;
        end


        function persistVisibleChannelMapping(app)
            row = app.displayedChannelMapIndex;
            data = app.ChannelMappingTable.Data;
            if row < 1 || isempty(data)
                return;
            end
            visibleMap = channelMapFromTableData(app, data);
            app.channelMap{row} = visibleMap;
            if app.ApplymappingtoallFOVsCheckBox.Value
                app.globalChannelMap = visibleMap;
            end
        end


        function rows = selectedImportRows(app)
            rows = find(cellfun(@(x) isequal(x, true) || ...
                (isnumeric(x) && isscalar(x) && x ~= 0), ...
                app.UITable.Data(:,1)));
            rows = double(rows(:).');
        end



        function map = channelMapFromTableData(app, data) %#ok<INUSD>
            nCh = size(data,1);
            map = repmat(struct('import',true, 'sourceName','', ...
                'type','', 'destName','', 'ioChannel',''), 1, nCh);
            for i = 1:nCh
                map(i).import = logical(data{i,1});
                map(i).sourceName = char(string(data{i,2}));
                map(i).type = char(string(data{i,3}));
                map(i).destName = char(string(data{i,4}));
                map(i).ioChannel = char(string(data{i,5}));
            end
        end


        function propagateEditedMappingToSelectedSources(app, selectedRows)
            selectedRows = double(selectedRows(:).');
            applyToAll = logical(app.ApplymappingtoallFOVsCheckBox.Value);
            editedRows = [];
            for row = selectedRows
                if row <= numel(app.channelMapEdited) && ...
                        app.channelMapEdited(row)
                    editedRows(end+1) = row; %#ok<AGROW>
                end
            end
            sourceRow = app.lastEditedChannelMapIndex;
            if applyToAll && ~isempty(app.globalChannelMap)
                sourceMap = app.globalChannelMap;
                sourceRow = 0;
            elseif applyToAll
                if sourceRow < 1 || sourceRow > numel(app.channelMapEdited) || ...
                        ~app.channelMapEdited(sourceRow)
                    return;
                end
                sourceMap = app.channelMap{sourceRow};
            else
                if isempty(editedRows), return; end
                if ~any(editedRows == sourceRow), sourceRow = editedRows(end); end
                if sourceRow < 1 || sourceRow > numel(app.channelMap) || ...
                        isempty(app.channelMap{sourceRow})
                    return;
                end
                sourceMap = app.channelMap{sourceRow};
            end

            targetRows = selectedRows;
            if applyToAll
                targetRows = 1:numel(app.Data.channelsToImport);
            end

            for targetRow = targetRows
                if targetRow == sourceRow
                    continue;
                end
                if ~applyToAll && ...
                        targetRow <= numel(app.channelMapEdited) && ...
                        app.channelMapEdited(targetRow)
                    continue;
                end
                available = roiImporterChannelNames( ...
                    app.Data.channelsToImport{targetRow});
                app.channelMap{targetRow} = ...
                    roiImporterProjectChannelMap(sourceMap, available);
            end
        end



       function [adjustChannel, adjustName, ioMap] = buildMappingForImport(app, idxTable)
    classiObj = app.Data.mainApp.Data.classiObj;

    adjustChannel = {};
    adjustName    = cell(1, numel(classiObj.channelName));
    ioMap         = [];

    if numel(app.channelMap) < idxTable || isempty(app.channelMap{idxTable})
        return;
    end

    map  = app.channelMap{idxTable};  % ce qui vient du GUI (avec les labels)
    ioMap = map;                      % copie que l'on va adapter pour addROI

    for i = 1:numel(map)
        if ~map(i).import
            continue;
        end

        src      = map(i).sourceName;
        destName = map(i).destName;
        io       = strtrim(map(i).ioChannel);   % ex: '-', 'Channel1_z2', 'Classifier annotation name'

        % � conversion du label humain vers le nom logique d'output
        if strcmp(io, 'Classifier annotation')
            io = classiObj.strid;   % ex: 'cellpose_2'
        end

        % 1) canaux à importer
        if ~isempty(src)
            adjustChannel{end+1} = src; %#ok<AGROW>
        end

        % 2) mapping vers les canaux d'INPUT du classif
        if ~isempty(io)
            k = find(strcmp(classiObj.channelName, io), 1);
            if ~isempty(k)
                % addROI's legacy adjustName contract expects the source
                % name. Destination/display renaming remains in ioMap.
                adjustName{k} = src;
            end
        end

        % � très important : on met à jour la copie envoyée à addROI
        ioMap(i).ioChannel = io;   % ici 'Classifier annotation name' devient 'cellpose_2'
    end

    if ~isempty(adjustChannel)
        adjustChannel = unique(adjustChannel,'stable');
    end
end



    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, option)



            if nargin~=3
                option=[];
            end

            app.Data.mainApp=mainApp;
            app.UIFigure.Name=['Import ROIs to ' mainApp.Data.classiObj.strid];
            app.Data.convert={};
            app.Data.preserve={};
            app.channelMap = {};
            app.channelMapEdited = false(1,0);
            app.lastEditedChannelMapIndex = 0;
            app.displayedChannelMapIndex = 0;
            app.globalChannelMap = [];

            app.Data.targetChannel={} ; %cell(1,numel(mainApp.Data.classiObj.channelName));
            app.Data.target={};

            %if isvarname()
            % tmp=evalin('base','classitmpi')

            evalin( 'base', 'clear classitmp' )

            if numel(option) % 3rd argument provides a filter to narrow down the selection
                s= gatherVariablesFromWorkspace(option); % provide the name of the classfier to import from
            else
                s= gatherVariablesFromWorkspace;
            end


            app.Data.st=s;

            displayROIs(app,option);


        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, event)
            evalin( 'base', 'clear classitmp' );
            uiresume(app.Data.mainApp.ClassifierUIFigure)
            delete(app)
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            uiresume(app.Data.mainApp.ClassifierUIFigure)
            delete(app)

        end

        % Button pushed function: ProceedButton
        function ProceedButtonPushed(app, event)

            pix=find(cellfun(@(x) x==1,app.UITable.Data(:,1)));
            data=app.UITable.Data;
            % value = app.ChoosePositionClassiferDropDown.Value;

            classiObj=app.Data.mainApp.Data.classiObj;

            %    pix=contains(app.Data.displaystr,value);

            if numel(pix)==0
                errordlg('You must select at least one item !','Error');
                return;
            end
            propagateEditedMappingToSelectedSources(app, pix);

            d = uiprogressdlg(app.UIFigure,'Title','Please Wait...',...
                'Message','Importing ROIs...');
            d.Value=0.33;

            for i=1:numel(pix)

                va=app.Data.varstr{pix(i)};
                tmp=evalin('base',va);

                raw = data{pix(i),4};

                if isnumeric(raw)
                    rois = raw;
                else
                    roistr = strtrim(char(raw));
                    if isempty(roistr)
                        rois = [];
                    else
                        roistr = regexprep(roistr, '[,;]', ' ');
                        roistr = regexprep(roistr, '\s+', ' ');
                        rois = str2num(roistr); %#ok<ST2NM>
                        if isempty(rois) && ~isempty(roistr)
                            errordlg(sprintf('Impossible d''interpréter "%s" comme indices de ROIs.', roistr), ...
                                'Erreur ROIs');
                            return;
                        end
                    end
                end



                if numel(rois)>0
                    d.Message=[ 'Importing ROIs.... From Position/Classifier: '   ' - ' num2str(i) ' / ' num2str(numel(pix))];
                    d.Value=0.33+0.66*(i-1)./numel(pix);

                    [adjustChannel, adjustName, ioMap] = buildMappingForImport(app, pix(i));

                    arg = {'rois', rois, ...
                        'convert', app.Data.convert{pix(i)}, ...
                        'adjustChannel', adjustChannel, ...
                        'adjustName',    adjustName, ...
                        'ioMap',         ioMap};

                    % return;

                    disp('---- Proceed DEBUG ----');
                    disp(['Source var : ' va]);
                    disp('ROIs demandées : '), disp(rois);
                    disp('channelsToImport = '), disp(app.Data.channelsToImport{pix(i)});


                    classiObj.addROI(tmp,arg{:})

                end
            end

            classiObj.trainingset=intersect(classiObj.trainingset,1:numel(classiObj.roi));

            d.Value=0.99;
            % d.Message='Transfer is complete!';
            %  pause(1);
            close(d);
            uialert(app.UIFigure,'Importing ROI is complete!','Success','Icon','success');
            uiresume(app.Data.mainApp.ClassifierUIFigure)
            delete(app)

        end

        % Value changed function: Preserveannotations
        function PreserveannotationsValueChanged(app, event)



            value = app.Preserveannotations.Value;



            selection = app.UITable.Selection;

            if numel(selection)==0
                warndlg('Please select an item in table above first !')
                return;
            end

            pix=selection(1,1);

            if value==1
                app.Data.preserve{pix}=true;
            else
                app.Data.preserve{pix}=false;
            end

            displayAnnotations(app);





        end

        % Button pushed function: SelectallButton
        function SelectallButtonPushed(app, event)


            n=size(app.UITable.Data,1);
            t=cell(1,n);
            t(:)={true};

            app.UITable.Data(:,1)=t';



        end

        % Button pushed function: DeselectallButton
        function DeselectallButtonPushed(app, event)
            n=size(app.UITable.Data,1);
            t=cell(1,n);
            t(:)={false};

            app.UITable.Data(:,1)=t';

        end

        % Cell edit callback: UITable
        function UITableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;

            if indices(1,2)==4 % roi edit
                pix=indices(1,1);
                app.UITable.Data{pix,1}=true;
            end

            app.UITable.Selection=indices;
            UITableSelectionChanged(app, event)
        end

        % Selection changed function: UITable
        function UITableSelectionChanged(app, event)
            selection = app.UITable.Selection;
            if isempty(selection)
                return;
            end

            % Anciennes choses que tu veux garder
            displayAnnotations(app);

            % Plus besoin de displayChannelsImport / displayChannels pour les canaux
            % displayChannelsImport(app)
            % displayChannels(app)

            updateChannelMappingTable(app);
        end

        % Value changed function: ClassesinthedestinationROIEditField
        function ClassesinthedestinationROIEditFieldValueChanged(app, event)
            value = app.ClassesinthedestinationROIEditField.Value;
            value2=app.ClassesinthesourceROIEditField.Value;
            selection = app.UITable.Selection;
            pix=selection(1,1);
            app.Data.convert{pix}={value2,value};
        end

        % Button pushed function: ImportROIsfromdiskButton
        function ImportROIsfromdiskButtonPushed(app, event)

            [file, path] = uigetfile( ...
                {'im_*.h5;im_*.mat','ROI files (HDF5 or legacy MAT)' ; ...
                'im_*.h5','HDF5 ROI' ; ...
                'im_*.mat','Legacy ROI (.mat)'}, ...
                'Select ROI files','Multiselect','on');
            if isequal(file,0), return; end
            if ischar(file), file = {file}; end

            classitmp = classi(path,'classitmp',1);
            if ~isprop(classitmp,'roi') || isempty(classitmp.roi) || ~isa(classitmp.roi,'roi')
                classitmp.roi = roi.empty(0,1);
            end

            d = uiprogressdlg(app.UIFigure,'Title','Please Wait...','Message','Importing ROIs...','Indeterminate','off');
            cleanup = onCleanup(@() (ishandle(d) && close(d)));

            n = numel(file);
            for i=1:n
                d.Value = i/n;
                d.Message = sprintf('Loading ROI %d/%d',i,n);

                f = fullfile(path,file{i});
                [~,~,ext] = fileparts(f);
                try
                    switch lower(ext)
                        case '.h5'
                            r = roi.fromH5(f,'headerOnly',true); % � léger, pas de pixels
                        case '.mat'
                            S = load(f,'roiobj');
                            if ~isfield(S,'roiobj') || ~isa(S.roiobj,'roi')
                                warning('Invalid legacy ROI: %s', file{i}); continue;
                            end
                            r = S.roiobj;
                            if isempty(r.path), r.path = path; end
                        otherwise
                            warning('Unsupported ROI file: %s', file{i}); continue;
                    end
                    % Normalisation minimale
                    if isempty(r.path), r.path = path; end
                    classitmp.roi(end+1,1) = r;
                catch ME
                    warning('Failed to import %s: %s', file{i}, ME.message);
                end
            end

            % TODO: attacher classitmp dans ta logique UI existante (liste, arbre, etc.)


        end

        % Selection changed function: ChannelMappingTable
        function ChannelMappingTableSelectionChanged(app, event)
            % Selecting a cell must not rebuild the table. Rebuilding here
            % could restore defaults before the user's edit was persisted.
        end

        % Cell edit callback: ChannelMappingTable
        function ChannelMappingTableCellEdit(app, event)
            data = app.ChannelMappingTable.Data;
            selection = app.UITable.Selection;
            if isempty(selection) || isempty(data)
                return;
            end

            pixtable = app.displayedChannelMapIndex;
            if pixtable < 1
                pixtable = selection(1,1);
            end
            try
                indices = event.Indices;
                if numel(indices) == 2
                    data{indices(1), indices(2)} = event.NewData;
                    app.ChannelMappingTable.Data = data;
                end
            catch
            end
            app.channelMap{pixtable} = channelMapFromTableData(app, data);
            app.channelMapEdited(pixtable) = true;
            app.lastEditedChannelMapIndex = pixtable;
            if app.ApplymappingtoallFOVsCheckBox.Value
                app.globalChannelMap = app.channelMap{pixtable};
            end
            propagateEditedMappingToSelectedSources(app, selectedImportRows(app));

        end

        % Value changed function: ApplymappingtoallFOVsCheckBox
        function ApplymappingtoallFOVsCheckBoxValueChanged(app, event)
            persistVisibleChannelMapping(app);
            if app.ApplymappingtoallFOVsCheckBox.Value && ...
                    isempty(app.globalChannelMap) && ...
                    app.displayedChannelMapIndex >= 1
                app.globalChannelMap = ...
                    app.channelMap{app.displayedChannelMapIndex};
            end
            propagateEditedMappingToSelectedSources(app, selectedImportRows(app));
            updateChannelMappingTable(app);

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 634 725];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create ProceedButton
            app.ProceedButton = uibutton(app.UIFigure, 'push');
            app.ProceedButton.ButtonPushedFcn = createCallbackFcn(app, @ProceedButtonPushed, true);
            app.ProceedButton.Position = [18 8 100 22];
            app.ProceedButton.Text = 'Proceed';

            % Create CancelButton
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Position = [521 18 100 22];
            app.CancelButton.Text = 'Cancel';

            % Create UITable
            app.UITable = uitable(app.UIFigure);
            app.UITable.ColumnName = {'Select'; 'Project'; 'Classifier or Position (FOV)'; 'Select ROIs'};
            app.UITable.RowName = {};
            app.UITable.CellEditCallback = createCallbackFcn(app, @UITableCellEdit, true);
            app.UITable.SelectionChangedFcn = createCallbackFcn(app, @UITableSelectionChanged, true);
            app.UITable.Position = [11 465 612 219];

            % Create SelectallButton
            app.SelectallButton = uibutton(app.UIFigure, 'push');
            app.SelectallButton.ButtonPushedFcn = createCallbackFcn(app, @SelectallButtonPushed, true);
            app.SelectallButton.Position = [352 693 121 27];
            app.SelectallButton.Text = 'Select all';

            % Create DeselectallButton
            app.DeselectallButton = uibutton(app.UIFigure, 'push');
            app.DeselectallButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectallButtonPushed, true);
            app.DeselectallButton.Position = [491 692 121 27];
            app.DeselectallButton.Text = 'Deselect all';

            % Create ImportedROIschannelnameselectionandmappingPanel
            app.ImportedROIschannelnameselectionandmappingPanel = uipanel(app.UIFigure);
            app.ImportedROIschannelnameselectionandmappingPanel.Title = 'Imported ROIs channel name selection and mapping';
            app.ImportedROIschannelnameselectionandmappingPanel.Position = [18 47 603 271];

            % Create ChannelMappingTable
            app.ChannelMappingTable = uitable(app.ImportedROIschannelnameselectionandmappingPanel);
            app.ChannelMappingTable.ColumnName = {'Import'; 'Source Channel Name'; 'Type'; 'Destination name'; 'Classifier I/O Channel'};
            app.ChannelMappingTable.RowName = {};
            app.ChannelMappingTable.ColumnEditable = [true false false true true];
            app.ChannelMappingTable.CellEditCallback = createCallbackFcn(app, @ChannelMappingTableCellEdit, true);
            app.ChannelMappingTable.SelectionChangedFcn = createCallbackFcn(app, @ChannelMappingTableSelectionChanged, true);
            app.ChannelMappingTable.Position = [10 11 583 207];

            % Create ApplymappingtoallFOVsCheckBox
            app.ApplymappingtoallFOVsCheckBox = uicheckbox(app.ImportedROIschannelnameselectionandmappingPanel);
            app.ApplymappingtoallFOVsCheckBox.ValueChangedFcn = createCallbackFcn(app, @ApplymappingtoallFOVsCheckBoxValueChanged, true);
            app.ApplymappingtoallFOVsCheckBox.Text = 'Apply channel mapping to all FOVs';
            app.ApplymappingtoallFOVsCheckBox.Tooltip = {'Unchecked: apply the edited mapping only to FOVs selected for import.'; 'Checked: apply it to every FOV listed above.'};
            app.ApplymappingtoallFOVsCheckBox.Position = [10 224 258 22];

            % Create ImportedROIsclassesmappingPanel
            app.ImportedROIsclassesmappingPanel = uipanel(app.UIFigure);
            app.ImportedROIsclassesmappingPanel.Title = 'Imported ROIs classes mapping';
            app.ImportedROIsclassesmappingPanel.Position = [14 329 607 127];

            % Create Preserveannotations
            app.Preserveannotations = uicheckbox(app.ImportedROIsclassesmappingPanel);
            app.Preserveannotations.ValueChangedFcn = createCallbackFcn(app, @PreserveannotationsValueChanged, true);
            app.Preserveannotations.Text = 'Preserve annotations from the original ROI if available';
            app.Preserveannotations.Position = [9 71 313 22];

            % Create ClassesinthedestinationROIEditFieldLabel
            app.ClassesinthedestinationROIEditFieldLabel = uilabel(app.ImportedROIsclassesmappingPanel);
            app.ClassesinthedestinationROIEditFieldLabel.HorizontalAlignment = 'right';
            app.ClassesinthedestinationROIEditFieldLabel.Enable = 'off';
            app.ClassesinthedestinationROIEditFieldLabel.Position = [39 10 170 22];
            app.ClassesinthedestinationROIEditFieldLabel.Text = 'Classes in the destination ROI:';

            % Create ClassesinthedestinationROIEditField
            app.ClassesinthedestinationROIEditField = uieditfield(app.ImportedROIsclassesmappingPanel, 'text');
            app.ClassesinthedestinationROIEditField.ValueChangedFcn = createCallbackFcn(app, @ClassesinthedestinationROIEditFieldValueChanged, true);
            app.ClassesinthedestinationROIEditField.Enable = 'off';
            app.ClassesinthedestinationROIEditField.Tooltip = {'Enter space-separated classes names; Type "0"  if you do not want to use a corresponding class; thenumber of items in both text fields must be  identical'; ''};
            app.ClassesinthedestinationROIEditField.Position = [218 10 276 22];

            % Create ClassesinthesourceROIEditFieldLabel
            app.ClassesinthesourceROIEditFieldLabel = uilabel(app.ImportedROIsclassesmappingPanel);
            app.ClassesinthesourceROIEditFieldLabel.HorizontalAlignment = 'right';
            app.ClassesinthesourceROIEditFieldLabel.Enable = 'off';
            app.ClassesinthesourceROIEditFieldLabel.Position = [35 41 152 22];
            app.ClassesinthesourceROIEditFieldLabel.Text = 'Classes in the source ROI: ';

            % Create ClassesinthesourceROIEditField
            app.ClassesinthesourceROIEditField = uieditfield(app.ImportedROIsclassesmappingPanel, 'text');
            app.ClassesinthesourceROIEditField.Editable = 'off';
            app.ClassesinthesourceROIEditField.Position = [218 42 276 22];

            % Create SelectROIstoimportLabel
            app.SelectROIstoimportLabel = uilabel(app.UIFigure);
            app.SelectROIstoimportLabel.FontSize = 16;
            app.SelectROIstoimportLabel.FontWeight = 'bold';
            app.SelectROIstoimportLabel.Position = [15 695 173 22];
            app.SelectROIstoimportLabel.Text = 'Select ROIs to import:';

            % Create ImportROIsfromdiskButton
            app.ImportROIsfromdiskButton = uibutton(app.UIFigure, 'push');
            app.ImportROIsfromdiskButton.ButtonPushedFcn = createCallbackFcn(app, @ImportROIsfromdiskButtonPushed, true);
            app.ImportROIsfromdiskButton.Tooltip = {'Select ROI files directly in the hard drive...'};
            app.ImportROIsfromdiskButton.Position = [193 692 142 27];
            app.ImportROIsfromdiskButton.Text = 'Import ROIs from disk...';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = roiImporterGUI(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
