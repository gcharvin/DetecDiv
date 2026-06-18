function name = annotationChannelName(classif)
% Return the single indexed training-label channel used by DeepLab.

name = '';
try
    if ~isempty(classif) && isprop(classif, 'strid') && ~isempty(classif.strid)
        name = char(string(classif.strid));
    end
catch
end

if isempty(name)
    name = 'deeplab_pixels';
end
end
