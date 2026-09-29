function mappings = detecdiv_paths_windows_drive_mappings(refresh)
% Network drive identities in the current Windows logon session.
% Cache the OS query; never infer a share from a drive letter or folder name.

    persistent cachedMappings cacheStarted
    if nargin < 1, refresh = false; end
    mappings = struct('driveRoot', {}, 'uncRoot', {});
    if ~ispc, return; end
    if ~refresh && ~isempty(cacheStarted) && toc(cacheStarted) < 30
        mappings = cachedMappings;
        return;
    end
    cachedMappings = mappings;
    cacheStarted = tic;
    script = ['try { Get-SmbMapping -ErrorAction Stop | ' ...
        'Select-Object @{Name=''driveRoot'';Expression={$_.LocalPath}},' ...
        '@{Name=''uncRoot'';Expression={$_.RemotePath}} | ConvertTo-Json -Compress } ' ...
        'catch { Get-CimInstance Win32_LogicalDisk -Filter ''DriveType=4'' | ' ...
        'Select-Object @{Name=''driveRoot'';Expression={$_.DeviceID}},' ...
        '@{Name=''uncRoot'';Expression={$_.ProviderName}} | ConvertTo-Json -Compress }'];
    try
        [status, output] = system(['powershell.exe -NoLogo -NoProfile -NonInteractive -Command "' script '"']);
        if status ~= 0 || isempty(strtrim(output)), return; end
        entries = jsondecode(output);
        for i = 1:numel(entries)
            drive = char(string(entries(i).driveRoot));
            unc = strrep(char(string(entries(i).uncRoot)), '/', '\');
            if isempty(regexp(drive, '^[A-Za-z]:[\\/]*$', 'once')) || ...
                    isempty(regexp(unc, '^\\\\[^\\]+\\[^\\]+', 'once'))
                continue;
            end
            mappings(end+1) = struct('driveRoot', [drive(1:2) '\'], ...
                'uncRoot', regexprep(unc, '[\\/]+$', '')); %#ok<AGROW>
        end
    catch
        % Explicit client mappings still work if OS discovery is unavailable.
    end
    cachedMappings = mappings;
end
