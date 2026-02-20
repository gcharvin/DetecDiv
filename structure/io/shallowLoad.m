function [shallowObj, msg] = shallowLoad(filename)

if nargin == 0
    [file, path] = uigetfile('*.mat', 'Select a shallow project', pwd);
    if isequal(file, 0)
        disp('User selected Cancel');
        msg = [];
        shallowObj = [];
        return;
    else
        disp(['User selected ', fullfile(path, file)]);
        filename = fullfile(path, file);
    end
end

[pathstr, namestr, ext] = fileparts(filename);
if isempty(ext)
    ext = '.mat';
end
filename = fullfile(pathstr, [namestr ext]);

if ~isfile(filename)
    msg = ['Fichier introuvable : ' filename];
    disp(msg);
    shallowObj = [];
    return;
end
file = namestr;
path = pathstr;

% Vérifier que le dossier associé au projet existe
projectFolder = fullfile(path, file);
if ~isfolder(projectFolder)
    msg = ['The folder "' projectFolder '" does not exsit. The project is incomplete... Quitting!'];
    disp(msg);
    shallowObj = [];
    return;
end

load(filename);

if ~exist('shallowObj', 'var')
    disp('this is not a shallow object ! Quitting....');
    msg = ['Wrong file name loaded'];
    shallowObj = [];
    return;
end

if ~isfield(shallowObj.processing, 'processor')
    shallowObj.processing.processor = process.empty;
end

if isunix || ismac
    shallowObj.setPath([path '/'], file);
