classdef Session < handle
    % Navigation state and legacy data adapter, independent of UI handles.
    properties (SetAccess = private)
        Project = []
        Position = 1
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
            obj.Position = 1;
            obj.Zone = 0;
        end
        function selectPosition(obj, index)
            validateattributes(index, {'numeric'}, {'scalar','integer','positive', ...
                '<=',numel(obj.Project.fov)});
            obj.Position = index;
            obj.Zone = 0;
        end
        function selectZone(obj, index)
            validateattributes(index, {'numeric'}, {'scalar','integer','nonnegative', ...
                '<=',numel(obj.Project.fov(obj.Position).roi)});
            obj.Zone = index;
        end
        function [names, frames] = dimensions(obj)
            if isempty(obj.Project), names = {}; frames = 1; return; end
            position = obj.Project.fov(obj.Position);
            if obj.Zone == 0
                names = cellstr(string(position.channel));
                frames = position.frames;
            else
                zone = position.roi(obj.Zone);
                obj.ensureZoneImages(zone);
                % Initial prototype exposes stored image planes individually.
                names = cellstr(compose('Plan %d', 1:size(zone.image,3)));
                frames = size(zone.image,4);
            end
            frames = double(frames(:));
            frames = frames(isfinite(frames) & frames >= 1);
            if isempty(frames), frames = 1; else, frames = floor(max(frames)); end
        end
        function plane = readPlane(obj, frame, channel)
            [names, frames] = obj.dimensions();
            validateattributes(frame, {'numeric'}, {'scalar','integer','positive','<=',frames});
            validateattributes(channel, {'numeric'}, {'scalar','integer','positive','<=',numel(names)});
            position = obj.Project.fov(obj.Position);
            if obj.Zone == 0
                plane = readImage(position, frame, channel);
            else
                plane = position.roi(obj.Zone).image(:,:,channel,frame);
            end
        end
        function text = breadcrumb(obj)
            if isempty(obj.Project), text = 'Ouvrir une expérience pour commencer'; return; end
            name = string(obj.Project.io.file);
            if strlength(name) == 0, name = "Expérience"; end
            text = sprintf('%s > Position %d', name, obj.Position);
            if obj.Zone > 0, text = sprintf('%s > Zone %d', text, obj.Zone); end
        end
    end
    methods (Access = private)
        function ensureZoneImages(~, zone)
            if isempty(zone.image)
                % Use existing extraction loading; never save or extract here.
                zone.load('Data', false);
            end
            assert(~isempty(zone.image), 'detecdivui:MissingPixels', ...
                'Cette zone ne contient pas de pixels extraits. Revenez à la position.');
        end
    end
end
