function events = score_normalizeMovieEvents(rawEvents)
% score_normalizeMovieEvents Normalize movie event intervals.
%
% Canonical cell columns:
%   {enabled, startFrame, endFrame, label, width}
%
% Legacy rows {enabled, time, label, color, width} are accepted as punctual
% events with startFrame=endFrame=time.

events = struct('enabled', {}, 'startFrame', {}, 'endFrame', {}, 'label', {}, 'width', {});
if nargin < 1 || isempty(rawEvents)
    return;
end

if istable(rawEvents)
    rawEvents = table2cell(rawEvents);
end
if ~iscell(rawEvents)
    return;
end

for i = 1:size(rawEvents, 1)
    try
        enabled = true;
        startFrame = [];
        endFrame = [];
        labelVal = "";
        widthVal = 1.5;

        if size(rawEvents, 2) >= 1
            enabled = logical(rawEvents{i, 1});
        end
        if size(rawEvents, 2) >= 2
            startFrame = localNumeric(rawEvents{i, 2});
        end

        isCanonicalInterval = false;
        if size(rawEvents, 2) >= 3
            endCandidate = localNumeric(rawEvents{i, 3});
            isCanonicalInterval = isfinite(endCandidate);
        end

        if isCanonicalInterval
            endFrame = endCandidate;
            if size(rawEvents, 2) >= 4
                labelVal = string(rawEvents{i, 4});
            end
            if size(rawEvents, 2) >= 5
                widthVal = localNumeric(rawEvents{i, 5});
            end
        else
            endFrame = startFrame;
            if size(rawEvents, 2) >= 3
                labelVal = string(rawEvents{i, 3});
            end
            if size(rawEvents, 2) >= 5
                widthVal = localNumeric(rawEvents{i, 5});
            end
        end

        if ~enabled || isempty(startFrame) || ~isfinite(startFrame)
            continue;
        end
        if isempty(endFrame) || ~isfinite(endFrame)
            endFrame = startFrame;
        end
        if endFrame < startFrame
            tmp = startFrame;
            startFrame = endFrame;
            endFrame = tmp;
        end
        if ~isfinite(widthVal) || widthVal <= 0
            widthVal = 1.5;
        end

        events(end+1) = struct( ...
            'enabled', true, ...
            'startFrame', double(startFrame), ...
            'endFrame', double(endFrame), ...
            'label', char(labelVal), ...
            'width', double(widthVal)); %#ok<AGROW>
    catch
    end
end
end

function value = localNumeric(raw)
value = [];
try
    if isnumeric(raw)
        value = double(raw);
        if ~isempty(value)
            value = value(1);
        end
    else
        value = str2double(string(raw));
    end
catch
    value = [];
end
end
