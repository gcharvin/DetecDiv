function scores = scoreHGBExternal(features, param, ctx, workRoot)
%BUDMOTHERLINKER.UTILS.SCOREHGBEXTERNAL Score features in cell_lineage_linker.

if nargin < 3 || isempty(ctx), ctx = struct(); end
if nargin < 4 || isempty(workRoot)
    workRoot = tempname;
    mkdir(workRoot);
    removeAtEnd = true;
else
    if ~isfolder(workRoot), mkdir(workRoot); end
    removeAtEnd = false;
end
cleanup = onCleanup(@() cleanupWorkRoot(workRoot, removeAtEnd));
inputPath = fullfile(workRoot, 'hgb_scoring_input.mat');
outputPath = fullfile(workRoot, 'hgb_scoring_output.mat');
configPath = fullfile(workRoot, 'hgb_scoring_config.json');
stdoutPath = fullfile(workRoot, 'hgb_scoring_stdout.txt');

X = double(features);
save(inputPath, 'X', '-v7');
config = struct( ...
    'input_path', normalizedPath(inputPath), ...
    'output_path', normalizedPath(outputPath), ...
    'model', struct( ...
        'source', char(string(param.modelSource)), ...
        'path', ''));
if strcmpi(char(string(param.modelSource)), 'trained')
    config.model.path = normalizedPath(param.modelPath);
end
writeJson(configPath, config);

budMotherLinker.utils.runPythonModule( ...
    'score-hgb', configPath, ctx, stdoutPath);
if ~isfile(outputPath)
    error('budMotherLinker:MissingExternalScores', ...
        'cell_lineage_linker did not produce the requested HGB scores.');
end
payload = load(outputPath, 'scores');
if ~isfield(payload, 'scores')
    error('budMotherLinker:InvalidExternalScores', ...
        'cell_lineage_linker output has no scores array.');
end
scores = double(payload.scores(:));
if numel(scores) ~= size(features, 1)
    error('budMotherLinker:InvalidExternalScores', ...
        'Expected %d scores, received %d.', size(features, 1), numel(scores));
end
end

function cleanupWorkRoot(workRoot, removeAtEnd)
if ~removeAtEnd || ~isfolder(workRoot), return; end
try rmdir(workRoot, 's'); catch, end
end

function writeJson(filename, value)
fid = fopen(filename, 'w');
if fid < 0
    error('budMotherLinker:ConfigWriteFailed', ...
        'Cannot create external linker configuration: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(value, 'PrettyPrint', true), 'char');
end

function value = normalizedPath(value)
value = strrep(char(string(value)), '\', '/');
end
