function detecdiv_local_watch_pipeline_result(resultPath, resultQueue, timeoutSeconds, consolePath, progressPath, eventQueue)
% detecdiv_local_watch_pipeline_result  Tail worker output off the UI thread.

    if nargin < 3 || isempty(timeoutSeconds)
        timeoutSeconds = 7 * 24 * 60 * 60;
    end
    if nargin < 4, consolePath = ''; end
    if nargin < 5, progressPath = ''; end
    if nargin < 6, eventQueue = []; end
    resultPath = char(string(resultPath));
    consolePath = char(string(consolePath));
    progressPath = char(string(progressPath));
    started = tic;
    consoleOffset = 0;
    consoleRemainder = '';
    progressSignature = '';
    while toc(started) < timeoutSeconds
        [consoleOffset, consoleChunk] = localReadConsoleChunk(consolePath, consoleOffset);
        if ~isempty(consoleChunk)
            [consoleText, progressEvents, consoleRemainder] = ...
                localDecodeConsoleProgress(consoleChunk, consoleRemainder, false);
            localSendConsoleAndProgress(eventQueue, consoleText, progressEvents);
        end
        [progressSignature, progress] = localReadProgress(progressPath, progressSignature);
        if ~isempty(progress)
            localSendEvent(eventQueue, struct('kind', 'progress', 'data', progress));
        end
        if exist(resultPath, 'file') == 2
            try
                result = jsondecode(fileread(resultPath));
                [consoleOffset, consoleChunk] = localReadConsoleChunk(consolePath, consoleOffset); %#ok<ASGLU>
                if ~isempty(consoleChunk)
                    [consoleText, progressEvents, consoleRemainder] = ...
                        localDecodeConsoleProgress(consoleChunk, consoleRemainder, false);
                    localSendConsoleAndProgress(eventQueue, consoleText, progressEvents);
                end
                [consoleText, progressEvents, consoleRemainder] = ...
                    localDecodeConsoleProgress('', consoleRemainder, true); %#ok<ASGLU>
                localSendConsoleAndProgress(eventQueue, consoleText, progressEvents);
                pause(0.5);
                send(resultQueue, result);
                return;
            catch
                % The worker may still be completing its atomic file write.
            end
        end
        pause(0.2);
    end

    [consoleText, progressEvents] = ...
        localDecodeConsoleProgress('', consoleRemainder, true);
    localSendConsoleAndProgress(eventQueue, consoleText, progressEvents);
    result = struct('status', 'failed', 'run_id', '', ...
        'project_mat_path', '', 'pipeline_json_path', '', ...
        'run_json_path', '', 'artifacts', struct([]), ...
        'summary', struct(), ...
        'error', sprintf('Timed out waiting for local worker result: %s', resultPath));
    send(resultQueue, result);
end

function [offset, chunk] = localReadConsoleChunk(pathText, offset)
    chunk = '';
    if isempty(pathText) || exist(pathText, 'file') ~= 2
        return;
    end
    info = dir(pathText);
    if isempty(info)
        return;
    end
    if info.bytes < offset
        offset = 0;
    end
    if info.bytes == offset
        return;
    end
    fid = fopen(pathText, 'r');
    if fid < 0
        return;
    end
    cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
    if fseek(fid, offset, 'bof') ~= 0
        offset = 0;
        fseek(fid, 0, 'bof');
    end
    data = fread(fid, Inf, '*uint8')';
    offset = ftell(fid);
    if isempty(data)
        return;
    end
    try
        chunk = native2unicode(data, 'UTF-8');
    catch
        chunk = char(data);
    end
end

function [signature, progress] = localReadProgress(pathText, previousSignature)
    signature = previousSignature;
    progress = [];
    if isempty(pathText) || exist(pathText, 'file') ~= 2
        return;
    end
    try
        raw = fileread(pathText);
        if strcmp(raw, previousSignature)
            return;
        end
        progress = jsondecode(raw);
        signature = raw;
    catch
        progress = [];
    end
end

function [displayText, progressEvents, remainder] = ...
        localDecodeConsoleProgress(chunk, remainder, flushRemainder)
    marker = '@@DETECDIV_PROGRESS@@';
    displayText = '';
    progressEvents = {};
    if nargin < 2 || isempty(remainder), remainder = ''; end
    if nargin < 3, flushRemainder = false; end
    combined = [char(remainder) char(chunk)];
    if isempty(combined)
        remainder = '';
        return;
    end

    [~, lineEnds] = regexp(combined, '\r\n|\r|\n', 'start', 'end');
    if isempty(lineEnds)
        if flushRemainder
            completeText = combined;
            remainder = '';
        else
            remainder = combined;
            return;
        end
    else
        completeText = combined(1:lineEnds(end));
        remainder = combined(lineEnds(end)+1:end);
    end

    lines = regexp(completeText, '\r\n|\r|\n', 'split');
    if ~flushRemainder && ~isempty(lines) && isempty(lines{end})
        lines(end) = [];
    end
    visibleLines = {};
    for i = 1:numel(lines)
        lineText = lines{i};
        trimmed = strtrim(lineText);
        if startsWith(trimmed, marker)
            encoded = strtrim(extractAfter(string(trimmed), strlength(marker)));
            try
                payload = jsondecode(char(encoded));
                if isstruct(payload) && isfield(payload, 'value')
                    progressEvents{end+1} = payload; %#ok<AGROW>
                    continue;
                end
            catch
                % Preserve malformed protocol lines in the detailed console.
            end
        end
        visibleLines{end+1} = lineText; %#ok<AGROW>
    end
    if ~isempty(visibleLines)
        displayText = [strjoin(visibleLines, newline) newline];
    end
end

function localSendConsoleAndProgress(queue, consoleText, progressEvents)
    if ~isempty(consoleText)
        localSendEvent(queue, struct('kind', 'console', 'text', consoleText));
    end
    for i = 1:numel(progressEvents)
        localSendEvent(queue, struct('kind', 'progress', ...
            'data', progressEvents{i}));
    end
end

function localSendEvent(queue, payload)
    try
        if ~isempty(queue)
            send(queue, payload);
        end
    catch
    end
end
