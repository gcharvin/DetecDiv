classdef MovieSnapshotSession < handle
    % Read-only, frame-bounded source adapter for an immutable export bundle.
    properties (SetAccess=private)
        Project
        Position=1
        Zone=1
    end
    properties (Access=private)
        Entry
        Folder
    end
    methods
        function obj=MovieSnapshotSession(entry,proxy,folder)
            obj.Entry=entry; obj.Folder=folder;
            obj.Project=shallow(); obj.Project.fov.id='Export snapshot'; obj.Project.fov.roi=proxy;
        end
        function [names,frames,descriptors]=dimensions(obj)
            names={obj.Entry.layers.name}; frames=obj.Entry.frameCount;
            descriptors=struct('name',{},'planes',{},'logicalId',{});
            for k=1:numel(names)
                descriptors(k)=struct('name',names{k},'planes',1:obj.Entry.planes(k),'logicalId',k);
            end
        end
        function plane=readPlane(obj,frame,channel)
            local=find(obj.Entry.frames==frame,1);
            assert(~isempty(local),'detecdivui:SnapshotFrame','Frame %d is not included in this immutable snapshot.',frame);
            plane=h5read(fullfile(obj.Folder,obj.Entry.asset),sprintf('/layer_%03d',channel), ...
                [1 1 1 local],[obj.Entry.height obj.Entry.width obj.Entry.planes(channel) 1]);
        end
    end
end
