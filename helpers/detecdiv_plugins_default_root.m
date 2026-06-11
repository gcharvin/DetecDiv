function rootDir = detecdiv_plugins_default_root()
%DETECDIV_PLUGINS_DEFAULT_ROOT Return the conventional sibling plugin repo.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
rootDir = fullfile(fileparts(repoRoot), 'DetecDiv-plugins');
end

