classdef classi < handle
    properties
        id=[] % number that identifies the classification algo

        typeid=1; % default category for classification found the classilist.mat file in the classification folde
        trainingset=[]; % % list of ROI ids used for training
        trainingParam=[];
        output=0; % type of output : 'one' , or 'sequence' for lstm classification
        path='' %  path where
        strid=''; % string id of the classi object
        description='';
        category={''};
        roi=roi('',[]);
        channel=1;
        channelName='';
        channelName2='';
        classes={}; % names of the classes
        classifyFun='';
        trainingFun='';
        classifierPkg=''; % package folder name (e.g. "cnn_lstm") for standardized dispatch
        colormap=[];
        bounds= struct('Type','Auto','Values',[],'Rules',struct('Dataseries',{[]},'Dataset',{[]},'Value',{[]},'Occurence',[0],'Offset',[0 ])); % type can be : auto,  manual, rules;   'Rules' is a struc that specifies the type of rules : ; 'Values' specifies the automated interval set for all ROIs

        score=[]; %struct('roisid',[],'recall',[],'accuracy',[],'fscore',[],'confusion',[],'classes',[],'rois',[]); %  a structure that stores the scores of the classification , which is done by the stats method

        % only for pixel classification
        outputType=''; % other options are : proba (outputs probabilities of class rather than segmentation), postpocressing (uses a default @post function for postprocessing), segmentation
        outputFun=[];
        outputArg={};
        status=[];
        userData=[];
        runProfiles = struct('train', struct(), 'classify', struct(), 'format', struct());
        dataset = struct('classes', {{}}, 'channels', {{}}, 'split', struct('train', [], 'val', [], 'test', []));


        history=table('Size',[1 3],'VariableTypes',{'datetime','string','string'},'VariableNames',{'Date','Category','Message'});

     run = struct( ...
    'active', false, ...
    'runDir', '', ...
    'runDirAbs', '', ...      % <--- AJOUT
    'consoleFile', '', ...
    'eventsFile', '', ...
    'metaFile', '', ...
    'startTime', [], ...
    'tag', '', ...
    'fun', '' );



        %  inputsize=[]; %size of the network (required for lstm only
    end
    methods
        function obj = classi(path, name, id, varargin)
            % COMPATIBLE AVEC CONSTRUCTEUR HISTORIQUE + EXTENSION TYPE CLASSIFIER

            % ----------------------------
            % 1) Arguments historiques
            % ----------------------------
            if nargin < 1 || isempty(path)
                % ➤ Nouveau comportement : folder courant
                path = pwd;
            end
            if nargin < 2 || isempty(name)
                name = '';
            end
            if nargin < 3 || isempty(id)
                id = 1;
            end

            % ----------------------------
            % 2) Parsing des Name-Value (nouvelle fonctionnalité)
            % ----------------------------
            className  = '';
            classIDReq = [];
            doInit     = true;

            if ~isempty(varargin)
                p = inputParser;
                addParameter(p, 'ClassName',   '',       @(x)ischar(x) || isstring(x));
                addParameter(p, 'ClassID',     [],       @(x)isnumeric(x) || isstring(x));
                addParameter(p, 'InitTraining', true,    @(x)islogical(x) && isscalar(x));
                parse(p, varargin{:});
                opt = p.Results;

                className  = char(opt.ClassName);
                classIDReq = opt.ClassID;
                doInit     = opt.InitTraining;
            end

            % ----------------------------
            % 3) Comportement original : créer le dossier
            % ----------------------------
            obj.path = path;
            obj.id   = id;

            obj.strid    = [name '_' num2str(id)];
            obj.colormap = shallowColormap(1);

            % Création automatique du dossier
            if ~isempty(path)
                if ~exist(path, "dir")
                    mkdir(path);
                end
                targetDir = fullfile(path, obj.strid);
                if ~exist(targetDir, "dir")
                    mkdir(path, obj.strid);
                end
                obj.path = targetDir;
            end

            % ----------------------------
            % 4) Si aucun type demandé → on s'arrête (compatibilité totale)
            % ----------------------------
            if isempty(className) && isempty(classIDReq)
                return;
            end

            % ----------------------------
            % 5) Sinon → enrichissement via classlist.mat
            % ----------------------------
            try
                row = classi.getClasslistRow(className, classIDReq);

                obj.typeid      = row.ID;
                obj.description = row.Description{1};
                obj.category    = classiNormalizeCategory(row.Category{1});

                % Optional package name (preferred for standardized dispatch)
                if istable(row) && ismember('Package', row.Properties.VariableNames)
                    try
                        pkgVal = row.Package{1};
                        if isstring(pkgVal) || ischar(pkgVal)
                            obj.classifierPkg = char(pkgVal);
                        end
                    catch
                    end
                end

                if ~isempty(row.TrainingFun)
                    obj.trainingFun = row.TrainingFun{1};
                end
                if ~isempty(row.ClassificationFun)
                    cf = row.ClassificationFun{1};
                    if ~(isnumeric(cf) && isempty(cf))
                        obj.classifyFun = cf;
                    end
                end

                % Backfill classifierPkg from standardized function names (legacy classlist)
                if isempty(obj.classifierPkg)
                    obj.classifierPkg = localInferPkg(obj.trainingFun, obj.classifyFun);
                end

                % ----------------------------
                % 6) Initialisation trainingParam via trainXXX(classif,1)
                % ----------------------------
                if doInit && ~isempty(obj.trainingFun)
                    try
                        funHandle = str2func(obj.trainingFun);

                        % Appel en "mode init"
                        if any(strcmpi(obj.trainingFun, {'trainImageLSTMNetFun','cnn_lstm.train'}))
                            ctx = struct('mode', 'init');
                            funHandle(obj, ctx);
                        else
                            funHandle(obj, 'init');   % legacy init path
                        end

                        % si un jour certaines fonctions renvoient un objet en plus,
                        % on pourra adapter, mais pour l'instant on ne s'y attend pas.

                    catch ME
                        warning('classi:InitTrainingFailed', ...
                            'Could not init training parameters via %s: %s', ...
                            obj.trainingFun, ME.message);
                    end
                end


            catch ME
                warning('classi:ClasslistError', ...
                    'Error loading classifier type info: %s', ME.message);
            end

            % Keep category format stable across legacy/new objects (1x1 cellstr)
            obj.category = classiNormalizeCategory(obj.category);
        end




        function addTrainingData(obj,list)
            % list is provdided as a an array  FOVid // ROIs : [1 1 1 1; 1 2
            % 3 4 ]
            % HERE add training data

            obj.trainingset=[obj.trainingset list];

            % copy files and ROI objects to training folder

            % update GUI to include classification capabilities
        end
        function [path,file]= getPath(obj)
            %  obj.props.path=pathname;
            % obj.props.name=filename;

            path=obj.path;
            file=obj.strid;
        end
        function obj = setPath(obj,pathe,file)

            %   aa= obj.path

            oldpath=fixpath(obj.path);
            oldfile=obj.strid;

            obj.path=pathe;
    

            for j=1:numel(obj.roi)

                obj.roi(j).path = pathe;
                %     obj.roi(j).path=fixpath(fullfile(obj.roi(j).path));
                %     obj.roi(j).path = replace(obj.roi(j).path,oldfullpath,newpath);

            end

            % --- keep run paths coherent with the new obj.path ---
