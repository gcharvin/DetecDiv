repoRoot = fileparts(mfilename('fullpath'));
detecdivRoot = fullfile(fileparts(repoRoot), 'DetecDiv');
detecdiv_setup_path(repoRoot, 'ResetPath', true, 'Verbose', true, 'DetecDivRoot', detecdivRoot);
detecdiv();
