function adjustROIAdvanced(obj, varargin)
%ADJUSTROIADVANCED Ajuste une ROI en une seule opération
% (bbox, channels, dataseries, binning).
%
% Nouveauté :
%   'localCrop', true
%       -> bbox interprétée dans le référentiel LOCAL de la ROI
%          (patch obj.image), pas en coordonnées FOV

    % ------------------------------------------------------------
    % Parse inputs
    % ------------------------------------------------------------
    p = inputParser;
    addParameter(p,'bbox',[], @(x)isnumeric(x) && (numel(x)==4 || numel(x)==2));
    addParameter(p,'keepChannels',{}, @(c)iscellstr(c) || isstring(c));
    addParameter(p,'keepDataseries',{}, @(c)iscellstr(c) || isstring(c));
    addParameter(p,'binning',[], @(x)isnumeric(x) && isscalar(x) && x>0);
    addParameter(p,'localCrop',false, @(x)islogical(x) && isscalar(x));
    addParameter(p,'renameChannels',[], @(x) isempty(x) || isstruct(x) || isa(x,'containers.Map'));
    addParameter(p,'renameDataseries',[], @(x) isempty(x) || isstruct(x) || isa(x,'containers.Map'));
    addParameter(p,'frames',[], @(x)isnumeric(x) && (isempty(x) || isvector(x)));


    parse(p,varargin{:});

    bbox         = p.Results.bbox;
    keepChannels = cellstr(p.Results.keepChannels);
    keepDS       = cellstr(p.Results.keepDataseries);
    binning      = p.Results.binning;
    localCrop    = p.Results.localCrop;

    keepChannels = keepChannels(~cellfun(@isempty, keepChannels));
    keepDS       = keepDS(~cellfun(@isempty, keepDS));

    renameCh = p.Results.renameChannels;
    renameDS = p.Results.renameDataseries;

frames = p.Results.frames;
if ~isempty(frames)
    frames = unique(round(frames(:)'));
    frames = frames(frames>=1 & isfinite(frames));
end

    % ------------------------------------------------------------
    % 1) Géométrie + binning
    % ------------------------------------------------------------
    if ~isempty(bbox) || ~isempty(binning)

        if isempty(bbox)
            val = obj.value;
            if isempty(val)
                % ROI non initialisée → on ne fait rien
                val = [1 1 1 1];
            end
        else
            val = bbox;
        end

        % --- APPEL CLÉ ---
       if localCrop
    if isempty(binning)
        if isempty(frames)
            obj.adjustROISize(val, 'localCrop', true);
        else
            obj.adjustROISize(val, 'localCrop', true, 'frames', frames);
        end
    else
        if isempty(frames)
            obj.adjustROISize(val, binning, 'localCrop', true);
        else
            obj.adjustROISize(val, binning, 'localCrop', true, 'frames', frames);
        end
    end
else
            % comportement historique (bbox FOV ou centerMode)
            if isempty(binning)
                obj.adjustROISize(val);
            else
                obj.adjustROISize(val, binning);
            end
        end
    end

    % ------------------------------------------------------------
    % 2) Filtrage des channels
    % ------------------------------------------------------------
    if ~isempty(keepChannels)
        names = obj.display.channel;
        if ischar(names)
            names = {names};
        elseif isstring(names)
            names = cellstr(names);
        end

        if ~isempty(names)
            toKeep = intersect(names, keepChannels, 'stable');
            if ~isempty(toKeep)
                toDrop = setdiff(names, toKeep, 'stable');
                for i = 1:numel(toDrop)
                    obj.removeChannel(toDrop{i});
                end
            end
        end
    end

    % ------------------------------------------------------------
% 2bis) Rename channels (metadata)
% ------------------------------------------------------------
if ~isempty(renameCh)
    names = obj.display.channel;
    if ischar(names), names = {names}; end
    names = cellstr(names);

    for i = 1:numel(names)
        src = names{i};
        dst = localMapLookup(renameCh, src);
        if ~isempty(dst) && ~strcmp(dst, src)
            names{i} = dst;
        end
    end

    obj.display.channel = names;
end

    % ------------------------------------------------------------
    % 3) Filtrage des dataseries
    % ------------------------------------------------------------
    if ~isempty(keepDS) && ~isempty(obj.data)
        toRemove = [];
        for k = 1:numel(obj.data)
            gname = '';
            if isprop(obj.data(k),'groupid') && ~isempty(obj.data(k).groupid)
                gname = char(obj.data(k).groupid);
            end

            if isempty(gname) || ~ismember(gname, keepDS)
                toRemove(end+1) = k; %#ok<AGROW>
            end
        end

        if ~isempty(toRemove)
            obj.data(toRemove) = [];
        end
    end

    % ------------------------------------------------------------
% 3bis) Rename dataseries groupid (metadata)
% ------------------------------------------------------------
if ~isempty(renameDS) && ~isempty(obj.data)
    for k = 1:numel(obj.data)
        if isprop(obj.data(k),'groupid') && ~isempty(obj.data(k).groupid)
            src = char(obj.data(k).groupid);
            dst = localMapLookup(renameDS, src);
            if ~isempty(dst) && ~strcmp(dst, src)
                obj.data(k).groupid = dst;
            end
        end
    end
end


    % ------------------------------------------------------------
    % 4) Logging
    % ------------------------------------------------------------
    try
        obj.log('ROI adjusted (bbox / channels / dataseries / binning)', ...
                'Processing');
    catch
    end
end

% --- helper local ---
function dst = localMapLookup(mp, src)
dst = '';
if isempty(mp) || isempty(src), return; end
if isa(mp,'containers.Map')
    if isKey(mp, src), dst = mp(src); end
elseif isstruct(mp)
    % attend struct array avec fields src/dst
    if isfield(mp,'src') && isfield(mp,'dst')
        idx = find(strcmp({mp.src}, src), 1);
        if ~isempty(idx), dst = mp(idx).dst; end
    end
end
dst = strtrim(char(dst));
end
