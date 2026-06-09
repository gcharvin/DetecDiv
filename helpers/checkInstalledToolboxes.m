function checkInstalledToolboxes(filePath)
% Check whether the required toolboxes and pretrained models (GoogLeNet, ResNet50) are installed.

    if nargin < 1
        % Merge both sources when available so a stale MAT file cannot mask a newer JSON export.
        scriptDir = fileparts(mfilename('fullpath'));
        matFile = fullfile(scriptDir, 'requiredToolboxes.mat');
        jsonFile = fullfile(scriptDir, 'requiredToolboxes.json');

        if isfile(matFile) && isfile(jsonFile)
            toolboxList = unique([localLoadToolboxNames(matFile), localLoadToolboxNames(jsonFile)], 'stable');
        elseif isfile(matFile)
            toolboxList = localLoadToolboxNames(matFile);
        elseif isfile(jsonFile)
            toolboxList = localLoadToolboxNames(jsonFile);
        else
            error('No requiredToolboxes.mat or requiredToolboxes.json found in script directory.');
        end
    else
        toolboxList = localLoadToolboxNames(filePath);
    end

    % Get list of installed products
    installed = ver;
    installedNames = {installed.Name};

    % Check toolbox presence
    fprintf('\n🔍 Checking installed toolboxes:\n');
    found = {};
    missing = {};

    for i = 1:numel(toolboxList)
        tb = toolboxList{i};
        if any(strcmpi(tb, installedNames))
            fprintf('✅ Installed: %s\n', tb);
            found{end+1} = tb; %#ok<AGROW>
        else
            fprintf('❌ Missing:   %s\n', tb);
            missing{end+1} = tb; %#ok<AGROW>
        end
    end

    % Check pretrained networks
    fprintf('\n🧠 Checking availability of pretrained models:\n');

    pretrainedModels = {'googlenet', 'resnet50'};
    for i = 1:numel(pretrainedModels)
        model = pretrainedModels{i};
        if exist(model, 'file') == 2
            fprintf('✅ Model available: %s\n', model);
        else
            fprintf('❌ Model NOT available: %s\n', model);
            fprintf('   👉 You can install it with:\n       >> %s\n', ['matlab.addons.installer.installModel(''' model ''')']);
        end
    end

    % Summary
    fprintf('\n📊 Summary:\n');
    fprintf('  - %d toolboxes required\n', numel(toolboxList));
    fprintf('  - %d found\n', numel(found));
    fprintf('  - %d missing\n', numel(missing));

    if ~isempty(missing)
        fprintf('\n🚫 Missing toolboxes:\n');
        for i = 1:numel(missing)
            fprintf('  - %s\n', missing{i});
        end
    end
end

function toolboxList = localLoadToolboxNames(filePath)
    if endsWith(filePath, '.mat')
        data = load(filePath);
        if isfield(data, 'requiredToolboxes')
            toolboxList = cellstr(string(data.requiredToolboxes(:)'));
        elseif isfield(data, 'toolboxStats')
            toolboxList = cellstr(string({data.toolboxStats.name}));
        else
            error('MAT file does not contain a recognized toolbox list.');
        end
    elseif endsWith(filePath, '.json')
        fid = fopen(filePath, 'r');
        raw = fread(fid, inf, 'char=>char')';
        fclose(fid);
        toolboxStats = jsondecode(raw);
        toolboxList = cellstr(string({toolboxStats.name}));
    else
        error('Unsupported file type: %s', filePath);
    end

    toolboxList = unique(toolboxList, 'stable');
end
