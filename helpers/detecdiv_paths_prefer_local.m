function pathOut = detecdiv_paths_prefer_local(pathIn, hub)
% Prefer this client's configured view of a shared path, even if UNC exists.
% Only adopt a usable equivalent; unrelated and unavailable paths are retained.

    pathOut = char(string(pathIn));
    if isempty(pathOut), return; end
    if nargin < 2, hub = detecdiv_hub_settings_get(); end
    [candidate, ~] = detecdiv_hub_apply_path_mapping(pathOut, hub);
    if ~isempty(candidate) && ~strcmp(candidate, pathOut) && ...
            (isfolder(candidate) || isfile(candidate))
        pathOut = candidate;
    end
end
