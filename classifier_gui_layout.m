function result = classifier_gui_layout(action)
%CLASSIFIER_GUI_LAYOUT Edit or apply the isolated classifierGUI layout.
%   classifier_gui_layout("edit") opens the design-only .mlapp.
%   classifier_gui_layout("apply") rebuilds the runtime .mlapp.
%   classifier_gui_layout("path") returns the design source path.

if nargin < 1 || isempty(action)
    action = "edit";
end
action = lower(string(action));

repoRoot = fileparts(mfilename('fullpath'));
layoutPath = fullfile(repoRoot, 'structure', 'GUI', 'classifier', ...
    'private', 'layout', 'classifierGUI.mlapp');

switch action
    case {"edit", "open"}
        if exist(layoutPath, 'file') ~= 2
            error('classifier_gui_layout:MissingLayout', ...
                'Missing App Designer source: %s', layoutPath);
        end
        appdesigner(layoutPath);
        result = string(layoutPath);
    case {"apply", "sync"}
        result = sync_classifier_layout();
    case "path"
        result = string(layoutPath);
    otherwise
        error('classifier_gui_layout:BadAction', ...
            'Unknown action "%s". Use edit, apply, or path.', action);
end

if nargout == 0
    clear result
end
end
