function pkglist = listDataloadingPackages()
% listDataloadingPackages  List available dataloading packages.

    str = which('shallowNew.m');
    [pth, ~, ~] = fileparts(str);
    rootPath = fullfile(pth, 'dataloading');

    if ~exist(rootPath, 'dir')
        pkglist = {};
        return;
    end

    pkgDirs = dir(fullfile(rootPath, '+*'));
    if isempty(pkgDirs)
        pkglist = {};
        return;
    end

    [~, idx] = sort({pkgDirs.name});
    pkgDirs = pkgDirs(idx);

    n = numel(pkgDirs);
    pkglist = cell(n,4);
    for k = 1:n
        pkgName = erase(pkgDirs(k).name, '+');
        pkglist{k,1} = k;
        pkglist{k,2} = pkgName;
        pkglist{k,3} = [pkgName ' dataloading'];
        pkglist{k,4} = inferDataloadingCategory(pkgName);
    end
end

function cat = inferDataloadingCategory(pkgName)
    switch lower(pkgName)
        case 'dataloader'
            cat = 'Loader';
        case 'roiidentify'
            cat = 'ROI';
        case 'roiextract'
            cat = 'ROI';
        otherwise
            cat = 'Pipeline';
    end
end
