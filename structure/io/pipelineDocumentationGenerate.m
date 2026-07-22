function result = pipelineDocumentationGenerate(pipelineInput, varargin)
% pipelineDocumentationGenerate Generate standalone Reveal.js pipeline documentation.
%
% result = pipelineDocumentationGenerate(pipelineJson, ...)
% result = pipelineDocumentationGenerate(pipelineObject, ...)
%
% Name-value options:
%   OutputDir   destination directory (default: <pipeline>/documentation)
%   RevealDir   local Reveal.js installation
%   Metadata    optional JSON file containing editorial overrides
%   Project     optional shallow object or project MAT file used to extract
%               representative intermediate results
%   ExportPdf   also print the presentation to PDF (default: true)
%   OpenBrowser open the generated HTML (default: false)

% The Node generator deliberately receives a JSON path. A pipeline object is
% first saved to a temporary JSON file so this function can later be called
% directly by pipeline2 without duplicating documentation logic in the GUI.

    parser = inputParser;
    parser.addParameter('OutputDir', '', @(x) ischar(x) || isstring(x));
    parser.addParameter('RevealDir', '', @(x) ischar(x) || isstring(x));
    parser.addParameter('Metadata', '', @(x) ischar(x) || isstring(x));
    parser.addParameter('Project', [], @(x) isempty(x) || isa(x, 'shallow') || ischar(x) || isstring(x));
    parser.addParameter('ExportPdf', true, @(x) islogical(x) || isnumeric(x));
    parser.addParameter('OpenBrowser', false, @(x) islogical(x) || isnumeric(x));
    parser.parse(varargin{:});
    opts = parser.Results;

    if isa(pipelineInput, 'pipeline')
        jsonPath = [tempname '.json'];
        writeTemporaryPipelineJson(pipelineInput, jsonPath);
        tempCleanup = onCleanup(@() deleteIfPresent(jsonPath));
    else
        jsonPath = char(string(pipelineInput));
    end
    if exist(jsonPath, 'file') ~= 2
        error('pipelineDocumentationGenerate:Input', 'Pipeline JSON not found: %s', jsonPath);
    end

    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    generator = fullfile(repoRoot, 'tools', 'pipeline-doc', 'generate-pipeline-doc.mjs');
    if isempty(opts.OutputDir)
        opts.OutputDir = fullfile(fileparts(jsonPath), 'documentation');
    end
    if isempty(opts.RevealDir)
        candidates = { ...
            getenv('REVEAL_JS_DIR'), ...
            fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'grc_seminar', 'node_modules', 'reveal.js'), ...
            fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'grc_seminar', 'dist', 'seminar-export', 'node_modules', 'reveal.js')};
        opts.RevealDir = firstExistingReveal(candidates);
    end
    if isempty(opts.RevealDir)
        error('pipelineDocumentationGenerate:Reveal', 'Reveal.js was not found. Pass RevealDir or define REVEAL_JS_DIR.');
    end

    cmd = sprintf('node %s --input %s --output-dir %s --reveal-dir %s', ...
        quoteArg(generator), quoteArg(jsonPath), quoteArg(opts.OutputDir), quoteArg(opts.RevealDir));
    if ~isempty(opts.Metadata)
        cmd = sprintf('%s --metadata %s', cmd, quoteArg(opts.Metadata));
    end
    if ~isempty(opts.Project)
        examplesDir = fullfile(char(string(opts.OutputDir)), 'examples');
        examplesManifest = pipelineDocumentationExtractExamples(opts.Project, examplesDir, pipelineInput);
        cmd = sprintf('%s --examples %s', cmd, quoteArg(examplesManifest));
    end
    if logical(opts.ExportPdf)
        cmd = [cmd ' --pdf'];
    end
    [status, output] = system(cmd);
    if status ~= 0
        error('pipelineDocumentationGenerate:Generator', 'Documentation generation failed:\n%s', output);
    end
    result = jsondecode(output);
    if exist('tempCleanup', 'var')
        clear tempCleanup;
    end
    if logical(opts.OpenBrowser)
        web(result.html, '-browser');
    end
end

function value = firstExistingReveal(candidates)
    value = '';
    for i = 1:numel(candidates)
        candidate = char(string(candidates{i}));
        if ~isempty(candidate) && exist(fullfile(candidate, 'dist', 'reveal.js'), 'file') == 2
            value = candidate;
            return;
        end
    end
end

function out = quoteArg(value)
    out = ['"' strrep(char(string(value)), '"', '\"') '"'];
end

function deleteIfPresent(filename)
    if exist(filename, 'file') == 2
        delete(filename);
    end
end

function writeTemporaryPipelineJson(pipeObj, filename)
    spec = struct();
    spec.name = pipeObj.strid;
    spec.id = pipeObj.id;
    spec.version = pipeObj.version;
    spec.description = pipeObj.description;
    spec.nodes = pipelineNormalizeNodes(pipeObj.nodes, 'persist');
    spec.edges = pipeObj.edges;
    if ~isempty(pipeObj.branches)
        spec.branches = pipeObj.branches;
    end
    spec.runState = pipeObj.runState;
    spec.runProfiles = pipeObj.runProfiles;
    spec.createdAt = '';
    spec.updatedAt = char(datetime('now'));
    try
        text = jsonencode(spec, 'PrettyPrint', true);
    catch
        text = jsonencode(spec);
    end
    fid = fopen(filename, 'w');
    if fid < 0
        error('pipelineDocumentationGenerate:IO', 'Unable to write temporary pipeline JSON: %s', filename);
    end
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, text, 'char');
    clear cleaner;
end