try
    if isprop(obj,'run')
        % Ensure struct has expected fields (retro-compat)
        if isempty(obj.run) || ~isstruct(obj.run)
            obj.run = struct( ...
                'active', false, ...
                'runDir', '', ...
                'runDirAbs', '', ...
                'consoleFile', '', ...
                'eventsFile', '', ...
                'metaFile', '', ...
                'startTime', [], ...
                'tag', '', ...
                'fun', '' );
        else
            % backfill missing fields
            f = fieldnames(obj.run);
            if ~ismember('active',f),      obj.run.active=false; end
            if ~ismember('runDir',f),      obj.run.runDir=''; end
            if ~ismember('runDirAbs',f),   obj.run.runDirAbs=''; end
            if ~ismember('consoleFile',f), obj.run.consoleFile=''; end
            if ~ismember('eventsFile',f),  obj.run.eventsFile=''; end
            if ~ismember('metaFile',f),    obj.run.metaFile=''; end
            if ~ismember('startTime',f),   obj.run.startTime=[]; end
            if ~ismember('tag',f),         obj.run.tag=''; end
            if ~ismember('fun',f),         obj.run.fun=''; end
        end

        % After moving path, the run cannot be considered active safely
        obj.run.active = false;

        % Normalize: ABS->REL by cutting before "/runs/", then rebuild runDirAbs from obj.path
        obj.runNormalizePaths();
    end
