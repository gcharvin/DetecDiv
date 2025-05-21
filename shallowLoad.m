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

% [path, file, ext] = fileparts(filename);
% abspath = what(path);
% abspath = abspath.path;
% filename = fullfile(abspath, [file ext]);
% load(filename);

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
file=namestr;
path=pathstr;
load(filename);


if ~exist('shallowObj', 'var')
    disp('this is not a shallow object ! Quitting....');
    msg = ['Wrong file name loaded'];
    shallowObj = [];
    return;
end

if ~isfield(shallowObj.processing, 'processor')
    shallowObj.processing.processor = [];
end

if isunix || ismac
    shallowObj.setPath([path '/'], file);
else
    shallowObj.setPath([path '\'], file);
end

normalizePathClean = @(p) regexprep(lower(strrep(p, '\', '/')), '/+$', '');

expectedPath = normalizePathClean(path);
expectedFile = lower(file);

varlist = evalin('base', 'who');
for i = 1:numel(varlist)
    varName = varlist{i};
    if strcmp(varName, 'ans')
        continue;
    end

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

    for j = 1:numel(listclassi)
        name = listclassi(j).name;
        str = fullfile(path, file, 'classification', name, [name '_classification.mat']);
        if exist(str, 'file') == 2
            [classiObj, msgclassi] = classiLoad(str);
            shallowObj.processing.classification(j) = classiObj;
        end
    end
end

%% Chargement des processeurs

listproc = dir(fullfile(path, file, 'processor'));
listproc = listproc(~contains({listproc.name}, {'.', '..'}));
listproc = listproc(arrayfun(@(x) x.isdir, listproc));

if ~isempty(listproc)
    arr = zeros(1, numel(listproc));
    for j = 1:numel(listproc)
        tmp = regexp(listproc(j).name, '\d+$', 'match');
        arr(j) = str2double(tmp{1});
    end
    [~, ix] = sort(arr);
    listproc = listproc(ix);

    for j = 1:numel(listproc)
        name = listproc(j).name;
        str = fullfile(path, file, 'processor', name, [name '_processor.mat']);
        if exist(str, 'file') == 2
            [procObj, msgproc] = processLoad(str);
            shallowObj.processing.processor(j) = procObj;
        end
    end
end

%% Vérification des FOV
if numel(shallowObj.fov(1).srcpath{1}) ~= 0
    disp('* Warning *');
    disp('* This project contains at least one FOV with the following path:');
    for i = 1:numel(shallowObj.fov)
        disp(shallowObj.fov(i).srcpath{1});
        shallowObj.fov(i).parent = shallowObj;
    end
    disp('* Need to update the path of the source images ?');
    disp('* To do so, use the shallowObj.setSrcPath function');
end

end
