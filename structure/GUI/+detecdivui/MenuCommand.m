classdef MenuCommand < handle
    % Menu state shared by the MATLAB controller and desktop menu adapter.
    properties
        Id
        Text
        Enable = 'on'
        Checked = 'off'
        Accelerator = ''
        Separator = 'off'
        MenuSelectedFcn = []
        Children = {}
    end
    methods
        function obj = MenuCommand(id,text,varargin)
            obj.Id = id; obj.Text = text;
            for k = 1:2:numel(varargin)
                name = varargin{k};
                assert(isprop(obj,name),'detecdivui:MenuProperty','Unknown menu property.');
                obj.(name) = varargin{k+1};
            end
        end
        function invoke(obj)
            if strcmp(obj.Enable,'on') && ~isempty(obj.MenuSelectedFcn)
                obj.MenuSelectedFcn(obj,[]);
            end
        end
        function data = serialize(obj)
            data = struct('id',obj.Id,'text',obj.Text, ...
                'enabled',strcmp(obj.Enable,'on'),'checked',strcmp(obj.Checked,'on'), ...
                'accelerator',obj.Accelerator,'separator',strcmp(obj.Separator,'on'), ...
                'children',{{}});
            data.children = cellfun(@(item)item.serialize(),obj.Children,'UniformOutput',false);
        end
    end
end
