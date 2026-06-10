classdef detecdiv < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        DetecDivUIFigure               matlab.ui.Figure
        FileMenu                       matlab.ui.container.Menu
        NewprojectMenu                 matlab.ui.container.Menu
        OpenprojectMenu                matlab.ui.container.Menu
        OpenrecentMenu                 matlab.ui.container.Menu
        Item1Menu                      matlab.ui.container.Menu
        SaveselectedprojectMenu        matlab.ui.container.Menu
        Closeproject                   matlab.ui.container.Menu
        ExportprojecttoPhylocellMenu   matlab.ui.container.Menu
        NewprojectindependentclassiiferMenu  matlab.ui.container.Menu
        OpenprojectindependentclassifierMenu  matlab.ui.container.Menu
        OpenrecentClassiMenu           matlab.ui.container.Menu
        SaveprojectindependentclassifierMenu  matlab.ui.container.Menu
        CloseprojectindependentclassifierMenu  matlab.ui.container.Menu
        ClassifierRepositoryMenu       matlab.ui.container.Menu
        ConvertoldtrainingandresultdataMenu  matlab.ui.container.Menu
        PipelineTemplatesMenu          matlab.ui.container.Menu
        NewpipelinetemplateMenu        matlab.ui.container.Menu
        OpenpipelinetemplateMenu       matlab.ui.container.Menu
        OpenrecentPipelineMenu         matlab.ui.container.Menu
        ClosepipelinetemplateMenu      matlab.ui.container.Menu
        FunctionsMenu                  matlab.ui.container.Menu
        ClassifyDataMenu               matlab.ui.container.Menu
        ProcessdataMenu                matlab.ui.container.Menu
        ExportdataMenu                 matlab.ui.container.Menu
        MakeROImoviesMenu              matlab.ui.container.Menu
        ProjectMenu                    matlab.ui.container.Menu
        PositionsMenu                  matlab.ui.container.Menu
        AddPositionsDataMenu           matlab.ui.container.Menu
        SetFrameOrientationMenu        matlab.ui.container.Menu
        CreateFullFrameROisMenu        matlab.ui.container.Menu
        DeleteROIsMenu                 matlab.ui.container.Menu
        AdjustROIsMenu                 matlab.ui.container.Menu
        DeletePositionsMenu_2          matlab.ui.container.Menu
        RestoredeletedROIsMenu         matlab.ui.container.Menu
        ClassifiersMenu                matlab.ui.container.Menu
        AddclassifierMenu              matlab.ui.container.Menu
        DeleteclassifierMenu           matlab.ui.container.Menu
        AdjustROIsMenu_3               matlab.ui.container.Menu
        DeleteROIsMenu_2               matlab.ui.container.Menu
        RestoredeletedROIsMenu_2       matlab.ui.container.Menu
        AdjustROIsMenu_2               matlab.ui.container.Menu
        DisplayMenu                    matlab.ui.container.Menu
        RefreshtreewindowMenu          matlab.ui.container.Menu
        SettingsMenu                   matlab.ui.container.Menu
        UserpreferencesMenu            matlab.ui.container.Menu
        ProjectsPanel                  matlab.ui.container.Panel
        OpenButton                     matlab.ui.control.Button
        ProcessdataButton              matlab.ui.control.Button
        AddprocessorButton             matlab.ui.control.Button
        ClassifydataButton             matlab.ui.control.Button
        UpdaterawdatapathButton        matlab.ui.control.Button
        ExtractROIhypervolumesButton   matlab.ui.control.Button
        IdentifyROIsinpositionsButton  matlab.ui.control.Button
        ProjectInformationLabel        matlab.ui.control.Label
        AddclassifierButton            matlab.ui.control.Button
        AdddataButton                  matlab.ui.control.Button
        UIAxes                         matlab.ui.control.UIAxes
        Tree                           matlab.ui.container.Tree
        ProjectsNode                   matlab.ui.container.TreeNode
        IndependentClassifiersNode     matlab.ui.container.TreeNode
        PipelinesNode                  matlab.ui.container.TreeNode
    end


    properties (Access = private)
        Data % Description
        RecentProjects string = strings(0)  % liste des chemins absolus récents
        RecentProjectsFile string          % chemin complet du .mat persistant
        RecentClassifiers string = strings(0)    % chemins complets vers *_classification.mat
        RecentClassifiersFile string             % stockage persistant
        RecentPipelines string = strings(0)      % chemins complets vers pipeline.json
        RecentPipelinesFile string               % stockage persistant
        MainGrid matlab.ui.container.GridLayout
        WorkspaceEventListenerId string = ""

    end

    methods (Access = public)

        function displayNodes(app)
            cc=1;
            %h1=[];
            %hproj=[];
            %hclassi=[];

            t=app.ProjectsNode.Children;
            t.delete;
            t=app.IndependentClassifiersNode.Children;
            t.delete;
            t=app.PipelinesNode.Children;
            t.delete;

            [pth fle ext]= fileparts(which('detecdiv.mlapp'));

            projectPipelineIdx = cell(1, numel(app.Data.Project));
            pipelineProjectIdx = cell(1, numel(app.Data.Pipeline));
            for iPipe = 1:numel(app.Data.Pipeline)
                if isempty(app.Data.Pipeline{iPipe})
                    continue;
                end
                [~, projectIdx] = app.findLinkedProjectIndicesForPipeline(getPipelineByIndex(iPipe));
                if isempty(projectIdx)
                    continue;
                end
                pipelineProjectIdx{iPipe} = projectIdx;
                for j = 1:numel(projectIdx)
                    pIdx = projectIdx(j);
                    if pIdx >= 1 && pIdx <= numel(projectPipelineIdx)
                        projectPipelineIdx{pIdx}(end+1) = iPipe; %#ok<AGROW>
                    end
                end
            end

            for i=1:numel(app.Data.Project)
                h1(i)=uitreenode(app.ProjectsNode,'Text',app.Data.Project{i},'Tag','Project','UserData',i,'Icon',fullfile(pth,'detecDiv_logo.png'));


                for k=1:numel(app.Data.Projectclassi{i})
                    cm=uicontextmenu(app.DetecDivUIFigure);
                    m = uimenu(cm,'Text','Open classifier...');
                    m.MenuSelectedFcn={@contextMenuClassiFcn,[i,k],'Projectclassi'};
                    m = uimenu(cm,'Text','Delete classifier');
                    m.MenuSelectedFcn={@contextMenuDeleteClassiFcn,[i,k],'Projectclassi'};
                    m = uimenu(cm,'Text','Delete ROIs...');
                    m.MenuSelectedFcn={@contextMenuDeleteROIsFcn,[i,k],'Projectclassi'};

                    g1(i,k)=uitreenode(h1(i),'Text',app.Data.Projectclassi{i}{k},'Tag','Projectclassi','UserData',[i,k],'ContextMenu',cm,'Icon',fullfile(pth,'brain.png'));


                    %                  if numel(app.Data.Projectclassirois{i})
                    %                    for n=1:numel(app.Data.Projectclassirois{i}{k})
                    %                       % aa=app.Data.Projectclassirois{i}{k}{n}
                    %                       cm=uicontextmenu(app.DetecDivUIFigure);
                    %                     m = uimenu(cm,'Text','Open ROI...');
                    %                     m.MenuSelectedFcn={@contextMenuROIFcn,[i,k,n],'Projectclassirois'};
                    %                     ''ContextMenu',cm'
                    %                   uitreenode(g1(i,k),'Text',app.Data.Projectclassirois{i}{k}{n},'Tag','Projectclassirois','UserData',[i,k,n],'Icon',fullfile(pth,'roi.png'));
                    %                                     % disabled because too heavy with large projects
                    %                   end
                    %                 end


                end

                for k=1:numel(app.Data.Projectprocess{i})
                    cm=uicontextmenu(app.DetecDivUIFigure);
                    m = uimenu(cm,'Text','Open processor...');
                    m.MenuSelectedFcn={@contextMenuProcessFcn,[i,k],'Projectprocess'};
                    m = uimenu(cm,'Text','Duplicate processor...');
                    m.MenuSelectedFcn = {@contextMenuDuplicateProcessFcn,[i,k],'Projectprocess'};
                    m = uimenu(cm,'Text','Delete processor');
                    m.MenuSelectedFcn={@contextMenuDeleteProcessFcn,[i,k],'Projectprocess'};
                    g1(i,k)=uitreenode(h1(i),'Text',app.Data.Projectprocess{i}{k},'Tag','Projectprocess','UserData',[i,k],'ContextMenu',cm,'Icon',fullfile(pth,'processor.png'));


                    %                  if numel(app.Data.Projectclassirois{i})
                    %                    for n=1:numel(app.Data.Projectclassirois{i}{k})
                    %                       % aa=app.Data.Projectclassirois{i}{k}{n}
                    %                       cm=uicontextmenu(app.DetecDivUIFigure);
                    %                     m = uimenu(cm,'Text','Open ROI...');
                    %                     m.MenuSelectedFcn={@contextMenuROIFcn,[i,k,n],'Projectclassirois'};
                    %                     ''ContextMenu',cm'
                    %                   uitreenode(g1(i,k),'Text',app.Data.Projectclassirois{i}{k}{n},'Tag','Projectclassirois','UserData',[i,k,n],'Icon',fullfile(pth,'roi.png'));
                    %                                     % disabled because too heavy with large projects
                    %                   end
                    %                 end


                end




                for k=1:numel(app.Data.Projectpos{i})
                    cm=uicontextmenu(app.DetecDivUIFigure);
                    m = uimenu(cm,'Text','Open position...');
                    m.MenuSelectedFcn={@contextMenuPositionFcn,[i,k],'Projectpos'};
                    m = uimenu(cm,'Text','Delete ROIs...');
                    m.MenuSelectedFcn={@contextMenuDeleteROIsFcn,[i,k],'Projectpos'};
                    m = uimenu(cm,'Text','Delete current position');
                    m.MenuSelectedFcn={@contextMenuDeletePositionFcn,[i,k],'Projectpos'};

                    g2(i,k)=uitreenode(h1(i),'Text',app.Data.Projectpos{i}{k},'Tag','Projectpos','UserData',[i,k],'ContextMenu',cm,'Icon',fullfile(pth,'data.png'));

                    %                      if numel(app.Data.Projectposrois{i})
                    %
                    %                     for n=1:numel(app.Data.Projectposrois{i}{k})
                    %                       % aa=app.Data.Projectclassirois{i}{k}{n}
                    %                    %   cm=uicontextmenu(app.DetecDivUIFigure);
                    %                   %  m = uimenu(cm,'Text','Open ROI...');
                    %                   %  m.MenuSelectedFcn={@contextMenuROIFcn,[i,k,n],'Projectposrois'};
                    %
                    %                 %        uitreenode(g2(i,k),'Text',app.Data.Projectposrois{i}{k}{n},'Tag','Projectposrois','UserData',[i,k,n],'Icon',fullfile(pth,'roi.png'));
                    %                       % disabled because too heavy with large projects
                    %                     end
                    %                      end

                end

                if i <= numel(app.Data.ProjectpipelineRun) && ~isempty(app.Data.ProjectpipelineRun{i})
                    runRoot = uitreenode(h1(i),'Text','Run','Tag','ProjectpipelineRunRoot', ...
                        'UserData',i,'Icon',fullfile(pth,'pipeline_run.png'));
                    for k=1:numel(app.Data.ProjectpipelineRun{i})
                        createPipelineRunTreeNode(runRoot, i, k, pth);
                    end
                end

                if i <= numel(projectPipelineIdx) && ~isempty(projectPipelineIdx{i})
                    for k = 1:numel(projectPipelineIdx{i})
                        createPipelineTreeNode(h1(i), projectPipelineIdx{i}(k), pth);
                    end
                end
            end

            for i=1:numel(app.Data.Pipeline)
                if isempty(app.Data.Pipeline{i})
                    continue;
                end
                if i <= numel(pipelineProjectIdx) && ~isempty(pipelineProjectIdx{i})
                    continue;
                end
                createPipelineTreeNode(app.PipelinesNode, i, pth);
            end

            for i=1:numel(app.Data.Classifier)
                cm=uicontextmenu(app.DetecDivUIFigure);
                m = uimenu(cm,'Text','Open classifier...');
                m.MenuSelectedFcn={@contextMenuClassiFcn,i,'Classifier'};
                m = uimenu(cm,'Text','Close classifier');
                m.MenuSelectedFcn={@contextMenuDeleteClassiFcn,i,'Classifier'};
                m = uimenu(cm,'Text','Delete ROIs...');
                m.MenuSelectedFcn={@contextMenuDeleteROIsFcn,i,'Classifier'};

                g3(i)=uitreenode(app.IndependentClassifiersNode,'Text',app.Data.Classifier{i},'Tag','Classifier','UserData',i,'ContextMenu',cm,'Icon',fullfile(pth,'brain.png'));

                %                if numel(app.Data.Classifierrois{i})

                %                    for n=1:numel(app.Data.Classifierrois{i})
                %                       % aa=app.Data.Projectclassirois{i}{k}{n}
                %                       cm=uicontextmenu(app.DetecDivUIFigure);
                %                     m = uimenu(cm,'Text','Open ROI...');
                %                     m.MenuSelectedFcn={@contextMenuROIFcn,[i,n],'Projectposrois'};
                %                     'ContextMenu',cm
                %          uitreenode(g3(i),'Text',app.Data.Projectclassirois{i}{n},'Tag','Classifierrois','UserData',[i,n],'Icon',fullfile(pth,'roi.png'));
                %                                       % disabled because too heavy with large projects
                %                     end
                %                end


            end

            expand(app.ProjectsNode);
            expand(app.IndependentClassifiersNode);
            expand(app.PipelinesNode);

            function pNode = createPipelineTreeNode(parentNode, pipeIdx, pth)
                pNode = [];
                if pipeIdx > numel(app.Data.Pipeline) || isempty(app.Data.Pipeline{pipeIdx})
                    return;
                end

                cm=uicontextmenu(app.DetecDivUIFigure);
                m = uimenu(cm,'Text','Open pipeline...');
                m.MenuSelectedFcn={@contextMenuPipelineFcn,pipeIdx,'Pipeline'};
                m = uimenu(cm,'Text','Add module...');
                m.MenuSelectedFcn={@contextMenuAddPipelineModuleFcn,pipeIdx,'Pipeline'};
                m = uimenu(cm,'Text','Save pipeline');
                m.MenuSelectedFcn={@contextMenuSavePipelineFcn,pipeIdx,'Pipeline'};
                m = uimenu(cm,'Text','Create run...');
                m.MenuSelectedFcn={@contextMenuCreatePipelineRunFcn,pipeIdx,'Pipeline'};
                m = uimenu(cm,'Text','Open pipeline.json...');
                m.MenuSelectedFcn={@contextMenuOpenPipelineJsonFcn,pipeIdx,'Pipeline'};
                m = uimenu(cm,'Text','Close pipeline');
                m.MenuSelectedFcn={@contextMenuClosePipelineFcn,pipeIdx,'Pipeline'};
                m = uimenu(cm,'Text','Delete pipeline folder');
                m.MenuSelectedFcn={@contextMenuDeletePipelineFcn,pipeIdx,'Pipeline'};

                pNode=uitreenode(parentNode,'Text',app.Data.Pipeline{pipeIdx},'Tag','Pipeline','UserData',pipeIdx, ...
                    'ContextMenu',cm,'Icon',fullfile(pth,'pipeline.png'));

                if pipeIdx <= numel(app.Data.PipelineModules) && ~isempty(app.Data.PipelineModules{pipeIdx})
                    for k=1:numel(app.Data.PipelineModules{pipeIdx})
                        moduleType = '';
                        if pipeIdx <= numel(app.Data.PipelineModuleTypes) && ~isempty(app.Data.PipelineModuleTypes{pipeIdx}) && k <= numel(app.Data.PipelineModuleTypes{pipeIdx})
                            moduleType = app.Data.PipelineModuleTypes{pipeIdx}{k};
                        end
                        iconFile = getPipelineModuleIcon(moduleType);

                        uitreenode(pNode,'Text',app.Data.PipelineModules{pipeIdx}{k},'Tag','PipelineModule','UserData',[pipeIdx,k], ...
                            'Icon',fullfile(pth,iconFile));
                    end
                end
            end

            function runNode = createPipelineRunTreeNode(parentNode, projIdx, runIdx, pth)
                runNode = [];
                if projIdx > numel(app.Data.ProjectpipelineRun) || runIdx > numel(app.Data.ProjectpipelineRun{projIdx})
                    return;
                end

                cm=uicontextmenu(app.DetecDivUIFigure);
                m = uimenu(cm,'Text','Run locally...');
                m.MenuSelectedFcn={@contextMenuRunPipelineRunFcn,[projIdx,runIdx],'ProjectpipelineRun'};
                m = uimenu(cm,'Text','Run on hub...');
                m.MenuSelectedFcn={@contextMenuRunPipelineRunOnHubFcn,[projIdx,runIdx],'ProjectpipelineRun'};
                m = uimenu(cm,'Text','Refresh hub status');
                m.MenuSelectedFcn={@contextMenuRefreshPipelineRunHubStatusFcn,[projIdx,runIdx],'ProjectpipelineRun'};
                m = uimenu(cm,'Text','Cancel hub job');
                m.MenuSelectedFcn={@contextMenuCancelPipelineRunHubJobFcn,[projIdx,runIdx],'ProjectpipelineRun'};
                m = uimenu(cm,'Text','Open run.json...');
                m.MenuSelectedFcn={@contextMenuOpenPipelineRunFcn,[projIdx,runIdx],'ProjectpipelineRun'};
                m = uimenu(cm,'Text','Delete run');
                m.MenuSelectedFcn={@contextMenuDeletePipelineRunFcn,[projIdx,runIdx],'ProjectpipelineRun'};

                runNode=uitreenode(parentNode,'Text',app.formatPipelineRunLabel(app.getProjectRunByIndex(projIdx, runIdx), runIdx), ...
                    'Tag','ProjectpipelineRun', ...
                    'UserData',[projIdx,runIdx],'ContextMenu',cm,'Icon',fullfile(pth,'pipeline_run.png'));
            end

            function contextMenuDeleteProcessFcn(src,event,arg,str)

                %               %  str,arg
                cc=arg(1);
                %                 if strcmp(str,'Processor')
                %                      cc=arg(1);
                %                      clas=app.Data.Classifier{cc};
                %                      %clas=evalin('base',clas);
                %
                %                      evalin('base',['clear ' clas]);
                %
                %                 end

                if strcmp(str,'Projectprocess')

                    proj=app.Data.Project{cc(1)};
                    pos=arg(2);
                    shallowObj=evalin('base',proj);
                    clas=shallowObj.processing.processor(pos);
                    n=1:numel(shallowObj.processing.processor);
                    pix=setxor(n,pos);

                    aa=uiconfirm(app.DetecDivUIFigure,'Are you really sure you want to delete this processor?','Warning');
                    if strcmp(aa,'OK')
                        % if numel(pix)

                        rmdir(clas.path,'s')
                        shallowObj.processing.processor=shallowObj.processing.processor(pix);
                        %   else

                        %   end
                    else
                        return;
                    end
                end

                % classifierGUI(clas)
                %    i,k
                RefreshtreewindowMenuSelected(app)
            end

          

function contextMenuDuplicateProcessFcn(src,event,arg,str) %#ok<INUSD>
    if ~strcmp(str,'Projectprocess')
        return;
    end

    proj = app.Data.Project{arg(1)};
    pos  = arg(2);
    shallowObj = evalin('base', proj);

    % ---- purge invalid processors ----
    procList = shallowObj.processing.processor;
    if ~isempty(procList)
        valid = arrayfun(@(p) (~isa(p,'handle')) || isvalid(p), procList);
        if any(~valid)
            procList = procList(valid);
            shallowObj.processing.processor = procList;
        end
    end

    if isempty(procList) || pos > numel(procList)
        uialert(app.DetecDivUIFigure, ...
            'This processor no longer exists (invalid handle). Tree will refresh.', ...
            'Warning','Icon','warning');
        RefreshtreewindowMenuSelected(app);
        return;
    end

    srcProc = procList(pos);

    % ---- propose a default name ----
    defaultName = [srcProc.strid '_copy'];
    answer = inputdlg({'New processor name:'}, 'Duplicate processor', 1, {defaultName});
    if isempty(answer), return; end
    newName = strtrim(answer{1});
    if isempty(newName), return; end

    % ---- avoid duplicate names ----
    existing = arrayfun(@(p) p.strid, procList, 'UniformOutput', false);
    if any(strcmp(existing, newName))
        uialert(app.DetecDivUIFigure, ...
            ['A processor named "' newName '" already exists in this project.'], ...
            'Name conflict','Icon','warning');
        return;
    end

    % ---- create new processor in project ----
    shallowObj.addProcessor('name', newName);
    dstProc = shallowObj.processing.processor(end);

    % ---- copy settings ----
    try, dstProc.processFun  = srcProc.processFun;  end
    try, dstProc.processArg  = srcProc.processArg;  end
    try, dstProc.runProfiles = srcProc.runProfiles; end
    try, dstProc.description = srcProc.description; end
    try, dstProc.category    = srcProc.category;    end

    try
        processSave(dstProc);
    catch ME
        warning('Duplicate processor: save failed: %s', ME.message);
    end

    RefreshtreewindowMenuSelected(app);
end




            function contextMenuDeleteClassiFcn(src,event,arg,str)

               cc = arg(1);

    % ---------------------------------------------------------------------
    % Cas 1 : classifier indépendant dans la base
    % ---------------------------------------------------------------------
    if strcmp(str,'Classifier')
        clas = app.Data.Classifier{cc};
        evalin('base',['clear ' clas]);
    end

    % ---------------------------------------------------------------------
    % Cas 2 : classifier attaché à un projet (shallow)
    % ---------------------------------------------------------------------
    if strcmp(str,'Projectclassi')
        proj = app.Data.Project{cc(1)};
        pos  = arg(2);

        shallowObj = evalin('base',proj);
        clas       = shallowObj.processing.classification(pos);

        n   = 1:numel(shallowObj.processing.classification);
        pix = setxor(n,pos);

        % confirmation utilisateur
        aa = uiconfirm(app.DetecDivUIFigure, ...
            'Are you really sure you want to delete the classifier?', ...
            'Warning');

        if ~strcmp(aa,'OK')
            return;
        end

        % -----------------------------------------------------------------
        % � Suppression sécurisée du dossier associé à ce classifier
        % -----------------------------------------------------------------
        classiPath = clas.path;

        if ~isempty(classiPath) && ischar(classiPath) && exist(classiPath,'dir')
            try
                rmdir(classiPath, 's');
            catch ME
                warning(['Could not delete classifier folder at: ' classiPath ...
                         '  | Reason: ' ME.message]);
            end
        else
            % Optionnel : avertir si le dossier n’existe pas
            disp(['[Info] Classifier folder does not exist or is invalid: ' char(classiPath)]);
        end

        % Mise à jour du shallowObj
        shallowObj.processing.classification = ...
            shallowObj.processing.classification(pix);
    end

    % Rafraîchissement de l’arbre
    RefreshtreewindowMenuSelected(app)

            end

            function contextMenuClassiFcn(src,event,arg,str)

                %  str,arg
                cc=arg(1);
                if strcmp(str,'Classifier')
                    cc=arg(1);
                    clas=app.Data.Classifier{cc};
                    clas=evalin('base',clas);
                end
                if strcmp(str,'Projectclassi')
                    proj=app.Data.Project{cc(1)};
                    pos=arg(2);
                    shallowObj=evalin('base',proj);
                    clas=shallowObj.processing.classification(pos);
                end

                classifierGUI(clas)
                %    i,k
            end
            function contextMenuProcessFcn(src,event,arg,str)

    cc = arg(1);

    if strcmp(str,'Projectprocess')
        proj = app.Data.Project{cc(1)};
        pos  = arg(2);
        shallowObj = evalin('base', proj);
        proc = shallowObj.processing.processor(pos);

        processDataGUI(shallowObj, proc);
    end

