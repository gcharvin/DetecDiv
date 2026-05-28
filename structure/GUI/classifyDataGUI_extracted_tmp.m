classdef classifyDataGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ClassifydataUIFigure            matlab.ui.Figure
        OuputnameEditField              matlab.ui.control.EditField
        OuputnameEditFieldLabel         matlab.ui.control.Label
        ClassificationoptionsPanel      matlab.ui.container.Panel
        ExecutionenvironmentDropDown    matlab.ui.control.DropDown
        ExecutionenvironmentDropDownLabel  matlab.ui.control.Label
        ProcessallframesoveridesframestableselectionCheckBox  matlab.ui.control.CheckBox
        ParallelROIs                    matlab.ui.control.CheckBox
        ClassifiervalidationoptionsPanel  matlab.ui.container.Panel
        LogpredGTstatsinrundirCheckBox  matlab.ui.control.CheckBox
        ClassifyallROIsoveridesROItableselectionCheckBox  matlab.ui.control.CheckBox
        UseadditionalCNNclassificationforLSTMmodelsCheckBox  matlab.ui.control.CheckBox
        ClassifyonlyROIswithGTCheckBox  matlab.ui.control.CheckBox
        SelecttableitemstoclassifyPanel  matlab.ui.container.Panel
        ApplyselectedsettingstoallButton  matlab.ui.control.Button
        DeselectallButton               matlab.ui.control.Button
        SelectallButton                 matlab.ui.control.Button
        ChannelListBox                  matlab.ui.control.ListBox
        SelectchannelnamesforselectedtableitemLabel  matlab.ui.control.Label
        CancelButton                    matlab.ui.control.Button
        ClassifyselecteddataButton      matlab.ui.control.Button
        UITable                         matlab.ui.control.Table
        SelectclassfiermodelDropDown    matlab.ui.control.DropDown
        SelectclassfiermodelDropDownLabel  matlab.ui.control.Label
    end

    
    properties (Access = private)
        Data % Description
    end
    
    methods (Access = private)
        
        
        function app = setDefaultOutputNameFromSelectedClassifier(app, force)
    if nargin < 2, force = false; end

    % Get current selected classifier object
    list = app.SelectclassfiermodelDropDown.Items;
    idx  = find(matches(list, app.SelectclassfiermodelDropDown.Value), 1);
    if isempty(idx), return; end

    classilist = app.Data.varstr;
    classifVar = classilist{idx};
    classif    = evalin('base', classifVar);

    autoName = string(classif.strid);

    curName = "";
    try
        curName = string(app.OuputnameEditField.Value);
    catch
    end

    % Overwrite only if:
    % - force OR
    % - user never edited OR
    % - field is empty OR
    % - field still equals the last auto name
    if force ...
            || ~isfield(app.Data,'outputNameUserEdited') || ~app.Data.outputNameUserEdited ...
            || strlength(strtrim(curName))==0 ...
            || (isfield(app.Data,'lastAutoOutputName') && curName == string(app.Data.lastAutoOutputName))

        app.OuputnameEditField.Value = char(autoName);
        app.Data.lastAutoOutputName  = autoName;
        if force
            app.Data.outputNameUserEdited = false;
        end
    end
end



