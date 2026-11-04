classdef Callback
    % Named inter-widget dispatch, without retaining anonymous source locations.
    properties (SetAccess = private)
        Owner
        Method
        Args
    end
    methods
        function obj = Callback(owner,method,varargin)
            obj.Owner = owner; obj.Method = char(method); obj.Args = varargin;
        end
    end
    methods (Static)
        function event(~,~,callback)
            detecdivui.Callback.call(callback);
        end
        function varargout = call(callback,varargin)
            varargout = cell(1,nargout);
            if isempty(callback), return; end
            if isa(callback,'detecdivui.Callback')
                owner = callback.Owner;
                if isempty(owner) || ~isa(owner,'handle') || ~isscalar(owner) || ~isvalid(owner), return; end
                if nargout
                    [varargout{:}] = feval(callback.Method,owner,callback.Args{:},varargin{:});
                else
                    feval(callback.Method,owner,callback.Args{:},varargin{:});
                end
            else
                assert(isa(callback,'function_handle'),'detecdivui:Callback','Expected a callback descriptor or function handle.');
                if nargout, [varargout{:}] = callback(varargin{:});
                else, callback(varargin{:}); end
            end
        end
    end
end