end

            function contextMenuPipelineFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'Pipeline')
                    return;
                end
                pipe = getPipelineByIndex(arg(1));
                if isempty(pipe)
                    return;
                end
                try
                    pipelineGUI([], pipe);
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Pipeline GUI error', 'Icon', 'error');
                end
            end

            function contextMenuOpenPipelineModuleFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'PipelineModule')
                    return;
                end
                if numel(arg) < 2
                    return;
                end
                app.openPipelineModuleByIndex(arg(1), arg(2));
            end

            function contextMenuOpenPipelineJsonFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'Pipeline')
                    return;
                end
                pipe = getPipelineByIndex(arg(1));
                if isempty(pipe)
                    return;
                end
                jsonFile = fullfile(pipe.path, 'pipeline.json');
                if ~isfile(jsonFile)
                    try
                        pipelineSave(pipe);
                    catch ME
                        uialert(app.DetecDivUIFigure, ME.message, 'Error', 'Icon', 'error');
                        return;
                    end
                end
                edit(jsonFile);
            end

            function contextMenuSavePipelineFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'Pipeline')
                    return;
                end
                pipe = getPipelineByIndex(arg(1));
                if isempty(pipe)
                    return;
                end
                try
                    pipelineSave(pipe);
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Error', 'Icon', 'error');
                end
            end

            function contextMenuClosePipelineFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'Pipeline')
                    return;
                end
                idx = arg(1);
                if idx > numel(app.Data.Pipeline)
                    return;
                end
                varName = app.Data.Pipeline{idx};
                evalin('base', ['clear ' varName]);
                RefreshtreewindowMenuSelected(app);
            end

            function contextMenuDeletePipelineFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'Pipeline')
                    return;
                end
                idx = arg(1);
                pipe = getPipelineByIndex(idx);
                if isempty(pipe)
                    return;
                end
                choice = uiconfirm(app.DetecDivUIFigure, ...
                    'Delete this pipeline folder from disk? This cannot be undone.', ...
                    'Warning');
                if ~strcmp(choice,'OK')
                    return;
                end

                pipePath = pipe.path;
                try
                    if ~isempty(pipePath) && isfolder(pipePath)
                        rmdir(pipePath, 's');
                    end
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Delete error', 'Icon', 'error');
                    return;
                end

                if idx <= numel(app.Data.Pipeline)
                    evalin('base', ['clear ' app.Data.Pipeline{idx}]);
                end
                RefreshtreewindowMenuSelected(app);
            end

            function contextMenuAddPipelineModuleFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'Pipeline')
                    return;
                end
                pipe = getPipelineByIndex(arg(1));
                if isempty(pipe)
                    return;
                end

                [ok, typeName, pkgName, nodeName] = askPipelineModuleSpec();
                if ~ok
                    return;
                end

                node = buildPipelineNode(typeName, pkgName, nodeName, pipe);
                if isempty(node)
                    uialert(app.DetecDivUIFigure, 'Unknown module type.', 'Error', 'Icon','error');
                    return;
                end

                if isempty(pipe.nodes)
                    pipe.nodes = node;
                else
                    pipe.nodes(end+1) = node;
                end

                try
                    pipelineSave(pipe);
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Save error', 'Icon', 'error');
                    return;
                end

                RefreshtreewindowMenuSelected(app);
            end

            function contextMenuDeletePipelineModuleFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'PipelineModule')
                    return;
                end
                pipe = getPipelineByIndex(arg(1));
                modIdx = arg(2);
                if isempty(pipe) || modIdx > numel(pipe.nodes)
                    return;
                end

                node = pipe.nodes(modIdx);
                nodeId = getStructFieldText(node, 'id', ['node_' num2str(modIdx)]);
                choice = uiconfirm(app.DetecDivUIFigure, ...
                    ['Delete module ' nodeId ' from pipeline?'], 'Warning');
                if ~strcmp(choice,'OK')
                    return;
                end

                pipe.nodes(modIdx) = [];
                if isprop(pipe,'edges') && ~isempty(pipe.edges)
                    keep = true(1, numel(pipe.edges));
                    for e = 1:numel(pipe.edges)
                        fromVal = getStructFieldText(pipe.edges(e), 'from', '');
                        toVal   = getStructFieldText(pipe.edges(e), 'to', '');

                        if strcmp(fromVal, nodeId) || strcmp(toVal, nodeId)
                            keep(e) = false;
                            continue;
                        end

                        if isfield(pipe.edges(e),'from') && isnumeric(pipe.edges(e).from)
                            if pipe.edges(e).from == modIdx
                                keep(e) = false;
                            elseif pipe.edges(e).from > modIdx
                                pipe.edges(e).from = pipe.edges(e).from - 1;
                            end
                        end
                        if isfield(pipe.edges(e),'to') && isnumeric(pipe.edges(e).to)
                            if pipe.edges(e).to == modIdx
                                keep(e) = false;
                            elseif pipe.edges(e).to > modIdx
                                pipe.edges(e).to = pipe.edges(e).to - 1;
                            end
                        end
                    end
                    pipe.edges = pipe.edges(keep);
                end

                try
                    pipelineSave(pipe);
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Save error', 'Icon', 'error');
                    return;
                end

                RefreshtreewindowMenuSelected(app);
            end

            function contextMenuCreatePipelineRunFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'Pipeline')
                    return;
                end
                pipe = getPipelineByIndex(arg(1));
                if isempty(pipe)
                    return;
                end
                try
                    pipelineRunGUI(pipe);
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Run GUI error', 'Icon', 'error');
                end
            end

            function contextMenuOpenPipelineRunFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'ProjectpipelineRun')
                    return;
                end
                runObj = getProjectRunByIndex(arg(1), arg(2));
                if isempty(runObj)
                    return;
                end
                runJson = fullfile(runObj.path, 'run.json');
                if isfile(runJson)
                    edit(runJson);
                else
                    uialert(app.DetecDivUIFigure, 'run.json not found for this run.', 'Warning', 'Icon','warning');
                end
            end

            function contextMenuDeletePipelineRunFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'ProjectpipelineRun')
                    return;
                end
                projIdx = arg(1);
                runIdx = arg(2);
                if projIdx > numel(app.Data.Project)
                    return;
                end

                projVar = app.Data.Project{projIdx};
                shallowObj = evalin('base', projVar);
                if ~isfield(shallowObj.processing,'pipelineRun') || runIdx > numel(shallowObj.processing.pipelineRun)
                    return;
                end

                runObj = shallowObj.processing.pipelineRun(runIdx);
                choice = uiconfirm(app.DetecDivUIFigure, ...
                    ['Delete run ' runObj.runId '?'], 'Warning');
                if ~strcmp(choice,'OK')
                    return;
                end

                try
                    if ~isempty(runObj.path) && isfolder(runObj.path)
                        rmdir(runObj.path, 's');
                    end
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Delete error', 'Icon', 'error');
                    return;
                end

                keep = setxor(1:numel(shallowObj.processing.pipelineRun), runIdx);
                if isempty(keep)
                    shallowObj.processing.pipelineRun = pipelineRun.empty;
                else
                    shallowObj.processing.pipelineRun = shallowObj.processing.pipelineRun(keep);
                end
                RefreshtreewindowMenuSelected(app);
            end

            function contextMenuRunPipelineRunFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'ProjectpipelineRun')
                    return;
                end
                executeProjectPipelineRun(arg(1), arg(2));
            end

            function contextMenuRunPipelineRunOnHubFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'ProjectpipelineRun')
                    return;
                end
                submitProjectPipelineRunToHub(arg(1), arg(2));
            end

            function contextMenuRefreshPipelineRunHubStatusFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'ProjectpipelineRun')
                    return;
                end
                refreshProjectPipelineRunHubStatus(arg(1), arg(2), true);
            end

            function contextMenuCancelPipelineRunHubJobFcn(src,event,arg,str) %#ok<INUSD>
                if ~strcmp(str,'ProjectpipelineRun')
                    return;
                end
                cancelProjectPipelineRunHubJob(arg(1), arg(2));
            end

            function pipe = getPipelineByIndex(idx)
                pipe = [];
                if idx > numel(app.Data.Pipeline)
                    return;
                end
                varName = app.Data.Pipeline{idx};
                try
                    pipe = evalin('base', varName);
                catch
                    pipe = [];
                end
                if ~isa(pipe,'pipeline')
                    pipe = [];
                end
            end

            function label = formatPipelineRunLabel(runObj, fallbackIdx)
                label = '';
                try
                    if isprop(runObj,'runId') && ~isempty(runObj.runId)
                        label = char(string(runObj.runId));
                    end
                catch
                end
                if isempty(label)
                    label = ['run_' num2str(fallbackIdx)];
                end
            end

            function [runMode, runStatus] = summarizePipelineRun(runObj)
                runMode = 'local';
                runStatus = 'unknown';

                try
                    if isprop(runObj,'status') && ~isempty(runObj.status)
                        runStatus = char(string(runObj.status));
                    end
                catch
                end

                try
                    if isstruct(runObj.ctx) && isfield(runObj.ctx,'hub') && isstruct(runObj.ctx.hub)
                        runMode = 'hub';
                        if isfield(runObj.ctx.hub,'status') && ~isempty(runObj.ctx.hub.status)
                            runStatus = char(string(runObj.ctx.hub.status));
                        end
                    end
                catch
                end

                if startsWith(runStatus,'hub_')
                    runMode = 'hub';
                    runStatus = extractAfter(runStatus, 4);
                    if isempty(runStatus)
                        runStatus = 'unknown';
                    end
                elseif any(strcmpi(runStatus, {'new','running','done','failed','cancelled'}))
                    if strcmp(runMode, 'local')
                        runMode = 'local';
                    end
                elseif isempty(runStatus)
                    runStatus = 'unknown';
                end
            end

            function [ok,node,pipeObj] = getPipelineNodeByIndex(pipeIdx, modIdx)
                ok = false;
                node = struct();
                pipeObj = [];

                pipeObj = getPipelineByIndex(pipeIdx);
                if isempty(pipeObj) || ~isprop(pipeObj,'nodes') || modIdx > numel(pipeObj.nodes)
                    return;
                end

                node = pipeObj.nodes(modIdx);
                ok = true;
            end

            function [nType, modObj] = buildPipelineModuleObject(node)
                nType = '';
                modObj = [];

                if ~(isstruct(node) && isfield(node,'type') && ~isempty(node.type))
                    return;
                end

                nType = lower(char(string(node.type)));

                if strcmp(nType,'processor')
                    tmpProc = process(tempdir, 'pipeline_module', randi(1e9));

                    pkgName = '';
                    if isfield(node,'pkg') && ~isempty(node.pkg)
                        pkgName = char(string(node.pkg));
                    end

                    if ~isempty(pkgName)
                        tmpProc.processFun = [pkgName '.process'];
                        try
                            p0 = feval([pkgName '.setparam'], struct());
                        catch
                            p0 = struct();
                        end
                        if isstruct(p0)
                            tmpProc.processArg = p0;
                        end
                    elseif isfield(node,'func') && ~isempty(node.func)
                        tmpProc.processFun = char(string(node.func));
                    end

                    if isfield(node,'params') && isstruct(node.params)
                        if isempty(tmpProc.processArg) || ~isstruct(tmpProc.processArg)
                            tmpProc.processArg = node.params;
                        else
                            fn = fieldnames(node.params);
                            for fi = 1:numel(fn)
                                tmpProc.processArg.(fn{fi}) = node.params.(fn{fi});
                            end
                        end
                    end

                    if isfield(node,'id') && ~isempty(node.id)
                        tmpProc.strid = char(string(node.id));
                    end

                    modObj = tmpProc;
                    return;
                end

                if strcmp(nType,'classifier')
                    tmpClassi = classi(tempdir, 'pipeline_module', randi(1e9));

                    if isfield(node,'id') && ~isempty(node.id)
                        tmpClassi.strid = char(string(node.id));
                    end

                    pkgName = '';
                    if isfield(node,'pkg') && ~isempty(node.pkg)
                        pkgName = char(string(node.pkg));
                    end

                    if ~isempty(pkgName)
                        tmpClassi.classifierPkg = pkgName;
                        if isempty(tmpClassi.classifyFun)
                            tmpClassi.classifyFun = [pkgName '.classify'];
                        end
                        if isempty(tmpClassi.trainingFun)
                            tmpClassi.trainingFun = [pkgName '.train'];
                        end

                        if strcmpi(pkgName,'cellposesam')
                            tmpClassi.category = {'Pixel'};
                        elseif strcmpi(pkgName,'cnn_lstm')
                            tmpClassi.category = {'LSTM'};
                        else
                            tmpClassi.category = {'Image'};
                        end
                    else
                        tmpClassi.category = {'Image'};
                    end

                    if isfield(node,'func') && ~isempty(node.func)
                        tmpClassi.classifyFun = char(string(node.func));
                    end

                    if isfield(node,'params') && isstruct(node.params)
                        if isfield(node.params,'classes') && ~isempty(node.params.classes)
                            cls = node.params.classes;
                            if isstring(cls), cls = cellstr(cls); end
                            if ischar(cls), cls = {cls}; end
                            tmpClassi.classes = cls;
                        end
                    end

                    tmpClassi.category = classiNormalizeCategory(tmpClassi.category);
                    modObj = tmpClassi;
                    return;
                end
            end

            function openPipelineModuleByIndex(pipeIdx, modIdx)
                [ok,node,pipeObj] = app.getPipelineNodeByIndex(pipeIdx, modIdx);
                if ~ok
                    return;
                end

                [nType, modObj] = buildPipelineModuleObject(node);
                try
                    switch nType
                        case 'processor'
                            processDataGUI([], modObj);
                        case 'classifier'
                            classifierGUI(modObj);
                        otherwise
                            app.openPipelineWithContext(pipeObj);
                    end
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Module GUI error', 'Icon', 'error');
                end
            end

            function runObj = getProjectRunByIndex(projIdx, runIdx)
                runObj = [];
                if projIdx > numel(app.Data.Project)
                    return;
                end
                projVar = app.Data.Project{projIdx};
                shallowObj = evalin('base', projVar);
                if ~isfield(shallowObj.processing,'pipelineRun') || runIdx > numel(shallowObj.processing.pipelineRun)
                    return;
                end
                runObj = shallowObj.processing.pipelineRun(runIdx);
            end

            function executeProjectPipelineRun(projIdx, runIdx)
                if projIdx > numel(app.Data.Project)
                    return;
                end

                projVar = app.Data.Project{projIdx};
                shallowObj = evalin('base', projVar);
                if ~isfield(shallowObj.processing,'pipelineRun') || runIdx > numel(shallowObj.processing.pipelineRun)
                    return;
                end

                runObj = shallowObj.processing.pipelineRun(runIdx);
                try
                    detecdiv_hub_assert_project_writable(shallowObj);
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Project is read-only', 'Icon', 'warning');
                    return;
                end
                [pipeObj, msg] = resolvePipelineFromRun(runObj, shallowObj);
                if isempty(pipeObj)
                    uialert(app.DetecDivUIFigure, msg, 'Run error', 'Icon', 'error');
                    return;
                end

                [runObj, runChanged] = backfillRunPipelineRef(runObj, pipeObj, shallowObj);
                if runChanged
                    shallowObj.processing.pipelineRun(runIdx) = runObj;
                    assignin('base', projVar, shallowObj);
                    try
                        pipelineRunSave(runObj);
                    catch
                    end
                end

                d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...', ...
                    'Message',['Running pipeline run ' runObj.runId '...']);
                d.Value = 0.2;

                try
                    runObj.status = 'running';
                    pipelineRunSave(runObj);

                    ctx = runObj.ctx;
                    ctx.shallow = shallowObj;
                    ctx.shallowObj = shallowObj;
                    ctx.allowGUI = true;

                    [ctxOut, report] = runPipeline(pipeObj, ctx);

                    runObj.ctx = ctxOut;
                    runObj.outputs = struct('report', report);
                    runObj.status = 'done';
                    runObj.updatedAt = char(datetime('now'));
                    pipelineRunSave(runObj);

                    d.Value = 1;
                    d.Message = 'Pipeline run completed.';
                    pause(0.2);
                    close(d);
                catch ME
                    runObj.status = 'failed';
                    runObj.updatedAt = char(datetime('now'));
                    try
                        pipelineRunSave(runObj);
                    catch
                    end
                    close(d);
                    uialert(app.DetecDivUIFigure, ME.message, 'Run failed', 'Icon', 'error');
                end

                RefreshtreewindowMenuSelected(app);
            end

            function submitProjectPipelineRunToHub(projIdx, runIdx)
                if projIdx > numel(app.Data.Project)
                    return;
                end
                projVar = app.Data.Project{projIdx};
                shallowObj = evalin('base', projVar);
                if ~isfield(shallowObj.processing,'pipelineRun') || runIdx > numel(shallowObj.processing.pipelineRun)
                    return;
                end

                runObj = shallowObj.processing.pipelineRun(runIdx);
                choice = uiconfirm(app.DetecDivUIFigure, ...
                    {'Submit this existing pipeline run to the hub?', ...
                     'The local project will be considered stale once the hub job writes results.'}, ...
                    'Run on hub', 'Options', {'Submit','Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(choice, 'Submit')
                    return;
                end

                d = uiprogressdlg(app.DetecDivUIFigure, 'Title', 'Please Wait...', ...
                    'Message', ['Submitting hub job for ' runObj.runId '...'], 'Indeterminate', 'on');
                try
                    try
                        detecdiv_hub_release_project_open(shallowObj);
                    catch
                    end
                    job = detecdiv_hub_submit_pipeline_run(runObj, shallowObj);
                    shallowObj.processing.pipelineRun(runIdx) = runObj;
                    if isprop(shallowObj, 'runProfiles')
                        if ~isfield(shallowObj.runProfiles, 'hub') || ~isstruct(shallowObj.runProfiles.hub)
                            shallowObj.runProfiles.hub = struct();
                        end
                        shallowObj.runProfiles.hub.read_only = true;
                        shallowObj.runProfiles.hub.reason = 'Hub pipeline job submitted; reload project before further local editing.';
                    end
                    assignin('base', projVar, shallowObj);
                    close(d);
                    uialert(app.DetecDivUIFigure, ...
                        sprintf('Hub job submitted: %s\nStatus: %s\nReload the project after the job completes before editing locally.', ...
                        char(string(job.id)), char(string(job.status))), ...
                        'Hub job submitted', 'Icon', 'success');
                catch ME
                    close(d);
                    uialert(app.DetecDivUIFigure, ME.message, 'Hub submit failed', 'Icon', 'error');
                end
                RefreshtreewindowMenuSelected(app);
            end

            function refreshProjectPipelineRunHubStatus(projIdx, runIdx, showDialog)
                if nargin < 4
                    showDialog = false;
                end
                if projIdx > numel(app.Data.Project)
                    return;
                end
                projVar = app.Data.Project{projIdx};
                shallowObj = evalin('base', projVar);
                runObj = shallowObj.processing.pipelineRun(runIdx);
                jobId = localRunHubJobId(runObj);
                if isempty(jobId)
                    if showDialog
                        uialert(app.DetecDivUIFigure, 'This run has no hub_job_id.', 'Hub status', 'Icon', 'warning');
                    end
                    return;
                end
                try
                    job = detecdiv_hub_get_pipeline_run(jobId);
                    if ~isstruct(runObj.ctx), runObj.ctx = struct(); end
                    if ~isfield(runObj.ctx, 'hub') || ~isstruct(runObj.ctx.hub), runObj.ctx.hub = struct(); end
                    runObj.ctx.hub.job_id = char(string(job.id));
                    runObj.ctx.hub.status = char(string(job.status));
                    runObj.ctx.hub.refreshed_at = char(datetime('now'));
                    runObj.status = ['hub_' char(string(job.status))];
                    shallowObj.processing.pipelineRun(runIdx) = runObj;
                    assignin('base', projVar, shallowObj);
                    pipelineRunSave(runObj);
                    if showDialog
                        msg = sprintf('Hub job: %s\nStatus: %s', char(string(job.id)), char(string(job.status)));
                        if any(strcmp(char(string(job.status)), {'done','failed','cancelled'}))
                            msg = sprintf('%s\n\nProject changed on hub/server. Reload before local editing.', msg);
                        end
                        uialert(app.DetecDivUIFigure, msg, 'Hub status', 'Icon', 'info');
                    end
                catch ME
                    if showDialog
                        uialert(app.DetecDivUIFigure, ME.message, 'Hub status failed', 'Icon', 'error');
                    end
                end
            end

            function cancelProjectPipelineRunHubJob(projIdx, runIdx)
                runObj = getProjectRunByIndex(projIdx, runIdx);
                jobId = localRunHubJobId(runObj);
                if isempty(jobId)
                    uialert(app.DetecDivUIFigure, 'This run has no hub_job_id.', 'Cancel hub job', 'Icon', 'warning');
                    return;
                end
                choice = uiconfirm(app.DetecDivUIFigure, ['Cancel hub job ' jobId '?'], ...
                    'Cancel hub job', 'Options', {'Cancel job','Keep running'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(choice, 'Cancel job')
                    return;
                end
                try
                    job = detecdiv_hub_cancel_pipeline_run(jobId);
                    refreshProjectPipelineRunHubStatus(projIdx, runIdx, false);
                    uialert(app.DetecDivUIFigure, ...
                        sprintf('Cancellation requested.\nHub status: %s', char(string(job.status))), ...
                        'Cancel hub job', 'Icon', 'info');
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Cancel hub job failed', 'Icon', 'error');
                end
            end

            function jobId = localRunHubJobId(runObj)
                jobId = '';
                try
                    if isstruct(runObj.ctx) && isfield(runObj.ctx, 'hub') && isstruct(runObj.ctx.hub)
                        if isfield(runObj.ctx.hub, 'job_id') && ~isempty(runObj.ctx.hub.job_id)
                            jobId = char(string(runObj.ctx.hub.job_id));
                        elseif isfield(runObj.ctx.hub, 'hub_job_id') && ~isempty(runObj.ctx.hub.hub_job_id)
                            jobId = char(string(runObj.ctx.hub.hub_job_id));
                        end
                    end
                catch
                end
            end

            function [pipeObj, msg] = resolvePipelineFromRun(runObj, shallowObj)
                pipeObj = [];
                msg = 'Could not resolve pipeline for this run.';

                try
                    spec = runObj.ctx.pipelineSpec;
                    if isstruct(spec) && isfield(spec,'nodes') && ~isempty(spec.nodes)
                        pipeObj = spec;
                        if ~isfield(pipeObj,'edges') || isempty(pipeObj.edges)
                            pipeObj.edges = struct([]);
                        end
                        msg = '';
                        return;
                    end
                catch
                end

                if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef)
                    if isfield(runObj.pipelineRef,'path') && ~isempty(runObj.pipelineRef.path)
                        [pipeObj, m] = pipelineLoad(runObj.pipelineRef.path);
                        if ~isempty(pipeObj)
                            msg = '';
                            return;
                        end
                        if ~isempty(m)
                            msg = m;
                        end
                    end
                end

                if isprop(runObj,'templatePath') && ~isempty(runObj.templatePath)
                    [pipeObj, m] = pipelineLoad(runObj.templatePath);
                    if ~isempty(pipeObj)
                        msg = '';
                        return;
                    end
                    if ~isempty(m)
                        msg = m;
                    end
                end

                if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef,'id') ...
                        && ~isempty(runObj.pipelineRef.id)
                    vars = evalin('base','who');
                    for vi = 1:numel(vars)
                        try
                            tmp = evalin('base', vars{vi});
                        catch
                            continue;
                        end
                        if isa(tmp,'pipeline') && strcmp(tmp.strid, char(string(runObj.pipelineRef.id)))
                            pipeObj = tmp;
                            msg = '';
                            return;
                        end
                    end
                end

                try
                    [foundDefault, defaultPipe] = app.getProjectDefaultPipelineObject(shallowObj);
                catch
                    foundDefault = false;
                    defaultPipe = [];
                end
                if foundDefault && ~isempty(defaultPipe)
                    wantId = '';
                    try
                        wantId = char(string(runObj.pipelineRef.id));
                    catch
                    end
                    if isempty(wantId) || strcmp(defaultPipe.strid, wantId)
                        pipeObj = defaultPipe;
                        msg = '';
                        return;
                    end
                end
            end

            function [runObj, changed] = backfillRunPipelineRef(runObj, pipeObj, shallowObj)
                changed = false;
                if nargin < 1 || isempty(runObj)
                    return;
                end

                resolvedPath = '';
                try
                    if isa(pipeObj,'pipeline') && isprop(pipeObj,'path') && ~isempty(pipeObj.path)
                        resolvedPath = char(string(pipeObj.path));
                    end
                catch
                end

                if isempty(resolvedPath)
                    try
                        defaultJson = app.getProjectDefaultPipelinePath(shallowObj);
                        if ~isempty(defaultJson)
                            resolvedPath = fileparts(defaultJson);
                        end
                    catch
                    end
                end

                if isempty(resolvedPath)
                    return;
                end

                if ~isprop(runObj,'pipelineRef') || isempty(runObj.pipelineRef) || ~isstruct(runObj.pipelineRef)
                    runObj.pipelineRef = struct('id','','path','','version','');
                    changed = true;
                end
                if ~isfield(runObj.pipelineRef,'path') || ~strcmp(char(string(runObj.pipelineRef.path)), resolvedPath)
                    runObj.pipelineRef.path = resolvedPath;
                    changed = true;
                end
                if isprop(runObj,'templatePath') && ~strcmp(char(string(runObj.templatePath)), resolvedPath)
                    runObj.templatePath = resolvedPath;
                    changed = true;
                end
                if isprop(runObj,'templateId') && isempty(runObj.templateId) && isfield(runObj.pipelineRef,'id')
                    runObj.templateId = runObj.pipelineRef.id;
                    changed = true;
                end
                if isstruct(runObj.ctx)
                    if ~isfield(runObj.ctx,'pipelineRef') || ~isstruct(runObj.ctx.pipelineRef)
                        runObj.ctx.pipelineRef = runObj.pipelineRef;
                        changed = true;
                    elseif ~isfield(runObj.ctx.pipelineRef,'path') || ~strcmp(char(string(runObj.ctx.pipelineRef.path)), resolvedPath)
                        runObj.ctx.pipelineRef.path = resolvedPath;
                        changed = true;
                    end
                end
            end

            function node = buildPipelineNode(typeIn, pkgName, nodeName, pipeObj)
                node = [];
                t = lower(strtrim(char(string(typeIn))));
                t = strrep(t, ' ', '');
                t = strrep(t, '_', '');
                switch t
                    case {'dataloader'}
                        t = 'dataloader';
                    case {'roipattern','roiidentification','roiidentify'}
                        if strcmp(t, 'roipattern')
                            t = 'roipattern';
                        else
                            t = 'roiidentify';
                        end
                    case {'roimanual'}
                        t = 'roimanual';
                    case {'roigrid'}
                        t = 'roigrid';
                    case {'roiextraction','roiextract'}
                        t = 'roiextract';
                    case {'processor','classifier'}
                        % keep as is
                    otherwise
                        % keep original token to fail in switch below
                end

                switch t
                    case 'dataloader'
                        typeName = 'dataLoader';
                        funcName = 'dataLoader.process';
                        inNames = {};
                        outNames = {'images'};
                        req = {'path'};
                        try
                            params = dataLoader.setparam(struct());
                        catch
                            params = struct();
                        end
                    case 'roipattern'
                        typeName = 'roiPattern';
                        funcName = 'roiPattern.process';
                        inNames = {'images'};
                        outNames = {'roiList'};
                        req = {};
                        try
                            params = roiPattern.setparam(struct());
                        catch
                            params = struct();
                        end
                    case 'roiidentify'
                        typeName = 'roiIdentify';
                        funcName = 'roiIdentify.process';
                        inNames = {'images'};
                        outNames = {'roiList'};
                        req = {};
                        try
                            params = roiIdentify.setparam(struct());
                        catch
                            params = struct();
                        end
                    case 'roimanual'
                        typeName = 'roiManual';
                        funcName = 'roiManual.process';
                        inNames = {'images'};
                        outNames = {'roiList'};
                        req = {};
                        try
                            params = roiManual.setparam(struct());
                        catch
                            params = struct();
                        end
                    case 'roigrid'
                        typeName = 'roiGrid';
                        funcName = 'roiGrid.process';
                        inNames = {'images'};
                        outNames = {'roiList'};
                        req = {};
                        try
                            params = roiGrid.setparam(struct());
                        catch
                            params = struct();
                        end
                    case 'roiextract'
                        typeName = 'roiExtract';
                        funcName = 'roiExtract.process';
                        inNames = {'roiList'};
                        outNames = {'channels'};
                        req = {};
                        try
                            params = roiExtract.setparam(struct());
                        catch
                            params = struct();
                        end
                    case 'processor'
                        typeName = 'processor';
                        funcName = '';
                        inNames = {'inputChannels'};
                        outNames = {'dataSeries'};
                        req = {'pkg'};
                        params = struct('pkg','');
                    case 'classifier'
                        typeName = 'classifier';
                        funcName = '';
                        inNames = {'inputChannels'};
                        outNames = {'dataSeries'};
                        req = {'pkg'};
                        params = struct('pkg','');
                    otherwise
                        return;
                end

                nodeId = nextModuleId(typeName, pipeObj);
                if isempty(nodeName)
                    nodeName = nodeId;
                end

                node = struct();
                node.id = nodeId;
                node.name = nodeName;
                node.type = typeName;
                node.func = funcName;
                node.gui = '';
                node.guiMode = 'replace';
                node.paramRequired = req;
                node.inputs = inNames;
                node.outputs = outNames;
                node.params = params;
                node.enabled = true;
                node.status = '';
                node.pkg = pkgName;
                node.layout = [10 10 20 10];

                if strcmp(typeName,'processor') && ~isempty(pkgName)
                    node.func = [pkgName '.process'];
                    node.gui = 'processDataGUI';
                    node.params.pkg = pkgName;
                    try
                        p0 = feval([pkgName '.setparam'], struct());
                        if isstruct(p0)
                            fn = fieldnames(p0);
                            for fi=1:numel(fn)
                                node.params.(fn{fi}) = p0.(fn{fi});
                            end
                        end
                    catch
                    end
                end
                if strcmp(typeName,'classifier') && ~isempty(pkgName)
                    node.gui = 'classifierGUI';
                    node.params.pkg = pkgName;
                end
            end

            function out = nextModuleId(typeName, pipeObj)
                base = lower(regexprep(typeName,'[^a-zA-Z0-9]',''));
                if isempty(base)
                    base = 'node';
                end
                n = 1;
                out = [base '_' num2str(n)];
                if isempty(pipeObj.nodes)
                    return;
                end
                existing = cell(1,numel(pipeObj.nodes));
                for ii=1:numel(pipeObj.nodes)
                    existing{ii} = getStructFieldText(pipeObj.nodes(ii),'id','');
                end
                while any(strcmp(existing, out))
                    n = n + 1;
                    out = [base '_' num2str(n)];
                end
            end

            function v = getStructFieldText(S, name, defaultVal)
                v = defaultVal;
                if isstruct(S) && isfield(S,name)
                    val = S.(name);
                    if isnumeric(val)
                        v = num2str(val);
                    else
                        v = char(string(val));
                    end
                end
            end

            function iconFile = getPipelineModuleIcon(typeName)
                t = lower(strrep(char(string(typeName)), ' ', ''));
                switch t
                    case {'classifier'}
                        iconFile = 'brain.png';
                    case {'processor'}
                        iconFile = 'processor.png';
                    case {'dataloader','dataload'}
                        iconFile = 'data.png';
                    case {'roipattern','roiidentify','roiidentification','roimanual','roigrid','roiextract','roiextraction'}
                        iconFile = 'roi.png';
                    otherwise
                        iconFile = 'processor.png';
                end
            end
            function names = getProcessorPackageChoices()
                names = listPlusPackages('processor');
            end
            function names = getClassifierPackageChoices()
                names = listPlusPackages('classification');
            end

            function names = listPlusPackages(kind)
                names = {};
                try
                    here = fileparts(mfilename('fullpath'));
                    repoRoot = fileparts(fileparts(here));
                    root = fullfile(repoRoot, 'engine', kind);
                    if ~isfolder(root)
                        return;
                    end

                    d = dir(fullfile(root, '+*'));
                    d = d([d.isdir]);
                    names = cell(1, numel(d));
                    for ii = 1:numel(d)
                        names{ii} = erase(d(ii).name, '+');
                    end
                    names = unique(names, 'stable');
                catch
                    names = {};
                end
            end

            function [ok, typeName, pkgName, nodeName] = askPipelineModuleSpec()
                ok = false;
                typeName = '';
                pkgName = '';
                nodeName = '';

                typeChoices = {'dataLoader','roiPattern','roiManual','roiGrid','roiExtract','processor','classifier'};
                procPkgs = getProcessorPackageChoices();
                classPkgs = getClassifierPackageChoices();

                f = uifigure('Name','Add module','WindowStyle','modal','Position',[100 100 430 220]);
                if ~isempty(app.DetecDivUIFigure) && isvalid(app.DetecDivUIFigure)
                    p = app.DetecDivUIFigure.Position;
                    f.Position(1) = p(1) + max(20, floor((p(3)-f.Position(3))/2));
                    f.Position(2) = p(2) + max(20, floor((p(4)-f.Position(4))/2));
                end

                gl = uigridlayout(f,[4 2]);
                gl.RowHeight = {30,30,30,40};
                gl.ColumnWidth = {130,'1x'};
                gl.Padding = [10 10 10 10];

                uilabel(gl,'Text','Module type:');
                ddType = uidropdown(gl,'Items',typeChoices,'Value','dataLoader');

                uilabel(gl,'Text','Package:');
                ddPkg = uidropdown(gl,'Items',{'<none>'},'Value','<none>');
                ddPkg.Enable = 'off';

                uilabel(gl,'Text','Module name:');
                edName = uieditfield(gl,'text','Value','');

                pnlBtns = uipanel(gl);
                pnlBtns.Layout.Row = 4;
                pnlBtns.Layout.Column = [1 2];
                glb = uigridlayout(pnlBtns,[1 3]);
                glb.ColumnWidth = {'1x',90,90};

                btnOK = uibutton(glb,'Text','OK'); %#ok<NASGU>
                btnOK.Layout.Column = 2;
                btnCancel = uibutton(glb,'Text','Cancel'); %#ok<NASGU>
                btnCancel.Layout.Column = 3;

                function refreshPkg()
                    t = lower(char(ddType.Value));
                    switch t
                        case 'processor'
                            if isempty(procPkgs)
                                ddPkg.Items = {'<none>'};
                                ddPkg.Value = '<none>';
                            else
                                ddPkg.Items = procPkgs;
                                ddPkg.Value = procPkgs{1};
                            end
                            ddPkg.Enable = 'on';
                        case 'classifier'
                            if isempty(classPkgs)
                                ddPkg.Items = {'<none>'};
                                ddPkg.Value = '<none>';
                            else
                                ddPkg.Items = classPkgs;
                                ddPkg.Value = classPkgs{1};
                            end
                            ddPkg.Enable = 'on';
                        otherwise
                            ddPkg.Items = {'<none>'};
                            ddPkg.Value = '<none>';
                            ddPkg.Enable = 'off';
                    end
                end

                ddType.ValueChangedFcn = @(~,~) refreshPkg();
                refreshPkg();

                btnOK.ButtonPushedFcn = @onOK;
                btnCancel.ButtonPushedFcn = @onCancel;
                f.CloseRequestFcn = @onCancel;

                uiwait(f);

                if isvalid(f)
                    delete(f);
                end

                function onOK(~,~)
                    typeName = char(ddType.Value);
                    nodeName = strtrim(char(edName.Value));

                    if strcmpi(typeName,'processor') || strcmpi(typeName,'classifier')
                        if strcmp(ddPkg.Value,'<none>')
                            uialert(f,'Please select a package for this module type.','Missing package','Icon','warning');
                            return;
                        end
                        pkgName = char(ddPkg.Value);
                    else
                        pkgName = '';
                    end

                    ok = true;
                    uiresume(f);
                end

                function onCancel(~,~)
                    ok = false;
                    uiresume(f);
                end
            end

            function contextMenuPositionFcn(src,event,arg,str)

                cc=arg(1);
                pos=arg(2);

                proj=app.Data.Project{cc(1)};
                shallowObj=evalin('base',proj);

                d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...',...
                    'Message','Loading raw data from source files; Please wait...');
                d.Value=0.33;

                if numel(shallowObj.fov(pos).srcpath{1})>0
                    im=readImage(shallowObj.fov(pos),1,1);

                    if numel(im)==0 & numel(shallowObj.fov(pos).srcpath{1})>0
                        errordlg('The path to your raw data is incorrect; please update the raw data path !');
                    end
                end

                shallowObj.fov(pos).view(shallowObj.fov(pos).display.frame,[]);


                d.Value=0.9;
                d.Message='Data loaded...';
                pause(1);
                close(d);

            end
            function contextMenuDeleteROIsFcn(src,event,arg,str)


                cc=arg(1);

                if strcmp(str,'Classifier')
                    clas=app.Data.Classifier{cc};
                    clas=evalin('base',clas);
                end
                if strcmp(str,'Projectclassi')
                    proj=app.Data.Project{cc(1)};
                    pos=arg(2);
                    shallowObj=evalin('base',proj);
                    clas=shallowObj.processing.classification(pos);
                end
                if strcmp(str,'Projectpos')
                    proj=app.Data.Project{cc(1)};
                    pos=arg(2);
                    shallowObj=evalin('base',proj);
                    clas=shallowObj.fov(pos);
                end


                defroi=['1:'  num2str(numel(clas.roi)) ];
                prompt = {'ROIs that will be deleted:'};%,'Period between frames for each channel (in frames units):'};
                dlgtitle = 'Deleting ROIs';

                dims = [1 100];


                definput = {defroi};%, num2str(inte)};
                answer = inputdlg(prompt,dlgtitle,dims,definput);
                if numel(answer)==0
                    return;
                end

                selection=uiconfirm(app.DetecDivUIFigure,'This will erase selected ROIs; Proceed?','Warning');



                if strcmp(selection,'OK')

                    id=str2num(answer{1});
                    if numel(id)
                        pix=setxor(1:numel(clas.roi),id);

                        if numel(pix)==0
                            clas.roi=roi;
                            if ~strcmp(str,'Projectpos')
                                clas.channelName={};
                            end
                        else
                            clas.roi=clas.roi(pix);
                        end

                    end

                    RefreshtreewindowMenuSelected(app)
                end
            end

            function contextMenuDeletePositionFcn(src,event,arg,str)

                cc=arg(1);
                pos=arg(2);

                proj=app.Data.Project{cc(1)};
                shallowObj=evalin('base',proj);

                selection=uiconfirm(app.DetecDivUIFigure,'This will erase the selected position; Proceed?','Warning');

                if strcmp(selection,'OK')

                    pix=setxor(1:numel(shallowObj.fov),pos);
                    shallowObj.fov=shallowObj.fov(pix);
                    RefreshtreewindowMenuSelected(app)
                end

            end


            %             function contextMenuROIFcn(src,event,arg,str)
            %
            %                %  str,arg
            %
            %
            %                 if strcmp(str,'Projectclassirois')
            %                     cc=arg(1);
            %                 pos=arg(2);
            %                 ro=arg(3);
            %
            %
            %                 proj=app.Data.Project{cc};
            %                 shallowObj=evalin('base',proj);
            %                 roiObj=shallowObj.processing.classification(pos).roi(ro);
            %                 roiObj.view;
            %                 end
            %
            %                 if strcmp(str,'Projectposrois')
            %                  cc=arg(1);
            %                 pos=arg(2);
            %                 ro=arg(3);
            %
            %
            %                 proj=app.Data.Project{cc};
            %                 shallowObj=evalin('base',proj);
            %                 roiObj=shallowObj.fov(pos).roi(ro);
            %                 roiObj.view;
            %                 end
            %
            %                 if strcmp(str,'Classifierrois')
            %                  cc=arg(1);
            %                  ro=arg(2);
            %                  clas=app.Data.Classifier{cc};
            %                  clas=evalin('base',clas);
            %
            %                 roiObj=clas.roi(ro);
            %                 roiObj.view;
            %                   end
            %
            %
            %             end


        end

        function gatherVarsFromWorkspace(app)
            varlist=evalin('base','who');
            st=struct('Project',{{}},'Classifier',{{}},'Pipeline',{{}},'PipelineModules',{{}},'PipelineModuleIds',{{}},'PipelineModuleTypes',{{}},'Projectpos',{{}},'Projectclassi',{{}},'Projectprocess',{{}},'ProjectpipelineRun',{{}},'Projectposrois',{{}},'Projectclassirois',{{}},'Classifierrois',{{}});
            cc=0;
            cd=0;
            cp=0;
            app.Data={};

            for i=1:numel(varlist)

                if strcmp(varlist{i},'ans')
                    continue;
                end

                tmp=evalin('base',varlist{i});


                if isa(tmp,'shallow')
                    %  disp('this is a shallow object')
                    cc=cc+1;

                    st.Project{cc}=varlist{i};

                    tmpclassi={};

                    for k=1:numel(tmp.processing.classification)
                        %  k
                        tmpclassi = [tmpclassi tmp.processing.classification(k).strid];

                        if numel(tmp.processing.classification(k).roi)==1 && numel(tmp.processing.classification(k).roi.id)==0
                            ntot=0;
                        else
                            ntot=numel(tmp.processing.classification(k).roi);
                        end

                        tmproi={};

                        %  ntot

                        for n=1:ntot

                            tmproi=[tmproi [num2str(n) ' - ' tmp.processing.classification(k).roi(n).id]];

                        end

                        % tmproi
                        st.Projectclassirois{cc}{k}=tmproi;


                    end

                    st.Projectclassi{cc}=tmpclassi;
                    tmpprocess={};

                    if isfield(tmp.processing,'processor')
                        for k=1:numel(tmp.processing.processor)
                            %  k
                            procList = tmp.processing.processor;
if ~isempty(procList)
    valid = arrayfun(@(p) isvalid(p), procList);
    if any(~valid)
        procList = procList(valid);
        tmp.processing.processor = procList;
    end
end

