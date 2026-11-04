function viewer = detecdiv_ui(project, varargin)
%DETECDIV_UI Launch the isolated unified-viewer prototype.
%   viewer = detecdiv_ui() discovers live DetecDiv objects in the base workspace.
%   viewer = detecdiv_ui([]) opens an empty viewer without discovery.
%   viewer = detecdiv_ui(shallowObj) explores an existing project.
%   viewer = detecdiv_ui({projectA,projectB}) opens multiple projects.
%   viewer.addProject(projectC) adds another project to the same tree.
% Configure this worktree with detecdiv_setup_path before calling.
discover = nargin < 1;
if discover, project = []; end
p = inputParser;
p.addParameter('Visible','on',@(x)any(strcmp(x,{'on','off'})));
p.addParameter('LayoutFile',fullfile(prefdir,'DetecDiv','ui-layout-r2026a.json'), ...
    @(x)ischar(x)||(isstring(x)&&isscalar(x)));
p.addParameter('AutoSaveLayout',true,@(x)islogical(x)&&isscalar(x));
p.addParameter('DiscoverWorkspace',discover,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
viewer = detecdivui.Viewer(project,p.Results.Visible,p.Results.LayoutFile,p.Results.AutoSaveLayout);
try
    if p.Results.DiscoverWorkspace, viewer.refreshWorkspace(); end
catch err
    delete(viewer); % Do not leave an orphaned window/menu timer after import fails.
    rethrow(err);
end
end