function updateTable(app)

    app.ChannelListBox.Items = {};
    app.ChannelListBox.Enable = 'off';

    app.Data.storedobj = [];

    list = app.SelectclassfiermodelDropDown.Items;
    valueClassi = find(matches(list, app.SelectclassfiermodelDropDown.Value), 1);

    if isempty(valueClassi)
        return;
    end

    classilist = app.Data.varstr;
    projectlist = app.Data.tobeclassified_varstr;
    projectnames = app.Data.tobeclassified_projectstr;

    classif = classilist{valueClassi};
    classif = evalin('base', classif);

    % Prefer dataset channels if available
    classifChannels = {};
    try
        classifChannels = classif.getInputChannels();
    catch
        classifChannels = classif.channelName;
    end
    if ischar(classifChannels)
        classifChannels = {classifChannels};
    end

    t = app.UITable;
    t.ColumnName = {'Select','Project','ROIs from Position or Classifier','Name', ...
                    'Select classification input channel(s)', ...
                    'Select ROIs array','Select frames'};
    t.ColumnEditable = [true false false false false true true];
    t.ColumnFormat = {[] [] [] [] [] [] []};

    Data = {};
    cc = 1;

    for i = 1:numel(projectlist)
        strcha = '';
        obj = evalin('base', projectlist{i});

        if isa(obj,'classi')
            if numel(app.Data.specificobj) && isa(app.Data.specificobj,'classi')
                if app.Data.specificobj ~= obj
                    continue
                end
            end
        else
            projn = evalin('base', projectnames{i});
            if app.Data.specificobj ~= projn
                continue
            end
        end

        app.Data.storedobj(cc).data = obj;

        if numel(obj.roi(1).id)
            cha = obj.roi(1).display.channel;

            if isempty(classifChannels)
                % fallback to ROI channel if no classif channels
                if ischar(cha)
                    classifChannels = {cha};
                else
                    classifChannels = cha;
                end
            end

            for j = 1:numel(classifChannels)
                query = classifChannels{j};

                if numel(find(matches(cha,query)))
                    strcha = [strcha classifChannels{j} ','];
                else
                    aa = obj.roi(1).display.channel;
                    if ischar(aa)
                        strcha = [aa ','];
                    else
                        strcha = [obj.roi(1).display.channel{1} ','];
                    end
                end
            end
        end

        if ~isempty(strcha)
            strcha = strcha(1:end-1);
        end

        fra = inferFrameCountForTable(app, obj, strcha);

        roilist = ['1:' num2str(numel(obj.roi))];

        if isa(obj,'classi')
            id = obj.strid;
            typ = 'Classifier';

            isValidation = false;
            try
                isValidation = isfield(app.Data,'validation') && app.Data.validation==1;
            catch
            end

            if isValidation
                trainIdx = [];
                testIdx  = [];

                try
                    if isprop(obj,'dataset') && isfield(obj.dataset,'split')
                        if isfield(obj.dataset.split,'train'), trainIdx = obj.dataset.split.train; end
                        if isfield(obj.dataset.split,'test'),  testIdx  = obj.dataset.split.test;  end
                    end
                catch
                end

                if isempty(trainIdx)
                    trainIdx = obj.trainingset;
                end

                if isempty(testIdx)
                    testIdx = setxor(1:numel(obj.roi), trainIdx);
                end

                roilist = idxRowStr(testIdx);
            end
        end

        if isa(obj,'fov')
            id = obj.id;
            typ = 'FOV';
        end

        Data(cc,:) = {true projectnames{i} typ id strcha roilist ['1:' num2str(fra)]};
        cc = cc + 1;
    end

    t.Data = Data;

    function s = idxRowStr(idx)
        idx = idx(:).';
        if isempty(idx)
            s = '';
        else
            s = strtrim(sprintf('%d ', idx));
        end
    end
end

function fra = inferFrameCountForTable(app, obj, channelSpec)
% Infer frame count without loading ROI image/data payloads.
    fra = [];

    try
        if isprop(obj,'frames') && ~isempty(obj.frames)
            objFrames = obj.frames;
            if numel(objFrames) > 1
                pix = [];
                try
                    if isprop(obj,'channel') && ~isempty(obj.channel) && ~isempty(channelSpec)
                        query = textscan(char(string(channelSpec)),'%s','Delimiter',',');
                        if ~isempty(query) && ~isempty(query{1})
                            pix = find(matches(obj.channel, query{1}{1}));
                        end
                    end
                catch
                    pix = [];
                end
                if ~isempty(pix)
                    fra = objFrames(pix(1));
                else
                    fra = objFrames(1);
                end
            else
                fra = objFrames;
            end
            return;
        end
    catch
        fra = [];
    end

    try
        if isprop(obj,'roi') && ~isempty(obj.roi)
            maxProbe = min(numel(obj.roi), 5);
            for idx = 1:maxProbe
                fra = inferFrameCountFromRoiHeader(app, obj.roi(idx));
                if ~isempty(fra)
                    return;
                end
            end
        end
    catch
        fra = [];
    end

    if isempty(fra)
        fra = 1;
    end
end

function fra = inferFrameCountFromRoiHeader(app, rr) %#ok<INUSD>
% Read only HDF5 metadata for an extracted ROI, avoiding roi.load().
    fra = [];
    try
        if isempty(rr.path) || isempty(rr.id)
            return;
        end
        h5File = fullfile(rr.path, ['im_' char(string(rr.id)) '.h5']);
        if ~isfile(h5File)
            return;
        end
        info = h5info(h5File);
        dsets = info.Datasets;
        if isempty(dsets)
            return;
        end
        sz = dsets(1).Dataspace.Size;
        if numel(sz) >= 4
            fra = double(sz(4));
        elseif ~isempty(sz)
            fra = double(sz(end));
        end
        fra = max(1, fra);
    catch
        fra = [];
    end