tmpprocess = {};
for k = 1:numel(procList)
    tmpprocess{end+1} = procList(k).strid; %#ok<AGROW>
end


                        end

                        st.Projectprocess{cc}=tmpprocess;
                    end

                    tmprun={};
                    if isfield(tmp.processing,'pipelineRun') && ~isempty(tmp.processing.pipelineRun)
                        for k=1:numel(tmp.processing.pipelineRun)
                            runObj = tmp.processing.pipelineRun(k);
                            tmprun{end+1} = app.formatPipelineRunLabel(runObj, k); %#ok<AGROW>
                        end
                    end
                    st.ProjectpipelineRun{cc}=tmprun;

                    tmpproj={};

                    for k=1:numel(tmp.fov)
                        %  k
                        if isprop(tmp.fov(k), 'srcpath') && iscell(tmp.fov(k).srcpath) && ...
                                numel(tmp.fov(k).srcpath) >= 1 && ~isempty(tmp.fov(k).srcpath{1})
                            tmpproj = [tmpproj [num2str(k) ' - ' tmp.fov(k).id]];
                            %  aa=tmp.fov(k).srcpath
                        end

                        if numel(tmp.fov(k).roi)==1 && numel(tmp.fov(k).roi.id)==0
                            ntot=0;
                        else
                            ntot=numel(tmp.fov(k).roi);
                        end

                        tmproi={};

                        %  ntot

                        for n=1:ntot

                            tmproi=[tmproi [num2str(n) ' - ' tmp.fov(k).roi(n).id]];

                        end

                        % tmproi
                        st.Projectposrois{cc}{k}=tmproi;


                    end

                    st.Projectpos{cc}=tmpproj;
                end

                if isa(tmp,'pipeline')
                    if ~isfield(st,'Pipeline') || isempty(st.Pipeline)
                        st.Pipeline = {};
                        st.PipelineModules = {};
                        st.PipelineModuleIds = {};
                        st.PipelineModuleTypes = {};
                    end

                    cp = cp + 1;
                    st.Pipeline{cp} = varlist{i};

                    modLabels = {};
                    modIds = {};
                    modTypes = {};
                    if isprop(tmp,'nodes') && ~isempty(tmp.nodes)
                        for kk = 1:numel(tmp.nodes)
                            node = tmp.nodes(kk);
                            nodeId = '';
                            if isfield(node,'id') && ~isempty(node.id)
                                nodeId = char(string(node.id));
                            else
                                nodeId = ['node_' num2str(kk)];
                            end

                            nodeName = nodeId;
                            if isfield(node,'name') && ~isempty(node.name)
                                nodeName = char(string(node.name));
                            end

                            nodeType = '';
                            if isfield(node,'type') && ~isempty(node.type)
                                nodeType = char(string(node.type));
                            end

                            nodePkg = '';
                            if isfield(node,'pkg') && ~isempty(node.pkg)
                                nodePkg = char(string(node.pkg));
                            end

                            label = nodeName;
                            if ~isempty(nodePkg)
                                label = [label ' {' nodePkg '}'];
                            end

                            modLabels{end+1} = label; %#ok<AGROW>
                            modIds{end+1} = nodeId; %#ok<AGROW>
                            modTypes{end+1} = nodeType; %#ok<AGROW>
                        end
                    end

                    st.PipelineModules{cp} = modLabels;
                    st.PipelineModuleIds{cp} = modIds;
                    st.PipelineModuleTypes{cp} = modTypes;
                end

                if isa(tmp,'classi')

                    %     disp('this is a classification object')
                    cd=cd+1;
                    st.Classifier{cd}=varlist{i};

                    if numel(tmp.roi)==1 && numel(tmp.roi.id)==0
                        ntot=0;
                    else
                        ntot=numel(tmp.roi);
                    end

                    tmproi={};

                    %  ntot

                    for n=1:ntot

                        tmproi=[tmproi [num2str(n) ' - ' tmp.roi(n).id]];

                    end

                    % tmproi,cc
                    st.Classifierrois{cd}=tmproi;

                end

            end

            %  st
            app.Data=st;

            %  st
        end


        function check = checkImagePath(app,proj)

            check=ones(1,numel(proj.fov));

            d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...',...
                'Message','Checking raw data path in the project...');
            d.Value=0.0;
            for i=1:numel(proj.fov)
                d.Value=i./numel(proj.fov);
                if numel(proj.fov(i).srcpath{1})>0
                    im=readImage(proj.fov(i),1,1);

                    if numel(im)==0 & numel(proj.fov(1).srcpath{1})>0
                        check(i)=0;
                    end
                end
            end



            if numel(find(check==0))
                d.Message='Some raw data paths are invalid. It will be impossible to display the raw images!';
                pause(5);
            else
                d.Message='The paths are OK!';
                pause(1);
            end

            close(d);
        end
    end

    methods (Access = private)

        function  displayClassiImage(app,clas)

            selectedNode=app.Tree.SelectedNodes;


            if numel(selectedNode.NodeData)==0
                loade=1;

                pth=clas.path;
                sam=fullfile(pth,'sampleImage.png');

                if exist(sam)
                    im=imread(sam);

                else

                    [ k, himg]=clas.displayFormattedTrainingSet('Display','Nimages',9);
                    %    himg
                    im=himg;
                    close

                end
                selectedNode.NodeData=im;
            else
                im=selectedNode.NodeData;
            end

            imshow(im,'parent',app.UIAxes);
        end


        function [ok,node,pipeObj] = getPipelineNodeByIndex(app, pipeIdx, modIdx)
            ok = false;
            node = struct();
            pipeObj = [];

            if pipeIdx > numel(app.Data.Pipeline)
                return;
            end

            pipeVar = app.Data.Pipeline{pipeIdx};
            try
                pipeObj = evalin('base', pipeVar);
            catch
                return;
            end

            if ~isa(pipeObj,'pipeline') || ~isprop(pipeObj,'nodes') || modIdx > numel(pipeObj.nodes)
                pipeObj = [];
                return;
            end

            node = pipeObj.nodes(modIdx);
            ok = true;
        end

        function [nType, modObj] = buildPipelineModuleObject(app, node) %#ok<INUSD>
            nType = '';
            modObj = [];

            if ~(isstruct(node) && isfield(node,'type') && ~isempty(node.type))
                return;
            end

            nType = lower(char(string(node.type)));

            if strcmp(nType,'processor')
                tmpProc = process(tempdir, 'pipeline_module', randi(1e9));

                pkgName = '';
                if isfield(node,'pkg') && ~isempty(node.pkg)
                    pkgName = char(string(node.pkg));
                end

                if ~isempty(pkgName)
                    tmpProc.processFun = [pkgName '.process'];
                    try
                        p0 = feval([pkgName '.setparam'], struct());
                    catch
                        p0 = struct();
                    end
                    if isstruct(p0)
                        tmpProc.processArg = p0;
                    end
                elseif isfield(node,'func') && ~isempty(node.func)
                    tmpProc.processFun = char(string(node.func));
                end

                if isfield(node,'params') && isstruct(node.params)
                    if isempty(tmpProc.processArg) || ~isstruct(tmpProc.processArg)
                        tmpProc.processArg = node.params;
                    else
                        fn = fieldnames(node.params);
                        for fi = 1:numel(fn)
                            tmpProc.processArg.(fn{fi}) = node.params.(fn{fi});
                        end
                    end
                end

                if isfield(node,'id') && ~isempty(node.id)
                    tmpProc.strid = char(string(node.id));
                end

                modObj = tmpProc;
                return;
            end

            if strcmp(nType,'classifier')
                tmpClassi = classi(tempdir, 'pipeline_module', randi(1e9));

                if isfield(node,'id') && ~isempty(node.id)
                    tmpClassi.strid = char(string(node.id));
                end

                pkgName = '';
                if isfield(node,'pkg') && ~isempty(node.pkg)
                    pkgName = char(string(node.pkg));
                end

                if ~isempty(pkgName)
                    tmpClassi.classifierPkg = pkgName;
                    if isempty(tmpClassi.classifyFun)
                        tmpClassi.classifyFun = [pkgName '.classify'];
                    end
                    if isempty(tmpClassi.trainingFun)
                        tmpClassi.trainingFun = [pkgName '.train'];
                    end

                    if strcmpi(pkgName,'cellposesam')
                        tmpClassi.category = {'Pixel'};
                    elseif strcmpi(pkgName,'cnn_lstm')
                        tmpClassi.category = {'LSTM'};
                    else
                        tmpClassi.category = {'Image'};
                    end
                else
                    tmpClassi.category = {'Image'};
                end

                if isfield(node,'func') && ~isempty(node.func)
                    tmpClassi.classifyFun = char(string(node.func));
                end

                if isfield(node,'params') && isstruct(node.params)
                    if isfield(node.params,'classes') && ~isempty(node.params.classes)
                        cls = node.params.classes;
                        if isstring(cls), cls = cellstr(cls); end
                        if ischar(cls), cls = {cls}; end
                        tmpClassi.classes = cls;
                    end
                end

                tmpClassi.category = classiNormalizeCategory(tmpClassi.category);
                modObj = tmpClassi;
                return;
            end
        end

        function openPipelineModuleByIndex(app, pipeIdx, modIdx)
            [ok,node,pipeObj] = app.getPipelineNodeByIndex(pipeIdx, modIdx);
            if ~ok
                return;
            end

            [nType, modObj] = app.buildPipelineModuleObject(node);
            switch nType
                case 'processor'
                    processDataGUI([], modObj);
                case 'classifier'
                    classifierGUI(modObj);
                otherwise
                    app.openPipelineWithContext(pipeObj);
            end
        end

        function openPipelineWithContext(app, pipeObj)
            pipeObj = app.reloadPipelineTemplateFromDiskIfAvailable(pipeObj);
            projectObj = [];
            [found, projectObj] = app.findLinkedProjectForPipeline(pipeObj);
            if found
                app.openPipelineEditorWithProgress(projectObj, pipeObj, 'Opening pipeline editor...');
            else
                app.openPipelineEditorWithProgress([], pipeObj, 'Opening pipeline editor...');
            end
        end

        function openPipelineEditorWithProgress(app, projectObj, targetObj, message)
            if nargin < 4 || isempty(message)
                message = 'Opening pipeline editor...';
            end
            d = uiprogressdlg(app.DetecDivUIFigure, ...
                'Title', 'Please wait', ...
                'Message', message, ...
                'Indeterminate', 'on');
            cleanupObj = onCleanup(@() app.safeCloseProgressDialog(d)); %#ok<NASGU>
            drawnow;
            pipeline2(projectObj, targetObj);
        end

        function safeCloseProgressDialog(app, dlg) %#ok<INUSD>
            try
                if ~isempty(dlg) && isvalid(dlg)
                    close(dlg);
                end
            catch
            end
        end

        function pipeObj = reloadPipelineTemplateFromDiskIfAvailable(app, pipeObj) %#ok<INUSD>
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end
            pipePath = '';
            try
                pipePath = char(string(pipeObj.path));
            catch
                pipePath = '';
            end
            if isempty(strtrim(pipePath))
                return;
            end
            jsonPath = pipePath;
            if exist(jsonPath, 'dir') == 7
                jsonPath = fullfile(jsonPath, 'pipeline.json');
            end
            if exist(jsonPath, 'file') ~= 2
                return;
            end
            try
                [freshPipe, msg] = pipelineLoad(jsonPath);
                if ~isempty(freshPipe)
                    pipeObj = freshPipe;
                elseif ~isempty(msg)
                    warning('detecdiv:PipelineReloadFailed', '%s', msg);
                end
            catch ME
                warning('detecdiv:PipelineReloadFailed', '%s', ME.message);
            end
        end

        function runObj = getProjectRunByIndex(app, projIdx, runIdx)
            runObj = [];
            if projIdx > numel(app.Data.Project)
                return;
            end
            projVar = app.Data.Project{projIdx};
            shallowObj = evalin('base', projVar);
            if ~isfield(shallowObj.processing,'pipelineRun') || runIdx > numel(shallowObj.processing.pipelineRun)
                return;
            end
            runObj = shallowObj.processing.pipelineRun(runIdx);
        end

        function label = formatPipelineRunLabel(app, runObj, fallbackIdx) %#ok<INUSD>
            label = '';
            try
                if isprop(runObj,'runId') && ~isempty(runObj.runId)
                    label = char(string(runObj.runId));
                end
            catch
            end
            if isempty(label)
                label = ['run_' num2str(fallbackIdx)];
            end
        end

        function [runMode, runStatus] = summarizePipelineRun(app, runObj) %#ok<INUSD>
            runMode = 'local';
            runStatus = 'unknown';

            try
                if isprop(runObj,'status') && ~isempty(runObj.status)
                    runStatus = char(string(runObj.status));
                end
            catch
            end

            try
                if isstruct(runObj.ctx) && isfield(runObj.ctx,'hub') && isstruct(runObj.ctx.hub)
                    runMode = 'hub';
                    if isfield(runObj.ctx.hub,'status') && ~isempty(runObj.ctx.hub.status)
                        runStatus = char(string(runObj.ctx.hub.status));
                    end
                end
            catch
            end

            if startsWith(runStatus,'hub_')
                runMode = 'hub';
                runStatus = extractAfter(runStatus, 4);
                if isempty(runStatus)
                    runStatus = 'unknown';
                end
            elseif isempty(runStatus)
                runStatus = 'unknown';
            end
        end

        function [found, shallowObj] = findLinkedProjectForPipeline(app, pipeObj)
            found = false;
            shallowObj = [];

            [found, projectIdx] = app.findLinkedProjectIndicesForPipeline(pipeObj);
            if ~found || isempty(projectIdx)
                return;
            end

            if projectIdx(1) <= numel(app.Data.Project)
                projVar = app.Data.Project{projectIdx(1)};
                try
                    shallowObj = evalin('base', projVar);
                catch
                    shallowObj = [];
                end
            end
        end

        function [found, projectIdx] = findLinkedProjectIndicesForPipeline(app, pipeObj)
            found = false;
            projectIdx = [];
            if isempty(pipeObj) || ~isa(pipeObj,'pipeline')
                return;
            end

            pipeJson = fullfile(pipeObj.path, 'pipeline.json');
            targetKey = app.normalizeFsPath(pipeJson);
            if isempty(targetKey)
                return;
            end

            for iProj = 1:numel(app.Data.Project)
                projVar = app.Data.Project{iProj};
                try
                    obj = evalin('base', projVar);
                catch
                    continue;
                end
                if ~isa(obj,'shallow')
                    continue;
                end

                if app.isPipelineInsideProjectFolder(obj, pipeObj)
                    projectIdx(end+1) = iProj; %#ok<AGROW>
                    found = true;
                    continue;
                end

                projectKey = app.normalizeFsPath(app.getProjectDefaultPipelinePath(obj));
                if ~isempty(projectKey) && strcmp(projectKey, targetKey)
                    projectIdx(end+1) = iProj; %#ok<AGROW>
                    found = true;
                    continue;
                end

                try
                    runs = obj.processing.pipelineRun;
                catch
                    runs = [];
                end
                for iRun = 1:numel(runs)
                    runPath = '';
                    try
                        if isprop(runs(iRun),'pipelineRef') && isstruct(runs(iRun).pipelineRef) && isfield(runs(iRun).pipelineRef,'path')
                            runPath = char(string(runs(iRun).pipelineRef.path));
                        elseif isprop(runs(iRun),'templatePath')
                            runPath = char(string(runs(iRun).templatePath));
                        end
                    catch
                    end
                    if ~isempty(runPath) && strcmp(app.normalizeFsPath(runPath), targetKey)
                        projectIdx(end+1) = iProj; %#ok<AGROW>
                        found = true;
                        break;
                    end
                end
            end

            if ~isempty(projectIdx)
                projectIdx = unique(projectIdx, 'stable');
                found = true;
            end
        end

        function tf = isPipelineInsideProjectFolder(app, shallowObj, pipeObj) %#ok<INUSD>
            tf = false;
            if isempty(shallowObj) || isempty(pipeObj) || ~isa(shallowObj,'shallow') || ~isa(pipeObj,'pipeline')
                return;
            end

            projectRoot = '';
            try
                if isprop(shallowObj,'io') && isstruct(shallowObj.io) && isfield(shallowObj.io,'path') && isfield(shallowObj.io,'file')
                    projectRoot = fullfile(char(string(shallowObj.io.path)), char(string(shallowObj.io.file)));
                end
            catch
            end
            if isempty(projectRoot) || isempty(pipeObj.path)
                return;
            end

            rootKey = app.normalizeFsPath(projectRoot);
            pipeKey = app.normalizeFsPath(pipeObj.path);
            if isempty(rootKey) || isempty(pipeKey)
                return;
            end

            tf = strcmp(pipeKey, rootKey) || startsWith(pipeKey, [rootKey '/']);
        end


        function autoLoadPipelinesForProjectRuns(app, shallowObj)
            if isempty(shallowObj) || ~isa(shallowObj,'shallow')
                return;
            end

            loaded = containers.Map('KeyType','char','ValueType','logical');
            existingPaths = app.listLoadedPipelinePaths();
            runsChanged = false;

            % 1) explicit project -> default pipeline link
            defaultPath = app.getProjectDefaultPipelinePath(shallowObj);
            if ~isempty(defaultPath)
                [~, existingPaths, loaded] = app.loadPipelineTemplateIfNeeded(defaultPath, existingPaths, loaded, 'project default');
            end

            % 2) pipelines referenced by existing runs
            if isfield(shallowObj.processing,'pipelineRun') && ~isempty(shallowObj.processing.pipelineRun)
                runs = shallowObj.processing.pipelineRun;
                for iRun = 1:numel(runs)
                    runObj = runs(iRun);
                    [pipeObj, ~] = app.resolvePipelineFromRun(runObj, shallowObj);
                    if isempty(pipeObj)
                        continue;
                    end

                    [runObj, runChanged] = app.backfillRunPipelineRef(runObj, pipeObj, shallowObj);
                    if runChanged
                        shallowObj.processing.pipelineRun(iRun) = runObj;
                        runsChanged = true;
                    end

                    label = 'pipeline run';
                    try
                        if isprop(runObj,'runId') && ~isempty(runObj.runId)
                            label = ['run ' char(string(runObj.runId))];
                        end
                    catch
                    end

                    loadablePipe = pipeObj;
                    if ~(isa(loadablePipe,'pipeline') && isprop(loadablePipe,'path') && ~isempty(loadablePipe.path))
                        try
                            if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef) ...
                                    && isfield(runObj.pipelineRef,'path') && ~isempty(runObj.pipelineRef.path)
                                [tmpPipe, ~] = pipelineLoad(runObj.pipelineRef.path);
                                if ~isempty(tmpPipe)
                                    loadablePipe = tmpPipe;
                                end
                            end
                        catch
                        end
                    end
                    if ~(isa(loadablePipe,'pipeline') && isprop(loadablePipe,'path') && ~isempty(loadablePipe.path))
                        continue;
                    end

                    key = app.normalizeFsPath(loadablePipe.path);
                    if isempty(key)
                        continue;
                    end
                    if isKey(existingPaths, key) || isKey(loaded, key)
                        continue;
                    end

                    varName = app.nextPipelineVarName(loadablePipe);
                    assignin('base', varName, loadablePipe);
                    loaded(key) = true;
                    existingPaths(key) = true;

                    try
                        app.registerRecentPipeline(string(fullfile(loadablePipe.path, 'pipeline.json')));
                    catch
                    end
                end
            end

            % 3) fallback: scan project folder for pipeline.json if no explicit link exists
            if isempty(defaultPath)
                candidates = app.resolveProjectPipelineJsonCandidates(shallowObj);
                if ~isempty(candidates)
                    for iPath = 1:numel(candidates)
                        [pipeObj, existingPaths, loaded] = app.loadPipelineTemplateIfNeeded(candidates{iPath}, existingPaths, loaded, 'project scan');
                        if iPath == 1 && ~isempty(pipeObj)
                            if app.setProjectDefaultPipelineRef(shallowObj, pipeObj)
                                try
                                    shallowSave(shallowObj);
                                catch
                                end
                            end
                        end
                    end
                end
            end

        end

        function [pipeObj, existingPaths, loaded] = loadPipelineTemplateIfNeeded(app, pipePath, existingPaths, loaded, sourceLabel)
            pipeObj = [];
            if nargin < 5 || isempty(sourceLabel)
                sourceLabel = 'pipeline';
            end
            if isempty(pipePath)
                return;
            end

            key = app.normalizeFsPath(pipePath);
            if isempty(key)
                return;
            end
            if isKey(existingPaths, key) || isKey(loaded, key)
                return;
            end

            [pipeObj, msg] = pipelineLoad(pipePath);
            if isempty(pipeObj)
                if ~isempty(msg)
                    warning('detecdiv:autoLoadPipeline', ...
                        '%s: cannot load pipeline at %s (%s)', ...
                        sourceLabel, pipePath, msg);
                else
                    warning('detecdiv:autoLoadPipeline', ...
                        '%s: cannot load pipeline at %s', ...
                        sourceLabel, pipePath);
                end
                return;
            end

            varName = app.nextPipelineVarName(pipeObj);
            assignin('base', varName, pipeObj);

            loaded(key) = true;
            existingPaths(key) = true;

            try
                app.registerRecentPipeline(string(fullfile(pipeObj.path, 'pipeline.json')));
            catch
            end
        end


        function paths = listLoadedPipelinePaths(app) %#ok<INUSD>
            paths = containers.Map('KeyType','char','ValueType','logical');
            try
                vars = evalin('base','who');
            catch
                return;
            end

            for iVar = 1:numel(vars)
                vname = vars{iVar};
                try
                    obj = evalin('base', vname);
                catch
                    continue;
                end
                if ~isa(obj,'pipeline')
                    continue;
                end
                if ~isprop(obj,'path') || isempty(obj.path)
                    continue;
                end
                key = app.normalizeFsPath(obj.path);
                if ~isempty(key)
                    paths(key) = true;
                end
            end
        end

        function varName = nextPipelineVarName(app, pipeObj) %#ok<INUSD>
            baseName = char(string(pipeObj.strid));
            if isempty(baseName)
                baseName = 'pipeline';
            end
            baseName = matlab.lang.makeValidName(baseName);

            varName = baseName;
            idx = 1;
            while evalin('base', sprintf('exist(''%s'',''var'')', varName))
                try
                    obj = evalin('base', varName);
                    if isa(obj,'pipeline') && isprop(obj,'path') && isprop(pipeObj,'path')
                        if strcmp(app.normalizeFsPath(obj.path), app.normalizeFsPath(pipeObj.path))
                            return;
                        end
                    end
                catch
                end
                idx = idx + 1;
                varName = sprintf('%s_%d', baseName, idx);
            end
        end

        function key = normalizeFsPath(app, inPath) %#ok<INUSD>
            key = '';
            if isempty(inPath)
                return;
            end
            try
                p = char(string(inPath));
            catch
                return;
            end
            p = strrep(p,'\','/');
            p = lower(p);
            p = regexprep(p,'/+$','');
            key = p;
        end

        function [pipeObj, msg] = resolvePipelineFromRun(app, runObj, shallowObj)
            pipeObj = [];
            msg = 'Could not resolve pipeline for this run.';

            try
                spec = runObj.ctx.pipelineSpec;
                if isstruct(spec) && isfield(spec,'nodes') && ~isempty(spec.nodes)
                    pipeObj = spec;
                    if ~isfield(pipeObj,'edges') || isempty(pipeObj.edges)
                        pipeObj.edges = struct([]);
                    end
                    msg = '';
                    return;
                end
            catch
            end

            if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef)
                if isfield(runObj.pipelineRef,'path') && ~isempty(runObj.pipelineRef.path)
                    [pipeObj, m] = pipelineLoad(runObj.pipelineRef.path);
                    if ~isempty(pipeObj)
                        msg = '';
                        return;
                    end
                    if ~isempty(m)
                        msg = m;
                    end
                end
            end

            if isprop(runObj,'templatePath') && ~isempty(runObj.templatePath)
                [pipeObj, m] = pipelineLoad(runObj.templatePath);
                if ~isempty(pipeObj)
                    msg = '';
                    return;
                end
                if ~isempty(m)
                    msg = m;
                end
            end

            if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef,'id') ...
                    && ~isempty(runObj.pipelineRef.id)
                vars = evalin('base','who');
                for vi = 1:numel(vars)
                    try
                        tmp = evalin('base', vars{vi});
                    catch
                        continue;
                    end
                    if isa(tmp,'pipeline') && strcmp(tmp.strid, char(string(runObj.pipelineRef.id)))
                        pipeObj = tmp;
                        msg = '';
                        return;
                    end
                end
            end

            try
                [foundDefault, defaultPipe] = app.getProjectDefaultPipelineObject(shallowObj);
            catch
                foundDefault = false;
                defaultPipe = [];
            end
            if foundDefault && ~isempty(defaultPipe)
                wantId = '';
                try
                    wantId = char(string(runObj.pipelineRef.id));
                catch
                end
                if isempty(wantId) || strcmp(defaultPipe.strid, wantId)
                    pipeObj = defaultPipe;
                    msg = '';
                    return;
                end
            end
        end

        function [runObj, changed] = backfillRunPipelineRef(app, runObj, pipeObj, shallowObj)
            changed = false;
            if nargin < 2 || isempty(runObj)
                return;
            end

            resolvedPath = '';
            try
                if isa(pipeObj,'pipeline') && isprop(pipeObj,'path') && ~isempty(pipeObj.path)
                    resolvedPath = char(string(pipeObj.path));
                end
            catch
            end

            if isempty(resolvedPath)
                try
                    defaultJson = app.getProjectDefaultPipelinePath(shallowObj);
                    if ~isempty(defaultJson)
                        resolvedPath = fileparts(defaultJson);
                    end
                catch
                end
            end

            if isempty(resolvedPath)
                return;
            end

            if ~isprop(runObj,'pipelineRef') || isempty(runObj.pipelineRef) || ~isstruct(runObj.pipelineRef)
                runObj.pipelineRef = struct('id','','path','','version','');
                changed = true;
            end
            if ~isfield(runObj.pipelineRef,'path') || ~strcmp(char(string(runObj.pipelineRef.path)), resolvedPath)
                runObj.pipelineRef.path = resolvedPath;
                changed = true;
            end
            if isprop(runObj,'templatePath') && ~strcmp(char(string(runObj.templatePath)), resolvedPath)
                runObj.templatePath = resolvedPath;
                changed = true;
            end
            if isprop(runObj,'templateId') && isempty(runObj.templateId) && isfield(runObj.pipelineRef,'id')
                runObj.templateId = runObj.pipelineRef.id;
                changed = true;
            end
            if isstruct(runObj.ctx)
                if ~isfield(runObj.ctx,'pipelineRef') || ~isstruct(runObj.ctx.pipelineRef)
                    runObj.ctx.pipelineRef = runObj.pipelineRef;
                    changed = true;
                elseif ~isfield(runObj.ctx.pipelineRef,'path') || ~strcmp(char(string(runObj.ctx.pipelineRef.path)), resolvedPath)
                    runObj.ctx.pipelineRef.path = resolvedPath;
                    changed = true;
                end
            end
        end

        function n = getProjectFovCount(app, shallowObj) %#ok<INUSD>
            n = 0;
            if isempty(shallowObj) || ~isa(shallowObj,'shallow')
                return;
            end
            if isempty(shallowObj.fov)
                return;
            end
            if numel(shallowObj.fov)==1
                try
                    if isempty(shallowObj.fov(1).srcpath) || isempty(shallowObj.fov(1).srcpath{1})
                        return;
                    end
                catch
                    return;
                end
            end
            n = numel(shallowObj.fov);
        end

        function pipeObj = ensureDefaultPipelineForProject(app, shallowObj)
            pipeObj = [];
            if isempty(shallowObj) || ~isa(shallowObj,'shallow')
                return;
            end
            if isempty(shallowObj.io.path) || isempty(shallowObj.io.file)
                return;
            end

            defaultPath = app.getProjectDefaultPipelinePath(shallowObj);
            candidateJson = defaultPath;
            if isempty(candidateJson)
                candidates = app.resolveProjectPipelineJsonCandidates(shallowObj);
                if ~isempty(candidates)
                    candidateJson = candidates{1};
                end
            end

            if ~isempty(candidateJson)
                [pipeObj,msg] = pipelineLoad(candidateJson);
                if isempty(pipeObj)
                    warning('detecdiv:defaultPipeline', 'Cannot load existing pipeline template: %s', msg);
                    return;
                end
            else
                projectRoot = fullfile(char(string(shallowObj.io.path)), char(string(shallowObj.io.file)));
                if ~exist(projectRoot,'dir')
                    return;
                end

                pipeName = [char(string(shallowObj.io.file)) '_pipeline'];
                try
                    pipeObj = pipelineNew('path', projectRoot, 'name', pipeName, 'workspace', false);
                catch ME
                    warning('detecdiv:defaultPipeline', 'Cannot create default pipeline: %s', ME.message);
                    return;
                end
                if isempty(pipeObj)
                    return;
                end
            end

            rawPath = app.deriveRawDataPathFromProject(shallowObj);
            changed = false;
            if ~isempty(rawPath)
                changed = app.populateDefaultDataLoaderPath(pipeObj, rawPath) || changed;
            end
            changed = app.setProjectDefaultPipelineRef(shallowObj, pipeObj) || changed;

            if changed
                try
                    pipelineSave(pipeObj);
                    app.publishPipelineObjectToWorkspace(pipeObj);
                catch
                end
                try
                    shallowSave(shallowObj);
                catch
                end
            end

            existingPaths = app.listLoadedPipelinePaths();
            key = app.normalizeFsPath(pipeObj.path);
            if ~isempty(key) && isKey(existingPaths, key)
                return;
            end

            varName = app.nextPipelineVarName(pipeObj);
            assignin('base', varName, pipeObj);

            try
                app.registerRecentPipeline(string(fullfile(pipeObj.path,'pipeline.json')));
            catch
            end
        end

        function rawPath = deriveRawDataPathFromProject(app, shallowObj) %#ok<INUSD>
            rawPath = '';

            try
                if isprop(shallowObj,'runProfiles') && isfield(shallowObj.runProfiles,'dataloading')
                    dl = shallowObj.runProfiles.dataloading;
                    if isfield(dl,'dataLoader') && isstruct(dl.dataLoader)
                        if isfield(dl.dataLoader,'path') && ~isempty(dl.dataLoader.path)
                            rawPath = char(string(dl.dataLoader.path));
                            if exist(rawPath,'dir')
                                return;
                            end
                            rawPath = '';
                        end
                    end
                end
            catch
                rawPath = '';
            end

            try
                if ~isempty(shallowObj.fov) && numel(shallowObj.fov)>=1
                    src = shallowObj.fov(1).srcpath;
                    if iscell(src) && ~isempty(src) && ~isempty(src{1})
                        rawPath = char(string(src{1}));
                        if exist(rawPath,'dir')
                            return;
                        end
                    end
                end
            catch
                rawPath = '';
            end
        end

        function changed = populateDefaultDataLoaderPath(app, pipeObj, rawPath) %#ok<INUSD>
            changed = false;
            if isempty(pipeObj) || ~isa(pipeObj,'pipeline')
                return;
            end
            if isempty(pipeObj.nodes)
                return;
            end
            if isempty(rawPath)
                return;
            end

            for iNode = 1:numel(pipeObj.nodes)
                n = pipeObj.nodes(iNode);
                if ~isfield(n,'type') || ~strcmpi(char(string(n.type)),'dataloader')
                    continue;
                end

                if ~isfield(n,'params') || ~isstruct(n.params)
                    n.params = struct();
                end

                hasPath = isfield(n.params,'path') && ~isempty(n.params.path);
                if ~hasPath || ~strcmp(char(string(n.params.path)), char(string(rawPath)))
                    n.params.path = rawPath;
                    pipeObj.nodes(iNode) = n;
                    changed = true;
                end
            end
        end

        function publishPipelineObjectToWorkspace(app, pipeObj)
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end

            targetKey = app.normalizeFsPath(pipeObj.path);
            if isempty(targetKey)
                return;
            end

            try
                vars = evalin('base', 'who');
            catch
                vars = {};
            end

            for iVar = 1:numel(vars)
                vname = vars{iVar};
                try
                    obj = evalin('base', vname);
                catch
                    continue;
                end
                if ~isa(obj, 'pipeline') || ~isprop(obj, 'path')
                    continue;
                end
                if strcmp(app.normalizeFsPath(obj.path), targetKey)
                    try
                        assignin('base', vname, pipeObj);
                    catch
                    end
                    return;
                end
            end

            try
                assignin('base', app.nextPipelineVarName(pipeObj), pipeObj);
            catch
            end
        end

        function defaultPath = getProjectDefaultPipelinePath(app, shallowObj) %#ok<INUSD>
            configuredPath = '';
            try
                if isprop(shallowObj,'runProfiles') && ~isempty(shallowObj.runProfiles) ...
                        && isfield(shallowObj.runProfiles,'pipeline') && ~isempty(shallowObj.runProfiles.pipeline)
                    p = shallowObj.runProfiles.pipeline;
                    if isfield(p,'defaultTemplatePath') && ~isempty(p.defaultTemplatePath)
                        configuredPath = char(string(p.defaultTemplatePath));
                    end
                end
            catch
                configuredPath = '';
            end

            defaultPath = app.resolveProjectPreferredPipelineJson(shallowObj, configuredPath);
        end

        function [found, pipeObj] = getProjectDefaultPipelineObject(app, shallowObj)
            found = false;
            pipeObj = [];

            jsonPath = app.getProjectDefaultPipelinePath(shallowObj);
            if isempty(jsonPath)
                return;
            end
            targetKey = app.normalizeFsPath(jsonPath);

            try
                vars = evalin('base', 'who');
            catch
                vars = {};
            end

            for iVar = 1:numel(vars)
                try
                    obj = evalin('base', vars{iVar});
                catch
                    continue;
                end
                if ~isa(obj, 'pipeline')
                    continue;
                end
                thisKey = app.normalizeFsPath(fullfile(obj.path, 'pipeline.json'));
                if ~isempty(thisKey) && strcmp(thisKey, targetKey)
                    found = true;
                    pipeObj = obj;
                    return;
                end
            end

            [pipeObj, msg] = pipelineLoad(jsonPath);
            if isempty(pipeObj)
                if ~isempty(msg)
                    warning('detecdiv:PipelineLoad', '%s', msg);
                end
                return;
            end

            found = true;
            try
                assignin('base', pipeObj.strid, pipeObj);
            catch
            end
        end

        function [isLoaded, pipeObj, pipeVar] = getLoadedPipelineForNode(app, node)
            isLoaded = false;
            pipeObj = [];
            pipeVar = '';
            if nargin < 2 || isempty(node) || ~isprop(node,'Tag') || ~strcmp(node.Tag,'Pipeline')
                return;
            end

            idx = [];
            try
                ud = node.UserData;
                if isnumeric(ud) && ~isempty(ud)
                    idx = ud(1);
                elseif isstruct(ud)
                    if isfield(ud,'pipeIdx') && ~isempty(ud.pipeIdx)
                        idx = ud.pipeIdx;
                    elseif isfield(ud,'idx') && ~isempty(ud.idx)
                        idx = ud.idx;
                    end
                    if isfield(ud,'varName') && ~isempty(ud.varName)
                        pipeVar = char(string(ud.varName));
                    elseif isfield(ud,'workspaceVar') && ~isempty(ud.workspaceVar)
                        pipeVar = char(string(ud.workspaceVar));
                    end
                end
            catch
                idx = [];
            end

            if isempty(pipeVar) && ~isempty(idx) && idx >= 1 && idx <= numel(app.Data.Pipeline)
                pipeVar = app.Data.Pipeline{idx};
            end
            if isempty(pipeVar)
                return;
            end

            try
                candidate = evalin('base', pipeVar);
                if isa(candidate,'pipeline')
                    pipeObj = candidate;
                    isLoaded = true;
                end
            catch
                pipeObj = [];
                isLoaded = false;
            end
        end

        function jsonPath = resolvePipelineJsonPathForNode(app, node)
            jsonPath = '';
            if nargin < 2 || isempty(node) || ~isprop(node,'Tag') || ~strcmp(node.Tag,'Pipeline')
                return;
            end

            [isLoaded, pipeObj] = app.getLoadedPipelineForNode(node);
            if isLoaded && isa(pipeObj,'pipeline') && isprop(pipeObj,'path') && ~isempty(pipeObj.path)
                jsonPath = fullfile(char(string(pipeObj.path)), 'pipeline.json');
                return;
            end

            try
                ud = node.UserData;
                if isstruct(ud)
                    if isfield(ud,'jsonPath') && ~isempty(ud.jsonPath)
                        jsonPath = char(string(ud.jsonPath));
                        return;
                    end
                    if isfield(ud,'pipelineJsonPath') && ~isempty(ud.pipelineJsonPath)
                        jsonPath = char(string(ud.pipelineJsonPath));
                        return;
                    end
                    if isfield(ud,'path') && ~isempty(ud.path)
                        candidatePath = char(string(ud.path));
                        if isfolder(candidatePath)
                            jsonPath = fullfile(candidatePath, 'pipeline.json');
                        else
                            jsonPath = candidatePath;
                        end
                        return;
                    end
                end
            catch
            end

            projectNode = [];
            try
                parentNode = node.Parent;
                if ~isempty(parentNode) && isprop(parentNode,'Tag') && strcmp(parentNode.Tag,'Project')
                    projectNode = parentNode;
                end
            catch
                projectNode = [];
            end
            if isempty(projectNode)
                return;
            end

            projIdx = [];
            try
                projIdx = projectNode.UserData;
            catch
                projIdx = [];
            end
            if isempty(projIdx) || projIdx < 1 || projIdx > numel(app.Data.Project)
                return;
            end

            try
                shallowObj = evalin('base', app.Data.Project{projIdx});
            catch
                shallowObj = [];
            end
            if isempty(shallowObj) || ~isa(shallowObj,'shallow')
                return;
            end

            preferred = app.getProjectDefaultPipelinePath(shallowObj);
            candidates = app.resolveProjectPipelineJsonCandidates(shallowObj);
            nodeLabel = char(string(node.Text));

            if ~isempty(preferred)
                try
                    [prefParent,~,~] = fileparts(preferred);
                    [~,prefFolder] = fileparts(prefParent);
                    if strcmp(prefFolder, nodeLabel)
                        jsonPath = preferred;
                        return;
                    end
                catch
                end
            end

            for iCand = 1:numel(candidates)
                candPath = char(string(candidates{iCand}));
                try
                    [candParent,~,~] = fileparts(candPath);
                    [~,candFolder] = fileparts(candParent);
                    if strcmp(candFolder, nodeLabel)
                        jsonPath = candPath;
                        return;
                    end
                catch
                end
            end

            if numel(candidates) == 1
                jsonPath = char(string(candidates{1}));
            elseif ~isempty(preferred)
                jsonPath = preferred;
            end
        end

        function [loaded, pipeObj, varName, jsonPath, msg] = loadPipelineForNode(app, node)
            loaded = false;
            pipeObj = [];
            varName = '';
            msg = '';
            jsonPath = app.resolvePipelineJsonPathForNode(node);

            if isempty(jsonPath)
                msg = 'Unable to resolve pipeline.json for the selected pipeline.';
                return;
            end
            if ~isfile(jsonPath)
                msg = sprintf('Pipeline not found:\n%s', jsonPath);
                return;
            end

            [pipeObj, msg] = pipelineLoad(jsonPath);
            if isempty(pipeObj)
                return;
            end

            varName = app.nextPipelineVarName(pipeObj);
            assignin('base', varName, pipeObj);
            loaded = true;

            try
                app.registerRecentPipeline(string(jsonPath));
            catch
            end
        end

        function selectPipelineNodeByJsonPath(app, jsonPath)
            if isempty(jsonPath)
                return;
            end

            targetKey = app.normalizeFsPath(jsonPath);
            if isempty(targetKey)
                return;
            end

            node = findNodeRecursive(app.Tree);
            if isempty(node)
                return;
            end

            try
                app.Tree.SelectedNodes = node;
            catch
            end

            function hit = findNodeRecursive(parentNode)
                hit = [];
                try
                    children = parentNode.Children;
                catch
                    children = [];
                end

                for iChild = 1:numel(children)
                    child = children(iChild);
                    try
                        if isprop(child,'Tag') && strcmp(child.Tag,'Pipeline')
                            childPath = app.resolvePipelineJsonPathForNode(child);
                            if strcmp(app.normalizeFsPath(childPath), targetKey)
                                hit = child;
                                return;
                            end
                        end
                    catch
                    end

                    hit = findNodeRecursive(child);
                    if ~isempty(hit)
                        return;
                    end
                end
            end
        end

        function changed = ensureProjectDefaultPipelineNode(app, shallowObj, nodeType, params)
            changed = false;
            if nargin < 4 || isempty(params) || ~isstruct(params)
                params = struct();
            end
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end

            pipeObj = app.ensureDefaultPipelineForProject(shallowObj);
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                [found, pipeObj] = app.getProjectDefaultPipelineObject(shallowObj);
                if ~found || isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                    return;
                end
            end

            targetType = lower(char(string(nodeType)));
            for iNode = 1:numel(pipeObj.nodes)
                node = pipeObj.nodes(iNode);
                if isfield(node, 'type') && strcmpi(char(string(node.type)), targetType)
                    return;
                end
            end

            switch targetType
                case 'roiextract'
                    defaults = roiExtract.setparam(struct());
                    node = struct( ...
                        'id', 'roiextract_1', ...
                        'name', 'roiextract_1', ...
                        'type', 'roiExtract', ...
                        'func', 'roiExtract.process', ...
                        'gui', 'roiExtract.ui', ...
                        'guiMode', 'replace', ...
                        'paramRequired', {{}}, ...
                        'pkg', '', ...
                        'params', defaults, ...
                        'inputs', {{'roiList'}}, ...
                        'outputs', {{'channels'}}, ...
                        'enabled', true, ...
                        'status', '', ...
                        'layout', [70 10 20 10]);
                otherwise
                    return;
            end

            if ~isempty(fieldnames(params))
                node.params = params;
            end

            nodes = pipeObj.nodes;
            insertIdx = numel(nodes) + 1;
            roiTypes = {'roiidentify','roipattern','roimanual','roigrid','roitracked'};
            for iNode = 1:numel(nodes)
                t = '';
                if isfield(nodes(iNode), 'type')
                    t = lower(char(string(nodes(iNode).type)));
                end
                if any(strcmp(t, roiTypes))
                    insertIdx = iNode + 1;
                end
            end

            nodes = app.insertNodeWithAlignedFields(nodes, node, insertIdx);
            pipeObj.nodes = pipelineNormalizeNodes(nodes, 'persist');

            roiId = '';
            for iNode = 1:numel(nodes)
                t = '';
                if isfield(nodes(iNode), 'type')
                    t = lower(char(string(nodes(iNode).type)));
                end
                if any(strcmp(t, roiTypes))
                    roiId = char(string(nodes(iNode).id));
                end
            end
            if ~isempty(roiId)
                pipeObj.edges(end+1) = struct('from', roiId, 'to', node.id, 'fromPort', 'roiList', 'toPort', 'roiList', 'condition', ''); %#ok<AGROW>
            end

            try
                pipelineSave(pipeObj);
                app.publishPipelineObjectToWorkspace(pipeObj);
                changed = true;
            catch ME
                warning('detecdiv:PipelineSave', '%s', ME.message);
            end
        end

        function changed = updateProjectDefaultPipelineNodeParams(app, shallowObj, nodeType, params)
            changed = false;
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end

            [found, pipeObj] = app.getProjectDefaultPipelineObject(shallowObj);
            if ~found || isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end

            for iNode = 1:numel(pipeObj.nodes)
                node = pipeObj.nodes(iNode);
                if ~isfield(node, 'type') || ~strcmpi(char(string(node.type)), char(string(nodeType)))
                    continue;
                end
                node.params = params;
                pipeObj.nodes(iNode) = node;
                changed = true;
                break;
            end

            if changed
                try
                    pipelineSave(pipeObj);
                    app.publishPipelineObjectToWorkspace(pipeObj);
                catch ME
                    warning('detecdiv:PipelineSave', '%s', ME.message);
                end
            end
        end

        function changed = replaceProjectDefaultRoiProducerNode(app, shallowObj, nodeType, params)
            changed = false;
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end

            pipeObj = app.ensureDefaultPipelineForProject(shallowObj);
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                [found, pipeObj] = app.getProjectDefaultPipelineObject(shallowObj);
                if ~found || isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                    return;
                end
            end

            roiTypes = {'roiidentify','roipattern','roigrid','roimanual','roitracked'};
            modeName = lower(char(string(nodeType)));
            switch modeName
                case {'roiidentify','roipattern'}
                    workflowMode = 'pattern';
                case 'roigrid'
                    workflowMode = 'grid';
                otherwise
                    workflowMode = modeName;
            end

            nodes = pipeObj.nodes;
            roiIdx = [];
            roiOldIds = {};
            roiLayout = [40 10 20 10];
            for iNode = 1:numel(nodes)
                t = '';
                if isfield(nodes(iNode), 'type')
                    t = lower(char(string(nodes(iNode).type)));
                end
                if any(strcmp(t, roiTypes))
                    roiIdx(end+1) = iNode; %#ok<AGROW>
                    roiOldIds{end+1} = char(string(nodes(iNode).id)); %#ok<AGROW>
                    if isfield(nodes(iNode), 'layout') && ~isempty(nodes(iNode).layout)
                        roiLayout = nodes(iNode).layout;
                    end
                end
            end

            newNode = app.buildDefaultRoiProducerNode(nodeType, params, roiLayout);
            if isempty(newNode)
                return;
            end

            if isempty(roiIdx)
                insertIdx = numel(nodes) + 1;
                for iNode = 1:numel(nodes)
                    t = '';
                    if isfield(nodes(iNode), 'type')
                        t = lower(char(string(nodes(iNode).type)));
                    end
                    if strcmp(t, 'roiextract')
                        insertIdx = iNode;
                        break;
                    end
                end
                nodes = app.insertNodeWithAlignedFields(nodes, newNode, insertIdx);
            else
                insertIdx = roiIdx(1);
                keepMask = true(1, numel(nodes));
                keepMask(roiIdx) = false;
                keptNodes = nodes(keepMask);
                if insertIdx <= 1
                    nodes = app.insertNodeWithAlignedFields(keptNodes, newNode, 1);
                elseif insertIdx > numel(keptNodes)
                    nodes = app.insertNodeWithAlignedFields(keptNodes, newNode, numel(keptNodes) + 1);
                else
                    nodes = app.insertNodeWithAlignedFields(keptNodes, newNode, insertIdx);
                end
            end

            pipeObj.nodes = pipelineNormalizeNodes(nodes, 'persist');

            normEdges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            roiIds = {newNode.id};
            if ~isempty(roiOldIds)
                roiIds = [roiIds roiOldIds]; %#ok<AGROW>
            end
            for iNode = 1:numel(nodes)
                t = '';
                if isfield(nodes(iNode), 'type')
                    t = lower(char(string(nodes(iNode).type)));
                end
                if any(strcmp(t, roiTypes))
                    idVal = char(string(nodes(iNode).id));
                    if ~any(strcmp(roiIds, idVal))
                        roiIds{end+1} = idVal; %#ok<AGROW>
                    end
                end
            end

            for iEdge = 1:numel(pipeObj.edges)
                e = pipeObj.edges(iEdge);
                fromId = '';
                toId = '';
                if isfield(e, 'from'), fromId = char(string(e.from)); end
                if isfield(e, 'to'), toId = char(string(e.to)); end
                if any(strcmp(roiIds, fromId)) || any(strcmp(roiIds, toId))
                    continue;
                end
                normEdges(end+1) = e; %#ok<AGROW>
            end

            loaderId = '';
            extractId = '';
            maskSourceId = '';
            for iNode = 1:numel(nodes)
                t = '';
                if isfield(nodes(iNode), 'type')
                    t = lower(char(string(nodes(iNode).type)));
                end
                if strcmp(t, 'dataloader') && isempty(loaderId)
                    loaderId = char(string(nodes(iNode).id));
                elseif strcmp(t, 'roiextract') && isempty(extractId)
                    extractId = char(string(nodes(iNode).id));
                elseif strcmp(t, 'classifier') && isempty(maskSourceId)
                    outs = {};
                    if isfield(nodes(iNode),'outputs') && ~isempty(nodes(iNode).outputs)
                        outs = lower(cellstr(nodes(iNode).outputs(:)));
                    end
                    if any(strcmp(outs,'masks'))
                        maskSourceId = char(string(nodes(iNode).id));
                    end
                end
            end

            if ~isempty(loaderId)
                normEdges(end+1) = struct('from', loaderId, 'to', newNode.id, 'fromPort', 'images', 'toPort', 'images', 'condition', ''); %#ok<AGROW>
            end
            if strcmpi(newNode.type, 'roiTracked') && ~isempty(maskSourceId)
                normEdges(end+1) = struct('from', maskSourceId, 'to', newNode.id, 'fromPort', 'masks', 'toPort', 'masks', 'condition', ''); %#ok<AGROW>
            end
            if ~isempty(extractId)
                normEdges(end+1) = struct('from', newNode.id, 'to', extractId, 'fromPort', 'roiList', 'toPort', 'roiList', 'condition', ''); %#ok<AGROW>
            end
            pipeObj.edges = normEdges;

            if ~isfield(pipeObj.runProfiles, 'roiWorkflow') || ~isstruct(pipeObj.runProfiles.roiWorkflow)
                pipeObj.runProfiles.roiWorkflow = struct();
            end
            pipeObj.runProfiles.roiWorkflow.mode = workflowMode;

            try
                pipelineSave(pipeObj);
                app.publishPipelineObjectToWorkspace(pipeObj);
                changed = true;
            catch ME
                warning('detecdiv:PipelineSave', '%s', ME.message);
            end
        end

        function nodes = insertNodeWithAlignedFields(app, nodes, node, insertIdx) %#ok<INUSD>
            if nargin < 4 || isempty(insertIdx)
                insertIdx = numel(nodes) + 1;
            end
            node = pipelineNormalizeNodes(node, 'persist');
            if isempty(nodes)
                nodes = node;
                return;
            end

            [nodes, node] = alignStructFieldsForNodeInsert(app, nodes, node);
            insertIdx = max(1, min(double(insertIdx), numel(nodes) + 1));
            if insertIdx > numel(nodes)
                nodes(end+1) = node; %#ok<AGROW>
            else
                tail = nodes(insertIdx:end);
                nodes = nodes(1:insertIdx-1);
                nodes(end+1) = node; %#ok<AGROW>
                for iTail = 1:numel(tail)
                    nodes(end+1) = tail(iTail); %#ok<AGROW>
                end
            end
        end

        function [nodes, node] = alignStructFieldsForNodeInsert(app, nodes, node) %#ok<INUSD>
            nodeFields = fieldnames(node);
            nodeArrayFields = fieldnames(nodes);
            allFields = unique([nodeArrayFields; nodeFields], 'stable');
            for i = 1:numel(allFields)
                key = allFields{i};
                if ~isfield(nodes, key)
                    [nodes.(key)] = deal([]);
                end
                if ~isfield(node, key)
                    node.(key) = [];
                end
            end
            nodes = orderfields(nodes, allFields);
            node = orderfields(node, allFields);
        end

        function node = buildDefaultRoiProducerNode(app, nodeType, params, layout) %#ok<INUSD>
            node = [];
            if nargin < 4 || isempty(layout)
                layout = [40 10 20 10];
            end

            t = lower(char(string(nodeType)));
            switch t
                case {'roiidentify','roipattern'}
                    defaults = roiPattern.setparam(struct());
                    node = struct( ...
                        'id', 'roipattern_1', ...
                        'name', 'roipattern_1', ...
                        'type', 'roiPattern', ...
                        'func', 'roiPattern.process', ...
                        'gui', 'roiPattern.ui', ...
                        'guiMode', 'replace', ...
                        'paramRequired', {{}}, ...
                        'pkg', '', ...
                        'params', defaults, ...
                        'inputs', {{'images'}}, ...
                        'outputs', {{'roiList'}}, ...
                        'enabled', true, ...
                        'status', '', ...
                        'layout', layout);
                case 'roimanual'
                    defaults = roiManual.setparam(struct());
                    node = struct( ...
                        'id', 'roimanual_1', ...
                        'name', 'roimanual_1', ...
                        'type', 'roiManual', ...
                        'func', 'roiManual.process', ...
                        'gui', 'roiManual.ui', ...
                        'guiMode', 'replace', ...
                        'paramRequired', {{}}, ...
                        'pkg', '', ...
                        'params', defaults, ...
                        'inputs', {{'images'}}, ...
                        'outputs', {{'roiList'}}, ...
                        'enabled', true, ...
                        'status', '', ...
                        'layout', layout);
                case 'roigrid'
                    defaults = roiGrid.setparam(struct());
                    node = struct( ...
                        'id', 'roigrid_1', ...
                        'name', 'roigrid_1', ...
                        'type', 'roiGrid', ...
                        'func', 'roiGrid.process', ...
                        'gui', 'roiGrid.ui', ...
                        'guiMode', 'replace', ...
                        'paramRequired', {{}}, ...
                        'pkg', '', ...
                        'params', defaults, ...
                        'inputs', {{'images'}}, ...
                        'outputs', {{'roiList'}}, ...
                        'enabled', true, ...
                        'status', '', ...
                        'layout', layout);
                case 'roitracked'
                    defaults = roiTracked.setparam(struct());
                    node = struct( ...
                        'id', 'roitracked_1', ...
                        'name', 'roitracked_1', ...
                        'type', 'roiTracked', ...
                        'func', 'roiTracked.process', ...
                        'gui', 'roiTracked.ui', ...
                        'guiMode', 'replace', ...
                        'paramRequired', {{}}, ...
                        'pkg', '', ...
                        'params', defaults, ...
                        'inputs', {{'roiList','masks'}}, ...
                        'outputs', {{'roiList'}}, ...
                        'enabled', true, ...
                        'status', '', ...
                        'layout', layout);
                otherwise
                    return;
            end

            if nargin >= 3 && isstruct(params) && ~isempty(params)
                node.params = params;
            end
        end

        function changed = setProjectDefaultPipelineRoiMode(app, shallowObj, modeName)
            changed = false;
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end

            pipeObj = app.ensureDefaultPipelineForProject(shallowObj);
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                [found, pipeObj] = app.getProjectDefaultPipelineObject(shallowObj);
                if ~found || isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                    return;
                end
            end

            modeName = lower(char(string(modeName)));
            roiNodeChanged = false;
            roiNodeFound = false;

            for iNode = 1:numel(pipeObj.nodes)
                node = pipeObj.nodes(iNode);
                if ~isfield(node, 'type')
                    continue;
                end
                if ~strcmpi(char(string(node.type)), 'roiidentify') && ~strcmpi(char(string(node.type)), 'roipattern') && ~strcmpi(char(string(node.type)), 'roimanual') && ~strcmpi(char(string(node.type)), 'roigrid') && ~strcmpi(char(string(node.type)), 'roitracked')
                    continue;
                end

                roiNodeFound = true;
                if ~isfield(node, 'params') || ~isstruct(node.params)
                    node.params = struct();
                end

                if strcmpi(char(string(node.type)), 'roiidentify') || strcmpi(char(string(node.type)), 'roiPattern')
                    newEnabled = strcmp(modeName, 'pattern');
                elseif strcmpi(char(string(node.type)), 'roiManual')
                    newEnabled = strcmp(modeName, 'manual');
                elseif strcmpi(char(string(node.type)), 'roiTracked')
                    newEnabled = strcmp(modeName, 'tracked');
                else
                    newEnabled = strcmp(modeName, 'grid');
                end
                if ~isfield(node, 'enabled') || logical(node.enabled) ~= newEnabled
                    node.enabled = newEnabled;
                    roiNodeChanged = true;
                end
                if ~isfield(node.params, 'roiMode') || ~strcmp(char(string(node.params.roiMode)), modeName)
                    node.params.roiMode = modeName;
                    roiNodeChanged = true;
                end

                pipeObj.nodes(iNode) = node;
            end

            if ~isfield(pipeObj.runProfiles, 'roiWorkflow') || ~isstruct(pipeObj.runProfiles.roiWorkflow)
                pipeObj.runProfiles.roiWorkflow = struct();
            end
            currentMode = '';
            if isfield(pipeObj.runProfiles.roiWorkflow, 'mode') && ~isempty(pipeObj.runProfiles.roiWorkflow.mode)
                currentMode = char(string(pipeObj.runProfiles.roiWorkflow.mode));
            end
            if ~strcmp(currentMode, modeName)
                pipeObj.runProfiles.roiWorkflow.mode = modeName;
                changed = true;
            end

            if roiNodeFound && roiNodeChanged
                changed = true;
            end

            if changed
                try
                    pipelineSave(pipeObj);
                    app.publishPipelineObjectToWorkspace(pipeObj);
                catch ME
                    warning('detecdiv:PipelineSave', '%s', ME.message);
                end
            end
        end

        function nodeType = getProjectCurrentRoiProducerType(app, shallowObj)
            nodeType = '';
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end

            [found, pipeObj] = app.getProjectDefaultPipelineObject(shallowObj);
            if ~found || isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end

            roiTypes = {'roiidentify','roipattern','roimanual','roigrid','roitracked'};
            fallbackType = '';
            for iNode = 1:numel(pipeObj.nodes)
                node = pipeObj.nodes(iNode);
                if ~isfield(node, 'type')
                    continue;
                end
                t = lower(char(string(node.type)));
                if any(strcmp(t, roiTypes))
                    enabled = true;
                    if isfield(node, 'enabled') && ~isempty(node.enabled)
                        enabled = logical(node.enabled);
                    end
                    if enabled
                        nodeType = t;
                        return;
                    end
                    if isempty(fallbackType)
                        fallbackType = t;
                    end
                end
            end
            nodeType = fallbackType;
        end

        function outType = canonicalRoiProducerType(app, nodeType) %#ok<INUSD>
            outType = lower(char(string(nodeType)));
            switch outType
                case {'roiidentify','roipattern'}
                    outType = 'roipattern';
            end
        end

        function changed = applyProjectRoiProducerChoice(app, shallowObj, nodeType, params)
            changed = false;
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end

            currentType = app.getProjectCurrentRoiProducerType(shallowObj);
            targetCanon = app.canonicalRoiProducerType(nodeType);
            currentCanon = app.canonicalRoiProducerType(currentType);

            if ~isempty(currentType) && strcmp(currentCanon, targetCanon) && ~strcmpi(currentType, 'roiidentify')
                changed = app.updateProjectDefaultPipelineNodeParams(shallowObj, currentType, params);
            else
                changed = app.replaceProjectDefaultRoiProducerNode(shallowObj, nodeType, params);
            end
        end

        function params = getProjectDefaultPipelineNodeParams(app, shallowObj, nodeType)
            params = struct();
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end

            [found, pipeObj] = app.getProjectDefaultPipelineObject(shallowObj);
            if ~found || isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end

            targetType = lower(char(string(nodeType)));
            switch targetType
                case {'roipattern','roiidentify'}
                    matchTypes = {'roipattern','roiidentify'};
                case 'roimanual'
                    matchTypes = {'roimanual'};
                case 'roigrid'
                    matchTypes = {'roigrid'};
                otherwise
                    matchTypes = {targetType};
            end

            for iNode = 1:numel(pipeObj.nodes)
                node = pipeObj.nodes(iNode);
                if ~isfield(node, 'type')
                    continue;
                end
                if ~any(strcmpi(char(string(node.type)), matchTypes))
                    continue;
                end
                if isfield(node, 'params') && isstruct(node.params)
                    params = node.params;
                end
                return;
            end
        end

        function changed = setProjectDefaultPipelineRef(app, shallowObj, pipeObj) %#ok<INUSD>
            changed = false;
            if isempty(shallowObj) || ~isa(shallowObj,'shallow') || isempty(pipeObj) || ~isa(pipeObj,'pipeline')
                return;
            end

            if ~isprop(shallowObj,'runProfiles') || isempty(shallowObj.runProfiles) || ~isstruct(shallowObj.runProfiles)
                shallowObj.runProfiles = struct();
            end
            if ~isfield(shallowObj.runProfiles,'pipeline') || isempty(shallowObj.runProfiles.pipeline) || ~isstruct(shallowObj.runProfiles.pipeline)
                shallowObj.runProfiles.pipeline = struct();
            end

            pipeInfo = shallowObj.runProfiles.pipeline;
            jsonPath = fullfile(pipeObj.path, 'pipeline.json');
            pipeId = char(string(pipeObj.strid));

            curPath = '';
            curId = '';
            if isfield(pipeInfo,'defaultTemplatePath') && ~isempty(pipeInfo.defaultTemplatePath)
                curPath = char(string(pipeInfo.defaultTemplatePath));
            end
            if isfield(pipeInfo,'defaultTemplateId') && ~isempty(pipeInfo.defaultTemplateId)
                curId = char(string(pipeInfo.defaultTemplateId));
            end

            if ~strcmp(app.normalizeFsPath(curPath), app.normalizeFsPath(jsonPath))
                pipeInfo.defaultTemplatePath = jsonPath;
                changed = true;
            end
            if ~strcmp(curId, pipeId)
                pipeInfo.defaultTemplateId = pipeId;
                changed = true;
            end

            shallowObj.runProfiles.pipeline = pipeInfo;
        end

        function paths = resolveProjectPipelineJsonCandidates(app, shallowObj) %#ok<INUSD>
            paths = {};
            if isempty(shallowObj) || ~isa(shallowObj,'shallow')
                return;
            end
            if isempty(shallowObj.io.path) || isempty(shallowObj.io.file)
                return;
            end

            projectRoot = fullfile(char(string(shallowObj.io.path)), char(string(shallowObj.io.file)));
            if ~exist(projectRoot,'dir')
                return;
            end

            d = dir(fullfile(projectRoot,'*','pipeline.json'));
            if isempty(d) && exist(fullfile(projectRoot,'pipeline.json'),'file')
                d = dir(fullfile(projectRoot,'pipeline.json'));
            end
            if isempty(d)
                return;
            end

            seen = containers.Map('KeyType','char','ValueType','logical');
            for i = 1:numel(d)
                p = fullfile(d(i).folder, d(i).name);
                key = app.normalizeFsPath(p);
                if isempty(key) || isKey(seen, key)
                    continue;
                end
                seen(key) = true;
                paths{end+1} = p; %#ok<AGROW>
            end
        end

        function preferredPath = resolveProjectPreferredPipelineJson(app, shallowObj, configuredPath) %#ok<INUSD>
            preferredPath = '';
            if nargin < 3 || isempty(configuredPath)
                configuredPath = '';
            else
                configuredPath = char(string(configuredPath));
            end

            candidates = app.resolveProjectPipelineJsonCandidates(shallowObj);

            if ~isempty(configuredPath)
                cfgKey = app.normalizeFsPath(configuredPath);
                for i = 1:numel(candidates)
                    candPath = char(string(candidates{i}));
                    if strcmp(app.normalizeFsPath(candPath), cfgKey)
                        preferredPath = candPath;
                        return;
                    end
                end

                cfgFolder = '';
                try
                    [cfgParent,~,~] = fileparts(configuredPath);
                    [~,cfgFolder] = fileparts(cfgParent);
                    cfgFolder = char(string(cfgFolder));
                catch
                    cfgFolder = '';
                end

                if ~isempty(cfgFolder)
                    for i = 1:numel(candidates)
                        candPath = char(string(candidates{i}));
                        [candParent,~,~] = fileparts(candPath);
                        [~,candFolder] = fileparts(candParent);
                        if strcmpi(char(string(candFolder)), cfgFolder)
                            preferredPath = candPath;
                            return;
                        end
                    end
                end
            end

            if ~isempty(configuredPath) && exist(configuredPath,'file')
                preferredPath = configuredPath;
                return;
            end

            if numel(candidates) == 1
                preferredPath = char(string(candidates{1}));
            end
        end


   function registerRecentProject(app, projectPath)



    % --- Normaliser input -> string scalar
    projectPath = string(projectPath);
    projectPath = projectPath(1);

    % --- Purge + normaliser liste existante -> string colonne
    app.cleanRecentProjectsList();

    old = app.RecentProjects;
    if isempty(old)
        old = string.empty(0,1);
    else
        if iscell(old), old = string(old); end
        old = string(old);
        old = old(:);
    end

    % --- Prepend + dédoublonner (garde le plus récent)
    newList = [projectPath; old];
    newList = unique(newList, 'stable');

    % --- Limiter
    maxN = 10;
    if numel(newList) > maxN
        newList = newList(1:maxN);
    end

    app.RecentProjects = newList;

    % --- Sauver sur disque
    try
        RecentProjects = app.RecentProjects; %#ok<NASGU>
        save(app.RecentProjectsFile, 'RecentProjects');
    catch ME
        warning('Could not save recent projects list: %s', ME.message);
    end

    % --- Refresh menu
    app.refreshRecentProjectsMenu();
