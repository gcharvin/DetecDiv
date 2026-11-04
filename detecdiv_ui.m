function viewer = detecdiv_ui(project, varargin)
%DETECDIV_UI Launch the isolated unified-viewer prototype.
%   viewer = detecdiv_ui() opens an empty workspace.
%   viewer = detecdiv_ui(shallowObj) explores an existing project.
% Configure this worktree with detecdiv_setup_path before calling.
if nargin < 1, project = []; end
p = inputParser;
p.addParameter('Visible','on',@(x)any(strcmp(x,{'on','off'})));
p.parse(varargin{:});
viewer = detecdivui.Viewer(project,p.Results.Visible);
end