end


   

 
%         function gatherVarsFromWorkspace(app)
%             varlist=evalin('base','who');
%             st=struct('Project',{''},'Classifier',{''},'Projectpos',{''},'Projectclassi',{''});
%             cc=0;
%             cd=0;
%             app.Data.st=[];
% 
%             for i=1:numel(varlist)
% 
%                 if strcmp(varlist{i},'ans')
%                     continue;
%                 end
% 
%                 tmp=evalin('base',varlist{i});
%                 
%                 if isa(tmp,'shallow')
%                     disp('this is a shallow object')
%                     cc=cc+1;
% 
%                     st.Project{cc}=varlist{i};
% 
%                     tmpclassi={};
% 
%                     for k=1:numel(tmp.processing.classification)
%                         %  k
%                         tmpclassi = [tmpclassi tmp.processing.classification(k).strid];
%                     end
% 
%                     st.Projectclassi{cc}=tmpclassi;
% 
%                     tmpproj={};
% 
%                     for k=1:numel(tmp.fov)
%                         %  k
%                         tmpproj = [tmpproj tmp.fov(k).id];
%                     end
% 
%                     st.Projectpos{cc}=tmpproj;
%                 end
% 
%                 if isa(tmp,'classi')
%                     
%                     disp('this is a classification object')
%                     cd=cd+1;
%                     st.Classifier{cd}=varlist{i};
%                    % aa= st.Classifier{cd}
%                 end
% 
%             end
% 
%           %  st
%             app.Data.st=st;
%             app.Data.convert={};
%         end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, shallowObj, classiObj)
           
            % shallowObj can be either a @shallow or a @classi 
            % classiObj can be provdied to select which @classi to use with
            % shalowObj 
            % if classiObj="Validation", then it is a validation procedure

            if nargin==1
                shallowObj=[];
                classiObj=[];
            end

            if nargin==2
                classiObj=[];
            end

            app.Data.shallowObj=shallowObj;
            
            if isa(classiObj,'string')
            if classiObj=="Validation" % this is classifier validation prcedure 
                app.Data.validation=1;
            end
            else
                app.Data.validation=0;
                app.ClassifiervalidationoptionsPanel.Visible="off";
            end

            if isa(shallowObj,'classi')
                app.SelectclassfiermodelDropDown.Enable="off";
                classiObj=shallowObj;
            end

            if isa(classiObj,'classi')
                app.SelectclassfiermodelDropDown.Enable="off";
            end

            app.Data.classiObj=classiObj;
            
            app.Data.st=gatherVariablesFromWorkspace;

             s=app.Data.st;
            cc=1;
            store=[];
            displaystr={};
            varstr={};
            tobeclassified_varstr={};
            tobeclassified_projectstr={};
            cd=1;

            % list avaialable fovs and classi with ROIs
            app.Data.specificobj=[];

                for i=1:numel(s.Project)
                    
                    proj=s.Project{i};
                    
                    if shallowObj==evalin('base',proj)
                        app.Data.specificobj=shallowObj; % project variable is provdided as input
                    end

                    for k=1:numel(s.Projectpos{i})

                        if isa(shallowObj,'classi') % if classi is provided as inout, then skip project pos
                            continue
                        end
                        
                        tmp= evalin('base',[proj '.fov(' num2str(k) ')']);
                        
                        if numel(tmp.roi)>0 & numel(tmp.roi(1).id)>0
                        tobeclassified_varstr{cd}=[proj '.fov(' num2str(k) ')'];
                        tobeclassified_projectstr{cd}=proj;
                        %displaystr{cc}=[proj '  //  ' s.Projectpos{i}{k}];
                        if numel(store)==0
                        store=numel(tmp.roi);
                        end
                        cd=cd+1;
                      %  cc=cc+1;
                        end
                    end

                    for k=1:numel(s.Projectclassi{i})
                        
                        tmp= evalin('base',[proj '.processing.classification(' num2str(k) ')']);

                        if shallowObj==tmp
                        app.Data.specificobj=shallowObj; % classi variable from project is provided
                        else
                            if isa(shallowObj,'classi') % remove all other classi is classi obj is provided
                                continue
                            else            % if project is provided with a specific classifier as input, then discard all other classifer
                                if tmp~=classiObj
                                    continue
                                end


                            end
                        end
                        
                       % if numel(tmp.roi)>0 & numel(tmp.roi(1).id)>0
                        varstr{cc}=[proj '.processing.classification(' num2str(k) ')'];

                        tobeclassified_varstr{cd}=[proj '.processing.classification(' num2str(k) ')'];
                        tobeclassified_projectstr{cd}=proj;
                        displaystr{cc}=[proj '  //  ' s.Projectclassi{i}{k}];

                        if numel(store)==0
                        store=numel(tmp.roi);
                        end
                        cc=cc+1;
                        cd=cd+1;

                       % end
                    end
                end
      
                for i=1:numel(s.Classifier)
                    
                    clas=s.Classifier{i};
                    
                    tmp= evalin('base',clas);

                     if shallowObj==tmp
                        app.Data.specificobj=shallowObj;
                     else
                        if isa(shallowObj,'classi') % remove all other classi is classi obj is provided
                        continue
                        else            % if project is provided with a specific classifier as input, then discard all other classifer
                                if tmp~=classiObj
                                    continue
                                end

                        end
                     end
                        
                    %if numel(tmp.roi)>0 & numel(tmp.roi(1).id)>0
                        varstr{cc}=clas;
                        
                        displaystr{cc}=clas;
                        tobeclassified_varstr{cd}=clas;
                        tobeclassified_projectstr{cd}='';
                        if numel(store)==0
                           store=numel(tmp.roi);
                        end
                        cd=cd+1;
                        cc=cc+1;
                    % end
                        
                end
                
             %   displaystr

                app.SelectclassfiermodelDropDown.Items=displaystr';

                % --- Output name default behavior (auto vs user override)
