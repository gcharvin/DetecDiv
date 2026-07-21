function ensureClassMetadata(classif)
% trackastra.ensureClassMetadata  Keep Trackastra classifier metadata stable.

if isempty(classif)
    return;
end
try
    titleText = 'Trackastra cell tracking';
    detailText = 'Trackastra linker and trainable temporal association model.';
    userComment = '';
    previousDescription = classif.description;
    if iscell(previousDescription)
        if numel(previousDescription) >= 3
            userComment = previousDescription{2};
        elseif numel(previousDescription) == 2
            % Migrate classifiers created by the initial Trackastra package,
            % which incorrectly stored the package details in slot 2.
            secondText = lower(strtrim(char(string(previousDescription{2}))));
            isOldPackageDetail = contains(secondText, 'trackastra') || ...
                contains(secondText, 'stable temporal tracklets');
            if ~isOldPackageDetail
                userComment = previousDescription{2};
            end
        end
    end
    if (ischar(userComment) || isstring(userComment)) && ...
            strcmp(strtrim(char(string(userComment))), '-')
        userComment = '';
    end

    classif.classifierPkg = 'trackastra';
    classif.trainingFun = 'trackastra.train';
    classif.classifyFun = 'trackastra.classify';
    classif.category = {'Pixel'};
    classif.classes = {'tracklet'};
    % classifierGUI relies on this legacy three-slot description contract:
    % {classifier type, user comment, package details}.
    classif.description = {titleText, userComment, detailText};
    classif.outputType = 'segmentation';
    if isempty(classif.colormap) || size(classif.colormap,1) < 2
        classif.colormap = shallowColormap(1);
    end
catch
end
end
