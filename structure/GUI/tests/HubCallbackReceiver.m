classdef HubCallbackReceiver < handle
    properties
        Payload = []
        Context = []
    end
    methods
        function receive(obj, payload, context)
            obj.Payload = payload;
            obj.Context = context;
        end
    end
end