app.Data.outputNameUserEdited = false;
app.Data.lastAutoOutputName   = "";


                app.Data.varstr=varstr; 
                app.Data.tobeclassified_varstr=tobeclassified_varstr; % list of classifier variables in the workspace
                app.Data.tobeclassified_projectstr=tobeclassified_projectstr;
                app.Data.displaystr=displaystr;


                % ----------------------------------------------------------
% Default checkbox state
% - validation mode => TRUE
% - normal classify  => FALSE
% ----------------------------------------------------------
isValidation = false;

try
    if isfield(app.Data,'validation') && app.Data.validation==1
        isValidation = true;
    end
    if isa(shallowObj,'classi')
        isValidation = true;
    end
    if isa(classiObj,'classi')
        isValidation = true;
    end
catch
    isValidation = false;
end

% Set default UI value
if isValidation
    app.LogpredGTstatsinrundirCheckBox.Value = true;
else
    app.LogpredGTstatsinrundirCheckBox.Value = false;
end


%             str={};
%             for i=1:numel(shallowObj.processing.classification)
%                 str{i}=shallowObj.processing.classification(i).strid;
%             end
           % app.SelectclassfiermodelDropDown.Items=str;
            
            updateTable(app);

            % Set default output name based on currently selected classifier
    setDefaultOutputNameFromSelectedClassifier(app, true);  % force

            
        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, event)
            delete(app)
        end

        % Close request function: ClassifydataUIFigure
        function ClassifydataUIFigureCloseRequest(app, event)
            delete(app)
            
        end

        % Value changed function: SelectclassfiermodelDropDown
        function SelectclassfiermodelDropDownValueChanged(app, event)
         %   value = app.SelectclassfiermodelDropDown.Value;
            
         %   shallowObj=app.Data.shallowObj;
            
          %  pix=find(contains(app.SelectclassfiermodelDropDown.Items,value));
            
            updateTable(app)

             setDefaultOutputNameFromSelectedClassifier(app, false);
            
%             dat=app.UITable.Data;
%             
%             dat{:,4}=num2str(shallowObj.processing.classification(pix).channel);
%             
%             app.UITable.Data=dat;
        end

        % Button pushed function: ClassifyselecteddataButton
        function ClassifyselecteddataButtonPushed(app, event)
          % Button pushed function: ClassifyselecteddataButton

    % shallowObj=app.Data.shallowObj;

    list=app.SelectclassfiermodelDropDown.Items;
    valueClassi=find(matches(list,app.SelectclassfiermodelDropDown.Value));

    classilist= app.Data.varstr;

    classif=classilist{valueClassi};
    classif=evalin('base',classif);

    % --- Output name (group id) for dataseries to be written