end


function registerRecentClassifier(app, classiMatPath)
    % classiMatPath = chemin absolu vers le *_classification.mat

    % --- Normaliser input -> string scalar
    classiMatPath = string(classiMatPath);
    classiMatPath = classiMatPath(1);

    % --- Purge + normaliser liste existante -> string colonne
    app.cleanRecentClassifiersList();

    old = app.RecentClassifiers;
    if isempty(old)
        old = string.empty(0,1);
    else
        if iscell(old), old = string(old); end
        old = string(old);
        old = old(:);
    end

    % --- Prepend + dédoublonner (garde le plus récent)
    newList = [classiMatPath; old];
    newList = unique(newList, 'stable');

    % --- Limiter
    maxN = 10;
    if numel(newList) > maxN
        newList = newList(1:maxN);
    end

    app.RecentClassifiers = newList;

    % --- Sauver sur disque
    try
        RecentClassifiers = app.RecentClassifiers; %#ok<NASGU>
        save(app.RecentClassifiersFile, 'RecentClassifiers');
    catch ME
        warning('Could not save recent classifiers list: %s', ME.message);
    end

    % --- Refresh menu
    app.refreshRecentClassifiersMenu();
end




function registerRecentPipeline(app, pipelineJsonPath)
    pipelineJsonPath = string(pipelineJsonPath);
    pipelineJsonPath = pipelineJsonPath(1);

    app.cleanRecentPipelinesList();

    old = app.RecentPipelines;
    if isempty(old)
        old = string.empty(0,1);
    else
        if iscell(old), old = string(old); end
        old = string(old);
        old = old(:);
    end

    newList = [pipelineJsonPath; old];
    newList = unique(newList, 'stable');

    maxN = 10;
    if numel(newList) > maxN
        newList = newList(1:maxN);
    end

    app.RecentPipelines = newList;

    try
        RecentPipelines = app.RecentPipelines; %#ok<NASGU>
        save(app.RecentPipelinesFile, 'RecentPipelines');
    catch ME
        warning('Could not save recent pipelines list: %s', ME.message);
    end

    app.refreshRecentPipelinesMenu();
