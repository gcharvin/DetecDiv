function out = score_wrapDisplayLabel(label, maxCharsPerLine)
% score_wrapDisplayLabel Wrap long display labels for axes and legends.

if nargin < 2 || isempty(maxCharsPerLine)
    maxCharsPerLine = 18;
end

if isstring(label) && numel(label) > 1
    out = arrayfun(@(s) score_wrapDisplayLabel(s, maxCharsPerLine), label, 'UniformOutput', false);
    return
end

if iscell(label)
    out = cellfun(@(s) score_wrapDisplayLabel(s, maxCharsPerLine), label, 'UniformOutput', false);
    return
end

txt = char(string(label));
txt = strrep(txt, sprintf('\r\n'), sprintf('\n'));
txt = strrep(txt, sprintf('\r'), sprintf('\n'));

if contains(txt, sprintf('\n')) || strlength(string(txt)) <= maxCharsPerLine
    out = txt;
    return
end

tokens = regexp(txt, '([^_\s]+|[_\s]+)', 'match');
lines = {};
current = '';

for i = 1:numel(tokens)
    tok = tokens{i};
    if isempty(current)
        current = tok;
    elseif strlength(string(current)) + strlength(string(tok)) <= maxCharsPerLine
        current = [current tok]; %#ok<AGROW>
    else
        lines{end+1} = trimSeparators(current); %#ok<AGROW>
        current = stripLeadingSeparators(tok);
    end

    while strlength(string(current)) > maxCharsPerLine
        splitAt = maxCharsPerLine;
        lines{end+1} = trimSeparators(current(1:splitAt)); %#ok<AGROW>
        current = stripLeadingSeparators(current(splitAt+1:end));
    end
end

if ~isempty(current)
    lines{end+1} = trimSeparators(current); %#ok<AGROW>
end

lines = lines(~cellfun(@isempty, lines));
out = strjoin(lines, sprintf('\n'));
end

function txt = stripLeadingSeparators(txt)
txt = regexprep(txt, '^[_\s]+', '');
end

function txt = trimSeparators(txt)
txt = regexprep(strtrim(txt), '[_\s]+$', '');
end
