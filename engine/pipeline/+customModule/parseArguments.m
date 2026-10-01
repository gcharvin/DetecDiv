function args = parseArguments(text)
% Decode each JSON array element separately to preserve argument boundaries.
% jsondecode of a homogeneous nested array can collapse it into a matrix.
text = strtrim(char(text));
jsondecode(text); % Validate the complete JSON before splitting elements.
if isempty(text) || text(1) ~= '[' || text(end) ~= ']'
    error('customModule:ArgumentsJson', 'argumentsJson must be a JSON array.');
end
body = text(2:end-1);
args = {};
if isempty(strtrim(body)), return; end
depth = 0;
quoted = false;
escaped = false;
start = 1;
for i = 1:numel(body)
    ch = body(i);
    if quoted
        if escaped
            escaped = false;
        elseif ch == '\'
            escaped = true;
        elseif ch == '"'
            quoted = false;
        end
    elseif ch == '"'
        quoted = true;
    elseif ch == '[' || ch == '{'
        depth = depth + 1;
    elseif ch == ']' || ch == '}'
        depth = depth - 1;
    elseif ch == ',' && depth == 0
        args{end+1} = jsondecode(body(start:i-1)); %#ok<AGROW>
        start = i + 1;
    end
end
args{end+1} = jsondecode(body(start:end));
end
