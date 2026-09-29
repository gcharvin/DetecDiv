function mappings = detecdiv_paths_expand_windows_aliases(mappings, driveMappings)
% Add equivalent UNC/drive roots without replacing the configured preference.
% The optional OS snapshot makes alias expansion independently testable.

    if nargin < 2
        driveMappings = detecdiv_paths_windows_drive_mappings();
    end
    original = mappings;
    for i = 1:numel(original)
        root = regexprep(strrep(char(string(original(i).localRoot)), '/', '\'), '[\\/]+$', '');
        for j = 1:numel(driveMappings)
            drive = regexprep(strrep(char(string(driveMappings(j).driveRoot)), '/', '\'), '[\\/]+$', '');
            unc = regexprep(strrep(char(string(driveMappings(j).uncRoot)), '/', '\'), '[\\/]+$', '');
            alias = '';
            if hasRoot(root, drive)
                alias = [unc root(numel(drive)+1:end)];
            elseif hasRoot(root, unc)
                alias = [drive root(numel(unc)+1:end)];
                if endsWith(alias, ':'), alias = [alias '\']; end
            end
            if isempty(alias), continue; end
            mappings(end+1).localRoot = alias; %#ok<AGROW>
            mappings(end).remoteRoot = original(i).remoteRoot;
        end
    end
end

function tf = hasRoot(path, root)
    tf = ~isempty(root) && startsWith(path, root, 'IgnoreCase', true) && ...
        (numel(path) == numel(root) || any(path(numel(root)+1) == ['\' '/']));
end
