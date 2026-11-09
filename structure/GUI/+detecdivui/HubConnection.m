classdef HubConnection < handle
    % Shared connection controller; credentials remain in existing Hub settings.
    properties (SetAccess=private)
        Connected=false
        User=struct()
        Targets=struct([])
        Message='Hub connection not checked'
    end
    properties
        OnChanged=[]
    end
    methods
        function connect(obj,parent)
            detecdiv_hub_connection_dialog(parent,@(~,~)obj.refresh());
        end
        function refresh(obj)
            try
                hub=detecdiv_hub_settings_get(); obj.User=detecdiv_hub_get_current_user(hub);
                obj.Targets=detecdiv_hub_list_execution_targets(hub);
                if iscell(obj.Targets), obj.Targets=[obj.Targets{:}]; end
                obj.Connected=true; obj.Message='Hub connected';
            catch err
                obj.Connected=false; obj.Message=err.message; obj.Targets=struct([]); obj.User=struct();
            end
            detecdivui.Callback.call(obj.OnChanged);
        end
        function logout(obj)
            [~,status]=detecdiv_hub_logout(); obj.Connected=false; obj.User=struct(); obj.Targets=struct([]);
            obj.Message='Hub disconnected';
            if ~isempty(status.message), obj.Message=[obj.Message ': ' status.message]; end
            detecdivui.Callback.call(obj.OnChanged);
        end
        function hub=settings(~)
            hub=detecdiv_hub_settings_get();
        end
        function [names,ids]=targetItems(obj)
            names={'Automatic'}; ids={''};
            for target=reshape(obj.Targets,1,[])
                if ~isfield(target,'supports_matlab')||~target.supports_matlab, continue; end
                label=char(string(target.display_name));
                if isfield(target,'status'), label=sprintf('%s · %s',label,char(string(target.status))); end
                names{end+1}=label; %#ok<AGROW>
                ids{end+1}=char(string(target.id)); %#ok<AGROW>
            end
        end
    end
end