end


function refreshRecentPipelinesMenu(app)

    if ~isempty(app.OpenrecentPipelineMenu.Children)
        delete(app.OpenrecentPipelineMenu.Children);
    end

    if isempty(app.RecentPipelines)
        uimenu(app.OpenrecentPipelineMenu, ...
            'Text','(No recent pipelines)', ...
            'Enable','off');
        return;
    end

    for k = 1:numel(app.RecentPipelines)
        thisPath = app.RecentPipelines(k);

        [parentDir, shortName] = fileparts(thisPath);
        [~, pipeFolder] = fileparts(parentDir);
        if strlength(pipeFolder) == 0
            labelName = shortName;
        else
            labelName = pipeFolder;
        end

        label = sprintf('%d. %s', k, labelName);

        uimenu(app.OpenrecentPipelineMenu, ...
            'Text', label, ...
            'Tooltip', char(thisPath), ...
            'MenuSelectedFcn', @(src,evt)app.openRecentPipelineCallback(thisPath));
    end

    uimenu(app.OpenrecentPipelineMenu, ...
        'Separator','on', ...
        'Text','Clear recent list', ...
        'MenuSelectedFcn', @(src,evt)app.clearRecentPipelines());
end


function openRecentPipelineCallback(app, pipelineJsonPath)

    if isstring(pipelineJsonPath)
        pipelineJsonPath = char(pipelineJsonPath(1));
    end

    if ~isfile(pipelineJsonPath)
        uialert(app.DetecDivUIFigure, ...
            sprintf('Pipeline not found:\n%s\nIt will be removed from recent list.', pipelineJsonPath), ...
            'Missing pipeline', ...
            'Icon','warning');

        app.cleanRecentPipelinesList();
        app.refreshRecentPipelinesMenu();
        return;
    end

    d = uiprogressdlg(app.DetecDivUIFigure, ...
        'Title','Please Wait...', ...
        'Message','Loading selected pipeline...');
    d.Value = 0.33;

    [pipeObj, msg] = pipelineLoad(pipelineJsonPath);

    if isempty(pipeObj)
        close(d);
        if ~isempty(msg)
            uialert(app.DetecDivUIFigure, msg, 'Error', 'Icon', 'error');
        end
        return;
    end

    d.Value = 0.66;
    pause(0.2);

    varBase = matlab.lang.makeValidName(pipeObj.strid);
    varName = varBase;
    used = evalin('base','who');
    n = 1;
    while any(strcmp(used, varName))
        n = n + 1;
        varName = [varBase '_' num2str(n)];
    end

    assignin('base', varName, pipeObj);

    app.registerRecentPipeline(string(pipelineJsonPath));

    gatherVarsFromWorkspace(app);
    displayNodes(app);

    close(d);
end


function refreshRecentClassifiersMenu(app)

    % Vider l'ancien contenu
    if ~isempty(app.OpenrecentClassiMenu.Children)
        delete(app.OpenrecentClassiMenu.Children);
    end

    if isempty(app.RecentClassifiers)
        uimenu(app.OpenrecentClassiMenu, ...
            'Text','(No recent classifiers)', ...
            'Enable','off');
        return;
    end

    for k = 1:numel(app.RecentClassifiers)
        thisClassiPath = app.RecentClassifiers(k);

        [~, shortName, ext] = fileparts(thisClassiPath);
        shortName = shortName + ext;  % e.g. "yolo_1_classification.mat"

        label = sprintf('%d. %s', k, shortName);

        uimenu(app.OpenrecentClassiMenu, ...
            'Text', label, ...
            'Tooltip', char(thisClassiPath), ...
            'MenuSelectedFcn', @(src,evt)app.openRecentClassifierCallback(thisClassiPath));
    end

    uimenu(app.OpenrecentClassiMenu, ...
        'Separator','on', ...
        'Text','Clear recent list', ...
        'MenuSelectedFcn', @(src,evt)app.clearRecentClassifiers());
end






        function refreshRecentProjectsMenu(app)

            if ~isempty(app.OpenrecentMenu.Children)
                delete(app.OpenrecentMenu.Children);
            end

            if isempty(app.RecentProjects)
                uimenu(app.OpenrecentMenu, ...
                    'Text','(No recent projects)', ...
                    'Enable','off');
                return;
            end

            for k = 1:numel(app.RecentProjects)
                thisPath = app.RecentProjects(k);
                
                % complet avec .mat

                [~, shortName, ext] = fileparts(thisPath);
                shortName = shortName + ext;  % ex: tmpProject.mat

                label = sprintf('%d. %s', k, shortName);

                uimenu(app.OpenrecentMenu, ...
                    'Text', label, ...
                    'Tooltip', char(thisPath), ...
                    'MenuSelectedFcn', @(src,evt)app.openRecentProjectCallback(thisPath));
            end

            uimenu(app.OpenrecentMenu, 'Separator','on', ...
                'Text','Clear recent list', ...
                'MenuSelectedFcn', @(src,evt)app.clearRecentProjects());
        end



function openRecentProjectCallback(app, projectPath)

    % force scalaire string -> char pour être sûr
    if isstring(projectPath)
        projectPath = projectPath(1); % prend juste le premier élément si jamais c'est un array
        projectPathChar = char(projectPath);
    else
        projectPathChar = projectPath; % déjà char
    end

    if ~isfile(projectPathChar)
        uialert(app.DetecDivUIFigure, ...
            sprintf('Project not found:\n%s\nIt will be removed from recent list.', projectPathChar), ...
            'Missing project', ...
            'Icon','warning');

        app.cleanRecentProjectsList();
        app.refreshRecentProjectsMenu();
        return;
    end

    d = uiprogressdlg(app.DetecDivUIFigure, ...
        'Title','Please Wait...', ...
        'Message','Loading selected project...');
    d.Value = 0.33;

    [proj, msg] = shallowLoad(projectPathChar);

    if isempty(proj)
        close(d);
        if ~isempty(msg)
            uialert(app.DetecDivUIFigure, msg, 'Error', 'Icon', 'error');
        end
        return;
    end

    [proj, hubAccess] = detecdiv_hub_prepare_project_open(proj);

    d.Value = 0.66;
    pause(0.2);

    name = proj.io.file;
    assignin('base', name, proj);

    % Auto-load pipeline templates referenced by existing project runs
    app.autoLoadPipelinesForProjectRuns(proj);

    % on réenregistre le chemin propre (pas le tableau chelou)
    app.registerRecentProject(string(projectPathChar));

    gatherVarsFromWorkspace(app);
    displayNodes(app);

    if hubAccess.hubManaged && hubAccess.readOnly
        uialert(app.DetecDivUIFigure, hubAccess.reason, 'Hub project opened read-only', 'Icon', 'warning');
    end

    close(d);
end


function openRecentClassifierCallback(app, classiMatPath)

    % sécuriser en char scalaire
    if isstring(classiMatPath)
        classiMatPath = char(classiMatPath(1));
    end

    if ~isfile(classiMatPath)
        uialert(app.DetecDivUIFigure, ...
            sprintf('Classifier not found:\n%s\nIt will be removed from recent list.', classiMatPath), ...
            'Missing classifier', ...
            'Icon','warning');

        app.cleanRecentClassifiersList();
        app.refreshRecentClassifiersMenu();
        return;
    end

    d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...',...
        'Message','Loading selected classifier...');
    d.Value = 0.33;

    % recharge via classiLoad(fullpath)
    [classiObj, msg] = classiLoad(classiMatPath);

    if isempty(classiObj)
        close(d);
        if ~isempty(msg)
            uialert(app.DetecDivUIFigure,msg,'Error','Icon','error');
        end
        return;
    end

    d.Value = 0.66;
    pause(0.2);

    % publier dans base workspace, cohérent avec ta callback existante
    name = [classiObj.strid '_indep'];
    assignin('base', name, classiObj);

    % le remettre en tête de la liste "récents"
    app.registerRecentClassifier(classiMatPath);

    % refresh l'état interne / arbres etc.
    gatherVarsFromWorkspace(app);
    displayNodes(app);

    close(d);
end

function cleanRecentClassifiersList(app)
    rc = string(app.RecentClassifiers(:));
    rc = rc(rc ~= "");  % vire les vides

    keep = false(size(rc));
    for k = 1:numel(rc)
        keep(k) = isfile(rc(k));  % on ne garde que les chemins encore valides
    end
    rc = rc(keep);

    % unicité (conserve l'ordre LRU)
    [~, ia] = unique(rc, 'stable');
    rc = rc(sort(ia,'ascend'));

    % max 10
    if numel(rc) > 10
        rc = rc(1:10);
    end

    app.RecentClassifiers = rc;
end



function cleanRecentPipelinesList(app)
    rp = string(app.RecentPipelines(:));
    rp = rp(rp ~= "");

    keep = false(size(rp));
    for k = 1:numel(rp)
        keep(k) = isfile(rp(k));
    end
    rp = rp(keep);

    [~, ia] = unique(rp, 'stable');
    rp = rp(ia);

    if numel(rp) > 10
        rp = rp(1:10);
    end

    app.RecentPipelines = rp;
end


         function cleanRecentProjectsList(app)
        rp = string(app.RecentProjects(:));
        rp = rp(rp ~= "");

        keep = false(size(rp));
        for k = 1:numel(rp)
            keep(k) = isfile(rp(k)); % le .mat doit exister encore
        end
        rp = rp(keep);

        % unicité en préservant l'ordre
     [~, ia] = unique(rp, 'stable');
rp = rp(ia);


        % max 10
        if numel(rp) > 10
            rp = rp(1:10);
        end

        app.RecentProjects = rp;
         end

   function clearRecentClassifiers(app)
    choice = uiconfirm(app.DetecDivUIFigure, ...
        'Clear the list of recent classifiers ?', ...
        'Confirm', ...
        'Options', {'Yes','No'}, ...
        'DefaultOption','No', ...
        'CancelOption','No');

    if strcmp(choice,'Yes')
        app.RecentClassifiers = strings(0);

        try
            RecentClassifiers = app.RecentClassifiers; %#ok<NASGU>
            save(app.RecentClassifiersFile, 'RecentClassifiers');
        catch ME
            warning('Could not save cleared recent classifiers list: %s', ME.message);
        end

        app.refreshRecentClassifiersMenu();
    end
end




   function clearRecentPipelines(app)
    choice = uiconfirm(app.DetecDivUIFigure, ...
        'Clear the list of recent pipelines ?', ...
        'Confirm', ...
        'Options', {'Yes','No'}, ...
        'DefaultOption','No', ...
        'CancelOption','No');

    if strcmp(choice,'Yes')
        app.RecentPipelines = strings(0);

        try
            RecentPipelines = app.RecentPipelines; %#ok<NASGU>
            save(app.RecentPipelinesFile, 'RecentPipelines');
        catch ME
            warning('Could not save cleared recent pipelines list: %s', ME.message);
        end

        app.refreshRecentPipelinesMenu();
    end
end


        function clearRecentProjects(app)
            choice = uiconfirm(app.DetecDivUIFigure, ...
                'Clear the list of recent projects ?', ...
                'Confirm', ...
                'Options', {'Yes','No'}, ...
                'DefaultOption','No', ...
                'CancelOption','No');

            if strcmp(choice,'Yes')
                app.RecentProjects = strings(0);

                % sauver la liste vide
                try
                    RecentProjects = app.RecentProjects; %#ok<NASGU>
                    save(app.RecentProjectsFile, 'RecentProjects');
                catch ME
                    warning('Could not save cleared recent list: %s', ME.message);
                end

                app.refreshRecentProjectsMenu();
            end
        end




       function initRecentProjectsSystem(app)
    % D?termine le dossier repo (un cran au-dessus de GUI/)
   % thisAppFile = mfilename('fullpath');  % .../GUI/detecdiv
   % [guiFolder, ~, ~] = fileparts(thisAppFile);
    repoFolder = prefdir; %fileparts(guiFolder);    % remonte d'un cran

    % Fichiers de persistance
    app.RecentProjectsFile     = fullfile(repoFolder, 'recentProjects.mat');
    app.RecentClassifiersFile  = fullfile(repoFolder, 'recentClassifiers.mat');
    app.RecentPipelinesFile    = fullfile(repoFolder, 'recentPipelines.mat');

    % Charger projets
    if exist(app.RecentProjectsFile, 'file')
        S = load(app.RecentProjectsFile, 'RecentProjects');
        if isfield(S,'RecentProjects') && ~isempty(S.RecentProjects)
            app.RecentProjects = string(S.RecentProjects(:));
        end
    end

    % Charger classifieurs
    if exist(app.RecentClassifiersFile, 'file')
        S2 = load(app.RecentClassifiersFile, 'RecentClassifiers');
        if isfield(S2,'RecentClassifiers') && ~isempty(S2.RecentClassifiers)
            app.RecentClassifiers = string(S2.RecentClassifiers(:));
        end
    end

    % Charger pipelines
    if exist(app.RecentPipelinesFile, 'file')
        S3 = load(app.RecentPipelinesFile, 'RecentPipelines');
        if isfield(S3,'RecentPipelines') && ~isempty(S3.RecentPipelines)
            app.RecentPipelines = string(S3.RecentPipelines(:));
        end
    end

    % Nettoyer / rafra?chir menus
    app.cleanRecentProjectsList();
    app.refreshRecentProjectsMenu();

    app.cleanRecentClassifiersList();
    app.refreshRecentClassifiersMenu();

    app.cleanRecentPipelinesList();
    app.refreshRecentPipelinesMenu();
        function [ok,node,pipeObj] = getPipelineNodeByIndex(app, pipeIdx, modIdx)
            ok = false;
            node = struct();
            pipeObj = [];

            if pipeIdx > numel(app.Data.Pipeline)
                return;
            end

            pipeVar = app.Data.Pipeline{pipeIdx};
            try
                pipeObj = evalin('base', pipeVar);
            catch
                return;
            end

            if ~isa(pipeObj,'pipeline') || ~isprop(pipeObj,'nodes') || modIdx > numel(pipeObj.nodes)
                pipeObj = [];
                return;
            end

            node = pipeObj.nodes(modIdx);
            ok = true;
        end

        function [nType, modObj] = buildPipelineModuleObject(app, node) %#ok<INUSD>
            nType = '';
            modObj = [];

            if ~(isstruct(node) && isfield(node,'type') && ~isempty(node.type))
                return;
            end

            nType = lower(char(string(node.type)));

            if strcmp(nType,'processor')
                tmpProc = process(tempdir, 'pipeline_module', randi(1e9));

                pkgName = '';
                if isfield(node,'pkg') && ~isempty(node.pkg)
                    pkgName = char(string(node.pkg));
                end

                if ~isempty(pkgName)
                    tmpProc.processFun = [pkgName '.process'];
                    try
                        p0 = feval([pkgName '.setparam'], struct());
                    catch
                        p0 = struct();
                    end
                    if isstruct(p0)
                        tmpProc.processArg = p0;
                    end
                elseif isfield(node,'func') && ~isempty(node.func)
                    tmpProc.processFun = char(string(node.func));
                end

                if isfield(node,'params') && isstruct(node.params)
                    if isempty(tmpProc.processArg) || ~isstruct(tmpProc.processArg)
                        tmpProc.processArg = node.params;
                    else
                        fn = fieldnames(node.params);
                        for fi = 1:numel(fn)
                            tmpProc.processArg.(fn{fi}) = node.params.(fn{fi});
                        end
                    end
                end

                if isfield(node,'id') && ~isempty(node.id)
                    tmpProc.strid = char(string(node.id));
                end

                modObj = tmpProc;
                return;
            end

            if strcmp(nType,'classifier')
                tmpClassi = classi(tempdir, 'pipeline_module', randi(1e9));

                if isfield(node,'id') && ~isempty(node.id)
                    tmpClassi.strid = char(string(node.id));
                end

                pkgName = '';
                if isfield(node,'pkg') && ~isempty(node.pkg)
                    pkgName = char(string(node.pkg));
                end

                if ~isempty(pkgName)
                    tmpClassi.classifierPkg = pkgName;
                    if isempty(tmpClassi.classifyFun)
                        tmpClassi.classifyFun = [pkgName '.classify'];
                    end
                    if isempty(tmpClassi.trainingFun)
                        tmpClassi.trainingFun = [pkgName '.train'];
                    end

                    if strcmpi(pkgName,'cellposesam')
                        tmpClassi.category = {'Pixel'};
                    elseif strcmpi(pkgName,'cnn_lstm')
                        tmpClassi.category = {'LSTM'};
                    else
                        tmpClassi.category = {'Image'};
                    end
                else
                    tmpClassi.category = {'Image'};
                end

                if isfield(node,'func') && ~isempty(node.func)
                    tmpClassi.classifyFun = char(string(node.func));
                end

                if isfield(node,'params') && isstruct(node.params)
                    if isfield(node.params,'classes') && ~isempty(node.params.classes)
                        cls = node.params.classes;
                        if isstring(cls), cls = cellstr(cls); end
                        if ischar(cls), cls = {cls}; end
                        tmpClassi.classes = cls;
                    end
                end

                tmpClassi.category = classiNormalizeCategory(tmpClassi.category);
                modObj = tmpClassi;
                return;
            end
        end

        function openPipelineModuleByIndex(app, pipeIdx, modIdx)
            [ok,node,pipeObj] = app.getPipelineNodeByIndex(pipeIdx, modIdx);
            if ~ok
                return;
            end

            [nType, modObj] = app.buildPipelineModuleObject(node);
            switch nType
                case 'processor'
                    processDataGUI([], modObj);
                case 'classifier'
                    classifierGUI(modObj);
                otherwise
                    app.openPipelineWithContext(pipeObj);
            end
        end

end


    end



    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.applyMainWindowLayout();
            app.resetMainPanelState();
            checkInstalledToolboxes;
            initUserPreferences;

            initRecentProjectsSystem(app);
            app.WorkspaceEventListenerId = detecdiv_event('subscribe', ...
                'workspaceChanged', @(payload, eventName) app.onExternalWorkspaceChanged(payload, eventName));


            gatherVarsFromWorkspace(app)
            displayNodes(app)
        end

        function onExternalWorkspaceChanged(app, payload, eventName) %#ok<INUSD>
            if isempty(app) || ~isvalid(app) || isempty(app.DetecDivUIFigure) || ~isvalid(app.DetecDivUIFigure)
                return;
            end
            RefreshtreewindowMenuSelected(app, []);
            drawnow limitrate;
        end

        function applyMainWindowLayout(app)
            if ~isvalid(app.DetecDivUIFigure)
                return;
            end

            figPos = app.DetecDivUIFigure.Position;
            app.DetecDivUIFigure.Position = [figPos(1) figPos(2) max(figPos(3), 708) max(figPos(4), 646)];

            if ~isempty(app.MainGrid) && isvalid(app.MainGrid)
                app.MainGrid.Padding = [8 8 8 8];
                app.MainGrid.ColumnSpacing = 12;
                app.MainGrid.RowSpacing = 0;
                app.MainGrid.ColumnWidth = {241, '1x'};
                app.MainGrid.RowHeight = {'1x'};
            end

            app.UIAxes.Position = [0 16 417 341];
            app.ProjectInformationLabel.Position = [8 361 410 240];
            app.AdddataButton.Position = [20 286 175 40];
            app.UpdaterawdatapathButton.Position = [249 284 169 45];
            app.IdentifyROIsinpositionsButton.Position = [20 211 385 46];
            app.ExtractROIhypervolumesButton.Position = [20 153 389 47];
            app.AddclassifierButton.Position = [20 74 175 43];
            app.AddprocessorButton.Position = [232 74 151 43];
            app.ClassifydataButton.Position = [20 12 175 43];
            app.ProcessdataButton.Position = [232 12 149 43];
            app.OpenButton.Position = [283 365 134 37];
        end

        function resetMainPanelState(app)
            app.ProjectsPanel.Title = 'Projects';
            app.ProjectInformationLabel.Text = 'Project Information';
            app.ProjectInformationLabel.Visible = 'on';

            app.AdddataButton.Visible='off';
            app.AddclassifierButton.Visible='off';
            app.UpdaterawdatapathButton.Visible='off';
            app.IdentifyROIsinpositionsButton.Visible='off';
            app.ExtractROIhypervolumesButton.Visible='off';
            app.ClassifydataButton.Visible='off';
            app.AddprocessorButton.Visible='off';
            app.ProcessdataButton.Visible='off';
            app.OpenButton.Visible='off';

            if isvalid(app.UIAxes)
                cla(app.UIAxes);
                app.UIAxes.Visible='off';
            end
        end

        % Selection changed function: Tree
        function TreeSelectionChanged(app, event)
            selectedNodes = app.Tree.SelectedNodes;

            app.AdddataButton.Visible='off';
            app.AddclassifierButton.Visible='off';

            app.UpdaterawdatapathButton.Visible='off';
            app.IdentifyROIsinpositionsButton.Visible='off';
            app.ExtractROIhypervolumesButton.Visible='off';

            app.ClassifydataButton.Visible='off';
            %    app.ClassifyprocessdataLabel.Visible='off';
            %      app.CreateorimportaclassifierprocessorLabel.Visible='off';
            %      app.IdentfyandextractregionsofinterestROIsindataLabel.Visible='off';
            %     app.AdddataintheprojectiepositionLabel.Visible='off';
            %  app.ProjectInformationLabel.Visible='off';
            app.AddprocessorButton.Visible='off';
            app.ProcessdataButton.Visible='off';
            app.OpenButton.Visible='off';
            app.OpenButton.Enable='on';
            cla( app.UIAxes);
            app.UIAxes.Visible='off';

            % HERE

            if numel(selectedNodes)==0
                return
            end

            if numel(selectedNodes.Tag)==0 & strcmp(selectedNodes.Text,'Projects')
                app.ProjectsPanel.Title='';
                app.ProjectInformationLabel.Text='';
            end
            if numel(selectedNodes.Tag)==0 & strcmp(selectedNodes.Text,'Independent Classifiers')
                app.ProjectsPanel.Title='';
                app.ProjectInformationLabel.Text='';
            end
            if strcmp(selectedNodes.Tag,'PipelinesRoot') || (numel(selectedNodes.Tag)==0 & strcmp(selectedNodes.Text,'Pipeline'))
                app.ProjectsPanel.Title='';
                app.ProjectInformationLabel.Text='';
            end

            if strcmp(selectedNodes.Tag,'Project')

                gatherVarsFromWorkspace(app);
                % displayNodes(app)

                app.ProjectsPanel.Title='Project';
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{i};
                shallowObj=evalin('base',proj);

                t='';
                t=[t 'Project path: ' newline newline];
                t=[t shallowObj.io.path shallowObj.io.file '.mat' newline newline];

                if numel(shallowObj.fov)==1 & numel(shallowObj.fov(1).srcpath{1})==0
                    n=0;
                else
                    n= numel(shallowObj.fov);
                end

                t=[t 'Number of positions: ' num2str(n) newline newline];

                t=[t 'Number of classifiers in project: ' num2str(numel(shallowObj.processing.classification)) newline newline];

                defaultPipePath = app.getProjectDefaultPipelinePath(shallowObj);
                if ~isempty(defaultPipePath)
                    defaultPipeId = '';
                    try
                        if isfield(shallowObj.runProfiles,'pipeline') && isfield(shallowObj.runProfiles.pipeline,'defaultTemplateId')
                            defaultPipeId = char(string(shallowObj.runProfiles.pipeline.defaultTemplateId));
                        end
                    catch
                    end

                    t=[t 'Default pipeline: '];
                    if ~isempty(defaultPipeId)
                        t=[t defaultPipeId newline];
                    else
                        [~, pipeFolder] = fileparts(fileparts(defaultPipePath));
                        t=[t pipeFolder newline];
                    end
                    t=[t defaultPipePath newline newline];
                end

                if isfield(shallowObj.processing,'pipelineRun')
                    t=[t 'Number of pipeline runs in project: ' num2str(numel(shallowObj.processing.pipelineRun)) newline newline];
                end
                app.ProjectInformationLabel.Text=t;

                app.AdddataButton.Visible='on';
                app.AdddataButton.Text='Open workflow...';
                app.AdddataButton.Tooltip={'Open the workflow frontend for data loading, ROI definition and ROI extraction'};
                app.AddclassifierButton.Visible='on';
                %                app.CheckrawdatapathButton.Visible='on';
                app.UpdaterawdatapathButton.Visible='on';
                app.IdentifyROIsinpositionsButton.Visible='off';
                app.ExtractROIhypervolumesButton.Visible='off';

                app.ClassifydataButton.Visible='on';
                %   app.ClassifyprocessdataLabel.Visible='on';
                %     app.CreateorimportaclassifierprocessorLabel.Visible='on';
                %     app.IdentfyandextractregionsofinterestROIsindataLabel.Visible='on';
                %     app.AdddataintheprojectiepositionLabel.Visible='on';
                % app.ProjectInformationLabel.Visible='on';
                app.AddprocessorButton.Visible='on';
                app.ProcessdataButton.Text='Process data...';
                app.ProcessdataButton.Visible='on';

            else

            end

            if strcmp(selectedNodes.Tag,'Projectpos')

                app.ProjectsPanel.Title='Position';
                app.OpenButton.Visible='on';
                app.OpenButton.Text='Open Position...';

                cc=app.Tree.SelectedNodes.UserData;

                proj=app.Data.Project{cc(1)};
                pos=cc(2);
                shallowObj=evalin('base',proj);
                position=shallowObj.fov(pos);

                % display sub,odes

                if numel(app.Tree.SelectedNodes.Children)==0
                    if numel(app.Data.Projectposrois{cc(1)})

                        for n=1:numel(app.Data.Projectposrois{cc(1)}{cc(2)})

                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            %   cm=uicontextmenu(app.DetecDivUIFigure);
                            %  m = uimenu(cm,'Text','Open ROI...');
                            %  m.MenuSelectedFcn={@contextMenuROIFcn,[i,k,n],'Projectposrois'};
                            [pth fle ext]= fileparts(which('detecdiv.mlapp'));
                            uitreenode(app.Tree.SelectedNodes,'Text',app.Data.Projectposrois{cc(1)}{cc(2)}{n},'Tag','Projectposrois','UserData',[cc(1),cc(2),n],'Icon',fullfile(pth,'roi.png'));
                            % disabled because too heavy with large projects
                        end
                    end
                end


                % display text

                t='';
                t=[t 'Source files path: ' newline newline];

                for i=1%:numel(position.srcpath)
                    t=[t position.srcpath{i} newline newline];
                end

                t=[t 'Source sample filename: ' newline newline];
                t=[t position.srclist{1}(1).name newline newline];

                t=[t num2str(numel(position.channel)) ' channels: '];

                for i=1:numel(position.channel)
                    t=[t position.channel{i} ' '];
                end

                t=[t newline newline];
                if numel(position.frames)
                    fr=position.frames;
                else
                    fr=numel(position.srclist{1});
                end
                t=[t num2str(fr) ' frames' newline newline];

                n=numel(position.roi);
                if n==1 & numel(position.roi(1).id)==0
                    n=0;
                end
                t=[t num2str(n) ' ROIs as available datasets' newline];

                if n==0
                    t=[t 'You must first define one or several ROIs by opening the raw data viewer!' newline newline];
                end
                app.ProjectInformationLabel.Text=t;

            end


            if strcmp(selectedNodes.Tag,'Projectclassi')
                app.ProjectsPanel.Title='Classifier';

                app.OpenButton.Visible='on';
                app.OpenButton.Text='Open Classifier...';

                app.UIAxes.Visible='on';

                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{cc(1)};
                pos=cc(2);
                shallowObj=evalin('base',proj);
                clas=shallowObj.processing.classification(pos);

                if numel(app.Tree.SelectedNodes.Children)==0
                    if numel(app.Data.Projectclassirois{cc(1)})
                        [pth fle ext]= fileparts(which('detecdiv.mlapp'));
                        for n=1:numel(app.Data.Projectclassirois{cc(1)}{cc(2)})
                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            cm=uicontextmenu(app.DetecDivUIFigure);
                            m = uimenu(cm,'Text','Open ROI...');
                            m.MenuSelectedFcn={@contextMenuROIFcn,[cc(1),cc(2),n],'Projectclassirois'};
                            %  ''ContextMenu',cm'
                            uitreenode(app.Tree.SelectedNodes,'Text',app.Data.Projectclassirois{cc(1)}{cc(2)}{n},'Tag','Projectclassirois','UserData',[cc(1),cc(2),n],'Icon',fullfile(pth,'roi.png'));
                            % disabled because too heavy with large projects
                        end
                    end
                end


                t='';
                t=[t 'Classification path: ' newline];
                t=[t clas.path newline newline];

                if numel(clas.description)
                    t=[t 'Description: '];

                    t=[t clas.description{1}];
                end

                if numel(clas.category)
                    [catCell, ~] = classiNormalizeCategory(clas.category);
                    t=[t catCell{1} char(13)];
                end

                if numel(clas.classes)
                    t=[t 'Classes: '];

                    for i=1:numel(clas.classes)
                        t=[t clas.classes{i}];
                    end
                end

                t=[t  char(13)];

                n=numel(clas.roi);
                if n==1 & numel(clas.roi(1).id)==0
                    n=0;
                end
                t=[t num2str(n) ' ROIs as training/test sets'  newline];

                if n==0
                    t=[t 'You must first import ROIs ! For this, first open the classifier.' newline newline];
                end

                app.ProjectInformationLabel.Text=t;
                displayClassiImage(app,clas);
            end

            if strcmp(selectedNodes.Tag,'Projectprocess')
                app.ProjectsPanel.Title='Processor';
                app.OpenButton.Visible='on';
                app.OpenButton.Text='Open Processor...';

                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{cc(1)};
                pos=cc(2);
                shallowObj=evalin('base',proj);
                clas=shallowObj.processing.processor(pos);

                %                 if numel(app.Tree.SelectedNodes.Children)==0
                %                  if numel(app.Data.Projectclassirois{cc(1)})
                %                  [pth fle ext]= fileparts(which('detecdiv.mlapp'));
                %                     for n=1:numel(app.Data.Projectclassirois{cc(1)}{cc(2)})
                %                       % aa=app.Data.Projectclassirois{i}{k}{n}
                %                       cm=uicontextmenu(app.DetecDivUIFigure);
                %                     m = uimenu(cm,'Text','Open ROI...');
                %                     m.MenuSelectedFcn={@contextMenuROIFcn,[cc(1),cc(2),n],'Projectclassirois'};
                %                   %  ''ContextMenu',cm'
                %                         uitreenode(app.Tree.SelectedNodes,'Text',app.Data.Projectclassirois{cc(1)}{cc(2)}{n},'Tag','Projectclassirois','UserData',[cc(1),cc(2),n],'Icon',fullfile(pth,'roi.png'));
                %                                     % disabled because too heavy with large projects
                %                     end
                %                  end
                %                 end


                t='';
                t=[t 'Processor path: ' newline];
                t=[t clas.path newline newline];

                if isprop(clas, 'description') && ~isempty(clas.description)
                    t=[t 'Description: '];
                    if iscell(clas.description)
                        t=[t char(string(clas.description{1})) newline];
                    else
                        t=[t char(string(clas.description)) newline];
                    end
                end

                if isprop(clas, 'category') && ~isempty(clas.category)
                    if iscell(clas.category)
                        categoryText = clas.category{1};
                    else
                        categoryText = clas.category;
                    end
                    t=[t 'Category: ' char(string(categoryText)) newline];
                end

                if isprop(clas, 'processFun') && ~isempty(clas.processFun)
                    t=[t 'Function: ' char(string(clas.processFun)) newline];
                end


                t=[t  char(13)];



                app.ProjectInformationLabel.Text=t;
            end



            if strcmp(selectedNodes.Tag,'Classifier')
                app.ProjectsPanel.Title='Classifier';
                app.OpenButton.Visible='on';
                app.OpenButton.Text='Open Classifier...';

                app.UIAxes.Visible='on';

                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Classifier{cc};

                clas=evalin('base',proj);


                if numel(app.Tree.SelectedNodes.Children)==0
                    if numel(app.Data.Classifierrois{cc})

                        for n=1:numel(app.Data.Classifierrois{cc})
                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            cm=uicontextmenu(app.DetecDivUIFigure);
                            m = uimenu(cm,'Text','Open ROI...');
                            m.MenuSelectedFcn={@contextMenuROIFcn,[cc,n],'Projectposrois'};
                            %  'ContextMenu',cm
                            [pth fle ext]= fileparts(which('detecdiv.mlapp'));

                            uitreenode(app.Tree.SelectedNodes,'Text',app.Data.Classifierrois{cc}{n},'Tag','Classifierrois','UserData',[cc,n],'Icon',fullfile(pth,'roi.png'));
                            % disabled because too heavy with large projects
                        end
                    end
                end

                t='';
                t=[t 'Classification path: ' newline newline];
                t=[t clas.path newline newline];

                if numel(clas.description)
                    t=[t 'Description: '];

                    t=[t clas.description{1} ' - '];
                end

                if numel(clas.category)
                    [catCell, ~] = classiNormalizeCategory(clas.category);
                    t=[t catCell{1} newline newline];
                end

                if numel(clas.classes)

                    t=[t 'Classes: ' newline newline];

                    for i=1:numel(clas.classes)
                        t=[t clas.classes{i} newline];
                    end
                end
                t=[t newline];
                n=numel(clas.roi);
                if n==1 & numel(clas.roi(1).id)==0
                    n=0;
                end
                t=[t num2str(n) ' ROIs as training/test sets' newline newline];

                if n==0
                    t=[t 'You must first import ROIs ! For this, first open the classifier.' newline newline];
                end

                app.ProjectInformationLabel.Text=t;

                if numel(clas.category)
                    [catCell, ~] = classiNormalizeCategory(clas.category);
                    if ~strcmp(char(string(catCell{1})),'Timeseries')
                        displayClassiImage(app,clas);
                    end
                end
            end

            if strcmp(selectedNodes.Tag,'Pipeline')
                app.ProjectsPanel.Title='Pipeline';
                app.OpenButton.Visible='on';
                [isLoaded, pipeObj, pipeVar] = app.getLoadedPipelineForNode(selectedNodes);
                pipelineJsonPath = app.resolvePipelineJsonPathForNode(selectedNodes);
                app.OpenButton.Text='Open Pipeline...';
                app.ProcessdataButton.Visible='on';
                app.ProcessdataButton.Text='Create run...';

                nNodes = 0;
                nEdges = 0;
                pipePathText = pipelineJsonPath;
                if isLoaded && isa(pipeObj,'pipeline')
                    if isprop(pipeObj,'nodes') && ~isempty(pipeObj.nodes)
                        nNodes = numel(pipeObj.nodes);
                    end
                    if isprop(pipeObj,'edges') && ~isempty(pipeObj.edges)
                        nEdges = numel(pipeObj.edges);
                    end
                    if isprop(pipeObj,'path') && ~isempty(pipeObj.path)
                        pipePathText = char(string(pipeObj.path));
                    end
                end

                t='';
                if isLoaded
                    t=[t 'Pipeline variable: ' pipeVar newline newline];
                else
                    t=[t 'Pipeline variable: (not loaded in workspace)' newline newline];
                end
                if ~isempty(pipePathText)
                    t=[t 'Pipeline path: ' newline pipePathText newline newline];
                end
                t=[t 'Nodes: ' num2str(nNodes) newline];
                t=[t 'Connections: ' num2str(nEdges) newline];
                app.ProjectInformationLabel.Text=t;
                if ~isLoaded && isempty(pipelineJsonPath)
                    app.OpenButton.Enable = 'off';
                else
                    app.OpenButton.Enable = 'on';
                end
            end

            if strcmp(selectedNodes.Tag,'PipelineModule')
                app.OpenButton.Visible='on';

                cc=app.Tree.SelectedNodes.UserData;
                pipeIdx = cc(1);
                modIdx = cc(2);

                [ok,node,pipeObj] = app.getPipelineNodeByIndex(pipeIdx, modIdx);
                if ~ok
                    return;
                end
                pipeVar = app.Data.Pipeline{pipeIdx};

                [nodeType, modObj] = app.buildPipelineModuleObject(node);

                if strcmp(nodeType,'classifier')
                    app.ProjectsPanel.Title='Classifier';
                    app.OpenButton.Text='Open Classifier...';
                    app.UIAxes.Visible='on';

                    clas = modObj;
                    t='';
                    t=[t 'Classification path: ' newline newline];
                    if isprop(clas,'path') && ~isempty(clas.path)
                        t=[t clas.path newline newline];
                    else
                        t=[t '(not saved yet)' newline newline];
                    end

                    if isprop(clas,'description') && numel(clas.description)
                        desc = clas.description;
                        if iscell(desc)
                            descTxt = char(string(desc{1}));
                        else
                            descTxt = char(string(desc));
                        end
                        t=[t 'Description: ' descTxt ' - '];
                    end

                    if isprop(clas,'category') && numel(clas.category)
                        [catCell, ~] = classiNormalizeCategory(clas.category);
                        t=[t catCell{1} newline newline];
                    end

                    if isprop(clas,'classes') && numel(clas.classes)
                        t=[t 'Classes: ' newline newline];
                        cls = clas.classes;
                        if isstring(cls), cls = cellstr(cls); end
                        if ischar(cls), cls = {cls}; end
                        for i=1:numel(cls)
                            t=[t char(string(cls{i})) newline];
                        end
                    end

                    t=[t newline];
                    if isprop(clas,'roi')
                        n=numel(clas.roi);
                        if n==1 && numel(clas.roi(1).id)==0
                            n=0;
                        end
                    else
                        n=0;
                    end
                    t=[t num2str(n) ' ROIs as training/test sets' newline newline];
                    app.ProjectInformationLabel.Text=t;

                    try
                        [catCell, ~] = classiNormalizeCategory(clas.category);
                        hasRoi = false;
                        if isprop(clas,'roi') && ~isempty(clas.roi)
                            hasRoi = ~(numel(clas.roi)==1 && isempty(clas.roi(1).id));
                        end
                        if hasRoi && ~strcmp(char(string(catCell{1})),'Timeseries')
                            displayClassiImage(app,clas);
                        else
                            cla(app.UIAxes);
                        end
                    catch
                        cla(app.UIAxes);
                    end

                elseif strcmp(nodeType,'processor')
                    app.ProjectsPanel.Title='Processor';
                    app.OpenButton.Text='Open Processor...';
                    app.UIAxes.Visible='off';

                    proc = modObj;
                    t='';
                    t=[t 'Processor path: ' newline newline];
                    if isprop(proc,'path') && ~isempty(proc.path)
                        t=[t proc.path newline newline];
                    else
                        t=[t '(not saved yet)' newline newline];
                    end

                    if isfield(node,'pkg') && ~isempty(node.pkg)
                        t=[t 'Package: ' char(string(node.pkg)) newline];
                    end
                    if isprop(proc,'processFun') && ~isempty(proc.processFun)
                        t=[t 'Function: ' char(string(proc.processFun)) newline];
                    end

                    if isprop(proc,'processArg') && isstruct(proc.processArg)
                        fn = fieldnames(proc.processArg);
                        if ~isempty(fn)
                            t=[t newline 'Parameters: ' num2str(numel(fn)) newline];
                            nShow = min(numel(fn), 8);
                            for ii=1:nShow
                                t=[t '- ' fn{ii} newline];
                            end
                            if numel(fn) > nShow
                                t=[t '...'];
                            end
                        end
                    end

                    app.ProjectInformationLabel.Text=t;

                else
                    app.ProjectsPanel.Title='Pipeline module';
                    app.OpenButton.Text='Open Pipeline...';
                    app.UIAxes.Visible='off';

                    t='';
                    t=[t 'Pipeline: ' pipeVar newline newline];
                    if isfield(node,'id'), t=[t 'Module id: ' char(string(node.id)) newline]; end
                    if isfield(node,'name'), t=[t 'Name: ' char(string(node.name)) newline]; end
                    if isfield(node,'type'), t=[t 'Type: ' char(string(node.type)) newline]; end
                    if isfield(node,'pkg') && ~isempty(node.pkg), t=[t 'Package: ' char(string(node.pkg)) newline]; end
                    if isfield(node,'func') && ~isempty(node.func), t=[t 'Function: ' char(string(node.func)) newline]; end
                    app.ProjectInformationLabel.Text=t;
                end
            end

            if strcmp(selectedNodes.Tag,'ProjectpipelineRun')
                app.ProjectsPanel.Title='Pipeline run';
                app.OpenButton.Visible='on';
                app.OpenButton.Text='Run Pipeline Run...';

                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{cc(1)};
                shallowObj=evalin('base',proj);
                if isfield(shallowObj.processing,'pipelineRun') && cc(2) <= numel(shallowObj.processing.pipelineRun)
                    runObj = shallowObj.processing.pipelineRun(cc(2));
                    t='';
                    t=[t 'Run id: ' runObj.runId newline newline];
                    [runMode, runStatus] = app.summarizePipelineRun(runObj);
                    t=[t 'Execution: ' runMode newline];
                    t=[t 'Status: ' runStatus newline newline];
                    if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef)
                        if isfield(runObj.pipelineRef,'id')
                            t=[t 'Pipeline id: ' char(string(runObj.pipelineRef.id)) newline];
                        end
                        if isfield(runObj.pipelineRef,'path')
                            t=[t 'Pipeline path: ' char(string(runObj.pipelineRef.path)) newline];
                        end
                    end
                    if isprop(runObj,'targetRef') && isstruct(runObj.targetRef)
                        if isfield(runObj.targetRef,'type')
                            t=[t newline 'Target type: ' char(string(runObj.targetRef.type)) newline];
                        end
                    end
                    app.ProjectInformationLabel.Text=t;
                end
            end

            if strcmp(selectedNodes.Tag,'Projectposrois') || strcmp(selectedNodes.Tag,'Projectclassirois') || strcmp(selectedNodes.Tag,'Classifierrois')

                arg=app.Tree.SelectedNodes.UserData;

                if strcmp(selectedNodes.Tag,'Projectclassirois')
                    cc=arg(1);
                    pos=arg(2);
                    ro=arg(3);


                    proj=app.Data.Project{cc};
                    shallowObj=evalin('base',proj);
                    roiObj=shallowObj.processing.classification(pos).roi(ro);
                    roiObj.parent=shallowObj.processing.classification(pos);
                end

                if strcmp(selectedNodes.Tag,'Projectposrois')
                    cc=arg(1);
                    pos=arg(2);
                    ro=arg(3);
                    proj=app.Data.Project{cc};
                    shallowObj=evalin('base',proj);
                    roiObj=shallowObj.fov(pos).roi(ro);
                    roiObj.parent=shallowObj.fov(pos);
                end

                if strcmp(selectedNodes.Tag,'Classifierrois')
                    cc=arg(1);
                    ro=arg(2);
                    clas=app.Data.Classifier{cc};
                    clas=evalin('base',clas);

                    roiObj=clas.roi(ro);

                    roiObj.parent=clas;
                end



                d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...',...
                    'Message','Loading selected ROI...');
                d.Value=0.33;

                %roiObj.view;

                if numel(roiObj.image)==0

                    roiObj.load;
                end

                if numel(roiObj.image)==0
                    disp('Cannot open ROI obj; Quitting...')
                    return;
                end

                switch selectedNodes.Tag
                    case 'Projectclassirois'
                        roiObj.parent=shallowObj.processing.classification(pos);
                    case 'Projectposrois'
                        roiObj.parent=shallowObj.fov(pos);
                    case 'Classifierrois'
                        roiObj.parent=clas;
                end

                figures=findall(0,'Type','figure');
                appFigure=findobj(figures,'Name','ScoreApp');
                if isprop(appFigure,'RunningAppInstance')
                    appFigure.RunningAppInstance.addROI(roiObj);
                else
                    score(roiObj);
                end

                d.Value=0.67;

                if numel(roiObj.image)==0
                    d.Message='Cannot access ROI file, or ROI data have not yet been extracted... Quitting!';
                    pause(2);
                else
                    d.Message='Loading ROI successful!';
                end
                pause(0.2);
                close(d)
            end


        end

        % Callback function
        function ContextMenuOpening(app, event)

        end

        % Callback function
        function OpenMenuSelected(app, event)

        end

        % Menu selected function: NewprojectMenu
        function NewprojectMenuSelected(app, event)
            proj=shallowNew;
            if numel(proj)==0
                return;
            end
            name=proj.io.file;
            assignin('base',name,proj);
            gatherVarsFromWorkspace(app);
            displayNodes(app)
        end

        % Callback function
        function DetecDivUIFigureWindowButtonDown(app, event)

        end

        % Callback function
        function DetecDivUIFigureButtonDown(app, event)

        end

        % Menu selected function: OpenprojectMenu
        function OpenprojectMenuSelected(app, event)

            d = uiprogressdlg(app.DetecDivUIFigure, ...
                'Title','Please Wait...', ...
                'Message','Loading selected project...');

            d.Value = 0.33;

            [proj, msg] = shallowLoad;
            if isempty(proj)
                close(d);
                if ~isempty(msg)
                    uialert(app.DetecDivUIFigure, msg, 'Warning', 'Icon', 'warning');
                end
                return;
            end
            [proj, hubAccess] = detecdiv_hub_prepare_project_open(proj);

            d.Value = 0.66;
            pause(0.2);  % (garde si tu veux forcer l'update graphique)

            % mettre l'objet dans le workspace base sous son nom
            name = proj.io.file;
            assignin('base', name, proj);

    % Auto-load pipeline templates referenced by existing project runs
    app.autoLoadPipelinesForProjectRuns(proj);

            % chemin absolu du .mat du projet

            projectPathChar = fullfile(proj.io.path, [proj.io.file '.mat']);
            app.registerRecentProject(string(projectPathChar));

            % mettre à jour l'état interne de l'app
            gatherVarsFromWorkspace(app);
            displayNodes(app);
            if exist('hubAccess', 'var') && hubAccess.hubManaged && hubAccess.readOnly
                uialert(app.DetecDivUIFigure, hubAccess.reason, 'Hub project opened read-only', 'Icon', 'warning');
            end

            % éventuellement, vérifier les chemins images (tu l'as commenté)
            % check = checkImagePath(app,proj);
            % if any(check)==0
            %     warnmsg = ['Those positions have an incorrect base path.' newline ...
            %                'You must update the path if you plan to build new region of interest / process the raw data !'];
            %     uialert(app.DetecDivUIFigure, warnmsg, 'Warning', 'Icon','warning');
            % end

            close(d);



        end

        % Menu selected function: Catalog Browser
        function CatalogBrowserMenuSelected(app, event) %#ok<INUSD>
            try
                if exist('launch_catalog_browser', 'file') == 2
                    launch_catalog_browser;
                else
                    detecdivCatalogBrowser;
                end
            catch ME
                uialert(app.DetecDivUIFigure, ME.message, 'Catalog Browser', 'Icon', 'error');
            end
        end

        % Menu selected function: NewpipelinetemplateMenu
        function NewpipelinetemplateMenuSelected(app, event) %#ok<INUSD>
            parentDir = uigetdir(pwd, 'Select parent folder where pipeline folder will be created');
            if isequal(parentDir,0)
                return;
            end

            answer = inputdlg({'Pipeline template name:'}, 'New pipeline template', [1 60], {'pipeline'});
            if isempty(answer)
                return;
            end
            pipeName = strtrim(answer{1});
            if isempty(pipeName)
                pipeName = ['pipeline_' char(datetime('now','Format','yyyyMMdd_HHmmss'))];
            end

            try
                pipeObj = pipelineNew('path', parentDir, 'name', pipeName, 'workspace', true);
            catch ME
                uialert(app.DetecDivUIFigure, ME.message, 'Error', 'Icon', 'error');
                return;
            end

            if isempty(pipeObj)
                return;
            end

            app.registerRecentPipeline(string(fullfile(pipeObj.path, 'pipeline.json')));

            gatherVarsFromWorkspace(app);
            displayNodes(app);
        end

        % Menu selected function: OpenpipelinetemplateMenu
        function OpenpipelinetemplateMenuSelected(app, event) %#ok<INUSD>
            [pipeObj, msg] = pipelineLoad;
            if isempty(pipeObj)
                if ~isempty(msg)
                    uialert(app.DetecDivUIFigure, msg, 'Warning', 'Icon', 'warning');
                end
                return;
            end

            varBase = matlab.lang.makeValidName(pipeObj.strid);
            varName = varBase;
            used = evalin('base','who');
            n = 1;
            while any(strcmp(used, varName))
                n = n + 1;
                varName = [varBase '_' num2str(n)];
            end

            assignin('base', varName, pipeObj);
            app.registerRecentPipeline(string(fullfile(pipeObj.path, 'pipeline.json')));

            gatherVarsFromWorkspace(app);
            displayNodes(app);
        end

        % Menu selected function: ClosepipelinetemplateMenu
        function ClosepipelinetemplateMenuSelected(app, event) %#ok<INUSD>
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a pipeline in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Pipeline')
                uialert(app.DetecDivUIFigure,'The selected node is not a pipeline template!','Error');
                return;
            end

            idx = app.Tree.SelectedNodes.UserData;
            if idx > numel(app.Data.Pipeline)
                return;
            end

            varName = app.Data.Pipeline{idx};
            evalin('base', ['clear ' varName]);

            gatherVarsFromWorkspace(app);
            displayNodes(app);
        end

        % Menu selected function: Closeproject
        function CloseprojectMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if strcmp(app.Tree.SelectedNodes.Tag,'Project')
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{i};

                shallowObj = [];
                try
                    shallowObj = evalin('base', proj);
                catch
                end
                try
                    if ~isempty(shallowObj)
                        detecdiv_hub_release_project_open(shallowObj);
                    end
                catch
                end

                clearVars = {proj};
                if isfield(app.Data,'Pipeline') && ~isempty(app.Data.Pipeline)
                    clearVars = [clearVars localFindLinkedPipelineVars(app, shallowObj, proj)]; %#ok<AGROW>
                end
                clearVars = unique(clearVars, 'stable');
                evalin('base',['clear ' strjoin(clearVars,' ')]);
                gatherVarsFromWorkspace(app);
                displayNodes(app)
            end
        end

        function vars = localFindLinkedPipelineVars(app, shallowObj, projVar)
            vars = {};
            if ~isfield(app.Data,'Pipeline') || isempty(app.Data.Pipeline)
                return;
            end

            projectRoot = "";
            if ~isempty(shallowObj)
                try
                    projectRoot = localNormalizeFsPath(fullfile(shallowObj.io.path, shallowObj.io.file));
                catch
                end
            end

            prefix = [char(string(projVar)) '_pipeline'];
            for idx = 1:numel(app.Data.Pipeline)
                pipeVar = app.Data.Pipeline{idx};
                if isempty(pipeVar)
                    continue;
                end

                pipeVarChar = char(string(pipeVar));
                if strcmp(pipeVarChar, prefix) || startsWith(pipeVarChar, [prefix '_'], 'IgnoreCase', true)
                    vars{end+1} = pipeVarChar; %#ok<AGROW>
                    continue;
                end

                try
                    pipeObj = evalin('base', pipeVarChar);
                catch
                    continue;
                end

                try
                    pipePath = localNormalizeFsPath(pipeObj.path);
                catch
                    pipePath = "";
                end

                if strlength(projectRoot) > 0 && strlength(pipePath) > 0 && ...
                        startsWith(pipePath, projectRoot, 'IgnoreCase', true)
                    vars{end+1} = pipeVarChar; %#ok<AGROW>
                end
            end
        end

        function out = localNormalizeFsPath(p)
            out = string(p);
            if strlength(out) == 0
                return;
            end
            out = replace(out, '/', filesep);
            out = replace(out, '\', filesep);
            while endsWith(out, filesep) && strlength(out) > 3
                out = extractBefore(out, strlength(out));
            end
        end

        % Menu selected function: SaveselectedprojectMenu
        function SaveselectedprojectMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if strcmp(app.Tree.SelectedNodes.Tag,'Project')
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{i};

                shallowObj=evalin('base',proj);

                if numel(shallowObj)==0
                    uialert(app.DetecDivUIFigure,'This project does not exist in the worksapce','Error','Icon','warning');
                end
                try
                    detecdiv_hub_assert_project_writable(shallowObj);
                catch ME
                    uialert(app.DetecDivUIFigure, ME.message, 'Project is read-only', 'Icon', 'warning');
                    return;
                end

                d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...',...
                    'Message','Saving selected project...');
                d.Value=0.1;
                pause(0.5)
                shallowSave(shallowObj,[],d);
                close(d);
            else
                uialert(app.DetecDivUIFigure,'No project was selected in the window!','Error','Icon','warning');
            end

        end

        % Button pushed function: AddclassifierButton
        function AddclassifierButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if strcmp(app.Tree.SelectedNodes.Tag,'Project')
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{i};

                shallowObj=evalin('base',proj);

                classifierImporterGUI(app,shallowObj)
                uiwait(app.DetecDivUIFigure)
                TreeSelectionChanged(app, event)
                gatherVarsFromWorkspace(app);
                displayNodes(app);
            end
        end

        % Button pushed function: AdddataButton
        function AdddataButtonPushed(app, event)

            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end
            i=app.Tree.SelectedNodes.UserData;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            app.ensureDefaultPipelineForProject(shallowObj);
            workflow(shallowObj);

            TreeSelectionChanged(app, event)
            gatherVarsFromWorkspace(app);
            displayNodes(app);

        end

        % Button pushed function: UpdaterawdatapathButton
        function UpdaterawdatapathButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);
            shallowObj.setSrcPath;
            check = checkImagePath(app,shallowObj);

            %  pix=find(check==0);

            %  warndlg(['These positions have an incorrect path : ' num2str(pix)]);



        end

        % Callback function
        function CheckrawdatapathButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);
            check = checkImagePath(app,shallowObj);
        end

        % Menu selected function: NewprojectindependentclassiiferMenu
        function NewprojectindependentclassiiferMenuSelected(app, event)
            %classifierGUI([],app)
            classifierImporterGUI(app,[])
            uiwait(app.DetecDivUIFigure)
            TreeSelectionChanged(app, event)
            gatherVarsFromWorkspace(app);
            displayNodes(app);
        end

        % Menu selected function: OpenprojectindependentclassifierMenu
        function OpenprojectindependentclassifierMenuSelected(app, event)
