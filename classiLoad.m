function [classiObj msg]=classiLoad(filename)

msg=[];

if nargin==0
    [file,path] = uigetfile('*classification*.mat','Select a classification object (i.e. a XXXXX_classification.mat file)',pwd);

    if isequal(file,0)
        disp('User selected Cancel')
        classiObj=[];
        return;
    else


        if ~contains(file, 'classification')
            warndlg('The selected file does not appear to be a classification file.', 'Warning');
            classiObj = [];
            return;
        end

        disp(['User selected ', fullfile(path, file)]);
        filename=fullfile(path, file);
    end
end



if isnumeric(filename) % loads classi from repository
    list=listRepositoryClassi;
    if numel(list)==0
        classiObj=[];
        return;
    end

    disp(list)

    prompt='Please enter the number associated with the classification you wish to set from the repository ? (Default:1): ';
    classitype= input(prompt);
    if numel(classitype)==0
        classitype=1;
    end

    filename=listRepositoryClassi(classitype);
end

[path,file,ext]=fileparts(filename);

%filename
abspath=what(path);
abspath=abspath.path;

filename=fullfile(abspath,[file ext]);

load(filename);
path=abspath;

if ~isa(classiObj,'classi')
    msg='This file does not correspond to a classification object';
    disp('This file does not correspond to a classification object');
    classiObj=[];
    return;

end

% check if processor is already open in the workspace
varlist=evalin('base','who');
for i=1:numel(varlist)

    if strcmp(varlist{i},'ans')
        continue;
    end

    tmp=evalin('base',varlist{i});
    if isa(tmp,'classi')
        % check path & filenemae
        %   path,file
        %   a=tmp.path, b=tmp.strid

        if strcmp(path,tmp.path(1:end-1)) & strcmp(file, [tmp.strid  '_classification']) % var exists already
            msg=['Classification is already in the workspace under the var name:' varlist{i} '; I will take take this classifier as loaded...'];
            disp(msg);
            classiObj=tmp;
            return
        end
    end
end


if isunix || ismac
    classiObj.setPath([path '/'],file); % adjust path
else
    classiObj.setPath([path '\'],file); % adjust path
end

% --- normalize run paths (old projects may have ABS stored) ---
try
    if isprop(classiObj,'run')
        % Never trust "active" state after reload
        if isstruct(classiObj.run) && isfield(classiObj.run,'active')
            classiObj.run.active = false;
        end
        classiObj.runNormalizePaths();
    end
catch
end

% --- load dataset.json if present (merge with existing) ---
try
    dsFile = fullfile(path, 'dataset.json');
    if exist(dsFile,'file') == 2
        txt = fileread(dsFile);
        ds = jsondecode(txt);
        if isprop(classiObj,'dataset') && isstruct(classiObj.dataset)
            classiObj.dataset = localMergeStruct(classiObj.dataset, ds);
        else
            classiObj.dataset = ds;
        end
    end
catch
end

% --- load runProfiles.json if present (merge with existing) ---
try
    rpFile = fullfile(path, 'runProfiles.json');
    if exist(rpFile,'file') == 2
        txt = fileread(rpFile);
        rp = jsondecode(txt);
        if isprop(classiObj,'runProfiles') && isstruct(classiObj.runProfiles)
            classiObj.runProfiles = localMergeStruct(classiObj.runProfiles, rp);
        else
            classiObj.runProfiles = rp;
        end
    end
catch
end


msg=['Classification was loaded with this path:' path];

classiObj.log(['Classi was loaded with this path:' path],'Creation');

disp(['Successfully loaded classification ' fullfile(path,[file '.mat']) '!']);

% --- ensure dataset / legacy fields are consistent ---
try
    classiObj.syncDatasetFromLegacy();
    classiObj.syncLegacyFromDataset();
catch
end

    function out = localMergeStruct(base, override)
        out = base;
        if ~isstruct(out), out = struct(); end
        if ~isstruct(override), return; end

        f = fieldnames(override);
        for i = 1:numel(f)
            k = f{i};
            v = override.(k);
            if isstruct(v) && isfield(out, k) && isstruct(out.(k))
                out.(k) = localMergeStruct(out.(k), v);
            else
                out.(k) = v;
            end
        end
    end

