function requiredToolboxes = listRequiredToolboxes(rootDir)
% Recursively scans .m files in rootDir, detects required MATLAB toolboxes,
% prints progress and findings, and saves the results to .mat and .json.

if nargin < 1
    rootDir = pwd;
end

% Get the folder of this script (for saving outputs)
scriptDir = fileparts(mfilename('fullpath'));

% Find all .m files recursively
files = dir(fullfile(rootDir, '**', '*.m'));
filePathsAll = fullfile({files.folder}, {files.name});

toolboxUsageMap = containers.Map();  % key = toolbox name (char), value = list of file paths
allRequired = {};  % list of all toolboxes found

fprintf('🔍 Scanning MATLAB files in: %s\n', rootDir);

for i = 1:numel(filePathsAll)
    filePath = filePathsAll{i};
    fprintf('\n📄 Checking file: %s\n', filePath);

    % Check for syntax errors
    issues = checkcode(filePath, '-id');
    hasSyntaxError = any(contains({issues.message}, 'might be missing') | ...
        contains({issues.message}, 'Parse error'));
    if hasSyntaxError
        fprintf('⚠️  Skipped (syntax error detected)\n');
        continue;
    end

    try
        % Get required products for this file
        [~, products] = matlab.codetools.requiredFilesAndProducts({filePath});
    catch ME
        fprintf('⚠️  Error analyzing file: %s\n%s\n', filePath, ME.message);
        continue;
    end

    % Process each detected toolbox
    for p = 1:numel(products)
        toolboxName = char(products(p).Name);  % enforce char type for Map keys

        % Print if it's a new toolbox
        if ~ismember(toolboxName, allRequired)
            fprintf('➕ New toolbox detected: %s (used in %s)\n', toolboxName, filePath);
            allRequired{end+1} = toolboxName;
        end

        % Update usage map
        if isKey(toolboxUsageMap, toolboxName)
            tmp = toolboxUsageMap(toolboxName);
            tmp{end+1} = filePath;
            toolboxUsageMap(toolboxName) = tmp;
        else
            toolboxUsageMap(toolboxName) = {filePath};
        end
    end
end

% Final list of unique toolboxes
requiredToolboxes = sort(allRequired(:));

% Summary output
fprintf('\n📦 Summary of required toolboxes:\n');
toolboxStats = struct([]);
for i = 1:numel(requiredToolboxes)
    tb = requiredToolboxes{i};
    fileList = toolboxUsageMap(char(tb));  % Convert string to char for indexing
    filesUsing = unique(fileList);
    usageCount = numel(filesUsing);

    fprintf('  - %s: used in %d file(s)\n', tb, usageCount);

    % Store in structure for JSON export
    toolboxStats(i).name = tb;
    toolboxStats(i).count = usageCount;
    toolboxStats(i).files = filesUsing;
end

% Save results
outMat = fullfile(scriptDir, 'requiredToolboxes.mat');
outJson = fullfile(scriptDir, 'requiredToolboxes.json');
save(outMat, 'requiredToolboxes', 'toolboxUsageMap', 'toolboxStats');

% Export JSON
jsonText = jsonencode(toolboxStats, 'PrettyPrint', true);
fid = fopen(outJson, 'w');
if fid ~= -1
    fwrite(fid, jsonText, 'char');
    fclose(fid);
    fprintf('\n📝 JSON file saved to: %s\n', outJson);
else
    warning('Could not write JSON file.');
end

fprintf('\n✅ All results saved to:\n  - %s\n  - %s\n', outMat, outJson);
end