catch
end



            function pathout=fixpath(pathin)
                pathout=pathin;
                if ~ispc

                    pathout(strfind(pathout,'\'))='/';

                else

                    pix=strfind(pathout,'\\');

                    if numel(pix)
                        pathout=pathout(pix+1:end);
                    end

                    pathout(strfind(pathout,'/'))='\';
                end
            end

        end

        function disp(obj)
            % Custom display for classi objects

            % ===== CASE 1: ARRAY OF CLASSI =====
            if numel(obj) > 1
                nC = numel(obj);
                fprintf('classi objects (%d):\n', nC);

                % header
                fprintf('    %-4s %-22s %-12s %-6s %-s\n', ...
                    'Idx', 'Name', 'Category', '#ROI', 'Path');

                for k = 1:nC
                    c = obj(k);

                    % Name (strid if possible)
                    cName = '';
                    if isprop(c,'strid') && ~isempty(c.strid)
                        cName = strsafe(c.strid);
                    elseif isprop(c,'id')
                        cName = ['class_' strsafe(num2str(c.id))];
                    else
                        cName = ['classif_' num2str(k)];
                    end

                    % Category
                    cCat = '';
                    if isprop(c,'category') && ~isempty(c.category)
                        cCat = strsafe(c.category);
                    end

                    % #ROI
                    nRoiC = 0;
                    if isprop(c,'roi') && ~isempty(c.roi)
                        try
                            nRoiC = numel(c.roi);
                        catch
                        end
                    end

                    % Path (shortened a bit for readability)
                    pth = '';
                    if isprop(c,'path') && ~isempty(c.path)
                        pth = strsafe(c.path);
                    end

                    fprintf('    %-4d %-22s %-12s %-6d %-s\n', ...
                        k, cName, cCat, nRoiC, pth);
                end

                return; % important: ne pas afficher la version détaillée après
            end

            % ===== CASE 2: SINGLE CLASSI OBJECT =====
            c = obj; % alias

            fprintf('==============================\n');
            fprintf('  Classification object\n');
            fprintf('==============================\n');

            % --- Identification
            fprintf('ID        : %s\n', num2str(c.id));

            fprintf('String ID : %s\n', strsafe(c.strid));

            catStr = strsafe(c.category);
            if ~isempty(catStr)
                fprintf('Category  : %s\n', catStr);
            end

            descStr = strsafe(c.description);
            if ~isempty(descStr)
                fprintf('Desc.     : %s\n', descStr);
            end

            fprintf('\n');

            % --- Path
            fprintf('Path      : %s\n', strsafe(c.path));
            fprintf('\n');

            % --- Type & channels
            fprintf('Type ID   : %s\n', num2str(c.typeid));

            % channel line, incl. channelName / channelName2 if available
            chanLine = sprintf('%d', c.channel);
            ch1 = strsafe(c.channelName);
            ch2 = strsafe(c.channelName2);
            if ~isempty(ch1)
                chanLine = [chanLine ' (' ch1 ')'];
            end
            if ~isempty(ch2)
                chanLine = [chanLine ' / ' ch2];
            end
            fprintf('Channel   : %s\n', chanLine);

            % --- Functions
            if ~isempty(c.classifierPkg)
                fprintf('Classifier pkg : %s\n', strsafe(c.classifierPkg));
            end
            if ~isempty(c.classifyFun)
                fprintf('Classify fun : %s\n', fun2char(c.classifyFun));
            end
            if ~isempty(c.trainingFun)
                fprintf('Training fun : %s\n', fun2char(c.trainingFun));
            end

            fprintf('\n');

            % --- Classes
            if ~isempty(c.classes)
                classNames = c.classes;
                if isstring(classNames)
                    classNames = cellstr(classNames);
                end
                if ischar(classNames)
                    classNames = {classNames};
                end
                if iscell(classNames)
                    flatNames = strjoin(cellfun(@strsafe, classNames, 'UniformOutput', false), ', ');
                    fprintf('Classes (%d): %s\n', numel(classNames), flatNames);
                else
                    fprintf('Classes : [unhandled format]\n');
                end
            else
                fprintf('Classes : none defined\n');
            end

            fprintf('\n');

            % --- Associated data
            nRoi = 0;
            if ~isempty(c.roi)
                nRoi = numel(c.roi);
            end
            nTrain = 0;
            if ~isempty(c.trainingset)
                nTrain = numel(c.trainingset);
            end

            fprintf('Associated data:\n');
            fprintf('  • %d ROI(s)\n', nRoi);
            fprintf('  • %d training sample(s)\n', nTrain);

            % --- Scores summary (optional block like before)
            if ~isempty(c.score) && isstruct(c.score)
                fieldsToShow = {'recall','accuracy','fscore'};
                f = intersect(fieldsToShow, fieldnames(c.score));
                if ~isempty(f)
                    fprintf('\nScores:\n');
                    for kk = 1:numel(f)
                        val = c.score.(f{kk});
                        if isnumeric(val)
                            m = mean(val(:), 'omitnan');
                            fprintf('  %s : %.3f\n', f{kk}, m);
                        elseif iscell(val) && ~isempty(val) && isnumeric(val{1})
                            m = mean(val{1}(:), 'omitnan');
                            fprintf('  %s : %.3f\n', f{kk}, m);
                        else
                            fprintf('  %s : %s\n', f{kk}, strsafe(val));
                        end
                    end
                end
            end

            fprintf('==============================\n');

            % ===== helpers =====
            function out = strsafe(x)
                if isempty(x)
                    out = '';
                elseif ischar(x)
                    out = x;
                elseif isstring(x)
                    x = x(:);
                    out = strjoin(cellstr(x), ', ');
                elseif iscell(x)
                    try
                        out = strjoin(cellfun(@strsafe, x, 'UniformOutput', false), ', ');
                    catch
                        out = '[cell]';
                    end
                elseif isnumeric(x)
                    out = num2str(x);
                else
                    out = class(x);
                end
            end

            function out = fun2char(f)
                if isa(f,'function_handle')
                    out = func2str(f);
                elseif ischar(f)
                    out = f;
                elseif isstring(f)
                    out = char(f);
                else
                    out = '[unknown function spec]';
                end
            end

            function pkg = localInferPkg(trainFun, classifyFun)
                pkg = '';
                f = '';
                if ~isempty(trainFun)
                    f = trainFun;
                elseif ~isempty(classifyFun)
                    f = classifyFun;
                end
                if isempty(f), return; end
                if isa(f,'function_handle')
                    f = func2str(f);
                end
                if isstring(f), f = char(f); end
                dot = strfind(f, '.');
                if ~isempty(dot)
                    pkg = f(1:dot(1)-1);
                    return;
                end

                % Legacy mappings (no dot)
                if any(strcmp(f, {'trainImageLSTMNetFun','classifyImageLSTMNetFun'}))
                    pkg = 'cnn_lstm';
            elseif any(strcmp(f, {'trainImageGoogleNetFun','classifyImageGoogleNetFun'}))
                pkg = 'cnn';
            elseif any(strcmp(f, {'trainCPSAMFun','classifyCPSAMFun'}))
                pkg = 'cellposesam';
            end
            end
        end

        function ctx = buildCtx(obj, kind, overrides)
            % buildCtx  Merge persisted runProfiles with explicit overrides.
            %
            % kind: 'train' | 'classify' | 'format'
            if nargin < 3 || isempty(overrides), overrides = struct(); end
            if nargin < 2 || isempty(kind), kind = ''; end

            base = struct();
            try
                if isprop(obj,'runProfiles') && isstruct(obj.runProfiles)
                    if isfield(obj.runProfiles, kind)
                        base = obj.runProfiles.(kind);
                    end
                end
            catch
            end

            ctx = obj.localMergeStruct(base, overrides);
        end

        function syncDatasetFromLegacy(obj)
            % syncDatasetFromLegacy  Populate dataset.* from legacy fields.
            if ~isprop(obj,'dataset') || ~isstruct(obj.dataset)
                obj.dataset = struct('classes', {{}}, 'channels', {{}}, ...
                    'split', struct('train', [], 'val', [], 'test', []));
            end

            if ~isfield(obj.dataset,'classes') || isempty(obj.dataset.classes)
                obj.dataset.classes = obj.classes;
            end
            if ~isfield(obj.dataset,'channels') || isempty(obj.dataset.channels)
                obj.dataset.channels = obj.channelName;
            end
            if ~isfield(obj.dataset,'split') || ~isstruct(obj.dataset.split)
                obj.dataset.split = struct('train', [], 'val', [], 'test', []);
            end
            if ~isfield(obj.dataset.split,'train') || isempty(obj.dataset.split.train)
                obj.dataset.split.train = obj.trainingset;
            end
            if ~isfield(obj.dataset.split,'val')
                obj.dataset.split.val = [];
            end
            if ~isfield(obj.dataset.split,'test')
                obj.dataset.split.test = [];
            end
        end

        function syncLegacyFromDataset(obj)
            % syncLegacyFromDataset  Update legacy fields from dataset.*.
            if ~isprop(obj,'dataset') || ~isstruct(obj.dataset)
                return;
            end

            if isfield(obj.dataset,'classes') && ~isempty(obj.dataset.classes)
                obj.classes = obj.dataset.classes;
            end
            if isfield(obj.dataset,'channels') && ~isempty(obj.dataset.channels)
                obj.channelName = obj.dataset.channels;
            end
            if isfield(obj.dataset,'split') && isstruct(obj.dataset.split)
                if isfield(obj.dataset.split,'train') && ~isempty(obj.dataset.split.train)
                    obj.trainingset = obj.dataset.split.train;
                end
            end
        end

        function ch = getInputChannels(obj)
            % getInputChannels  Preferred input channels for training/classify.
            ch = [];
            if isprop(obj,'dataset') && isstruct(obj.dataset) && ...
                    isfield(obj.dataset,'channels') && ~isempty(obj.dataset.channels)
                ch = obj.dataset.channels;
                return;
            end
            ch = obj.channelName;
        end


        function L = runStart(obj, funName, trainingParam, varargin)
% runStart  Start (or attach to) a run folder under <obj.path>/runs
% - obj.run.runDir    : RELATIVE path (portable)     e.g. "runs\2025..._strid_tag_fun"
% - obj.run.runDirAbs : ABSOLUTE local path          e.g. "C:\...\<obj.path>\runs\..."
%
% Options:
%   'Tag'    : string/char tag added to folder name
%   'Attach' : true -> reuse current run if active

if nargin < 3, trainingParam = []; end

p = inputParser;
addParameter(p,'Tag','',@(x)ischar(x)||isstring(x));
addParameter(p,'Attach',false,@(x)islogical(x)||isnumeric(x));
parse(p,varargin{:});

tag    = char(p.Results.Tag);
attach = logical(p.Results.Attach);

% Ensure run struct exists (defensive)
if ~isprop(obj,'run') || isempty(obj.run) || ~isstruct(obj.run)
    obj.run = struct( ...
        'active', false, ...
        'runDir', '', ...
        'runDirAbs', '', ...
        'consoleFile', '', ...
        'eventsFile', '', ...
        'metaFile', '', ...
        'startTime', [], ...
        'tag', '', ...
        'fun', '' );
end

% Attach: reuse active run
if attach && isfield(obj.run,'active') && isequal(obj.run.active,true)
    try
        obj.localAppendRunEvent(sprintf('RUN ATTACH fun=%s tag=%s', char(funName), tag));
        obj.runMsg('AttachRun: using existing runDir=%s', obj.run.runDir);
    catch
    end
    if nargout, L = obj.run; end
    return;
end

% Idempotent: if already active, do not create a new folder
if isfield(obj.run,'active') && isequal(obj.run.active,true)
    try
        obj.localAppendRunEvent(sprintf('RUN START SKIP (already active) fun=%s tag=%s', char(funName), tag));
        obj.runMsg('runStart skipped (already active). fun=%s', char(funName));
    catch
    end
    if nargout, L = obj.run; end
    return;
end

% ---- base (REL + ABS) ----
baseRel = 'runs';
baseAbs = fullfile(obj.path, baseRel);
if ~exist(baseAbs,'dir'); mkdir(baseAbs); end

% timestamp with milliseconds
ts = datestr(now,'yyyymmdd_HHMMSS_FFF');

safeStrid = regexprep(string(obj.strid), '[^\w\-]', '_');
safeFun   = regexprep(string(funName),   '[^\w\-]', '_');
safeTag   = regexprep(string(tag),       '[^\w\-]', '_');

if strlength(safeTag) > 0
    runFolder = sprintf('%s_%s_%s_%s', ts, safeStrid, safeTag, safeFun);
else
    runFolder = sprintf('%s_%s_%s', ts, safeStrid, safeFun);
end

runDirRel = fullfile(baseRel, runFolder);     % "runs\xxxx"
runDirAbs = fullfile(obj.path, runDirRel);    % "<obj.path>\runs\xxxx"
if ~exist(runDirAbs,'dir'); mkdir(runDirAbs); end

% Stop previous diary if any
try, diary off; catch, end

% Console diary (ABS)
consoleAbs = fullfile(runDirAbs,'console.log');
try, diary(consoleAbs); catch, end

% Update run state
obj.run.active    = true;
obj.run.runDir    = char(runDirRel);
obj.run.runDirAbs = char(runDirAbs);

% Store REL paths for portability
obj.run.consoleFile = char(fullfile(runDirRel,'console.log'));
obj.run.eventsFile  = char(fullfile(runDirRel,'events.log'));
obj.run.metaFile    = char(fullfile(runDirRel,'run.json'));

obj.run.startTime = datetime('now');
obj.run.tag       = tag;
obj.run.fun       = char(safeFun);

% Meta json (write to ABS, but meta stores REL)
try
    meta = obj.localCollectRunMeta(funName, trainingParam, runDirRel, tag);
    obj.localWriteJson(fullfile(runDirAbs,'run.json'), meta);
catch
end

% Snapshot trainingParam
if ~isempty(trainingParam)
    try
        save(fullfile(runDirAbs,'trainingParam.mat'),'trainingParam','-v7.3');
    catch
    end
end

% Log start
try
    obj.localAppendRunEvent(sprintf('RUN START dirRel=%s dirAbs=%s', char(runDirRel), char(runDirAbs)));
catch
end

if nargout, L = obj.run; end
end



        function runMsg(obj, fmt, varargin)
            % runMsg  Append a timestamped message into events.log
            if ~obj.localRunIsActive(), return; end

            if nargin < 2 || isempty(fmt), return; end
            if isempty(varargin)
                txt = sprintf('%s', fmt);
            else
                txt = sprintf(fmt, varargin{:});
            end
            obj.localAppendRunEvent(txt);
        end


        function runSave(obj, fileName, varargin)
            % runSave  Save name/value pairs into MAT in runDir.
            %
            % obj.runSave('stuff.mat', 'var1', var1, 'var2', var2, ...)
            if ~obj.localRunIsActive(), return; end
            if nargin < 2 || isempty(fileName), return; end

            S = struct();
            for k = 1:2:numel(varargin)
                if k+1 > numel(varargin), break; end
                key = varargin{k};
                val = varargin{k+1};
                if ~(ischar(key) || isstring(key)), continue; end
                S.(char(key)) = val;
            end

            runDirAbs = obj.localGetRunDirAbs();
            fp = fullfile(runDirAbs, fileName);
            try
                save(fp,'-struct','S','-v7.3');
                obj.localAppendRunEvent(sprintf('Saved MAT: %s', fp));
            catch ME
                obj.localAppendRunEvent(sprintf('WARN runSave failed: %s (%s)', fp, ME.message));
            end
        end


        function runSaveStruct(obj, fileName, S)
            % runSaveStruct  Save a struct/object snapshot as variable "obj"
            if ~obj.localRunIsActive(), return; end
            if nargin < 2 || isempty(fileName), return; end

            runDirAbs = obj.localGetRunDirAbs();
            fp = fullfile(runDirAbs, fileName);
            try
                obj2 = S; %#ok<NASGU>
                save(fp,'obj2','-v7.3');
                obj.localAppendRunEvent(sprintf('Saved MAT struct: %s', fp));
            catch ME
                obj.localAppendRunEvent(sprintf('WARN runSaveStruct failed: %s (%s)', fp, ME.message));
            end
        end


        function runJson(obj, fileName, S)
            % runJson  Save struct as JSON into runDir
            if ~obj.localRunIsActive(), return; end
            if nargin < 2 || isempty(fileName), return; end

            runDirAbs = obj.localGetRunDirAbs();
            fp = fullfile(runDirAbs, fileName);

            try
                obj.localWriteJson(fp, S);
                obj.localAppendRunEvent(sprintf('Saved JSON: %s', fp));
            catch ME
                obj.localAppendRunEvent(sprintf('WARN runJson failed: %s (%s)', fp, ME.message));
            end
        end


        function copied = runCopyArtifacts(obj, varargin)
            % runCopyArtifacts  Copy key classifier artifacts into the active run folder.
            %
            % copied = obj.runCopyArtifacts('ExtraFiles', {"/abs/path/other.mat", ...});

            p = inputParser;
            addParameter(p,'ExtraFiles',{},@(x) iscell(x) || isstring(x) || ischar(x));
            parse(p,varargin{:});

            if nargout
                copied = strings(0,1);
            else
                copied = [];
            end

            if ~obj.localRunIsActive(), return; end

            runDir = obj.localGetRunDirAbs();
if ~(ischar(runDir) || isstring(runDir)) || strlength(string(runDir))==0
    return;
end
runDir = char(runDir);
if ~exist(runDir,'dir')
    try, mkdir(runDir); catch, return; end
end

            sid  = '';
            base = '';
            try, sid = char(string(obj.strid)); catch, sid = ''; end
            try, base = char(string(obj.path)); catch, base = ''; end

            candidates = strings(0,1);
            if ~isempty(base)
                if ~isempty(sid)
                    candidates(end+1) = fullfile(base, sprintf('%s_classification.mat', sid)); %#ok<AGROW>
                    candidates(end+1) = fullfile(base, sprintf('%s.mat', sid)); %#ok<AGROW>
                    candidates(end+1) = fullfile(base, sprintf('netCNN_%s.mat', sid)); %#ok<AGROW>
                    candidates(end+1) = fullfile(base, sprintf('netLSTM_%s.mat', sid)); %#ok<AGROW>
                end
                candidates(end+1) = fullfile(base, 'netCNN.mat'); %#ok<AGROW>
                candidates(end+1) = fullfile(base, 'netLSTM.mat'); %#ok<AGROW>
            end

            % --- normalize ExtraFiles to string column ---
extra = p.Results.ExtraFiles;

if isempty(extra)
    extra = strings(0,1);
elseif ischar(extra) || isstring(extra)
    extra = string(extra(:));
elseif iscell(extra)
    extra = string(extra(:));
else
    extra = strings(0,1);
end

% force column + remove empties
extra = extra(:);
extra = extra(strlength(extra) > 0);

% concatenate safely
candidates = unique([candidates(:); extra]);

            candidates = candidates(strlength(candidates) > 0);

            copiedLocal = strings(0,1);

            for i = 1:numel(candidates)
                src = char(candidates(i));
                if exist(src,'file') ~= 2
                    continue;
                end

                [~, name, ext] = fileparts(src);
                dst = fullfile(runDir, [name ext]);

                try
                    copyfile(src, dst);
                    copiedLocal(end+1) = string(dst); %#ok<AGROW>
                    obj.runMsg('Copied artifact: %s', dst);
                catch ME
                    obj.runMsg('WARN copy artifact failed: %s (%s)', src, ME.message);
                end
            end

            if nargout
                copied = copiedLocal;
            end
        end


     function runStop(obj)
% runStop  Stop diary and close the run.

% Robust guard if obj.run or obj.run.active does not exist
isActive = false;
try
    isActive = isstruct(obj.run) && isfield(obj.run,'active') && isequal(obj.run.active,true);
catch
    isActive = false;
end

% Always try to stop diary (avoid nested diaries)
try, diary off; catch, end

if ~isActive
    return
end

try
    obj.localAppendRunEvent('RUN STOP');
catch
end

obj.run.active = false;
end



        function L = runGet(obj)
            % runGet  Returns current run state (even if inactive)
            L = obj.run;
        end


      function runNormalizePaths(obj)
% runNormalizePaths  Force obj.run.* paths to be REL to obj.path, keep runDirAbs ABS.
% Handles Windows paths, UNC, and Linux/WSL paths (starting with "/").

try
    if ~isprop(obj,'run') || isempty(obj.run) || ~isstruct(obj.run)
        return;
    end

    baseAbs = char(string(obj.path));

    % ---- helpers ----
    toChar = @(x) char(string(x));
    normSep = @(p) strrep(strrep(toChar(p),'\','/'),'//','/');

    isAbsAny = @(p) localIsAbsAny_(toChar(p));

    % Extract "runs/<suffix>" from any absolute path that contains ".../runs/<suffix>"
    extractRunsRel = @(p) localExtractRunsRel_(toChar(p));

    % Ensure rel starts with "runs"
    ensureRunsPrefix = @(rel) localEnsureRunsPrefix_(toChar(rel));

    % --------------------------------
    % 1) normalize runDir -> REL
    % --------------------------------
    if isfield(obj.run,'runDir') && ~isempty(obj.run.runDir)
        rd = toChar(obj.run.runDir);

        if isAbsAny(rd)
            rel = extractRunsRel(rd);
            if isempty(rel)
                % If it's inside obj.path, relativize to obj.path
                rdN = normSep(rd);
                baseN = normSep(baseAbs);
                if startsWith(rdN, baseN)
                    rel = rdN(numel(baseN)+2:end);
                else
                    % last resort: keep leaf folder name under runs
                    [~,name] = fileparts(rd);
                    rel = fullfile('runs', name);
                end
            end
            obj.run.runDir = ensureRunsPrefix(rel);
        else
            obj.run.runDir = ensureRunsPrefix(rd);
        end
    end

    % --------------------------------
    % 2) rebuild runDirAbs from REL
    % --------------------------------
    if isfield(obj.run,'runDir') && ~isempty(obj.run.runDir)
        runDirRel = toChar(obj.run.runDir);
        candAbs = fullfile(baseAbs, runDirRel);

        % Prefer the reconstructed one if it exists OR if current runDirAbs is empty/bad
        curAbs = '';
        if isfield(obj.run,'runDirAbs') && ~isempty(obj.run.runDirAbs)
            curAbs = toChar(obj.run.runDirAbs);
        end

        curAbsN = normSep(curAbs);
        baseN   = normSep(baseAbs);
        candAbsN = normSep(candAbs);

        curLooksValid = ~isempty(curAbs) && (exist(curAbs,'dir')==7) && startsWith(curAbsN, baseN);
        candLooksValid = (exist(candAbs,'dir')==7) || startsWith(candAbsN, baseN);

        if ~curLooksValid && candLooksValid
            obj.run.runDirAbs = candAbs;
        elseif isempty(curAbs) && candLooksValid
            obj.run.runDirAbs = candAbs;
        elseif ~curLooksValid && ~isempty(candAbs)
            % even if folder doesn't exist yet, keep it coherent relative to obj.path
            obj.run.runDirAbs = candAbs;
        end
    end

    % --------------------------------
    % 3) normalize file fields -> REL
    % --------------------------------
    fileFields = {'consoleFile','eventsFile','metaFile'};
    for i = 1:numel(fileFields)
        ff = fileFields{i};
        if ~isfield(obj.run,ff) || isempty(obj.run.(ff)), continue; end

        fp = toChar(obj.run.(ff));
        if isAbsAny(fp)
            rel = extractRunsRel(fp);
            if isempty(rel)
                % inside obj.path?
                fpN = normSep(fp);
                baseN = normSep(baseAbs);
                if startsWith(fpN, baseN)
                    rel = fpN(numel(baseN)+2:end);
                else
                    % fallback: put it under runDir
                    if isfield(obj.run,'runDir') && ~isempty(obj.run.runDir)
                        [~,name,ext] = fileparts(fp);
                        rel = fullfile(toChar(obj.run.runDir), [name ext]);
                    else
                        rel = ''; % give up
                    end
                end
            end
            if ~isempty(rel)
                obj.run.(ff) = ensureRunsPrefix(rel);
            end
        else
            obj.run.(ff) = ensureRunsPrefix(fp);
        end
    end

catch
end

    % ===== local helpers =====
    function tf = localIsAbsAny_(p)
        p = char(string(p));
        if isempty(p), tf = false; return; end
        % Windows drive
        if ~isempty(regexp(p,'^[A-Za-z]:[\\/]', 'once')), tf = true; return; end
        % UNC
        if startsWith(p,'\\'), tf = true; return; end
        % Linux/WSL absolute
        if startsWith(p,'/'), tf = true; return; end
        % Tilde home
        if startsWith(p,'~'), tf = true; return; end
        tf = false;
    end

    function rel = localExtractRunsRel_(p)
        rel = '';
        pN = normSep(p);
        % Find last occurrence of "/runs/"
        k = strfind(pN, '/runs/');
        if isempty(k)
            % also tolerate ending with "/runs"
            k2 = strfind(pN, '/runs');
            if ~isempty(k2) && (k2(end)+4 == strlength(string(pN)))
                rel = 'runs';
            end
            return;
        end
        suffix = pN(k(end)+6:end); % after "/runs/"
        if isempty(suffix)
            rel = 'runs';
        else
            rel = fullfile('runs', suffix);
        end
    end

    function rel2 = localEnsureRunsPrefix_(rel)
        rel = char(string(rel));
        if isempty(rel), rel2 = rel; return; end
        relN = normSep(rel);
        if startsWith(relN,'runs/')
            rel2 = rel;
        elseif strcmp(relN,'runs')
            rel2 = 'runs';
        else
            rel2 = fullfile('runs', rel);
        end
    end
end
  
  
    end
  

    methods (Access = private)

        function out = localMergeStruct(~, base, override)
            % Recursive struct merge: override wins, but merges nested structs.
            out = base;
            if ~isstruct(out), out = struct(); end
            if ~isstruct(override), return; end

            f = fieldnames(override);
            for i = 1:numel(f)
                k = f{i};
                v = override.(k);
                if isstruct(v) && isfield(out, k) && isstruct(out.(k))
                    out.(k) = localMergeStruct([], out.(k), v);
                else
                    out.(k) = v;
                end
            end
        end

        function p = localGetRunDirAbs(obj)
% Always return absolute run directory (or '')

p = '';
try
    if ~isprop(obj,'run') || isempty(obj.run), return; end
    r = obj.run;

    % Prefer runDirAbs if present
    if isstruct(r) && isfield(r,'runDirAbs') && strlength(string(r.runDirAbs))>0
        p = char(string(r.runDirAbs));
        return;
    end

    % Else build from relative runDir
    % Else build from relative runDir (ensure it's really relative)
if isstruct(r) && isfield(r,'runDir') && strlength(string(r.runDir))>0
    rd = char(string(r.runDir));

    if ispc
        isAbs = ~isempty(regexp(rd,'^[A-Za-z]:[\\/]', 'once')) || startsWith(rd,'\\');
    else
        isAbs = startsWith(rd,'/');
    end

    if isAbs
        p = rd;               % accept as-is (best effort)
    else
        p = fullfile(obj.path, rd);
    end
    return;
end

catch
    p = '';
end
end


        function row = getClasslistRow(~, className, classIDReq)
            % getClasslistRow  Renvoie la ligne correspondante de classlist.mat

            % On part du principe que @classi est dans .../classification/@classi
            thisFile   = mfilename('fullpath');
            thisFolder = fileparts(thisFile);         % .../@classi
            classDir   = fileparts(thisFolder);       % .../classification
            clFile     = fullfile(classDir, ['classification/','classlist.mat']);

            if ~exist(clFile, 'file')
                error('classi:getClasslistRow:NoClasslist', ...
                    'classlist.mat not found at %s', clFile);
            end

            S = load(clFile, 'classlist');
            classlist = S.classlist;

            idx = [];

            % 1) priorité à ClassID
            if ~isempty(classIDReq)
                if isstring(classIDReq)
                    classIDReq = str2double(classIDReq);
                end
                idx = find(classlist.ID == classIDReq, 1);
                if isempty(idx)
                    error('Unknown ClassID = %d in classlist', classIDReq);
                end
            end

            % 2) sinon, ClassName
            if isempty(idx) && ~isempty(className)
                nameList = classlist.Name;
                mask = strcmp(nameList, className);
                idx = find(mask, 1);
                if isempty(idx)
                    error('Unknown ClassName "%s" in classlist', className);
                end
            end

            % 3) fallback de sécurité (ex. ID 1)
            if isempty(idx)
                idx = find(classlist.ID == 1, 1);
            end

            row = classlist(idx,:);
        end

      function tf = localRunIsActive(obj)
