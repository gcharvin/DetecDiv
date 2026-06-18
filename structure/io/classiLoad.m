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

% Normalize legacy category storage (char/string -> 1x1 cellstr)
try
    classiObj.category = classiNormalizeCategory(classiObj.category);
catch
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

% --- backfill classifierPkg + report framework (visible) ---
try
    wasPkg = false;
    if isprop(classiObj,'classifierPkg') && ~isempty(classiObj.classifierPkg)
        wasPkg = true;
    end

    if isprop(classiObj,'classifierPkg') && isempty(classiObj.classifierPkg)
        % infer from training/classify function
        f = '';
        try
            if isprop(classiObj,'trainingFun') && ~isempty(classiObj.trainingFun)
                f = classiObj.trainingFun;
            elseif isprop(classiObj,'classifyFun') && ~isempty(classiObj.classifyFun)
                f = classiObj.classifyFun;
            end
        catch
            f = '';
        end

        if isa(f,'function_handle'), f = func2str(f); end
        if isstring(f), f = char(f); end

        dot = strfind(f,'.');
        if ~isempty(dot)
            classiObj.classifierPkg = f(1:dot(1)-1);
        elseif any(strcmp(f, {'trainImageLSTMNetFun','classifyImageLSTMNetFun'}))
            classiObj.classifierPkg = 'cnn_lstm';
        elseif any(strcmp(f, {'trainImageGoogleNetFun','classifyImageGoogleNetFun'}))
            classiObj.classifierPkg = 'cnn';
        elseif any(strcmp(f, {'trainCPSAMFun','classifyCPSAMFun'}))
            classiObj.classifierPkg = 'cellposesam';
        end
    end

    % Prepare ID string
    idStr = '';
    try
        if isprop(classiObj,'strid') && ~isempty(classiObj.strid)
            idStr = char(classiObj.strid);
        elseif isprop(classiObj,'id')
            idStr = ['classi_' num2str(classiObj.id)];
        end
    catch
        idStr = '';
    end

    if isprop(classiObj,'classifierPkg') && ~isempty(classiObj.classifierPkg)
        classiObj.category = localCategoryFromPackage(classiObj.classifierPkg, classiObj.category);
        localApplyPackageClassMetadata(classiObj);
        disp('===============================================================');
        disp(['[CLASSI LOAD] NEW PACKAGE FRAMEWORK: ' classiObj.classifierPkg]);
        if ~isempty(idStr)
            disp(['[CLASSI LOAD] ID: ' idStr]);
        end
        disp('===============================================================');
    else
        disp('===============================================================');
        disp('[CLASSI LOAD] LEGACY FRAMEWORK (trainingFun/classifyFun)');
        if ~isempty(idStr)
            disp(['[CLASSI LOAD] ID: ' idStr]);
        end
        disp('===============================================================');
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

    function category = localCategoryFromPackage(pkg, currentCategory)
        category = currentCategory;
        try
            specFun = [char(string(pkg)) '.executionSpec'];
            if isempty(which(specFun))
                return;
            end
            spec = feval(specFun);
            if isstruct(spec) && isfield(spec, 'category') && ~isempty(spec.category)
                category = classiNormalizeCategory(spec.category);
            end
        catch
        end
    end

    function localApplyPackageClassMetadata(classiObjLocal)
        try
            if ~isprop(classiObjLocal, 'classifierPkg') || isempty(classiObjLocal.classifierPkg)
                return;
            end
            fun = [char(string(classiObjLocal.classifierPkg)) '.ensureClassMetadata'];
            if ~isempty(which(fun))
                feval(fun, classiObjLocal);
            end
        catch
        end
    end
end
   



