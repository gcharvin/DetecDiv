function result = score_gui_layout(action)
%SCORE_GUI_LAYOUT Edit or apply the isolated App Designer source for score.
%   score_gui_layout              opens the design-only score.mlapp
%   score_gui_layout("edit")      same as above
%   score_gui_layout("apply")     builds the runtime score.mlapp
%   score_gui_layout("path")      returns the design file path

if nargin < 1 || isempty(action)
    action = "edit";
end
action = lower(string(action));

repoRoot = fileparts(mfilename('fullpath'));
layoutPath = fullfile(repoRoot, 'structure', 'GUI', 'score', ...
    'private', 'layout', 'score.mlapp');

switch action
    case {"edit", "open"}
        if exist(layoutPath, 'file') ~= 2
            error('score_gui_layout:MissingLayout', ...
                'Missing App Designer source: %s', layoutPath);
        end
        appdesigner(layoutPath);
        result = string(layoutPath);

    case {"apply", "sync"}
        result = sync_score_layout();

    case "path"
        result = string(layoutPath);

    otherwise
        error('score_gui_layout:BadAction', ...
            'Unknown action "%s". Use edit, apply, or path.', action);
end

if nargout == 0
    clear result
end
end