% Menu selected function: OpenprojectindependentclassifierMenu
    d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...',...
        'Message','Loading selected classifier...');
    d.Value = 0.33;

    [classiObj, msg] = classiLoad;

    if isempty(classiObj)
        close(d);
        if ~isempty(msg)
            uialert(app.DetecDivUIFigure,msg,'Warning','Icon','warning');
        end
        return;
    end

    d.Value = 0.66;
    pause(0.2);

    % Publier dans le workspace
    name = [classiObj.strid '_indep'];
    assignin('base', name, classiObj);

    % Construire le chemin absolu du fichier .mat de ce classi,
    % pour l'ajouter à la liste des récents.
    % classiLoad a déjà fait:
    %   path = abspath;
    %   file = ...'_classification';
    %   classiObj.setPath([path '\'], file);
    %
    % Du coup:
    classiMatPath = fullfile(classiObj.path, [classiObj.strid '_classification.mat']);
    % Attention : classiObj.path finit avec '\' (ou '/'), et strid n'inclut pas "_classification" ?
    % On doit être 100% sûr. Sinon, plus robuste:
    %   classiObj.path -> "...\classification\yolo_1\"
    %   classiObj.strid -> "yolo_1"
    %   le fichier réel -> "yolo_1_classification.mat"
    %
    % Donc mieux :
    classiMatFilename = [classiObj.strid '_classification.mat'];
    classiMatFull = fullfile(classiObj.path, classiMatFilename);

    app.registerRecentClassifier(classiMatFull);

    gatherVarsFromWorkspace(app);
    displayNodes(app);

    close(d);

        end

        % Menu selected function: CloseprojectindependentclassifierMenu
        function CloseprojectindependentclassifierMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if strcmp(app.Tree.SelectedNodes.Tag,'Classifier')
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Classifier{i};

                evalin('base',['clear ' proj]);
                gatherVarsFromWorkspace(app);
                displayNodes(app)
            end
        end

        % Menu selected function: SaveprojectindependentclassifierMenu
        function SaveprojectindependentclassifierMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if strcmp(app.Tree.SelectedNodes.Tag,'Classifier')
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Classifier{i};

                classiObj=evalin('base',proj);

                if numel(classiObj)==0
                    uialert(app.DetecDivUIFigure,'This project does not exist in the worksapce','Error','Icon','warning');
                    return;
                end

                d = uiprogressdlg(app.DetecDivUIFigure,'Title','Please Wait...',...
                    'Message','Saving selected project...');
                d.Value=0.1;
                pause(0.5)
                classiSave(classiObj);
                d.Value=0.9;
                close(d);
            end

        end

        % Button pushed function: IdentifyROIsinpositionsButton
        function IdentifyROIsinpositionsButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end
            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i = app.Tree.SelectedNodes.UserData;
            proj = app.Data.Project{i};
            shallowObj = evalin('base', proj);

            if numel(shallowObj.fov)==1 && numel(shallowObj.fov(1).srcpath)==0
                uialert(app.DetecDivUIFigure,'First add data before defining or generating ROIs.','Error');
                return;
            end

            options = { ...
                'Pattern calibration + detection', ...
                'Manual ROI drawing', ...
                'Full-frame / grid ROIs', ...
                'Tracked ROIs from masks'};
            [sel, ok] = listdlg('ListString', options, ...
                'SelectionMode', 'single', ...
                'PromptString', 'Choose how to define ROIs for this project:', ...
                'ListSize', [260 130], ...
                'Name', 'ROI workflow');
            if ~ok || isempty(sel)
                return;
            end

            switch sel
                case 1
                    params = app.getProjectDefaultPipelineNodeParams(shallowObj, 'roiPattern');
                    ctx = struct('shallow', shallowObj);
                    if ~isempty(fieldnames(params))
                        ctx.roiPattern = params;
                        ctx.params = params;
                    end
                    ctx = roiPattern.ui(ctx);
                    if isfield(ctx,'cancelled') && ctx.cancelled
                        return;
                    end
                    if ~isfield(ctx,'roiPattern') || ~isstruct(ctx.roiPattern)
                        return;
                    end

                    app.applyProjectRoiProducerChoice(shallowObj, 'roiPattern', ctx.roiPattern);
                    RefreshtreewindowMenuSelected(app, event);

                case 2
                    params = app.getProjectDefaultPipelineNodeParams(shallowObj, 'roiManual');
                    ctx = struct('shallow', shallowObj);
                    if ~isempty(fieldnames(params))
                        ctx.roiManual = params;
                        ctx.params = params;
                    end
                    ctx = roiManual.ui(ctx);
                    if isfield(ctx,'cancelled') && ctx.cancelled
                        return;
                    end
                    if ~isfield(ctx,'roiManual') || ~isstruct(ctx.roiManual)
                        return;
                    end

                    app.applyProjectRoiProducerChoice(shallowObj, 'roiManual', ctx.roiManual);

                    try
                        runCtx = struct('shallow', shallowObj, 'roiManual', ctx.roiManual, 'params', ctx.roiManual);
                        roiManual.process(runCtx);
                        uialert(app.DetecDivUIFigure, ...
                            'Use the raw data viewer to draw or edit ROIs manually, then save/close the viewer when done.', ...
                            'Manual ROI mode', 'Icon', 'info');
                    catch ME
                        uialert(app.DetecDivUIFigure, ME.message, 'Manual ROI setup failed', 'Icon', 'error');
                        return;
                    end

                    RefreshtreewindowMenuSelected(app, event);

                case 3
                    params = app.getProjectDefaultPipelineNodeParams(shallowObj, 'roiGrid');
                    ctx = struct('shallow', shallowObj);
                    if ~isempty(fieldnames(params))
                        ctx.roiGrid = params;
                        ctx.params = params;
                    end
                    ctx = roiGrid.ui(ctx);
                    if isfield(ctx,'cancelled') && ctx.cancelled
                        return;
                    end
                    if ~isfield(ctx,'roiGrid') || ~isstruct(ctx.roiGrid)
                        return;
                    end

                    app.applyProjectRoiProducerChoice(shallowObj, 'roiGrid', ctx.roiGrid);

                    d = uiprogressdlg(app.DetecDivUIFigure, ...
                        'Title', 'Please Wait...', ...
                        'Message', 'Generating grid ROIs...');
                    try
                        runCtx = struct('shallow', shallowObj, 'roiGrid', ctx.roiGrid, 'params', ctx.roiGrid);
                        roiGrid.process(runCtx);
                        close(d);
                        uialert(app.DetecDivUIFigure, 'ROI generation is complete.', 'Success', 'Icon', 'success');
                    catch ME
                        close(d);
                        uialert(app.DetecDivUIFigure, ME.message, 'ROI generation failed', 'Icon', 'error');
                        return;
                    end

                    RefreshtreewindowMenuSelected(app, event);

                case 4
                    trackedParams = app.getProjectDefaultPipelineNodeParams(shallowObj, 'roiTracked');
                    if isempty(trackedParams) || ~isstruct(trackedParams) || isempty(fieldnames(trackedParams))
                        trackedParams = roiTracked.setparam(struct());
                    end
                    choice = uiconfirm(app.DetecDivUIFigure, ...
                        ['This uses tracked masks already present in ROI data to generate moving ROIs.' newline ...
                         'Run createTrackedCellROIs on the current project using default settings?'], ...
                        'Tracked ROIs', ...
                        'Options', {'Run','Cancel'}, ...
                        'DefaultOption', 'Run', ...
                        'CancelOption', 'Cancel');
                    if ~strcmp(choice, 'Run')
                        return;
                    end
                    d = uiprogressdlg(app.DetecDivUIFigure, ...
                        'Title', 'Please Wait...', ...
                        'Message', 'Creating tracked ROIs from masks...');
                    try
                        createTrackedCellROIs(shallowObj);
                        app.applyProjectRoiProducerChoice(shallowObj, 'roiTracked', trackedParams);
                        app.setProjectDefaultPipelineRoiMode(shallowObj, 'tracked');
                        close(d);
                        uialert(app.DetecDivUIFigure, 'Tracked ROI creation is complete.', 'Success', 'Icon', 'success');
                    catch ME
                        close(d);
                        uialert(app.DetecDivUIFigure, ME.message, 'Tracked ROI creation failed', 'Icon', 'error');
                        return;
                    end
                    RefreshtreewindowMenuSelected(app, event);
            end
        end

        % Button pushed function: ExtractROIhypervolumesButton
        function ExtractROIhypervolumesButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end
            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i = app.Tree.SelectedNodes.UserData;
            proj = app.Data.Project{i};
            shallowObj = evalin('base', proj);

            if numel(shallowObj.fov)==1 && numel(shallowObj.fov(1).srcpath)==0
                uialert(app.DetecDivUIFigure,'There is no position available for ROI extraction.','Error');
                return;
            end

            app.ensureProjectDefaultPipelineNode(shallowObj, 'roiExtract');
            params = app.getProjectDefaultPipelineNodeParams(shallowObj, 'roiExtract');
            ctx = struct('shallow', shallowObj);
            if ~isempty(fieldnames(params))
                ctx.roiExtract = params;
                ctx.params = params;
            end
            ctx = roiExtract.ui(ctx);
            if isfield(ctx,'cancelled') && ctx.cancelled
                return;
            end
            if ~isfield(ctx,'roiExtract') || ~isstruct(ctx.roiExtract)
                return;
            end

            app.updateProjectDefaultPipelineNodeParams(shallowObj, 'roiExtract', ctx.roiExtract);

            if ~isfield(ctx,'runNow') || ~ctx.runNow
                RefreshtreewindowMenuSelected(app, event);
                return;
            end

            d = uiprogressdlg(app.DetecDivUIFigure, ...
                'Title', 'Please Wait...', ...
                'Message', 'Extracting ROI hypervolumes...');
            try
                runCtx = struct('shallow', shallowObj, 'roiExtract', ctx.roiExtract, 'params', ctx.roiExtract);
                roiExtract.process(runCtx);
                close(d);
                uialert(app.DetecDivUIFigure,'ROI extraction is complete!','Success','Icon','success');
                RefreshtreewindowMenuSelected(app, event);
            catch ME
                close(d);
                uialert(app.DetecDivUIFigure, ME.message, 'ROI extraction failed', 'Icon', 'error');
                return;
            end
        end

        % Callback function
        function OpendatatosetROIsORtodefineanimagepatternButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            t=app.ProjectsNode.Children(i);
            expand(t);

            uialert(app.DetecDivUIFigure,'Browse data available in the tree menu, right-click Open on the desired dataset,','Warning')
        end

        % Button pushed function: ClassifydataButton
        function ClassifydataButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            classifyDataGUI(shallowObj);
        end

        % Callback function
        function SelectROItoviewDropDownValueChanged(app, event)
            value = app.SelectROItoviewDropDown.Value;

            % selectedfortraining=cellfun(@(x) x==1,app.UITableData.Data(:,1));
        end

        % Menu selected function: RefreshtreewindowMenu
        function RefreshtreewindowMenuSelected(app, event)
            gatherVarsFromWorkspace(app);
            displayNodes(app);
        end

        % Callback function
        function CreateSingleFullScreenROIinallpositionsMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return

            end

            selection=uiconfirm(app.DetecDivUIFigure,'This will erase all exisiting ROIs; Proceed?','Warning');



            if strcmp(selection,'OK')

                for i=1:numel(shallowObj.fov)
                    tmp=shallowObj.fov(i).readImage(1,1);
                    roival=[1 1 size(tmp,2) size(tmp,1)];
                    shallowObj.fov(i).roi=roi;
                    shallowObj.fov(i).addROI(roival,shallowObj.fov(i).id)

                end

            end


        end

        % Button pushed function: AddprocessorButton
        function AddprocessorButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if strcmp(app.Tree.SelectedNodes.Tag,'Project')
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{i};

                shallowObj=evalin('base',proj);

                ProcessorImporterGUI(app,shallowObj)
                uiwait(app.DetecDivUIFigure)



                TreeSelectionChanged(app, event)
                gatherVarsFromWorkspace(app);
                displayNodes(app);
            end
        end

        % Button pushed function: ProcessdataButton
        function ProcessdataButtonPushed(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select an item in the tree window!','Error');
                return;
            end

            tag = app.Tree.SelectedNodes.Tag;

            if strcmp(tag,'Project')
                i=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{i};
                shallowObj=evalin('base',proj);
                processDataGUI(shallowObj);
                return;
            end

            if strcmp(tag,'Pipeline')
                idx = app.Tree.SelectedNodes.UserData;
                if idx <= numel(app.Data.Pipeline)
                    pipeVar = app.Data.Pipeline{idx};
                    pipeObj = evalin('base', pipeVar);
                    pipelineRunGUI(pipeObj);
                end
                return;
            end

            if strcmp(tag,'ProjectpipelineRun')
                OpenButtonPushed(app, event);
                return;
            end

            uialert(app.DetecDivUIFigure,'The selected node cannot be processed with this button.','Error');
        end

        % Menu selected function: ExportprojecttoPhylocellMenu
        function ExportprojecttoPhylocellMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            export2phylocellGUI(shallowObj);
        end

        % Callback function
        function CreateFullFrameSingleROIMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return

            end

            deffov=['1:'  num2str(numel(shallowObj.fov)) ];
            prompt = {'Positions in which ROIs will be created:'};%,'Period between frames for each channel (in frames units):'};
            dlgtitle = 'Creating a single full frame ROI';

            dims = [1 100];


            definput = {deffov};%, num2str(inte)};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            if numel(answer)==0
                return;
            end

            selection=uiconfirm(app.DetecDivUIFigure,'This will erase all exisiting ROIs; Proceed?','Warning');



            if strcmp(selection,'OK')

                id=str2num(answer{1});
                if numel(id)
                    for i=id
                        tmp=shallowObj.fov(i).readImage(1,1);
                        roival=[1 1 size(tmp,2) size(tmp,1)];
                        shallowObj.fov(i).roi=roi;
                        shallowObj.fov(i).addROI(roival,shallowObj.fov(i).id)

                    end
                end

                uialert(app.DetecDivUIFigure,'ROI data must now be extracted to be functional...','Warning');
                RefreshtreewindowMenuSelected(app)
            end
        end

        % Callback function
        function DeleteallROIsinallpositionsMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return
            end


            selection=uiconfirm(app.DetecDivUIFigure,'This will erase all exisiting ROIs; Proceed?','Warning');

            if strcmp(selection,'OK')
                for i=1:numel(shallowObj.fov)
                    shallowObj.fov(i).roi=roi;
                end
            end


            RefreshtreewindowMenuSelected(app)
        end

        % Callback function
        function DeletePositionsMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return

            end

            deffov=['1:'  num2str(numel(shallowObj.fov)) ];
            prompt = {'Positions that will be deleted:'};%,'Period between frames for each channel (in frames units):'};
            dlgtitle = 'Deleting positions';

            dims = [1 100];


            definput = {deffov};%, num2str(inte)};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            if numel(answer)==0
                return;
            end

            selection=uiconfirm(app.DetecDivUIFigure,'This will erase selected positions; Proceed?','Warning');



            if strcmp(selection,'OK')

                id=str2num(answer{1});
                if numel(id)
                    pix=setxor(1:numel(shallowObj.fov),id);
                    shallowObj.fov=shallowObj.fov(pix);
                end

                RefreshtreewindowMenuSelected(app)
            end
        end

        % Callback function
        function SetPositionsorientationMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return
            end


            deffov=['1:'  num2str(numel(shallowObj.fov)) ];
            prompt = {'Positions that will be deleted:', 'Orientation in degrees (0,90,180,270):'};%,'Period between frames for each channel (in frames units):'};
            dlgtitle = 'Set position orientation';

            dims = [1 100];


            definput = {deffov,'0'};%, num2str(inte)};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            if numel(answer)==0
                return;
            end


            if numel(intersect(str2num(answer{2}),[0 90 180 270]))==0
                uialert(app.DetecDivUIFigure,'Orientation value is wrong; quitting !','Warning');
                return
            end

            id=str2num(answer{1});
            if numel(id)
                for i=1:numel(shallowObj.fov)
                    shallowObj.fov(i).orientation=str2num(answer{2});
                end
            end
        end

        % Callback function
        function AdjustROIssizeMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            deffov=['1:'  num2str(numel(shallowObj.fov)) ];
            defroi=num2str(shallowObj.fov(1).roi(1).value(3:4));
            prompt = {'Positions in which to change ROI size:','New Width/Height [width height]:'};%,'Period between frames for each channel (in frames units):'};
            dlgtitle = 'Adjusting ROI size';

            dims = [1 100];


            definput = {deffov,defroi};%, num2str(inte)};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            if numel(answer)==0
                disp('User canceled');
                return;
            end

            sz=str2num(answer{2});

            for i=1:numel(str2num(answer{1}))
                for j=1:numel(1:numel(shallowObj.fov(i).roi))
                    shallowObj.fov(i).roi(j).adjustROISize([0 0 sz(1) sz(2)]);
                end
            end
        end

        % Menu selected function: UserpreferencesMenu
        function UserpreferencesMenuSelected(app, event)
            preferencesGUI;
        end

        % Menu selected function: ClassifierRepositoryMenu
        function ClassifierRepositoryMenuSelected(app, event)
            classiRepository;
        end

        % Button pushed function: OpenButton
        function OpenButtonPushed(app, event)

    d = uiprogressdlg(app.DetecDivUIFigure, ...
        'Title', 'Please wait', ...
        'Message', 'Opening selection...', ...
        'Indeterminate', 'on');

    try
        selectedNodes = app.Tree.SelectedNodes;

        arg = selectedNodes.UserData;
        str = selectedNodes.Tag;
        cc  = [];
        if isnumeric(arg) && ~isempty(arg)
            cc = arg(1);
        end

        if strcmp(str,'Classifier')
            d.Message = 'Opening classifier...';
            clas = app.Data.Classifier{cc};
            clas = evalin('base', clas);
            classifierGUI(clas);
        end

        if strcmp(str,'Projectclassi')
            d.Message = 'Opening project classifier...';
            proj = app.Data.Project{cc(1)};
            pos  = arg(2);
            shallowObj = evalin('base', proj);
            clas = shallowObj.processing.classification(pos);
            classifierGUI(clas);
        end

        if strcmp(str,'Projectpos')
            d.Message = 'Loading image data...';

            cc  = arg(1);
            pos = arg(2);

            proj = app.Data.Project{cc(1)};
            shallowObj = evalin('base', proj);

            if numel(shallowObj.fov(pos).srcpath{1}) > 0
                im = readImage(shallowObj.fov(pos),1,1);

                if isempty(im)
                    close(d);
                    errordlg('The path to your raw data is incorrect; please update the raw data path !');
                    return
                end
            end

            d.Message = 'Opening field of view...';
            shallowObj.fov(pos).view( ...
                shallowObj.fov(pos).display.frame, []);
        end

        if strcmp(str,'Projectprocess')
            d.Message = 'Opening processing pipeline...';

            proj = app.Data.Project{cc(1)};
            pos  = arg(2);
            shallowObj = evalin('base', proj);
            proc = shallowObj.processing.processor(pos);

            processDataGUI(shallowObj, proc);
        end

        if strcmp(str,'Pipeline')
            [isLoaded, pipeObj] = app.getLoadedPipelineForNode(selectedNodes);
            if ~isLoaded
                d.Message = 'Loading pipeline in workspace...';
                [loaded, pipeObj, ~, jsonPath, msg] = app.loadPipelineForNode(selectedNodes);
                if ~loaded
                    error(msg);
                end
                gatherVarsFromWorkspace(app);
                displayNodes(app);
                app.selectPipelineNodeByJsonPath(jsonPath);
            end

            d.Message = 'Opening pipeline editor...';
            drawnow;
            app.safeCloseProgressDialog(d);
            app.openPipelineWithContext(pipeObj);
            return;
        end

        if strcmp(str,'PipelineModule')
            d.Message = 'Opening pipeline module...';
            pipeIdx = arg(1);
            modIdx = arg(2);
            app.openPipelineModuleByIndex(pipeIdx, modIdx);
        end

        if strcmp(str,'ProjectpipelineRun')
            d.Message = 'Running pipeline run...';
            proj = app.Data.Project{cc(1)};
            runIdx = arg(2);
            shallowObj = evalin('base', proj);
            if ~isfield(shallowObj.processing,'pipelineRun') || runIdx > numel(shallowObj.processing.pipelineRun)
                error('Run not found in project.');
            end

            runObj = shallowObj.processing.pipelineRun(runIdx);

            [pipeObj, msg] = app.resolvePipelineFromRun(runObj, shallowObj);
            if isempty(pipeObj)
                error(msg);
            end

            [runObj, runChanged] = app.backfillRunPipelineRef(runObj, pipeObj, shallowObj);
            if runChanged
                shallowObj.processing.pipelineRun(runIdx) = runObj;
                assignin('base', proj, shallowObj);
                pipelineRunSave(runObj);
            end

            runObj.status = 'running';
            pipelineRunSave(runObj);

            ctx = runObj.ctx;
            ctx.shallow = shallowObj;
            ctx.shallowObj = shallowObj;
            ctx.allowGUI = true;

            [ctxOut, report] = runPipeline(pipeObj, ctx);

            runObj.ctx = ctxOut;
            runObj.outputs = struct('report', report);
            runObj.status = 'done';
            runObj.updatedAt = char(datetime('now'));
            pipelineRunSave(runObj);

            RefreshtreewindowMenuSelected(app);
        end

    catch ME
        try
            close(d);
        catch
        end
        rethrow(ME)
    end

    close(d);

        end

        % Menu selected function: AddclassifierMenu
        function AddclassifierMenuSelected(app, event)
            AddclassifierButtonPushed(app, event)
        end

        % Menu selected function: SetFrameOrientationMenu
        function SetFrameOrientationMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return
            end


            deffov=['1:'  num2str(numel(shallowObj.fov)) ];

            results=myDialog({'Positions','Orientation'},{deffov,{'0','90','180','270','0'}},'Tip',{'Choose the list of positions to be processed','Orientation in deegrees'},...
                'CallingApp',app.DetecDivUIFigure,...
                'Title','Choose orientation of positions');

            if numel(results)==0
                return;
            end


            id=str2num(results.Positions);
            if numel(id)
                for i=1:numel(shallowObj.fov)
                    shallowObj.fov(i).orientation=str2num(results.Orientation{end});
                end
            end
        end

        % Menu selected function: CreateFullFrameROisMenu
        function CreateFullFrameROisMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return

            end

            deffov=['1:'  num2str(numel(shallowObj.fov)) ];

            results=myDialog({'Positions','Number_of_ROIs_per_frame'},{deffov,{'1' '4' '9' '16' '25' '1'}},'Tip',{'Choose the list of positions to be processed','Choose how many ROIs to split the full frame into'},...
                'CallingApp',app.DetecDivUIFigure,...
                'Title','Choose parameters to create  ROIs that cover the whole frame ');

            if numel(results)==0
                return;
            end

            selection=uiconfirm(app.DetecDivUIFigure,'This will erase all exisiting ROIs; Proceed?','Warning');



            if strcmp(selection,'OK')

                id=str2num(results.Positions);
                nb=str2num(results.Number_of_ROIs_per_frame{end});

                if numel(id)
                    for j=id
                        tmp=shallowObj.fov(j).readImage(1,1);
                        %    roival=[1 1 size(tmp,2) size(tmp,1)];

                        rows = sqrt(nb);
                        cols = sqrt(nb);
                        k=nb;
                        N=size(tmp,1);
                        M=size(tmp,2);

                        % Calculate the size of each square
                        squareSizeRows = N / rows;
                        squareSizeCols = M / cols;

                        % Initialize cell array to store coordinates
                        coordinates = cell(k, 2);

                        shallowObj.fov(j).roi=roi;

                        for i = 1:k
                            % Calculate the row and column indices of the i-th square
                            rowIdx = ceil(i / cols);
                            colIdx = mod(i - 1, cols) + 1;

                            % Calculate the coordinates of the top-left corner
                            topLeftRow = (rowIdx - 1) * squareSizeRows + 1;
                            topLeftCol = (colIdx - 1) * squareSizeCols + 1;

                            % Calculate the coordinates of the bottom-right corner
                            bottomRightRow = min(rowIdx * squareSizeRows, N);
                            bottomRightCol = min(colIdx * squareSizeCols, M);

                            % Store the coordinates in the cell array
                            %  coordinates{i, 1} = [topLeftRow, topLeftCol];
                            %coordinates{i, 2} = [bottomRightRow, bottomRightCol];

                            roival= [topLeftCol, topLeftRow, bottomRightCol-topLeftCol+1,  bottomRightRow-topLeftRow+1];
                            roival=uint16(roival);
                            shallowObj.fov(j).addROI(roival,shallowObj.fov(j).id)
                        end

                    end
                end

                uialert(app.DetecDivUIFigure,'ROI data must now be extracted to be functional...','Warning','Icon','warning');
                RefreshtreewindowMenuSelected(app)
            end
        end

        % Menu selected function: DeleteROIsMenu
        function DeleteROIsMenuSelected(app, event)

    % 1. Vérifier qu'un projet est sélectionné
    if numel(app.Tree.SelectedNodes) == 0
        uialert(app.DetecDivUIFigure, ...
            'First select a project in the tree window!', ...
            'Error');
        return;
    end

    if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
        uialert(app.DetecDivUIFigure, ...
            'The selected node is not a project!', ...
            'Error');
        return;
    end

    % 2. Charger le projet (shallowObj) depuis base
    projIdx     = app.Tree.SelectedNodes.UserData;
    projVarName = app.Data.Project{projIdx};
    shallowObj  = evalin('base', projVarName);

    % Vérifier qu'il y a bien des FOVs utilisables
    if numel(shallowObj.fov) == 1 && numel(shallowObj.fov.srcpath) == 0
        uialert(app.DetecDivUIFigure, ...
            'There is no position available', ...
            'Warning');
        return;
    end

    nFOV = numel(shallowObj.fov);

    % Pour chaque FOV, on va :
    % - déterminer le nom affiché
    % - déterminer le default ROI deletion string "1:N"
    % - marquer la ligne comme sélectionnée par défaut (true)
    tableSelect   = false(nFOV,1);
    tableName     = cell(nFOV,1);
    tableROIQuery = cell(nFOV,1);

    for ff = 1:nFOV

        % 2a. Nom FOV pour l'affichage
        % On essaie de trouver quelque chose d'informatif
        fovLabel = sprintf('FOV #%d', ff);
        if isprop(shallowObj.fov(ff),'name') && ~isempty(shallowObj.fov(ff).name)
            fovLabel = sprintf('FOV #%d (%s)', ff, shallowObj.fov(ff).name);
        elseif isprop(shallowObj.fov(ff),'id') && ~isempty(shallowObj.fov(ff).id)
            fovLabel = sprintf('FOV #%d (%s)', ff, shallowObj.fov(ff).id);
        elseif isprop(shallowObj.fov(ff),'srcpath') && ~isempty(shallowObj.fov(ff).srcpath)
            [~,tmpn,~] = fileparts(shallowObj.fov(ff).srcpath);
            fovLabel = sprintf('FOV #%d (%s)', ff, tmpn);
        end
        tableName{ff} = fovLabel;

        % 2b. String par défaut des ROIs à supprimer : "1:N"
          if isprop(shallowObj.fov(ff),'roi') && ~isempty(shallowObj.fov(ff).roi)
        nROI = numel(shallowObj.fov(ff).roi);
        if nROI > 0
            if nROI == 1
                tableROIQuery{ff} = '1';
            else
                tableROIQuery{ff} = sprintf('1:%d', nROI);
            end
        else
            tableROIQuery{ff} = '';
        end
    else
        tableROIQuery{ff} = '';
    end

    % 2c. Sélection par défaut : vrai si le champ roi existe
    tableSelect(ff) = ~isempty(tableROIQuery{ff}) && ~strcmp(tableROIQuery{ff},'');
    end

    % 3. Construire la fenêtre modale
    dlg = uifigure('Name','Delete ROIs from Project', ...
                   'WindowStyle','modal', ...
                   'Position',[100 100 600 400]);

    % Layout global
    gl = uigridlayout(dlg, [3 1]);
    gl.RowHeight = {'1x',40,40};
    gl.ColumnWidth = {'1x'};

    % 3a. Table
    t = uitable(gl);
    t.Layout.Row = 1;
    t.Layout.Column = 1;

    % Data de base pour la table
    tData = [num2cell(tableSelect), tableName, tableROIQuery];

    % Définition des colonnes
    % Col1: checkbox editable logique
    % Col2: texte non éditable
    % Col3: texte éditable
    t.ColumnName = {'Select','FOV','ROIs to delete'};
    t.ColumnEditable = [true false true];
    t.Data = tData;

    % Forcer des largeurs raisonnables
    t.ColumnWidth = {60, 220, '1x'};

    % 3b. Ligne boutons Select/Deselect
    rowButtons = uigridlayout(gl,[1 3]);
    rowButtons.Layout.Row = 2;
    rowButtons.Layout.Column = 1;
    rowButtons.ColumnWidth = {100,120,'1x'};

    btnSelectAll = uibutton(rowButtons,'push', ...
        'Text','Select all', ...
        'ButtonPushedFcn',@(~,~) doSelectAll(true));

    btnDeselectAll = uibutton(rowButtons,'push', ...
        'Text','Deselect all', ...
        'ButtonPushedFcn',@(~,~) doSelectAll(false));

    % filler panel pour pousser à gauche
    uilabel(rowButtons,'Text',''); % just spacer

    % 3c. Ligne boutons OK / Cancel
    rowOK = uigridlayout(gl,[1 3]);
    rowOK.Layout.Row = 3;
    rowOK.Layout.Column = 1;
    rowOK.ColumnWidth = {'1x',80,80};

    % spacer
    uilabel(rowOK,'Text','');

    btnCancel = uibutton(rowOK,'push', ...
        'Text','Cancel', ...
        'ButtonPushedFcn',@(~,~) onCancel());

    btnOK = uibutton(rowOK,'push', ...
        'Text','OK', ...
        'ButtonPushedFcn',@(~,~) onOK());

    % On va utiliser uiwait/uiresume pour bloquer tant que la boîte est ouverte
    userChoice = struct('action','cancel','table',[]);
    uiwait(dlg);  % bloquant jusqu'à uiresume dans onOK/onCancel

    % À ce stade, soit OK, soit Cancel a défini userChoice
    if ~isvalid(dlg)
        % La figure a déjà été détruite dans le callback.
        % On lit userChoice.action via le nested scope (fermé dessus).
    end

    % Si cancel -> on sort sans rien changer
    if strcmp(userChoice.action,'cancel')
        return;
    end

    % 4. Application des suppressions ROI selon userChoice.table
    % userChoice.table(:,1) : logical select?
    % userChoice.table(:,3) : string "1:10" etc
    finalData = userChoice.table;

    for ff = 1:nFOV

        % skip si pas sélectionné
        if ~finalData{ff,1}
            continue;
        end

        if ~isprop(shallowObj.fov(ff),'roi') || isempty(shallowObj.fov(ff).roi)
            continue;
        end

        roiStr = strtrim(finalData{ff,3});
        if isempty(roiStr)
            % rien à supprimer
            continue;
        end

        % Parser la chaîne "1:32" etc en indices
        % On utilise eval de façon contrôlée: si l'utilisateur tape une
        % horreur, on catch et on ignore.
        try
            delIdx = eval(['[', roiStr, ']']); %#ok<EVLDIR>
            if ~isnumeric(delIdx)
                delIdx = [];
            end
        catch
            delIdx = [];
        end

        if isempty(delIdx)
            continue;
        end

        allIdx  = 1:numel(shallowObj.fov(ff).roi);
        keepIdx = setxor(allIdx, delIdx);

        if isempty(keepIdx)
            % plus aucune ROI
            shallowObj.fov(ff).roi = roi;
        else
            shallowObj.fov(ff).roi = shallowObj.fov(ff).roi(keepIdx);
        end
    end

    % 5. Sauvegarde de l'objet modifié dans le workspace
    assignin('base', projVarName, shallowObj);

    % 6. Refresh UI
    RefreshtreewindowMenuSelected(app);


    % ==========================
    %  NESTED CALLBACKS
    % ==========================
    function doSelectAll(state)
        % state=true -> tout à true
        % state=false -> tout à false
        tbl = t.Data;
        for r = 1:size(tbl,1)
            tbl{r,1} = state;
        end
        t.Data = tbl;
    end

    function onCancel()
        % L'utilisateur annule : rien à faire
        userChoice.action = 'cancel';
        userChoice.table  = t.Data;
        if isvalid(dlg)
            uiresume(dlg);
            delete(dlg);
        end
    end

    function onOK()
        % Vérifier qu'au moins une ligne est sélectionnée et qu'il y a des ROIs ?
        % (on ne rend pas ça bloquant pour ne pas le frustrer)
        userChoice.action = 'ok';
        userChoice.table  = t.Data;
        if isvalid(dlg)
            uiresume(dlg);
            delete(dlg);
        end
    end


    

        end

        % Menu selected function: AdjustROIsMenu
        function AdjustROIsMenuSelected(app, event)

            ROIAdjustGUI();
            
            % if numel(app.Tree.SelectedNodes)==0
            %     uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
            %     return;
            % end
            % 
            % if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
            %     uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
            %     return;
            % end
            % 
            % i=app.Tree.SelectedNodes.UserData;
            % % store=app.Tree.SelectedNodes;
            % proj=app.Data.Project{i};
            % shallowObj=evalin('base',proj);
            % 
            % 
            % deffov=['1:'  num2str(numel(shallowObj.fov)) ];
            % defroi=num2str(shallowObj.fov(1).roi(1).value(3:4));
            % results=myDialog({'Positions','ROI_size'},{deffov,defroi},'Tip',{'Choose the list of positions to be processed','Enter new ROI width and height, eg.: 60 60'},...
            %     'CallingApp',app.DetecDivUIFigure,...
            %     'Title','Choose positions in which to adjust ROI size');
            % 
            % if numel(results)==0
            %     return;
            % end
            % 
            % 
            % 
            % sz=str2num(results.ROI_size);
            % 
            % for i=str2num(results.Positions)
            %     for j=1:numel(1:numel(shallowObj.fov(i).roi))
            %         shallowObj.fov(i).roi(j).adjustROISize([0 0 sz(1) sz(2)]);
            %     end
            % end
        end

        % Menu selected function: DeletePositionsMenu_2
        function DeletePositionsMenu_2Selected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return

            end

            deffov=['1:'  num2str(numel(shallowObj.fov)) ];
            results=myDialog({'Positions'},{deffov},'Tip',{'Choose the list of positions to delete'},...
                'CallingApp',app.DetecDivUIFigure,...
                'Title','Choose positions to delete');

            if numel(results)==0
                return;
            end




            selection=uiconfirm(app.DetecDivUIFigure,'This will erase selected positions; Proceed?','Warning');



            if strcmp(selection,'OK')

                id=str2num(results.Positions);
                if numel(id)
                    pix=setxor(1:numel(shallowObj.fov),id);
                    shallowObj.fov=shallowObj.fov(pix);
                end

                RefreshtreewindowMenuSelected(app)
            end
        end

        % Menu selected function: AddPositionsDataMenu
        function AddPositionsDataMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end
            i=app.Tree.SelectedNodes.UserData;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            nBefore = app.getProjectFovCount(shallowObj);

            addDataGUI(shallowObj,app);
            uiwait(app.DetecDivUIFigure);

            nAfter = app.getProjectFovCount(shallowObj);
            if nAfter > nBefore
                app.ensureDefaultPipelineForProject(shallowObj);
            end

            TreeSelectionChanged(app, event)
            gatherVarsFromWorkspace(app);
            displayNodes(app);
        end

        % Callback function
        function CleanupROItrainingandresultsMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);

            if numel(shallowObj.fov)==1 & numel(shallowObj.fov.srcpath)==0

                uialert(app.DetecDivUIFigure,'There is no position available','Warning');
                return

            end


            deffov=['1:'  num2str(numel(shallowObj.fov)) ];

            % listof training and results field.

            trainstr={};
            resultsstr={};
            cc=1;
            cc2=1;

            for i=1:numel(shallowObj.fov)
                for k=1:numel(shallowObj.fov(i).roi)
                    roiobj=shallowObj.fov(i).roi(k);

                    roiobj.load('results');

                    if numel(roiobj.train)

                        f=fieldnames(roiobj.train);

                        for j=1:numel(f)
                            trainstr{cc}=f{j};
                            cc=cc+1;
                        end
                    end
                    if numel(roiobj.results)
                        f=fieldnames(roiobj.results);

                        for j=1:numel(f)
                            resultsstr{cc2}=f{j};
                            cc2=cc2+1;
                        end
                    end
                end
            end

            trainstr=unique(trainstr);
            resultsstr=unique(resultsstr);

            % if numel(trainstr)==0
            trainstr=[trainstr '-' '-'];
            % end

            % if numel(resultsstr)==0
            resultsstr=[resultsstr '-' '-'];
            %  end

            results=myDialog({'Positions','Train_Fields','Results_Fields','Remove_All_Train','Remove_All_Results'},...
                {deffov,trainstr,resultsstr,false,false},...
                'Tip',{'Choose the positions to process','Choose the training field to remove','Choose the result field to remove','Check to remove all trainings','Check to remove all results'},...
                'CallingApp',app.DetecDivUIFigure,...
                'Title','Choose fields to remove from training and results');

            if numel(results)==0
                return;
            end



            for i=str2num(results.Positions)
                for k=1:numel(shallowObj.fov(i).roi)

                    roiobj=shallowObj.fov(i).roi(k);

                    if numel(roiobj.image)==0
                        roiobj.load;
                    end

                    if results.Remove_All_Train==1
                        roiobj.train=[];
                    else
                        tr=results.Train_Fields{end};
                        if ~strcmp(tr,'-')
                            roiobj.removeData({tr},{});
                        end
                    end
                    if results.Remove_All_Results==1
                        roiobj.results=[];
                    else
                        roiobj.load('results');
                        re=results.Results_Fields{end};
                        if ~strcmp(re,'-')
                            roiobj.removeData({},{re});
                        end
                    end

                    roiobj.save('results');
                end
            end





            RefreshtreewindowMenuSelected(app)


        end

        % Callback function
        function CleanupROIstrainingandresultsMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a classifier in the tree window!','Error');
                return;
            end

            selectedNodes=  app.Tree.SelectedNodes;

            okclas=0;
            if strcmp(selectedNodes.Tag,'Projectclassi')
                okclas=1;
                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{cc(1)};
                pos=cc(2);
                shallowObj=evalin('base',proj);
                clas=shallowObj.processing.classification(pos);
            end

            if strcmp(selectedNodes.Tag,'Classifier')
                okclas=1;
                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Classifier{cc};

                clas=evalin('base',proj);
            end

            if okclas==0
                uialert(app.DetecDivUIFigure,'First select a classifier in the tree window!','Error');
                return;
            end

            % listof training and results field.

            trainstr={};
            resultsstr={};
            cc=1;
            cc2=1;
            for k=1:numel(clas.roi)
                roiobj=clas.roi(k);

                roiobj.load('results');

                if numel(roiobj.train)

                    f=fieldnames(roiobj.train);

                    for j=1:numel(f)
                        trainstr{cc}=f{j};
                        cc=cc+1;
                    end
                end
                if numel(roiobj.results)
                    f=fieldnames(roiobj.results);

                    for j=1:numel(f)
                        resultsstr{cc2}=f{j};
                        cc2=cc2+1;

                    end
                end
            end

            trainstr=unique(trainstr);
            resultsstr=unique(resultsstr);

            % if numel(trainstr)==0
            trainstr=[trainstr '-' '-'];
            % end

            % if numel(resultsstr)==0
            resultsstr=[resultsstr '-' '-'];
            %  end

            results=myDialog({'Train_Fields','Results_Fields','Remove_All_Train','Remove_All_Results'},...
                {trainstr,resultsstr,false,false},...
                'Tip',{'Choose the training field to remove','Choose the result field to remove','Check to remove all trainings but the one selected above','Check to remove all results but the one selected above'},...
                'CallingApp',app.DetecDivUIFigure,...
                'Title','Choose fields to remove from training and results');

            if numel(results)==0
                return;
            end


            for k=1:numel(clas.roi)

                roiobj=clas.roi(k);
                if numel(roiobj.image)==0
                    roiobj.load;
                end

                if results.Remove_All_Train==1
                    tr=results.Train_Fields{end};
                    if ~strcmp(tr,'-')
                        tmp=setxor(trainstr,tr);
                        roiobj.removeData(tmp,{});
                    else
                        roiobj.train=[];
                    end
                else
                    tr=results.Train_Fields{end};
                    if ~strcmp(tr,'-')
                        roiobj.removeData({tr},{});
                    end
                end

                if results.Remove_All_Results==1
                    tr=results.Results_Fields{end};
                    if ~strcmp(tr,'-')
                        tmp=setxor(resultsstr,tr);
                        roiobj.removeData({},tmp);
                    else

                        roiobj.results=[];
                    end
                else
                    roiobj.load('results');
                    re=results.Results_Fields{end};
                    if ~strcmp(re,'-')
                        roiobj.removeData({},{re});
                    end
                end

                roiobj.save;

            end


            RefreshtreewindowMenuSelected(app)

        end

        % Callback function
        function ChangeChannelnameMenuSelected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
                return;
            end

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
                uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
                return;
            end

            i=app.Tree.SelectedNodes.UserData;
            % store=app.Tree.SelectedNodes;
            proj=app.Data.Project{i};
            shallowObj=evalin('base',proj);


            deffov=['1:'  num2str(numel(shallowObj.fov)) ];
            listChannels=listAvailableChannels;
            listChannels{end+1}=listChannels{1};
            newname='newchannel';

            results=myDialog({'Positions','ChannelToReplace','NewChannelName'},{deffov,listChannels,newname},...
                'Tip',{'Choose the list of positions to be processed','Choose the channel to be replaced','Enter the new name'},...
                'CallingApp',app.DetecDivUIFigure,...
                'Title','Change the name of a channel');

            if numel(results)==0
                return;
            end


            chan=results.ChannelToReplace{end};


            newchan=results.NewChannelName;

            for i=str2num(results.Positions)

                disp([ 'Processing position ' num2str(i) 'out of ' results.Positions]);
                for j=1:numel(1:numel(shallowObj.fov(i).roi))

                    pix=shallowObj.fov(i).roi(j).findChannelID(chan);

                    if numel(pix)
                        shallowObj.fov(i).roi(j).display.channel{pix}=newchan;
                        disp('Change channel name is done !')
                    else
                        disp(['Channel ' chan ' not found for ROI ' shallowObj.fov(i).roi(j).id ]);
                    end
                end
            end


        end

        % Callback function
        function ChangechannelnameMenuSelected(app, event)

            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a classifier in the tree window!','Error');
                return;
            end

            selectedNodes=app.Tree.SelectedNodes;

            okclas=0;
            if strcmp(selectedNodes.Tag,'Projectclassi')
                okclas=1;
                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Project{cc(1)};
                pos=cc(2);
                shallowObj=evalin('base',proj);
                clas=shallowObj.processing.classification(pos);
            end

            if strcmp(selectedNodes.Tag,'Classifier')
                okclas=1;
                cc=app.Tree.SelectedNodes.UserData;
                proj=app.Data.Classifier{cc};

                clas=evalin('base',proj);
            end

            if okclas==0
                uialert(app.DetecDivUIFigure,'First select a classifier in the tree window!','Error');
                return;
            end

            defroi=['1:'  num2str(numel(clas.roi)) ];

            listChannels=listAvailableChannels
            listChannels{end+1}=listChannels{1};
            newname='newchannel';

            results=myDialog({'ROIs','ChannelToReplace','NewChannelName'},{defroi,listChannels,newname},...
                'Tip',{'Choose the ROIs to replace','Choose the channel to be replaced','Enter the new name'},...
                'CallingApp',app.DetecDivUIFigure,...
                'Title','Change the name of a channel');

            if numel(results)==0
                return;
            end


            chan=results.ChannelToReplace{end};


            newchan=results.NewChannelName;

            rois=str2num(results.ROIs);

            for j=rois %1:numel(1:numel(clas.roi))

                pix=clas.roi(j).findChannelID(chan);

                if numel(pix)
                    clas.roi(j).display.channel{pix}=newchan;
                    disp(['Change channel name is done for roi ' clas.roi(j).id '!'])
                else
                    disp(['Channel ' chan ' not found for ROI ' clas.roi(j).id ]);
                end
            end



        end

        % Menu selected function: DeleteROIsMenu_2
        function DeleteROIsMenu_2Selected(app, event)
            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a classifier in the tree window!','Error');
                return;
            end

            selectedNodes=app.Tree.SelectedNodes;
            str=app.Tree.SelectedNodes.Tag;

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Classifier') && ~strcmp(app.Tree.SelectedNodes.Tag,'Projectclassi')
                uialert(app.DetecDivUIFigure,'The selected node is not a classifier !','Error');
                return;
            end

            arg=selectedNodes.UserData;
            cc=arg(1);

            if strcmp(str,'Classifier')
                clas=app.Data.Classifier{cc};
                clas=evalin('base',clas);
            end
            if strcmp(str,'Projectclassi')
                proj=app.Data.Project{cc(1)};
                pos=arg(2);
                shallowObj=evalin('base',proj);
                clas=shallowObj.processing.classification(pos);
            end



            defroi=['1:'  num2str(numel(clas.roi)) ];
            prompt = {'ROIs that will be deleted:'};%,'Period between frames for each channel (in frames units):'};
            dlgtitle = 'Deleting ROIs';

            dims = [1 100];


            definput = {defroi};%, num2str(inte)};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            if numel(answer)==0
                return;
            end

            selection=uiconfirm(app.DetecDivUIFigure,'This will erase selected ROIs; Proceed?','Warning');



            if strcmp(selection,'OK')

                id=str2num(answer{1});
                if numel(id)
                    pix=setxor(1:numel(clas.roi),id);

                    if numel(pix)==0
                        clas.roi=roi;
                        clas.channelName={};
                    else
                        clas.roi=clas.roi(pix);
                    end

                end

                RefreshtreewindowMenuSelected(app)
            end



        end

        % Menu selected function: ClassifyDataMenu
        function ClassifyDataMenuSelected(app, event)
            classifyDataGUI;
        end

        % Menu selected function: RestoredeletedROIsMenu
        function RestoredeletedROIsMenuSelected(app, event)
           
