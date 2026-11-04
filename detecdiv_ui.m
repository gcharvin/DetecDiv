function viewer = detecdiv_ui(project, varargin)
%DETECDIV_UI Launch the isolated unified-viewer prototype.
%   viewer = detecdiv_ui() opens an empty workspace.
%   viewer = detecdiv_ui(shallowObj) explores an existing project.
%   viewer = detecdiv_ui({projectA,projectB}) opens multiple projects.
%   viewer.addProject(projectC) adds another project to the same tree.
% Configure this worktree with detecdiv_setup_path before calling.
if nargin < 1, project = []; end
p = inputParser;
p.addParameter('Visible','on',@(x)any(strcmp(x,{'on','off'})));
p.addParameter('LayoutFile',fullfile(prefdir,'DetecDiv','ui-layout-r2026a.json'), ...
    @(x)ischar(x)||(isstring(x)&&isscalar(x)));
p.addParameter('AutoSaveLayout',true,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
viewer = detecdivui.Viewer(project,p.Results.Visible,p.Results.LayoutFile,p.Results.AutoSaveLayout);
end