% localRunIsActive  Robust check for active run (struct OR object)

tf = false;

% 1) obj must have a property "run"
if ~isprop(obj,'run') || isempty(obj.run)
    return;
end

r = obj.run;

try
    % --- case 1: run is a struct ---
    if isstruct(r)
        if isfield(r,'active') && r.active
            tf = true;
        end

    % --- case 2: run is an object ---
    elseif isobject(r)
        if isprop(r,'active') && r.active
            tf = true;
        elseif ismethod(r,'isActive')
            tf = r.isActive();
        end
    end
catch
    tf = false;
end
end


       function localAppendRunEvent(obj, msg)
% Append one line to events.log in the active run folder (ABS if possible)

try
    if ~isprop(obj,'run') || isempty(obj.run) || ~isstruct(obj.run)
        return;
    end

    % Resolve events.log absolute path
    fp = '';
    if isfield(obj.run,'runDirAbs') && ~isempty(obj.run.runDirAbs)
        fp = fullfile(char(obj.run.runDirAbs), 'events.log');
    elseif isfield(obj.run,'eventsFile') && ~isempty(obj.run.eventsFile)
        fp = fullfile(obj.path, char(obj.run.eventsFile)); % eventsFile is REL
    elseif isfield(obj.run,'runDir') && ~isempty(obj.run.runDir)
        fp = fullfile(obj.path, char(obj.run.runDir), 'events.log');
    else
        return;
    end

    % Ensure folder exists
    d = fileparts(fp);
    if ~exist(d,'dir'); mkdir(d); end

    fid = fopen(fp,'a');
    if fid < 0, return; end
    fprintf(fid,'[%s] %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'), msg);
    fclose(fid);

