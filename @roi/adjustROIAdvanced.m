function adjustROIAdvanced(obj, varargin)
% Example:
%   adjustROIAdvanced(obj,'bbox',[0 0 w h], ...
%                        'keepChannels',{'phase','GFP'}, ...
%                        'keepDataseries',{'mean_fluo','divduration'});

    p = inputParser;
    addParameter(p,'bbox',[], @(x)isnumeric(x) && (numel(x)==4 || numel(x)==2));
    addParameter(p,'keepChannels',{}, @(c)iscellstr(c) || isstring(c));
    addParameter(p,'keepDataseries',{}, @(c)iscellstr(c) || isstring(c));
    parse(p,varargin{:});

    bbox         = p.Results.bbox;
    keepChannels = cellstr(p.Results.keepChannels);
    keepDS       = cellstr(p.Results.keepDataseries);

    % 1) resize : réutilise ton adjustROISize existant
    if ~isempty(bbox)
        obj.adjustROISize(bbox);
    end

    % 2) filtrage des channels (display.channel, channelid, etc.)
    %    -> à coder selon ta structure exacte

    % 3) filtrage des dataseries (obj.dataseries / obj.timeseries)
    %    -> idem
end
