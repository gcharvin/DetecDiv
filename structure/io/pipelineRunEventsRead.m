function events = pipelineRunEventsRead(runOrPath)
% pipelineRunEventsRead  Read a pipeline run JSONL event ledger.
%
% Input can be:
%   - a pipelineRun object
%   - a run folder
%   - a direct run_events.jsonl path
%
% Output is a struct array of decoded events.

    eventPath = localResolveEventPath(runOrPath);
    events = struct([]);
    if isempty(eventPath) || exist(eventPath, 'file') ~= 2
        return;
    end

    txt = fileread(eventPath);
    lines = regexp(txt, '\r\n|\n|\r', 'split');
    for i = 1:numel(lines)
        line = strtrim(lines{i});
        if isempty(line)
            continue;
        end
        try
            evt = jsondecode(line);
            if isempty(events)
                events = evt;
            else
                [events, evt] = localAlignEventFields(events, evt);
                events(end+1) = evt; %#ok<AGROW>
            end
        catch
            evt = struct('ts', '', 'type', 'parse_error', 'runId', '', ...
                'Message', line);
            if isempty(events)
                events = evt;
            else
                [events, evt] = localAlignEventFields(events, evt);
                events(end+1) = evt; %#ok<AGROW>
            end
        end
    end
end

function path = localResolveEventPath(runOrPath)
    path = '';
    if nargin < 1 || isempty(runOrPath)
        return;
    end
    if isa(runOrPath, 'pipelineRun')
        try
            [runPath, ~] = runOrPath.getPath;
            path = fullfile(runPath, 'run_events.jsonl');
        catch
            path = '';
        end
        return;
    end
    path = char(string(runOrPath));
    if isfolder(path)
        path = fullfile(path, 'run_events.jsonl');
    end
end

function [events, evt] = localAlignEventFields(events, evt)
    known = fieldnames(events);
    current = fieldnames(evt);
    for i = 1:numel(known)
        if ~isfield(evt, known{i})
            evt.(known{i}) = [];
        end
    end
    missing = setdiff(current, known);
    if ~isempty(missing)
        for i = 1:numel(missing)
            [events.(missing{i})] = deal([]);
        end
    end
end
