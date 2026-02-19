function [root, ok] = detecdiv_paths_prompt_root(defaultRoot, missingPath, fovId)
% Prompt user for a RAWDATA folder with an editable path field + Browse button.
% Returns:
%   root : selected/typed folder path (string)
%   ok   : true if validated by user and folder exists

root = "";
ok = false;

if nargin < 1 || strlength(string(defaultRoot)) == 0
    defaultRoot = string(pwd);
else
    defaultRoot = string(defaultRoot);
end
if nargin < 2, missingPath = ""; end
if nargin < 3, fovId = ""; end

if ~usejava('desktop')
    warning('No desktop UI available for RAWDATA path prompt.');
    return;
end

missingPath = string(missingPath);
fovId = string(fovId);

dlg = dialog( ...
    'Name', 'Relink RAWDATA Path', ...
    'Position', [300 300 780 240], ...
    'WindowStyle', 'modal', ...
    'Resize', 'off');

promptStr = "Enter a new RAWDATA folder path, or click Browse.";
if strlength(fovId) > 0 || strlength(missingPath) > 0
    promptStr = sprintf('FOV: %s\nMissing source:\n%s\n\n%s', ...
        char(fovId), char(missingPath), char(promptStr));
end

uicontrol(dlg, ...
    'Style', 'text', ...
    'Position', [20 140 740 80], ...
    'HorizontalAlignment', 'left', ...
    'String', promptStr);

hEdit = uicontrol(dlg, ...
    'Style', 'edit', ...
    'Position', [20 110 620 24], ...
    'HorizontalAlignment', 'left', ...
    'String', char(defaultRoot));

hStatus = uicontrol(dlg, ...
    'Style', 'text', ...
    'Position', [20 84 740 20], ...
    'HorizontalAlignment', 'left', ...
    'ForegroundColor', [0.8 0 0], ...
    'String', '');

uicontrol(dlg, ...
    'Style', 'pushbutton', ...
    'Position', [650 108 110 28], ...
    'String', 'Browse...', ...
    'Callback', @onBrowse);

uicontrol(dlg, ...
    'Style', 'pushbutton', ...
    'Position', [540 20 100 34], ...
    'String', 'Cancel', ...
    'Callback', @onCancel);

uicontrol(dlg, ...
    'Style', 'pushbutton', ...
    'Position', [650 20 110 34], ...
    'String', 'Use Path', ...
    'Callback', @onUsePath);

uiwait(dlg);

if ishghandle(dlg)
    if isappdata(dlg, 'selectedRoot')
        root = string(getappdata(dlg, 'selectedRoot'));
        ok = true;
    end
    delete(dlg);
end

    function onBrowse(~, ~)
        current = string(strtrim(hEdit.String));
        if strlength(current) == 0 || ~isfolder(current)
            current = defaultRoot;
        end
        if strlength(current) == 0 || ~isfolder(current)
            current = string(pwd);
        end

        picked = uigetdir(char(current), 'Select RAWDATA folder');
        if isequal(picked, 0)
            return;
        end

        hEdit.String = picked;
        hStatus.String = '';
    end

    function onCancel(~, ~)
        uiresume(dlg);
    end

    function onUsePath(~, ~)
        candidate = string(strtrim(hEdit.String));
        if strlength(candidate) == 0
            hStatus.String = 'Path is empty.';
            return;
        end
        if ~isfolder(candidate)
            hStatus.String = sprintf('Folder not found: %s', char(candidate));
            return;
        end

        setappdata(dlg, 'selectedRoot', char(candidate));
        uiresume(dlg);
    end
end