% SNIPPET FROM DEV BRANCH (commit ee414e4 context)
% Paste this callback into GUI/detecdiv.mlapp if you want the ROI restore
% logic that merges ROIs from disk (HDF5) into the selected position.

% Restore/Merge ROIs from disk into shallowObj.fov(pix).roi
% Disk ROI files are HDF5 named: im_<id>.h5 (or .hdf5)
% Canonical ROI id = substring between "im_" and ".h5"
% Loading is done via roiobj.load(...) using roiobj.path + roiobj.id

% ---- basic checks ----
if isempty(app.Tree.SelectedNodes)
    uialert(app.DetecDivUIFigure,'First select a project in the tree window!','Error');
    return;
end
if ~strcmp(app.Tree.SelectedNodes.Tag,'Project')
    uialert(app.DetecDivUIFigure,'The selected node is not a project!','Error');
    return;
end

projIdx = app.Tree.SelectedNodes.UserData;
projVar = app.Data.Project{projIdx};   % base workspace var name
shallowObj = evalin('base', projVar);

% ---- position list ----
posList = arrayfun(@(f) string(f.id), shallowObj.fov, 'UniformOutput', true);
posList = posList(posList ~= "");
if isempty(posList)
    uialert(app.DetecDivUIFigure,'No positions found in project (shallowObj.fov is empty).','Error');
    return;