catch
    try, fclose(fid); catch, end %#ok<TRYNC>
end
end


        function meta = localCollectRunMeta(obj, funName, trainingParam, runDir, tag)
            meta = struct();
            meta.timestamp = char(datetime('now'));
            meta.runDir    = runDir;
            meta.strid     = obj.strid;
            meta.path      = obj.path;
            meta.fun       = funName;
            meta.tag       = tag;

            meta.matlab = struct();
            meta.matlab.version = version;
            meta.matlab.release = version('-release');
            meta.matlab.java    = version('-java');

            meta.system = struct();
            try
                meta.system.computer = computer;
                meta.system.arch     = computer('arch');
                meta.system.ispc     = ispc;
                meta.system.ismac    = ismac;
                meta.system.isunix   = isunix;
            catch
            end

            meta.gpu = struct();
            try
                g = gpuDevice;
                meta.gpu.name = g.Name;
                meta.gpu.computeCapability = g.ComputeCapability;
                meta.gpu.totalMemoryGB = double(g.TotalMemory)/1e9;
                meta.gpu.driverVersion = g.DriverVersion;
            catch
                meta.gpu = [];
            end

            meta.rng = struct();
            try
                r = rng;
                meta.rng.type = r.Type;
                meta.rng.seed = r.Seed;
            catch
            end

            % Git (best-effort)
            [ok, git] = obj.localGitInfo(obj.path);
            if ok
                meta.git = git;
            else
                meta.git = [];
            end

            % Light snapshot of trainingParam (may be big; still useful)
            try
                meta.trainingParam = trainingParam;
            catch
            end
        end

        function [ok, git] = localGitInfo(obj, repoPath) %#ok<INUSL>
            ok = false;
            git = struct('commit','', 'branch','', 'status','');
            try
                [s1, out1] = system(sprintf('cd "%s" && git rev-parse HEAD', repoPath));
                [s2, out2] = system(sprintf('cd "%s" && git rev-parse --abbrev-ref HEAD', repoPath));
                [s3, out3] = system(sprintf('cd "%s" && git status --porcelain', repoPath));
                if s1==0
                    git.commit = strtrim(out1);
                    git.branch = strtrim(out2);
                    git.status = strtrim(out3);
                    ok = true;
                end
            catch
            end
        end

        function localWriteJson(obj, fp, S) %#ok<INUSL>
            txt = jsonencode(S);
            % "pretty-ish"
            txt = regexprep(txt, ',"', sprintf(',\n"'));
            fid = fopen(fp,'w');
            if fid<0, return; end
            fwrite(fid, txt, 'char');
            fclose(fid);
        end


    end
end
