function entries = workspaceObjects()
%WORKSPACEOBJECTS Snapshot supported live objects without loading or saving data.
entries = struct('object',{},'variables',{},'kind',{});
variables = evalin('base','whos');
classes = {'shallow','classi','process','pipeline'};
for k = 1:numel(variables)
    if ~ismember(variables(k).class,classes), continue; end
    try
        value = evalin('base',variables(k).name);
        for j = 1:numel(value)
            item = value(j);
            if ~isvalid(item), continue; end
            label = variables(k).name;
            if numel(value) > 1, label = sprintf('%s(%d)',label,j); end
            hit = [];
            for n = 1:numel(entries)
                if isequal(entries(n).object,item), hit = n; break; end
            end
            if isempty(hit)
                entries(end+1) = struct('object',item,'variables',{{label}}, ...
                    'kind',variables(k).class); %#ok<AGROW>
            else
                entries(hit).variables{end+1} = label;
            end
        end
    catch
        % A cleared/deleted workspace handle must not prevent other imports.
    end
end
end
