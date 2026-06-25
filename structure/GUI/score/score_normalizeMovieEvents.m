function events = score_normalizeMovieEvents(rawEvents)
% score_normalizeMovieEvents Normalize movie event marker table/cell data.

events = struct('enabled', {}, 'time', {}, 'label', {}, 'color', {}, 'width', {});
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
        timeVal = [];
        labelVal = "";
        colorVal = [0.2 0.95 0.25];
        widthVal = 1.5;
        if size(rawEvents, 2) >= 1
            enabled = logical(rawEvents{i, 1});
        end
        if size(rawEvents, 2) >= 2
            timeVal = double(rawEvents{i, 2});
            if isempty(timeVal) || isnan(timeVal)
                timeVal = str2double(string(rawEvents{i, 2}));
            end
        end
        if size(rawEvents, 2) >= 3
            labelVal = string(rawEvents{i, 3});
        end
        if size(rawEvents, 2) >= 4
            parsedColor = str2num(char(string(rawEvents{i, 4}))); %#ok<ST2NM>
            if isnumeric(parsedColor) && numel(parsedColor) == 3 && all(isfinite(parsedColor))
                colorVal = min(max(double(parsedColor(:).'), 0), 1);
            end
        end
        if size(rawEvents, 2) >= 5
            widthVal = str2double(string(rawEvents{i, 5}));
            if ~isfinite(widthVal) || widthVal <= 0
                widthVal = 1.5;
            end
        end
        if ~enabled || isempty(timeVal) || ~isfinite(timeVal)
            continue;
        end
        events(end+1) = struct('enabled', true, 'time', double(timeVal), ...
            'label', char(labelVal), 'color', colorVal, 'width', double(widthVal)); %#ok<AGROW>
    catch
    end
end
end
