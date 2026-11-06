function result = startupGuard(action)
%STARTUPGUARD Defer menu polling during viewer construction or native teardown.
persistent depth
if isempty(depth), depth = 0; end
if nargin < 1, action = 'active'; end
switch action
    case 'begin'
        depth = depth+1;
        result = onCleanup(@()detecdivui.startupGuard('end'));
    case 'active'
        result = depth > 0;
    case 'end'
        depth = max(0,depth-1); result = [];
    otherwise
        error('detecdivui:StartupGuard','Unknown startup guard action.');
end
end
