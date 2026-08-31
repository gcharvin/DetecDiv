function [hub, connected] = detecdiv_hub_connection_dialog(parentFigure)
%detecdiv_hub_connection_dialog  Shared compact Hub connection editor.
%
% It deliberately uses the same persisted fields as pipeline2: URL,
% fallback URLs, user key, password, session token, timeout and project
% path roots.  Password is used only for the current login and is never
% saved in the Hub settings structure.

if nargin < 1, parentFigure = []; end
hub = detecdiv_hub_settings_get();
connected = false;
result = struct('hub', hub, 'connected', false, 'done', false);

pos = [100 100 560 355];
try
    if ~isempty(parentFigure) && isgraphics(parentFigure)
        p = parentFigure.Position; pos(1:2) = p(1:2) + [35 35];
    end
catch
end
fig = uifigure('Name', 'DetecDiv Hub connection', 'Position', pos, ...
    'WindowStyle', 'modal', 'Resize', 'off');
cleanup = onCleanup(@()localDelete(fig)); %#ok<NASGU>
grid = uigridlayout(fig, [10 3]);
grid.RowHeight = [repmat({28},1,8) {28} {32}];
grid.ColumnWidth = {104, '1x', 86};
grid.Padding = [12 12 12 12]; grid.RowSpacing = 6; grid.ColumnSpacing = 7;

labels = {'Hub URL','Fallback URLs','User key','Password','Session token','Timeout','Remote root','Local root'};
keys = {'baseUrl','fallbackBaseUrls','userKey','password','sessionToken','timeout','defaultRemoteProjectRoot','defaultLocalProjectRoot'};
fields = struct();
for i = 1:numel(keys)
    label = uilabel(grid, 'Text', labels{i}, 'HorizontalAlignment', 'right');
    label.Layout.Row = i; label.Layout.Column = 1;
    if strcmp(keys{i}, 'timeout')
        value = localTimeout(hub);
        field = uieditfield(grid, 'numeric', 'Value', value, 'Limits', [1 600]);
    else
        field = uieditfield(grid, 'text', 'Value', localInitialValue(hub, keys{i}));
    end
    field.Layout.Row = i; field.Layout.Column = 2;
    if strcmp(keys{i}, 'password')
        field.Value = '';
    end
    fields.(keys{i}) = field;
end
connectButton = uibutton(grid, 'push', 'Text', 'Connect', 'ButtonPushedFcn', @onConnect);
connectButton.Layout.Row = 4; connectButton.Layout.Column = 3;
status = uilabel(grid, 'Text', 'Not connected', 'FontColor', [0.45 0.45 0.45]);
status.Layout.Row = 9; status.Layout.Column = [1 3];
saveButton = uibutton(grid, 'push', 'Text', 'Save settings', 'ButtonPushedFcn', @onSave);
saveButton.Layout.Row = 10; saveButton.Layout.Column = 2;
cancelButton = uibutton(grid, 'push', 'Text', 'Cancel', 'ButtonPushedFcn', @onCancel);
cancelButton.Layout.Row = 10; cancelButton.Layout.Column = 3;

uiwait(fig);
hub = result.hub;
connected = result.connected;

    function onConnect(~, ~)
        try
            status.Text = 'Connecting…'; status.FontColor = [0.1 0.35 0.7]; drawnow;
            candidate = localReadFields();
            password = char(string(fields.password.Value));
            if ~isempty(strtrim(password))
                [~, candidate] = detecdiv_hub_login(candidate.userKey, password, candidate);
            end
            health = detecdiv_hub_request('GET', '/health', [], candidate); %#ok<NASGU>
            detecdiv_hub_settings_set(candidate);
            fields.password.Value = '';
            result.hub = candidate; result.connected = true;
            status.Text = 'Connected — settings saved.'; status.FontColor = [0.1 0.55 0.2];
        catch ME
            status.Text = ME.message; status.FontColor = [0.75 0.1 0.1];
        end
    end

    function onSave(~, ~)
        candidate = localReadFields();
        detecdiv_hub_settings_set(candidate);
        result.hub = candidate; result.done = true;
        uiresume(fig);
    end

    function onCancel(~, ~)
        result.done = true;
        uiresume(fig);
    end

    function candidate = localReadFields()
        candidate = hub;
        candidate.baseUrl = char(string(fields.baseUrl.Value));
        candidate.fallbackBaseUrls = localSplitUrls(fields.fallbackBaseUrls.Value);
        candidate.userKey = char(string(fields.userKey.Value));
        candidate.sessionToken = char(string(fields.sessionToken.Value));
        candidate.timeout = double(fields.timeout.Value);
        candidate.defaultRemoteProjectRoot = char(string(fields.defaultRemoteProjectRoot.Value));
        candidate.defaultLocalProjectRoot = char(string(fields.defaultLocalProjectRoot.Value));
    end
end

function value = localInitialValue(hub, key)
if strcmp(key, 'fallbackBaseUrls')
    value = strjoin(localSplitUrls(localField(hub, key, {})), ', ');
else
    value = char(string(localField(hub, key, '')));
end
end

function value = localTimeout(hub)
value = double(localField(hub, 'timeout', 20));
if ~isscalar(value) || ~isfinite(value), value = 20; end
end

function values = localSplitUrls(value)
if iscell(value), values = value; else, values = regexp(char(string(value)), '\s*,\s*', 'split'); end
values = values(~cellfun(@isempty, values));
end

function value = localField(S, key, fallback)
value = fallback;
if isstruct(S) && isfield(S, key) && ~isempty(S.(key)), value = S.(key); end
end

function localDelete(fig)
try, if isgraphics(fig), delete(fig); end, catch, end
end
