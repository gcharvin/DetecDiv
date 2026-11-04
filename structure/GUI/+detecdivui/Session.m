classdef Session < handle
    % Navigation state and legacy data adapter, independent of UI handles.
    properties (SetAccess = private)
        Project = []
        Position = 0
        Zone = 0
    end
    methods
        function obj = Session(project)
            if nargin > 0, obj.setProject(project); end
        end
        function setProject(obj, project)
            assert(isa(project, 'shallow') && isscalar(project), ...
                'detecdivui:Project', 'An existing shallow project is required.');
            obj.Project = project;
            [~, indices] = obj.positionItems();
            obj.Position = 0;
            if ~isempty(indices), obj.Position = indices(1); end
            obj.Zone = 0;
        end
        function [labels, indices] = positionItems(obj)
            labels = {}; indices = [];
            if isempty(obj.Project), return; end
            for k = 1:numel(obj.Project.fov)
                p = obj.Project.fov(k);
                populated = strlength(string(p.id)) > 0 || ~isempty(p.channel) || ...
                    ~isempty(p.srclist) || any(strlength(string(p.srcpath)) > 0);
                if ~populated
                    for j = 1:numel(p.roi)
                        populated = obj.isZone(p.roi(j));
                        if populated, break; end
                    end
                end
                if populated
                    indices(end+1) = k; %#ok<AGROW>
                    labels{end+1} = obj.itemLabel('Position',k,p.id); %#ok<AGROW>
                end
            end
        end
        function [labels, indices] = zoneItems(obj)
            labels = {}; indices = [];
            if obj.Position == 0, return; end
            zones = obj.Project.fov(obj.Position).roi;
            for k = 1:numel(zones)
                if obj.isZone(zones(k))
                    indices(end+1) = k; %#ok<AGROW>
                    labels{end+1} = obj.itemLabel('Zone',k,zones(k).id); %#ok<AGROW>
                end
            end
        end
        function selectPosition(obj, index)
            [~, indices] = obj.positionItems();
            assert(isscalar(index) && any(index == indices), ...
                'detecdivui:Position', 'Position indisponible.');
            obj.Position = index; obj.Zone = 0;
        end
        function selectZone(obj, index)
            [~, indices] = obj.zoneItems();
            assert(obj.Position > 0 && isscalar(index) && any(index == [0 indices]), ...
                'detecdivui:Zone', 'Zone indisponible.');
            obj.Zone = index;
        end
        function [names, frames, channels] = dimensions(obj)
            names = {}; frames = 1;
            channels = struct('name',{},'planes',{});
            if obj.Position == 0, return; end
            position = obj.Project.fov(obj.Position);
            if obj.Zone == 0
                names = reshape(cellstr(string(position.channel)),1,[]);
                for k = 1:numel(names)
                    channels(k) = struct('name',names{k},'planes',k);
                end
                frames = position.frames;
                if isempty(frames) && ~isempty(position.srclist)
                    frames = cellfun(@numel,position.srclist);
                end
            else
                zone = position.roi(obj.Zone);
                obj.ensureZoneImages(zone);
                channels = obj.zoneChannels(zone);
                names = {channels.name};
                frames = size(zone.image,4);
            end
            frames = double(frames(:));
            frames = frames(isfinite(frames) & frames >= 1);
            if isempty(frames), frames = 1; else, frames = floor(max(frames)); end
        end
        function plane = readPlane(obj, frame, channel)
            [names, frames, channels] = obj.dimensions();
            assert(~isempty(names),'detecdivui:NoChannels', ...
                'Aucune image disponible pour cette position.');
            validateattributes(frame, {'numeric'}, {'scalar','integer','positive','<=',frames});
            validateattributes(channel, {'numeric'}, {'scalar','integer','positive','<=',numel(names)});
            position = obj.Project.fov(obj.Position);
            if obj.Zone == 0
                plane = readImage(position, frame, channel);
            else
                plane = position.roi(obj.Zone).image(:,:,channels(channel).planes,frame);
            end
        end
        function regions = referenceRegions(obj)
            % Same reference rectangles as workflow; no inferred drift/crop.
            regions = struct('index',{},'position',{},'label',{});
            [labels, indices] = obj.zoneItems();
            for k = 1:numel(indices)
                value = obj.Project.fov(obj.Position).roi(indices(k)).value;
                if isnumeric(value) && isvector(value) && numel(value) >= 4
                    value = double(reshape(value(1:4),1,[]));
                    if all(isfinite(value)) && all(value(3:4) > 0)
                        regions(end+1) = struct('index',indices(k), ...
                            'position',value,'label',labels{k}); %#ok<AGROW>
                    end
                end
            end
        end
        function text = breadcrumb(obj)
            if isempty(obj.Project), text = 'Votre espace de travail'; return; end
            name = string(obj.Project.io.file);
            if strlength(name) == 0, name = "Expérience"; end
            text = char(name);
            if obj.Position > 0
                p = obj.Project.fov(obj.Position);
                text = sprintf('%s  /  %s',text,obj.itemLabel('Position',obj.Position,p.id));
                if obj.Zone > 0
                    text = sprintf('%s  /  %s',text, ...
                        obj.itemLabel('Zone',obj.Zone,p.roi(obj.Zone).id));
                end
            end
        end
    end
    methods (Access = private)
        function ensureZoneImages(~, zone)
            if isempty(zone.image), zone.load('Data',false); end
            assert(~isempty(zone.image), 'detecdivui:MissingPixels', ...
                'Cette zone n''a pas de pixels extraits accessibles. Revenez à la position.');
        end
        function channels = zoneChannels(~, zone)
            count = size(zone.image,3);
            ids = zone.channelid;
            labels = {};
            if isstruct(zone.display) && isfield(zone.display,'channel')
                labels = cellstr(string(zone.display.channel));
            end
            channels = struct('name',{},'planes',{});
            if isnumeric(ids) && numel(ids) == count && ...
                    all(isfinite(ids) & ids >= 1 & ids == floor(ids))
                for id = reshape(unique(ids,'stable'),1,[])
                    planes = find(ids == id);
                    label = sprintf('Canal %d',id);
                    if id <= numel(labels) && ~isempty(labels{id}), label = labels{id}; end
                    if isscalar(planes) || numel(planes) == 3
                        channels(end+1) = struct('name',label,'planes',planes); %#ok<AGROW>
                    else
                        for j = 1:numel(planes)
                            channels(end+1) = struct('name',sprintf('%s · plan %d',label,j), ...
                                'planes',planes(j)); %#ok<AGROW>
                        end
                    end
                end
            else
                for k = 1:count
                    channels(k) = struct('name',sprintf('Plan %d',k),'planes',k);
                end
            end
        end
    end
    methods (Static, Access = private)
        function tf = isZone(zone)
            tf = strlength(string(zone.id)) > 0 || ~isempty(zone.value) || ~isempty(zone.image);
        end
        function label = itemLabel(kind,index,id)
            label = sprintf('%s %d',kind,index);
            if strlength(string(id)) > 0, label = sprintf('%s · %s',label,string(id)); end
        end
    end
end