outName = string(app.OuputnameEditField.Value);
outName = strtrim(outName);
if strlength(outName)==0
    outName = string(classif.strid);
end


    data=app.UITable.Data;

    selpos=find(cellfun(@(x) x==1,data(:,1)));

    frames={};
    channel={};

    roiobj=[];
    cc=1;

    for i=1:numel(selpos)

        obj=app.Data.storedobj(selpos(i)).data;

        tmp=str2num(data{selpos(i),6});

        if sum(ismember(tmp,1:numel(obj.roi)))==numel(tmp)

            if app.ClassifyallROIsoveridesROItableselectionCheckBox.Value==true
                roiobj=[roiobj obj.roi];
            else
                roiobj=[roiobj obj.roi(tmp)];
            end

            txt=textscan(data{selpos(i),5},'%s','Delimiter',',');

            str={};

            for j=1:numel(txt{1})
                str{j}=txt{1}{j};
            end

            for j=1:numel(tmp)

                channel{cc}=str;

                if app.ProcessallframesoveridesframestableselectionCheckBox.Value==1
                    frames{cc}=-1;
                else
                    frames{cc}=str2num(data{selpos(i),7});
                end

                cc=cc+1;
            end
        end
    end

    d = uiprogressdlg(app.ClassifydataUIFigure,'Title','Please Wait...', ...
        'Message','Starting data classification...');
    d.Value=0.01;

   arg = {'Progress',d,'Channel',channel,'Frames',frames, 'OutputName', char(outName)};

    if app.UseadditionalCNNclassificationforLSTMmodelsCheckBox.Value==true
        arg=[arg {'ClassifierCNN'}];
    end

    if app.ClassifyonlyROIswithGTCheckBox.Value==true
        arg=[arg {'RoiWithGT'}];
    end

    if app.ParallelROIs.Value==true
        arg=[arg {'Parallel'}];
    end

    if app.ExecutionenvironmentDropDown.Value=="CPU"
        arg=[arg {'CPU'}];
    end
    if app.ExecutionenvironmentDropDown.Value=="GPU"
        arg=[arg {'GPU'}];
    end

   % ==========================================================
% Are we in validation mode?
% ==========================================================
isValidation = false;
try
    if isfield(app.Data,'validation') && app.Data.validation==1
        isValidation = true;
    end
    if isfield(app.Data,'shallowObj') && isa(app.Data.shallowObj,'classi')
        isValidation = true;
    end
    if isfield(app.Data,'classiObj') && isa(app.Data.classiObj,'classi')
        isValidation = true;
    end
catch
    isValidation = false;
end

% ==========================================================
% Checkbox drives stats + batonnets
% - In non-validation mode: we force stats off (even if checkbox exists)
% ==========================================================
doStats = false;
if isValidation
    doStats = logical(app.LogpredGTstatsinrundirCheckBox.Value);
end

% Logging/run I/O only needed if we actually do stats (exports + batonnets)
if doStats
    logMode  = 'on';
    closeRun = true;
else
    logMode  = 'off';
    closeRun = false;
end

