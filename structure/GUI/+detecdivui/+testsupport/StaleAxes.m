classdef StaleAxes < handle
    % Destroy a native container between the listener's guard and its use.
    properties (Dependent)
        InteractionContainer
    end
    properties (Access = private)
        NativeContainer
        Reads = 0
    end
    methods
        function obj = StaleAxes(interaction)
            obj.NativeContainer = interaction;
        end
        function value = get.InteractionContainer(obj)
            obj.Reads = obj.Reads+1;
            value = obj.NativeContainer;
            if obj.Reads == 3, delete(value); end
        end
    end
end
