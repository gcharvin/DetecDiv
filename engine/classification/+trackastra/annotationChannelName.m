function channelName = annotationChannelName(classif)
% trackastra.annotationChannelName  Canonical editable tracking-GT channel.

classifierId = '';
try
    classifierId = strtrim(char(string(classif.strid)));
catch
end

className = 'tracklet';
try
    classes = classif.classes;
    if ischar(classes) || isstring(classes)
        classes = cellstr(string(classes));
    end
    if iscell(classes) && ~isempty(classes)
        candidate = strtrim(char(string(classes{1})));
        if ~isempty(candidate)
            className = candidate;
        end
    end
catch
end

if isempty(classifierId)
    channelName = '';
else
    channelName = [classifierId '_' className];
end
end