validateTrainingData(classif, roiobj, arg{:}, ...
    'LogMode', logMode, ...
    'DoStats', doStats, ...
    'CloseRun', closeRun);


    uialert(app.ClassifydataUIFigure,'Classification is complete!','Success','Icon','success');

    %shallowSave(shallowObj);

        end

        % Button pushed function: SelectallButton
        function SelectallButtonPushed(app, event)
            data=app.UITable.Data;
             
            data(:,1)={true};
             
             app.UITable.Data=data;
        end

        % Button pushed function: DeselectallButton
        function DeselectallButtonPushed(app, event)
             data=app.UITable.Data;
             
            data(:,1)={false};
             
             app.UITable.Data=data;
        end

        % Button pushed function: ApplyselectedsettingstoallButton
        function ApplyselectedsettingstoallButtonPushed(app, event)
             data=app.UITable.Data;
             
             selectedfovs=find(cellfun(@(x) x==1,data(:,1)));
             
             if numel(selectedfovs)==0
                 uialert(app.ClassifydataUIFigure,'No position was selected','Error');
             end
             
             for i=1:size(data,1)
                 
                 if i~=selectedfovs(1)
                     
                     data(i,4:end)=data(selectedfovs(1),4:end);
                     
                 end
             end
             
             app.UITable.Data=data;
        end

        % Value changed function: ChannelListBox
        function ChannelListBoxValueChanged(app, event)
            
            value = app.ChannelListBox.Value;     % cellstr des channels sélectionnés
    selcel = app.UITable.UserData;        % [row col] de la cellule sélectionnée dans la table

    if isempty(selcel)
        return
    end

    % Concaténer les channels sélectionnés avec des virgules
    if isempty(value)
        cha = '';
    else
        cha = strjoin(value, ',');
    end

    % Écrire dans la colonne 5 ("Select classification input channel(s)")
    app.UITable.Data{selcel(1), 5} = cha;
            
            
        end

        % Cell selection callback: UITable
        function UITableCellSelection(app, event)
   
    indices = event.Indices;

    if isempty(indices)
        return
    end

    row = indices(1);
    app.UITable.UserData = indices;

    Data        = app.UITable.Data;
    projectlist = app.Data.tobeclassified_varstr;

    % Objet correspondant à la ligne sélectionnée
    obj = evalin('base', projectlist{row});

    % ---- Déterminer les ROIs à considérer (colonne 6) ----
    roiIdx = 1:numel(obj.roi);
    roiStr = Data{row, 6};

    if ~isempty(roiStr)
        tmpIdx = str2num(roiStr); %#ok<ST2NM>
        if ~isempty(tmpIdx)
            roiIdx = tmpIdx(tmpIdx >= 1 & tmpIdx <= numel(obj.roi));
        end
    end

    % ---- Construire la liste de channels comme union sur toutes ces ROIs ----
    allCha = {};

    for k = roiIdx
        tmpRoi = obj.roi(k);
        if numel(tmpRoi) > 1
            tmpRoi = tmpRoi(1);
        end

        % Sécuriser display (évite comma‑separated list)
        dispStruct = [];
        try
            dispStruct = tmpRoi.display;
        catch
            dispStruct = [];
        end
        if isempty(dispStruct)
            continue
        end
        if numel(dispStruct) > 1
            dispStruct = dispStruct(1);
        end
        if ~isfield(dispStruct,'channel')
            continue
        end

        cha_k = dispStruct.channel;
        if isempty(cha_k)
            continue
        end
        if ischar(cha_k)
            cha_k = {cha_k};
        end

        allCha = [allCha, cha_k(:)']; %#ok<AGROW>
    end

    % Supprimer doublons en conservant l'ordre
    allCha = unique(allCha, 'stable');

    if isempty(allCha)
        app.ChannelListBox.Items  = {};
        app.ChannelListBox.Value  = {};
        app.ChannelListBox.Enable = 'off';
        return
    end

    % Remplir la listbox
    app.ChannelListBox.Items  = allCha;
    app.ChannelListBox.Enable = 'on';

    % ---- Pré-sélectionner les channels déjà choisis (colonne 5) ----
    selcha = Data{row, 5};
    if isempty(selcha)
        app.ChannelListBox.Value = {};
        return
    end

    tokens = strtrim(strsplit(selcha, ','));
    tokens = tokens(ismember(tokens, allCha));

    app.ChannelListBox.Value = tokens;


        end

        % Value changed function: OuputnameEditField
        function OuputnameEditFieldValueChanged(app, event)
             % Mark as user-edited if different from last auto value
    v = string(app.OuputnameEditField.Value);

    if ~isfield(app.Data,'lastAutoOutputName')
        app.Data.lastAutoOutputName = "";
    end
    if ~isfield(app.Data,'outputNameUserEdited')
        app.Data.outputNameUserEdited = false;
    end

    if strlength(strtrim(v))==0
        % empty => consider as not edited, will fallback to auto later
        app.Data.outputNameUserEdited = false;
        return
    end

    if v ~= string(app.Data.lastAutoOutputName)
        app.Data.outputNameUserEdited = true;
    else
        app.Data.outputNameUserEdited = false;
    end
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ClassifydataUIFigure and hide until all components are created
            app.ClassifydataUIFigure = uifigure('Visible', 'off');
            app.ClassifydataUIFigure.Position = [100 100 987 611];
            app.ClassifydataUIFigure.Name = 'Classify data';
            app.ClassifydataUIFigure.CloseRequestFcn = createCallbackFcn(app, @ClassifydataUIFigureCloseRequest, true);

            % Create SelectclassfiermodelDropDownLabel
            app.SelectclassfiermodelDropDownLabel = uilabel(app.ClassifydataUIFigure);
            app.SelectclassfiermodelDropDownLabel.HorizontalAlignment = 'right';
            app.SelectclassfiermodelDropDownLabel.Position = [12 580 129 22];
            app.SelectclassfiermodelDropDownLabel.Text = 'Select classfier/model: ';

            % Create SelectclassfiermodelDropDown
            app.SelectclassfiermodelDropDown = uidropdown(app.ClassifydataUIFigure);
            app.SelectclassfiermodelDropDown.ValueChangedFcn = createCallbackFcn(app, @SelectclassfiermodelDropDownValueChanged, true);
            app.SelectclassfiermodelDropDown.Position = [148 580 249 22];

            % Create UITable
            app.UITable = uitable(app.ClassifydataUIFigure);
            app.UITable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITable.RowName = {};
            app.UITable.CellSelectionCallback = createCallbackFcn(app, @UITableCellSelection, true);
            app.UITable.Position = [19 66 959 341];

            % Create ClassifyselecteddataButton
            app.ClassifyselecteddataButton = uibutton(app.ClassifydataUIFigure, 'push');
            app.ClassifyselecteddataButton.ButtonPushedFcn = createCallbackFcn(app, @ClassifyselecteddataButtonPushed, true);
            app.ClassifyselecteddataButton.Position = [18 17 642 34];
            app.ClassifyselecteddataButton.Text = 'Classify selected data';

            % Create CancelButton
            app.CancelButton = uibutton(app.ClassifydataUIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Position = [685 17 269 34];
            app.CancelButton.Text = 'Cancel';

            % Create SelectchannelnamesforselectedtableitemLabel
            app.SelectchannelnamesforselectedtableitemLabel = uilabel(app.ClassifydataUIFigure);
            app.SelectchannelnamesforselectedtableitemLabel.HorizontalAlignment = 'right';
            app.SelectchannelnamesforselectedtableitemLabel.Position = [465 497 249 22];
            app.SelectchannelnamesforselectedtableitemLabel.Text = 'Select channel names for selected table item:';

            % Create ChannelListBox
            app.ChannelListBox = uilistbox(app.ClassifydataUIFigure);
            app.ChannelListBox.Multiselect = 'on';
            app.ChannelListBox.ValueChangedFcn = createCallbackFcn(app, @ChannelListBoxValueChanged, true);
            app.ChannelListBox.Position = [469 417 249 74];
            app.ChannelListBox.Value = {'Item 1'};

            % Create SelecttableitemstoclassifyPanel
            app.SelecttableitemstoclassifyPanel = uipanel(app.ClassifydataUIFigure);
            app.SelecttableitemstoclassifyPanel.Title = 'Select table items to classify:';
            app.SelecttableitemstoclassifyPanel.Position = [20 416 437 66];

            % Create SelectallButton
            app.SelectallButton = uibutton(app.SelecttableitemstoclassifyPanel, 'push');
            app.SelectallButton.ButtonPushedFcn = createCallbackFcn(app, @SelectallButtonPushed, true);
            app.SelectallButton.Position = [12 13 83 22];
            app.SelectallButton.Text = 'Select all';

            % Create DeselectallButton
            app.DeselectallButton = uibutton(app.SelecttableitemstoclassifyPanel, 'push');
            app.DeselectallButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectallButtonPushed, true);
            app.DeselectallButton.Position = [118 13 78 22];
            app.DeselectallButton.Text = 'Deselect all';

            % Create ApplyselectedsettingstoallButton
            app.ApplyselectedsettingstoallButton = uibutton(app.SelecttableitemstoclassifyPanel, 'push');
            app.ApplyselectedsettingstoallButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyselectedsettingstoallButtonPushed, true);
            app.ApplyselectedsettingstoallButton.Position = [223 13 167 22];
            app.ApplyselectedsettingstoallButton.Text = 'Apply selected settings to all';

            % Create ClassifiervalidationoptionsPanel
            app.ClassifiervalidationoptionsPanel = uipanel(app.ClassifydataUIFigure);
            app.ClassifiervalidationoptionsPanel.Title = 'Classifier validation options';
            app.ClassifiervalidationoptionsPanel.Position = [469 525 475 77];

            % Create ClassifyonlyROIswithGTCheckBox
            app.ClassifyonlyROIswithGTCheckBox = uicheckbox(app.ClassifiervalidationoptionsPanel);
            app.ClassifyonlyROIswithGTCheckBox.Text = 'Classify only ROIs with GT';
            app.ClassifyonlyROIswithGTCheckBox.Position = [10 28 165 22];

            % Create UseadditionalCNNclassificationforLSTMmodelsCheckBox
            app.UseadditionalCNNclassificationforLSTMmodelsCheckBox = uicheckbox(app.ClassifiervalidationoptionsPanel);
            app.UseadditionalCNNclassificationforLSTMmodelsCheckBox.Text = 'Use additional CNN classification for LSTM models';
            app.UseadditionalCNNclassificationforLSTMmodelsCheckBox.Position = [180 28 298 22];

            % Create ClassifyallROIsoveridesROItableselectionCheckBox
            app.ClassifyallROIsoveridesROItableselectionCheckBox = uicheckbox(app.ClassifiervalidationoptionsPanel);
            app.ClassifyallROIsoveridesROItableselectionCheckBox.Text = 'Classify all ROIs (overides ROI table selection)';
            app.ClassifyallROIsoveridesROItableselectionCheckBox.Position = [10 2 275 22];

            % Create LogpredGTstatsinrundirCheckBox
            app.LogpredGTstatsinrundirCheckBox = uicheckbox(app.ClassifiervalidationoptionsPanel);
            app.LogpredGTstatsinrundirCheckBox.Text = 'Log pred/GT stats in run dir';
            app.LogpredGTstatsinrundirCheckBox.Position = [297 2 168 22];

            % Create ClassificationoptionsPanel
            app.ClassificationoptionsPanel = uipanel(app.ClassifydataUIFigure);
            app.ClassificationoptionsPanel.Title = 'Classification options';
            app.ClassificationoptionsPanel.Position = [21 488 437 85];

            % Create ParallelROIs
            app.ParallelROIs = uicheckbox(app.ClassificationoptionsPanel);
            app.ParallelROIs.Text = 'Parallel computing';
            app.ParallelROIs.Position = [9 35 121 22];

            % Create ProcessallframesoveridesframestableselectionCheckBox
            app.ProcessallframesoveridesframestableselectionCheckBox = uicheckbox(app.ClassificationoptionsPanel);
            app.ProcessallframesoveridesframestableselectionCheckBox.Text = 'Process all frames (overides frames table selection)';
            app.ProcessallframesoveridesframestableselectionCheckBox.Position = [9 9 302 22];

            % Create ExecutionenvironmentDropDownLabel
            app.ExecutionenvironmentDropDownLabel = uilabel(app.ClassificationoptionsPanel);
            app.ExecutionenvironmentDropDownLabel.HorizontalAlignment = 'right';
            app.ExecutionenvironmentDropDownLabel.Position = [176 35 127 22];
            app.ExecutionenvironmentDropDownLabel.Text = 'Execution environment';

            % Create ExecutionenvironmentDropDown
            app.ExecutionenvironmentDropDown = uidropdown(app.ClassificationoptionsPanel);
            app.ExecutionenvironmentDropDown.Items = {'CPU', 'GPU'};
            app.ExecutionenvironmentDropDown.Position = [318 35 100 22];
            app.ExecutionenvironmentDropDown.Value = 'GPU';

            % Create OuputnameEditFieldLabel
            app.OuputnameEditFieldLabel = uilabel(app.ClassifydataUIFigure);
            app.OuputnameEditFieldLabel.HorizontalAlignment = 'right';
            app.OuputnameEditFieldLabel.Position = [727 467 74 22];
            app.OuputnameEditFieldLabel.Text = 'Ouput name:';

            % Create OuputnameEditField
            app.OuputnameEditField = uieditfield(app.ClassifydataUIFigure, 'text');
            app.OuputnameEditField.ValueChangedFcn = createCallbackFcn(app, @OuputnameEditFieldValueChanged, true);
            app.OuputnameEditField.Position = [816 467 157 22];

            % Show the figure after all components are created
            app.ClassifydataUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = classifyDataGUI(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ClassifydataUIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ClassifydataUIFigure)
        end
    end
end