end

% myDialog expects: { items..., defaultValue }
posDialog = cellstr(posList);
posDialog{end+1} = posDialog{1};

results = myDialog({'Position_to_restore'}, {posDialog}, ...
    'Tip',{'Choose the position in which the ROIs should be restored / merged'}, ...
    'CallingApp',app.DetecDivUIFigure, ...
    'Title','Restore ROIs (merge with disk)');

if isempty(results), return; end
posname = string(results.Position_to_restore{end});
pix = find(strcmp(cellstr(posList), posname), 1);
if isempty(pix)
    uialert(app.DetecDivUIFigure,'Selected position not found in project.','Error');
    return;
end

% ---- disk folder ----
dirpath = fullfile(shallowObj.io.path, shallowObj.io.file, char(posList(pix)));
if ~isfolder(dirpath)
    uialert(app.DetecDivUIFigure, "Folder not found: " + dirpath, 'Error');
    return;
end

% ---- scan H5 ROI files (im_<id>.h5) ----
diskFiles = [dir(fullfile(dirpath,'im_*.h5')); dir(fullfile(dirpath,'im_*.hdf5'))];
diskFiles = diskFiles(~[diskFiles.isdir]);

if isempty(diskFiles)
    uialert(app.DetecDivUIFigure, "No ROI files found (im_*.h5) in: " + dirpath, 'Info');
    return;
end

% ---- ROIs in memory ----
roiMem = [];
if isfield(shallowObj.fov(pix),'roi') && ~isempty(shallowObj.fov(pix).roi)
    roiMem = shallowObj.fov(pix).roi;
end

% ---- index memory by id ----
memIdToIdx = containers.Map('KeyType','char','ValueType','int32');
if ~isempty(roiMem)
    for i = 1:numel(roiMem)
        rid = "";
        try, rid = string(roiMem(i).id); catch, end
        if rid ~= "" && ~isKey(memIdToIdx, char(rid))
            memIdToIdx(char(rid)) = int32(i);
        end
    end
end

added = 0;
replaced = 0;
unreadable = 0;

for k = 1:numel(diskFiles)
    fname = diskFiles(k).name;
    id = roiIdFromImH5Filename(fname);
    if id == ""
        unreadable = unreadable + 1;
        fprintf('[RESTORE][SKIP] %s -> not im_<id>.h5\n', fname);
        continue;
    end

    h5File = fullfile(dirpath, sprintf('im_%s.h5', char(id)));
    if ~isfile(h5File)
        h5File = fullfile(dirpath, sprintf('im_%s.hdf5', char(id)));
    end
    dataFile = fullfile(dirpath, sprintf('data_%s.mat', char(id))); %#ok<NASGU>

    fprintf('\n[RESTORE] %3d/%3d  id="%s"\n', k, numel(diskFiles), char(id));
    fprintf('          H5  : %s\n', h5File);
    fprintf('          MAT : %s\n', dataFile);

    if ~isfile(h5File)
        unreadable = unreadable + 1;
        fprintf('          -> FAIL: missing H5 file\n');
        continue;
    end

    % HDF5 sanity
    try
        info = h5info(h5File);
        nD = numel(info.Datasets);
        nG = numel(info.Groups);
        fprintf('          h5info OK: %d datasets, %d groups\n', nD, nG);
    catch MEh5
        unreadable = unreadable + 1;
        fprintf('          -> FAIL: H5 unreadable: %s\n', MEh5.message);
        continue;
    end

    % Load via roi.load (debug verbose)
    try
        roiDisk = roi();
        roiDisk.path = dirpath;
        roiDisk.id = char(id);
        roiDisk.load('Debug');

        % merge
        if isKey(memIdToIdx, char(id))
            idx = memIdToIdx(char(id));
            roiMem(idx) = roiDisk;
            replaced = replaced + 1;
            fprintf('          -> OK: replaced existing ROI\n');
        else
            if isempty(roiMem), roiMem = roiDisk;
            else, roiMem(end+1) = roiDisk; %#ok<AGROW>
            end
            memIdToIdx(char(id)) = int32(numel(roiMem));
            added = added + 1;
            fprintf('          -> OK: added ROI\n');
        end
    catch ME
        unreadable = unreadable + 1;
        fprintf('          -> FAIL in roi.load: %s\n', ME.message);
        for s = 1:numel(ME.stack)
            fprintf('             at %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
    end
end

% ---- write back once ----
shallowObj.fov(pix).roi = roiMem;
assignin('base', projVar, shallowObj);

msg = sprintf(['Merge done for %s\n' ...
               '- Disk files scanned: %d\n' ...
               '- Added: %d\n' ...
               '- Replaced (same id): %d\n' ...
               '- Unreadable/ignored: %d'], ...
               posname, numel(diskFiles), added, replaced, unreadable);
uialert(app.DetecDivUIFigure, msg, 'Restore ROIs');

% ===== local helper =====
function id = roiIdFromImH5Filename(fnameLocal)
    [~, base, ext] = fileparts(fnameLocal);
    if ~strcmpi(ext,'.h5') && ~strcmpi(ext,'.hdf5')
        id = "";
        return;
    end
    if startsWith(base, 'im_', 'IgnoreCase', false)
        id = string(extractAfter(base, 'im_'));
    else
        id = "";
    end
end


        end

        % Menu selected function: ExportdataMenu
        function ExportdataMenuSelected(app, event)
            %     exportdata;
            detector;
        end

        % Menu selected function: ConvertoldtrainingandresultdataMenu
        function ConvertoldtrainingandresultdataMenuSelected(app, event)

            app.Data.st=gatherVariablesFromWorkspace;

            s=app.Data.st;


            % list avaialable fovs and classi with ROIs


            list=[];

            for i=1:numel(s.Project)

                proj=s.Project{i};

                for k=1:numel(s.Projectpos{i})

                    tmp= evalin('base',[proj '.fov(' num2str(k) ')']);

                    for j=1:numel(tmp.roi)
                        list=[list tmp.roi(j)];
                    end

                end

                for k=1:numel(s.Projectclassi{i})

                    tmp= evalin('base',[proj '.processing.classification(' num2str(k) ')']);

                    for j=1:numel(tmp.roi)
                        list=[list tmp.roi(j)];
                    end



                end
            end
            for i=1:numel(s.Classifier)

                clas=s.Classifier{i};

                tmp= evalin('base',clas);

                for j=1:numel(tmp.roi)
                    list=[list tmp.roi(j)];
                end


            end

            formatInDataSeries(list);

        end

        % Menu selected function: ProcessdataMenu
        function ProcessdataMenuSelected(app, event)
            processDataGUI;
        end

        % Menu selected function: MakeROImoviesMenu
        function MakeROImoviesMenuSelected(app, event)
            movieGUI;
        end

        % Menu selected function: RestoredeletedROIsMenu_2
        function RestoredeletedROIsMenu_2Selected(app, event)
            % in case rois have been redfined, but are still stored on the
            % hard drive, this function allows one to restore the previous
            % verison

            if numel(app.Tree.SelectedNodes)==0
                uialert(app.DetecDivUIFigure,'First select a classifier in the tree window!','Error');
                return;
            end

            selectedNodes=app.Tree.SelectedNodes;
            str=app.Tree.SelectedNodes.Tag;

            if ~strcmp(app.Tree.SelectedNodes.Tag,'Classifier') && ~strcmp(app.Tree.SelectedNodes.Tag,'Projectclassi')
                uialert(app.DetecDivUIFigure,'The selected node is not a classifier !','Error');
                return;
            end

            arg=selectedNodes.UserData;
            cc=arg(1);

            if strcmp(str,'Classifier')
                clas=app.Data.Classifier{cc};
                clas=evalin('base',clas);
            end

            if strcmp(str,'Projectclassi')
                proj=app.Data.Project{cc(1)};
                pos=arg(2);
                shallowObj=evalin('base',proj);
                clas=shallowObj.processing.classification(pos);
            end

            dirpath=fullfile(clas.path);

            ls=dir(dirpath);
            lsname={ls.name};

            for i=1:numel(clas.roi)

                nme=['im_' clas.roi(i).id '.mat'];

                if numel(find(matches(lsname,nme)))
                    fle=fullfile(dirpath,nme);
                    tmp=load(fle);
                    clas.roi(i)=tmp.roiobj;
                    %  clas.roi(i).clear;
                    clas.roi(i).save;
                    clas.roi(i).clear;
                end

            end
        end

        % Menu selected function: DeleteclassifierMenu
        function DeleteclassifierMenuSelected(app, event)

        end

        % Menu selected function: AdjustROIsMenu_2
        function AdjustROIsMenu_2Selected(app, event)
            ROIAdjustGUI();
        end

        % Menu selected function: AdjustROIsMenu_3
        function AdjustROIsMenu_3Selected(app, event)
            ROIAdjustGUI();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create DetecDivUIFigure and hide until all components are created
            app.DetecDivUIFigure = uifigure('Visible', 'off');
            app.DetecDivUIFigure.Position = [100 100 708 646];
            app.DetecDivUIFigure.Name = 'DetecDiv';
            app.DetecDivUIFigure.Icon = 'detecDiv_logo.png';
            app.DetecDivUIFigure.AutoResizeChildren = 'off';

            % Create MainGrid
            app.MainGrid = uigridlayout(app.DetecDivUIFigure);
            app.MainGrid.ColumnWidth = {241, '1x'};
            app.MainGrid.RowHeight = {'1x'};
            app.MainGrid.Padding = [8 8 8 8];
            app.MainGrid.ColumnSpacing = 12;
            app.MainGrid.RowSpacing = 0;

            % Create FileMenu
            app.FileMenu = uimenu(app.DetecDivUIFigure);
            app.FileMenu.Text = 'File';

            % Create NewprojectMenu
            app.NewprojectMenu = uimenu(app.FileMenu);
            app.NewprojectMenu.MenuSelectedFcn = createCallbackFcn(app, @NewprojectMenuSelected, true);
            app.NewprojectMenu.Text = 'New project...';

            % Create OpenprojectMenu
            app.OpenprojectMenu = uimenu(app.FileMenu);
            app.OpenprojectMenu.MenuSelectedFcn = createCallbackFcn(app, @OpenprojectMenuSelected, true);
            app.OpenprojectMenu.Text = 'Open project...';

            % Create OpenrecentMenu
            app.OpenrecentMenu = uimenu(app.FileMenu);
            app.OpenrecentMenu.Text = 'Open recent';

            % Create Item1Menu
            app.Item1Menu = uimenu(app.OpenrecentMenu);
            app.Item1Menu.Text = 'Item1';

            uimenu(app.FileMenu, ...
                'Text', 'Catalog browser...', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', createCallbackFcn(app, @CatalogBrowserMenuSelected, true));

            % Create SaveselectedprojectMenu
            app.SaveselectedprojectMenu = uimenu(app.FileMenu);
            app.SaveselectedprojectMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveselectedprojectMenuSelected, true);
            app.SaveselectedprojectMenu.Text = 'Save selected project';

            % Create Closeproject
            app.Closeproject = uimenu(app.FileMenu);
            app.Closeproject.MenuSelectedFcn = createCallbackFcn(app, @CloseprojectMenuSelected, true);
            app.Closeproject.Text = 'Close selected project';

            % Create ExportprojecttoPhylocellMenu
            app.ExportprojecttoPhylocellMenu = uimenu(app.FileMenu);
            app.ExportprojecttoPhylocellMenu.MenuSelectedFcn = createCallbackFcn(app, @ExportprojecttoPhylocellMenuSelected, true);
            app.ExportprojecttoPhylocellMenu.Separator = 'on';
            app.ExportprojecttoPhylocellMenu.Text = 'Export project to Phylocell...';

            % Create PipelineTemplatesMenu
            app.PipelineTemplatesMenu = uimenu(app.FileMenu);
            app.PipelineTemplatesMenu.Separator = 'on';
            app.PipelineTemplatesMenu.Text = 'Pipeline templates';

            % Create NewpipelinetemplateMenu
            app.NewpipelinetemplateMenu = uimenu(app.PipelineTemplatesMenu);
            app.NewpipelinetemplateMenu.MenuSelectedFcn = createCallbackFcn(app, @NewpipelinetemplateMenuSelected, true);
            app.NewpipelinetemplateMenu.Text = 'New...';

            % Create OpenpipelinetemplateMenu
            app.OpenpipelinetemplateMenu = uimenu(app.PipelineTemplatesMenu);
            app.OpenpipelinetemplateMenu.MenuSelectedFcn = createCallbackFcn(app, @OpenpipelinetemplateMenuSelected, true);
            app.OpenpipelinetemplateMenu.Text = 'Open...';

            % Create OpenrecentPipelineMenu
            app.OpenrecentPipelineMenu = uimenu(app.PipelineTemplatesMenu);
            app.OpenrecentPipelineMenu.Text = 'Open recent';

            % Create ClosepipelinetemplateMenu
            app.ClosepipelinetemplateMenu = uimenu(app.PipelineTemplatesMenu);
            app.ClosepipelinetemplateMenu.MenuSelectedFcn = createCallbackFcn(app, @ClosepipelinetemplateMenuSelected, true);
            app.ClosepipelinetemplateMenu.Text = 'Close selected';

            % Create NewprojectindependentclassiiferMenu
            app.NewprojectindependentclassiiferMenu = uimenu(app.FileMenu);
            app.NewprojectindependentclassiiferMenu.MenuSelectedFcn = createCallbackFcn(app, @NewprojectindependentclassiiferMenuSelected, true);
            app.NewprojectindependentclassiiferMenu.Separator = 'on';
            app.NewprojectindependentclassiiferMenu.Text = 'New project-independent classiifer...';

            % Create OpenprojectindependentclassifierMenu
            app.OpenprojectindependentclassifierMenu = uimenu(app.FileMenu);
            app.OpenprojectindependentclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @OpenprojectindependentclassifierMenuSelected, true);
            app.OpenprojectindependentclassifierMenu.Text = 'Open project-independent classifier...';

            % Create OpenrecentClassiMenu
            app.OpenrecentClassiMenu = uimenu(app.FileMenu);
            app.OpenrecentClassiMenu.Text = 'Open recent independent classifier';

            % Create SaveprojectindependentclassifierMenu
            app.SaveprojectindependentclassifierMenu = uimenu(app.FileMenu);
            app.SaveprojectindependentclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveprojectindependentclassifierMenuSelected, true);
            app.SaveprojectindependentclassifierMenu.Text = 'Save project-independent classifier';

            % Create CloseprojectindependentclassifierMenu
            app.CloseprojectindependentclassifierMenu = uimenu(app.FileMenu);
            app.CloseprojectindependentclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @CloseprojectindependentclassifierMenuSelected, true);
            app.CloseprojectindependentclassifierMenu.Text = 'Close project-independent classifier';

            % Create ClassifierRepositoryMenu
            app.ClassifierRepositoryMenu = uimenu(app.FileMenu);
            app.ClassifierRepositoryMenu.MenuSelectedFcn = createCallbackFcn(app, @ClassifierRepositoryMenuSelected, true);
            app.ClassifierRepositoryMenu.Separator = 'on';
            app.ClassifierRepositoryMenu.Text = 'Classifier Repository...';

            % Create ConvertoldtrainingandresultdataMenu
            app.ConvertoldtrainingandresultdataMenu = uimenu(app.FileMenu);
            app.ConvertoldtrainingandresultdataMenu.MenuSelectedFcn = createCallbackFcn(app, @ConvertoldtrainingandresultdataMenuSelected, true);
            app.ConvertoldtrainingandresultdataMenu.Separator = 'on';
            app.ConvertoldtrainingandresultdataMenu.Text = 'Convert old training and result data';

            % Create FunctionsMenu
            app.FunctionsMenu = uimenu(app.DetecDivUIFigure);
            app.FunctionsMenu.Text = 'Functions';

            % Create ClassifyDataMenu
            app.ClassifyDataMenu = uimenu(app.FunctionsMenu);
            app.ClassifyDataMenu.MenuSelectedFcn = createCallbackFcn(app, @ClassifyDataMenuSelected, true);
            app.ClassifyDataMenu.Text = 'Classify Data...';

            % Create ProcessdataMenu
            app.ProcessdataMenu = uimenu(app.FunctionsMenu);
            app.ProcessdataMenu.MenuSelectedFcn = createCallbackFcn(app, @ProcessdataMenuSelected, true);
            app.ProcessdataMenu.Text = 'Process data...';

            % Create ExportdataMenu
            app.ExportdataMenu = uimenu(app.FunctionsMenu);
            app.ExportdataMenu.MenuSelectedFcn = createCallbackFcn(app, @ExportdataMenuSelected, true);
            app.ExportdataMenu.Text = 'Export data...';

            % Create MakeROImoviesMenu
            app.MakeROImoviesMenu = uimenu(app.FunctionsMenu);
            app.MakeROImoviesMenu.MenuSelectedFcn = createCallbackFcn(app, @MakeROImoviesMenuSelected, true);
            app.MakeROImoviesMenu.Text = 'Make ROI movies...';

            % Create ProjectMenu
            app.ProjectMenu = uimenu(app.DetecDivUIFigure);
            app.ProjectMenu.Text = 'Project';

            % Create PositionsMenu
            app.PositionsMenu = uimenu(app.ProjectMenu);
            app.PositionsMenu.Text = 'Positions';

            % Create AddPositionsDataMenu
            app.AddPositionsDataMenu = uimenu(app.PositionsMenu);
            app.AddPositionsDataMenu.MenuSelectedFcn = createCallbackFcn(app, @AddPositionsDataMenuSelected, true);
            app.AddPositionsDataMenu.Text = 'Add Positions (Data)...';

            % Create SetFrameOrientationMenu
            app.SetFrameOrientationMenu = uimenu(app.PositionsMenu);
            app.SetFrameOrientationMenu.MenuSelectedFcn = createCallbackFcn(app, @SetFrameOrientationMenuSelected, true);
            app.SetFrameOrientationMenu.Separator = 'on';
            app.SetFrameOrientationMenu.Text = 'Set Frame Orientation...';

            % Create CreateFullFrameROisMenu
            app.CreateFullFrameROisMenu = uimenu(app.PositionsMenu);
            app.CreateFullFrameROisMenu.MenuSelectedFcn = createCallbackFcn(app, @CreateFullFrameROisMenuSelected, true);
            app.CreateFullFrameROisMenu.Text = 'Create Full Frame ROis...';

            % Create DeleteROIsMenu
            app.DeleteROIsMenu = uimenu(app.PositionsMenu);
            app.DeleteROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @DeleteROIsMenuSelected, true);
            app.DeleteROIsMenu.Text = 'Delete ROIs...';

            % Create AdjustROIsMenu
            app.AdjustROIsMenu = uimenu(app.PositionsMenu);
            app.AdjustROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @AdjustROIsMenuSelected, true);
            app.AdjustROIsMenu.Text = 'Adjust ROIs...';

            % Create DeletePositionsMenu_2
            app.DeletePositionsMenu_2 = uimenu(app.PositionsMenu);
            app.DeletePositionsMenu_2.MenuSelectedFcn = createCallbackFcn(app, @DeletePositionsMenu_2Selected, true);
            app.DeletePositionsMenu_2.Text = 'Delete Positions...';

            % Create RestoredeletedROIsMenu
            app.RestoredeletedROIsMenu = uimenu(app.PositionsMenu);
            app.RestoredeletedROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @RestoredeletedROIsMenuSelected, true);
            app.RestoredeletedROIsMenu.Text = 'Restore deleted ROIs...';

            % Create ClassifiersMenu
            app.ClassifiersMenu = uimenu(app.ProjectMenu);
            app.ClassifiersMenu.Text = 'Classifiers';

            % Create AddclassifierMenu
            app.AddclassifierMenu = uimenu(app.ClassifiersMenu);
            app.AddclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @AddclassifierMenuSelected, true);
            app.AddclassifierMenu.Text = 'Add classifier...';

            % Create DeleteclassifierMenu
            app.DeleteclassifierMenu = uimenu(app.ClassifiersMenu);
            app.DeleteclassifierMenu.MenuSelectedFcn = createCallbackFcn(app, @DeleteclassifierMenuSelected, true);
            app.DeleteclassifierMenu.Text = 'Delete classifier...';

            % Create AdjustROIsMenu_3
            app.AdjustROIsMenu_3 = uimenu(app.ClassifiersMenu);
            app.AdjustROIsMenu_3.MenuSelectedFcn = createCallbackFcn(app, @AdjustROIsMenu_3Selected, true);
            app.AdjustROIsMenu_3.Text = 'Adjust ROIs...';

            % Create DeleteROIsMenu_2
            app.DeleteROIsMenu_2 = uimenu(app.ClassifiersMenu);
            app.DeleteROIsMenu_2.MenuSelectedFcn = createCallbackFcn(app, @DeleteROIsMenu_2Selected, true);
            app.DeleteROIsMenu_2.Text = 'Delete ROIs...';

            % Create RestoredeletedROIsMenu_2
            app.RestoredeletedROIsMenu_2 = uimenu(app.ClassifiersMenu);
            app.RestoredeletedROIsMenu_2.MenuSelectedFcn = createCallbackFcn(app, @RestoredeletedROIsMenu_2Selected, true);
            app.RestoredeletedROIsMenu_2.Text = 'Restore deleted ROIs...';

            % Create AdjustROIsMenu_2
            app.AdjustROIsMenu_2 = uimenu(app.ProjectMenu);
            app.AdjustROIsMenu_2.MenuSelectedFcn = createCallbackFcn(app, @AdjustROIsMenu_2Selected, true);
            app.AdjustROIsMenu_2.Text = 'Adjust ROIs...';

            % Create DisplayMenu
            app.DisplayMenu = uimenu(app.DetecDivUIFigure);
            app.DisplayMenu.Text = 'Display';

            % Create RefreshtreewindowMenu
            app.RefreshtreewindowMenu = uimenu(app.DisplayMenu);
            app.RefreshtreewindowMenu.MenuSelectedFcn = createCallbackFcn(app, @RefreshtreewindowMenuSelected, true);
            app.RefreshtreewindowMenu.Text = 'Refresh tree window';

            % Create SettingsMenu
            app.SettingsMenu = uimenu(app.DetecDivUIFigure);
            app.SettingsMenu.Text = 'Settings';

            % Create UserpreferencesMenu
            app.UserpreferencesMenu = uimenu(app.SettingsMenu);
            app.UserpreferencesMenu.MenuSelectedFcn = createCallbackFcn(app, @UserpreferencesMenuSelected, true);
            app.UserpreferencesMenu.Text = 'User preferences...';

            % Create Tree
            app.Tree = uitree(app.MainGrid);
            app.Tree.SelectionChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
            app.Tree.Tooltip = {'Use left-click to scroll projects and classifiers; Use right-click to open positions and classifiers'};
            app.Tree.Layout.Row = 1;
            app.Tree.Layout.Column = 1;

            % Create ProjectsNode
            app.ProjectsNode = uitreenode(app.Tree);
            app.ProjectsNode.Text = 'Projects';

            % Create IndependentClassifiersNode
            app.IndependentClassifiersNode = uitreenode(app.Tree);
            app.IndependentClassifiersNode.Text = 'Independent Classifiers';

            % Create PipelinesNode
            app.PipelinesNode = uitreenode(app.Tree);
            app.PipelinesNode.Tag = 'PipelinesRoot';
            app.PipelinesNode.Text = 'Pipeline';

            % Create ProjectsPanel
            app.ProjectsPanel = uipanel(app.MainGrid);
            app.ProjectsPanel.Title = 'Projects';
            app.ProjectsPanel.Layout.Row = 1;
            app.ProjectsPanel.Layout.Column = 2;

            % Create UIAxes
            app.UIAxes = uiaxes(app.ProjectsPanel);
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            app.UIAxes.Visible = 'off';
            app.UIAxes.Position = [0 16 417 341];

            % Create AdddataButton
            app.AdddataButton = uibutton(app.ProjectsPanel, 'push');
            app.AdddataButton.ButtonPushedFcn = createCallbackFcn(app, @AdddataButtonPushed, true);
            app.AdddataButton.Icon = 'data.png';
            app.AdddataButton.Visible = 'off';
            app.AdddataButton.Tooltip = {'Open the workflow frontend for data loading, ROI definition and ROI extraction'};
            app.AdddataButton.Position = [20 286 175 40];
            app.AdddataButton.Text = 'Open workflow...';

            % Create AddclassifierButton
            app.AddclassifierButton = uibutton(app.ProjectsPanel, 'push');
            app.AddclassifierButton.ButtonPushedFcn = createCallbackFcn(app, @AddclassifierButtonPushed, true);
            app.AddclassifierButton.Icon = 'brain.png';
            app.AddclassifierButton.Visible = 'off';
            app.AddclassifierButton.Tooltip = {'Creates a new classifier or imports an existing classifier to the project'};
            app.AddclassifierButton.Position = [20 74 175 43];
            app.AddclassifierButton.Text = 'Add classifier...';

            % Create ProjectInformationLabel
            app.ProjectInformationLabel = uilabel(app.ProjectsPanel);
            app.ProjectInformationLabel.VerticalAlignment = 'top';
            app.ProjectInformationLabel.WordWrap = 'on';
            app.ProjectInformationLabel.Position = [8 361 410 240];
            app.ProjectInformationLabel.Text = 'Project Information';

            % Create IdentifyROIsinpositionsButton
            app.IdentifyROIsinpositionsButton = uibutton(app.ProjectsPanel, 'push');
            app.IdentifyROIsinpositionsButton.ButtonPushedFcn = createCallbackFcn(app, @IdentifyROIsinpositionsButtonPushed, true);
            app.IdentifyROIsinpositionsButton.Visible = 'off';
            app.IdentifyROIsinpositionsButton.Tooltip = {'This allows you to use a pattern to identify multiple ROIs automatically. The pattern must be defined in one of the positions'};
            app.IdentifyROIsinpositionsButton.Position = [20 211 385 46];
            app.IdentifyROIsinpositionsButton.Text = 'Define / generate ROIs...';

            % Create ExtractROIhypervolumesButton
            app.ExtractROIhypervolumesButton = uibutton(app.ProjectsPanel, 'push');
            app.ExtractROIhypervolumesButton.ButtonPushedFcn = createCallbackFcn(app, @ExtractROIhypervolumesButtonPushed, true);
            app.ExtractROIhypervolumesButton.Visible = 'off';
            app.ExtractROIhypervolumesButton.Tooltip = {'Generates the ROIs by extracting subimages from raw data and copy them in the project directory. After this step, access to the raw data is no longer necessary'};
            app.ExtractROIhypervolumesButton.Position = [20 153 389 47];
            app.ExtractROIhypervolumesButton.Text = 'Extract ROI hypervolumes...';

            % Create UpdaterawdatapathButton
            app.UpdaterawdatapathButton = uibutton(app.ProjectsPanel, 'push');
            app.UpdaterawdatapathButton.ButtonPushedFcn = createCallbackFcn(app, @UpdaterawdatapathButtonPushed, true);
            app.UpdaterawdatapathButton.Visible = 'off';
            app.UpdaterawdatapathButton.Tooltip = {'Please select the directory that contains  a list of images in your project'};
            app.UpdaterawdatapathButton.Position = [249 284 169 45];
            app.UpdaterawdatapathButton.Text = 'Update raw data path...';

            % Create ClassifydataButton
            app.ClassifydataButton = uibutton(app.ProjectsPanel, 'push');
            app.ClassifydataButton.ButtonPushedFcn = createCallbackFcn(app, @ClassifydataButtonPushed, true);
            app.ClassifydataButton.Icon = 'gears.png';
            app.ClassifydataButton.Visible = 'off';
            app.ClassifydataButton.Tooltip = {'Classifies defined ROIs using a given classifier '};
            app.ClassifydataButton.Position = [20 12 175 43];
            app.ClassifydataButton.Text = 'Classify data...';

            % Create AddprocessorButton
            app.AddprocessorButton = uibutton(app.ProjectsPanel, 'push');
            app.AddprocessorButton.ButtonPushedFcn = createCallbackFcn(app, @AddprocessorButtonPushed, true);
            app.AddprocessorButton.Icon = 'processor.png';
            app.AddprocessorButton.Visible = 'off';
            app.AddprocessorButton.Position = [232 74 151 43];
            app.AddprocessorButton.Text = 'Add processor...';

            % Create ProcessdataButton
            app.ProcessdataButton = uibutton(app.ProjectsPanel, 'push');
            app.ProcessdataButton.ButtonPushedFcn = createCallbackFcn(app, @ProcessdataButtonPushed, true);
            app.ProcessdataButton.Icon = 'gears.png';
            app.ProcessdataButton.Visible = 'off';
            app.ProcessdataButton.Position = [232 12 149 43];
            app.ProcessdataButton.Text = 'Process data...';

            % Create OpenButton
            app.OpenButton = uibutton(app.ProjectsPanel, 'push');
            app.OpenButton.ButtonPushedFcn = createCallbackFcn(app, @OpenButtonPushed, true);
            app.OpenButton.Visible = 'off';
            app.OpenButton.Position = [283 365 134 37];
            app.OpenButton.Text = 'Open';

            % Show the figure after all components are created
            app.DetecDivUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = detecdiv

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.DetecDivUIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.DetecDivUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            if strlength(app.WorkspaceEventListenerId) > 0
                detecdiv_event('unsubscribe', app.WorkspaceEventListenerId);
                app.WorkspaceEventListenerId = "";
            end

            % Delete UIFigure when app is deleted
            delete(app.DetecDivUIFigure)
        end
    end
end