else
    shallowObj.setPath([path '\'], file);
end

% éviter de charger 2x le même projet dans le workspace
normalizePathClean = @(p) regexprep(lower(strrep(p, '\', '/')), '/+$', '');
expectedPath = normalizePathClean(path);
expectedFile = lower(file);

varlist = evalin('base', 'who');
for i = 1:numel(varlist)
    varName = varlist{i};
    if strcmp(varName, 'ans'), continue; end

    try
        tmp = evalin('base', varName);
    catch
        continue;
    end

    if isa(tmp, 'shallow') && isprop(tmp, 'io') && isfield(tmp.io, 'path') && isfield(tmp.io, 'file')
        tmpPath = normalizePathClean(tmp.io.path);
        tmpFile = lower(tmp.io.file);

        if strcmp(tmpPath, expectedPath) && strcmp(tmpFile, expectedFile)
            msg = ['Project is already in the workspace under the var name: ' varName '; Quitting...'];
            disp(msg);
            shallowObj = tmp;
            return;
        end
    end
end

msg = ['Successfully loaded shallow project ' fullfile(path, [file '.mat']) '!'];
disp(msg);
disp('');

%% Chargement des classifieurs

listclassi = dir(fullfile(path, file, 'classification'));
listclassi = listclassi(~contains({listclassi.name}, {'.', '..'}));
listclassi = listclassi(arrayfun(@(x) x.isdir, listclassi));

if ~isempty(listclassi)
    arr = zeros(1, numel(listclassi));
    for j = 1:numel(listclassi)
        tmp = regexp(listclassi(j).name, '\d+$', 'match');
        arr(j) = str2double(tmp{1});
    end
    [~, ix] = sort(arr);
    listclassi = listclassi(ix);

    if isfield(shallowObj.processing, 'classification') && ...
            ~isempty(shallowObj.processing.classification) && ...
            ~isa(shallowObj.processing.classification, 'classi')
        warning('shallowLoad:ResetClassificationField', ...
            ['processing.classification n''est pas un tableau de ''classi'' (type actuel : %s). ', ...
             'Le champ est réinitialisé à partir du contenu du dossier classification/.'], ...
             class(shallowObj.processing.classification));
    end

    shallowObj.processing.classification = classi.empty;

    for j = 1:numel(listclassi)
        name = listclassi(j).name;
        str  = fullfile(path, file, 'classification', name, [name '_classification.mat']);
        if exist(str, 'file') == 2
            [classiObj, ~] = classiLoad(str); %#ok<NASGU>
            if isa(classiObj, 'classi')
                shallowObj.processing.classification(end+1) = classiObj;
            else
                warning('shallowLoad:InvalidClassi', ...
                    'Le fichier "%s" ne contient pas un objet de type ''classi'' (type:%s). Ignoré.', ...
                    str, class(classiObj));
            end
        end
    end
end

%% Chargement des processeurs

listproc = dir(fullfile(path, file, 'processor'));
listproc = listproc(~contains({listproc.name}, {'.', '..'}));
listproc = listproc(arrayfun(@(x) x.isdir, listproc));

shallowObj.processing.processor = process.empty;

if ~isempty(listproc)
    arr = zeros(1, numel(listproc));
    for j = 1:numel(listproc)
        tmp = regexp(listproc(j).name, '\d+$', 'match');
        arr(j) = str2double(tmp{1});
    end
    [~, ix] = sort(arr);
    listproc = listproc(ix);

    procList = process.empty;
    for j = 1:numel(listproc)
        name = listproc(j).name;
        str = fullfile(path, file, 'processor', name, [name '_processor.mat']);
        if exist(str, 'file') == 2
            try
                [procObj, ~] = processLoad(str); %#ok<NASGU>
                procList(end+1) = procObj;
            catch ME
                warning('Erreur processLoad : %s', ME.message);
            end
        end
    end
    shallowObj.processing.processor = procList;
end

%% Chargement des pipelines (runs)

listpipe = dir(fullfile(path, file, 'pipeline'));
listpipe = listpipe(~contains({listpipe.name}, {'.', '..'}));
listpipe = listpipe(arrayfun(@(x) x.isdir, listpipe));

shallowObj.processing.pipeline = pipelineRun.empty;

if ~isempty(listpipe)
    arr = zeros(1, numel(listpipe));
    for j = 1:numel(listpipe)
        tmp = regexp(listpipe(j).name, '\\d+$', 'match');
        if ~isempty(tmp)
            arr(j) = str2double(tmp{1});
        else
            arr(j) = j;
        end
    end
    [~, ix] = sort(arr);
    listpipe = listpipe(ix);

    pipeList = pipelineRun.empty;
    for j = 1:numel(listpipe)
        pth = fullfile(path, file, 'pipeline', listpipe(j).name);
        try
            [runObj, msg] = pipelineRunLoad(pth);
            if isempty(runObj)
                warning('pipelineRunLoad failed: %s', msg);
                continue;
            end
            pipeList(end+1) = runObj; %#ok<AGROW>
        catch ME
            warning('pipelineRunLoad error: %s', ME.message);
        end
    end
    shallowObj.processing.pipeline = pipeList;
end

%% Vérification des FOV (PAS d'auto-fix ici)

anyMissing = false;

% Charger prefs si dispo (pour mémoriser passivement les chemins valides)
try
    userprefs = detecdiv_prefs_load();
catch
    userprefs = [];
end

if numel(shallowObj.fov) ~= 0 && isprop(shallowObj.fov(1), 'srcpath') && ~isempty(shallowObj.fov(1).srcpath)

    for i = 1:numel(shallowObj.fov)
        shallowObj.fov(i).parent = shallowObj;

        if ~iscell(shallowObj.fov(i).srcpath), continue; end
        for ch = 1:numel(shallowObj.fov(i).srcpath)
            p = shallowObj.fov(i).srcpath{ch};
            if isempty(p), continue; end

            if isfolder(p)
                % mémorisation passive : on stocke ce qui marche (optionnel)
                if ~isempty(userprefs)
                    userprefs = detecdiv_paths_register_one(userprefs, p);
                end
            else
                anyMissing = true;
            end
        end
    end

    % Sauver prefs si modifiées
    if ~isempty(userprefs)
        try, detecdiv_prefs_save(userprefs); catch, end
    end

    if anyMissing
        disp('* Note * Some rawdata srcpath are missing/unreachable.');
        disp('* They will be requested only when needed (open FOV / extract ROI).');
        disp('* You can also use shallowObj.setSrcPath manually if you want to relink now.');
    end

    % Affichage informatif (channel 1)
    if ~isempty(shallowObj.fov(1).srcpath) && numel(shallowObj.fov(1).srcpath{1}) ~= 0
        disp('* Project contains FOV srcpath (channel 1 shown):');
        for i = 1:numel(shallowObj.fov)
            disp(shallowObj.fov(i).srcpath{1});
        end
    end

else
    disp('There is no available FOV in this project!');
end

end
