function varargout = detecdiv_paths_relink_project(obj, varargin)
% Relink raw-data paths for all FOVs/channels in a project object.
% Fast mode by default (no recursive scan, no UI blocking).
%
% Usage:
%   report = detecdiv_paths_relink_project(obj) % UI prompt for RAWDATA folder
%   report = detecdiv_paths_relink_project(obj, rawRoot)
%   report = detecdiv_paths_relink_project(obj, rawRoot, 'Debug', true)
%   report = detecdiv_paths_relink_project(obj, rawRoot, 'Force', true)
%   report = detecdiv_paths_relink_project(obj, 'Debug', true) % UI + options
%   [obj, report] = detecdiv_paths_relink_project(obj, rawRoot) % legacy-compatible

rawRoot = "";
args = varargin;
if ~isempty(args)
    first = args{1};
    isNameToken = (ischar(first) || (isstring(first) && isscalar(first))) && ...
        any(strcmpi(string(first), ["Debug","Channels","Force"]));
    if ~isNameToken
        rawRoot = string(first);
        args = args(2:end);
    end
end

ip = inputParser;
ip.addParameter('Debug', false, @(x)islogical(x) || isnumeric(x));
ip.addParameter('Channels', [], @(x)isnumeric(x) || isempty(x));
ip.addParameter('Force', false, @(x)islogical(x) || isnumeric(x));
ip.parse(args{:});

debug = logical(ip.Results.Debug);
forceRebase = logical(ip.Results.Force);
channels = unique(double(ip.Results.Channels(:)'));
channels = channels(channels >= 1 & mod(channels,1)==0);

report = struct( ...
    'fovIndex', {}, ...
    'fovId', {}, ...
    'channel', {}, ...
    'ok', {}, ...
    'before', {}, ...
    'after', {}, ...
    'error', {});

if ~isprop(obj,'fov') || isempty(obj.fov)
    warning('No FOV available in project object.');
    varargout = localPackOutputs(obj, report, nargout);
    return;
end

if strlength(string(rawRoot)) == 0
    if ~usejava('desktop')
        warning('rawRoot is required in non-desktop mode.');
        varargout = localPackOutputs(obj, report, nargout);
        return;
    end
    [picked, okPick] = detecdiv_paths_prompt_root(string(pwd), "", "PROJECT");
    if ~okPick
        warning('Relink cancelled by user.');
        varargout = localPackOutputs(obj, report, nargout);
        return;
    end
    rawRoot = string(picked);
else
    rawRoot = string(rawRoot);
end

if ~isfolder(rawRoot)
    warning('Invalid RAWDATA folder: %s', rawRoot);
    varargout = localPackOutputs(obj, report, nargout);
    return;
end

% Register the chosen root once so future lazy checks can resolve quickly.
try
    userprefs = detecdiv_prefs_load();
    userprefs = detecdiv_paths_register_one(userprefs, rawRoot);
    if ~isfield(userprefs,'paths'), userprefs.paths = struct(); end
    if ~isfield(userprefs.paths,'rootCandidates')
        userprefs.paths.rootCandidates = {};
    end
    roots = unique([rawRoot; string(userprefs.paths.rootCandidates(:))], 'stable');
    userprefs.paths.rootCandidates = cellstr(roots);
    detecdiv_prefs_save(userprefs);
catch ME
    if debug
        fprintf('[paths] prefs update warning: %s\n', ME.message);
    end
end

nFov = numel(obj.fov);
for i = 1:nFov
    f = obj.fov(i);

    nChan = 1;
    if isprop(f,'channel'), nChan = max(nChan, numel(f.channel)); end
    if isprop(f,'srcpath'), nChan = max(nChan, numel(f.srcpath)); end
    if isprop(f,'tiffSource'), nChan = max(nChan, numel(f.tiffSource)); end
    if isempty(channels)
        chanList = 1:nChan;
    else
        chanList = channels(channels <= nChan);
        if isempty(chanList)
            chanList = 1:min(1,nChan);
        end
    end

    for ch = chanList
        rec.fovIndex = i;
        rec.fovId = f.id;
        rec.channel = ch;
        rec.ok = false;
        rec.before = char(localGetRawPointer(f, ch));
        rec.after = rec.before;
        rec.error = '';

        try
            [f, rec.ok] = detecdiv_paths_ensure_fov_ready(f, ch, debug, false, rawRoot, forceRebase);
            rec.after = char(localGetRawPointer(f, ch));
        catch ME
            rec.ok = false;
            rec.error = ME.message;
            if debug
                fprintf('[paths] relink error FOV %s ch=%d: %s\n', f.id, ch, ME.message);
            end
        end

        report(end+1) = rec; %#ok<AGROW>
    end

    obj.fov(i) = f;
end

if debug
    okCount = sum([report.ok]);
    fprintf('[paths] relink project done: %d/%d channel entries relinked or already valid\n', ...
        okCount, numel(report));
end

varargout = localPackOutputs(obj, report, nargout);
end

function p = localGetRawPointer(f, ch)
p = "";

isMT = isprop(f,'isMultiTiff') && f.isMultiTiff;
isND = isprop(f,'isNDTiff') && f.isNDTiff;

if isMT
    if ch <= numel(f.tiffSource) && ~isempty(f.tiffSource{ch})
        p = string(f.tiffSource{ch});
    elseif ~isempty(f.tiffSource)
        p = string(f.tiffSource{1});
    end
    return;
end

if isND
    if isprop(f,'ndtiffPath') && ~isempty(f.ndtiffPath)
        p = string(f.ndtiffPath);
    end
    return;
end

if iscell(f.srcpath) && ch <= numel(f.srcpath) && ~isempty(f.srcpath{ch})
    p = string(f.srcpath{ch});
end
end

function out = localPackOutputs(obj, report, nout)
if nout <= 0
    out = {};
elseif nout == 1
    out = {report};
else
    out = {obj, report};
end
end
