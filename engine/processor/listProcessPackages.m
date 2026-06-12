function processlist = listProcessPackages()
% listProcessPackages  Build processor list from package folders.

    % Use this file location as canonical processor root.
    rootPath = fileparts(mfilename('fullpath'));

    if ~exist(rootPath, 'dir')
        processlist = {};
        return;
    end

    pkgDirs = dir(fullfile(rootPath, '+*'));
    if isempty(pkgDirs)
        % fallback to legacy processlist.mat if it exists
        procListFile = fullfile(rootPath, 'processlist.mat');
        if exist(procListFile, 'file')
            s = load(procListFile, 'processlist');
            processlist = s.processlist;
        else
            processlist = {};
        end
        return;
    end

    [~, idx] = sort({pkgDirs.name});
    pkgDirs = pkgDirs(idx);

    n = numel(pkgDirs);
    processlist = cell(n,5);
    for k = 1:n
        pkgName = erase(pkgDirs(k).name, '+');
        processlist{k,1} = k;
        processlist{k,2} = pkgName;
        processlist{k,3} = [pkgName ' processor'];
        processlist{k,4} = inferProcessCategory(pkgName);
        processlist{k,5} = {[pkgName '.process']};
    end
end

function cat = inferProcessCategory(pkgName)
    switch lower(pkgName)
        case 'combinemultiplechannels'
            cat = 'Image';
        case {'basicobjecttracking','trackmotherlineageviterbi'}
            cat = 'Tracking';
        case {'computemetrics','computerls','computelineage','formatindataseries','singlecelloscillations'}
            cat = 'Processing';
        case 'computemaxprojection'
            cat = 'Image';
        otherwise
            cat = 'Image';
    end
end
