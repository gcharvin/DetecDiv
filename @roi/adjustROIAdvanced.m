function adjustROIAdvanced(obj, varargin)
%ADJUSTROIADVANCED Ajuste une ROI en une seule opération (bbox, channels, dataseries, binning).

    p = inputParser;
    addParameter(p,'bbox',[], @(x)isnumeric(x) && (numel(x)==4 || numel(x)==2));
    addParameter(p,'keepChannels',{}, @(c)iscellstr(c) || isstring(c));
    addParameter(p,'keepDataseries',{}, @(c)iscellstr(c) || isstring(c));
    addParameter(p,'binning',[], @(x)isnumeric(x) && isscalar(x) && x>0);
    parse(p,varargin{:});

    bbox         = p.Results.bbox;
    keepChannels = cellstr(p.Results.keepChannels);
    keepDS       = cellstr(p.Results.keepDataseries);
    binning      = p.Results.binning;

    keepChannels = keepChannels(~cellfun(@isempty, keepChannels));
    keepDS       = keepDS(~cellfun(@isempty, keepDS));

    %% 1) Géométrie + binning => délégué à adjustROISize
    if ~isempty(bbox) || ~isempty(binning)
        if isempty(bbox)
            val = obj.value;
            if isempty(val)
                % fallback : ROI encore non initialisée => on fait rien
                val = [1 1 1 1];
            end
        else
            val = bbox;
        end

        if isempty(binning)
            obj.adjustROISize(val);
        else
            obj.adjustROISize(val, binning);
        end
    end

    %% 2) Filtrage des channels (via removeChannel)
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

    %% 3) Filtrage des dataseries dans obj.data (par groupid)
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

    %% 4) Logging (optionnel)
    try
        obj.log('ROI adjusted (bbox / channels / dataseries / binning)','Processing');
    catch
    end
end
