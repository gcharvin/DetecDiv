function note = detecdiv_hub_create_project_note(projectId, noteText, isPinned, hubSettings)
% detecdiv_hub_create_project_note  Create one note on a hub project.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_create_project_note:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || strlength(string(noteText)) == 0
        error('detecdiv_hub_create_project_note:MissingNoteText', ...
            'Note text cannot be empty.');
    end
    if nargin < 3 || isempty(isPinned)
        isPinned = false;
    end
    if nargin < 4 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = ['/projects/' char(string(projectId)) '/notes'];
    payload = struct( ...
        'note_text', char(string(noteText)), ...
        'is_pinned', logical(isPinned));
    note = detecdiv_hub_write_json(endpoint, payload, hubSettings);
end
