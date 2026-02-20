function [processObj, msg] = processLoad(filename)

msg = [];
processObj = [];

if nargin == 0
    [file, path] = uigetfile('*.mat', 'Select a processor (i.e. a XXXXX_processor.mat file)', pwd);
    if isequal(file, 0)
        disp('User selected Cancel');
        return;
    else
        filename = fullfile(path, file);
    end
end

[path, file, ext] = fileparts(filename);
abspath = what(path);
abspath = abspath.path;
filename = fullfile(abspath, [file ext]);

% Charger toutes les variables dans une struct temporaire
s = load(filename);

% Rechercher une variable de type 'process'
varNames = fieldnames(s);
found = false;

for i = 1:numel(varNames)
    candidate = s.(varNames{i});
    if isa(candidate, 'process')
        processObj = candidate;
        found = true;
        break;
    end
end

if ~found
    msg = '❌ Ce fichier ne contient aucun objet de type ''process''.';
    disp(msg);
    return;
end

% Ensure runProfiles exists
try
    if ~isprop(processObj,'runProfiles') || isempty(processObj.runProfiles)
        processObj.runProfiles = struct('process', struct(), 'selection', struct());
    end
catch
end

% Normalize processFun to package-style if available
try
    if isprop(processObj,'processFun') && ~isempty(processObj.processFun)
        processObj.processFun = normalizeProcessFun(processObj.processFun);
    end
catch
end

% Vérifie si déjà présent dans le workspace
varlist = evalin('base', 'who');
for i = 1:numel(varlist)
    if strcmp(varlist{i}, 'ans')
        continue;
    end
    try
        tmp = evalin('base', varlist{i});
        if isa(tmp, 'process')
            if strcmp(path, tmp.path(1:end-1)) && strcmp(file, [tmp.strid '_processor'])
                msg = ['Processor is already in the workspace under the var name: ' varlist{i} '; Quitting...'];
                disp(msg);
                processObj = [];
                return;
            end
        end
    catch
        % ignorer les erreurs
    end
end

% Définir le chemin
if isunix || ismac
    processObj.setPath([path '/'], file);
else
    processObj.setPath([path '\'], file);
end

msg = ['Process was loaded with this path: ' path];
processObj.log(msg, 'Creation');

disp(['✅ Successfully loaded processor ' fullfile(path, [file '.mat']) '!']);
end

function f = normalizeProcessFun(f)
    if isempty(f)
        return;
    end
    if isa(f,'function_handle')
        f = func2str(f);
    end
    f = char(string(f));
    if contains(f,'.process')
        return;
    end
    if contains(f,'.')
        return;
    end
    if ~isempty(which([f '.process']))
        f = [f '.process'];
    end
end
