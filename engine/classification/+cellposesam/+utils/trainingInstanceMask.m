function mask = trainingInstanceMask(roiObj, classif, frame)
%TRAININGINSTANCEMASK Read the same GT binding as review and annotation tools.
gtName = cellposesam.annotationChannelName(classif);
classes = cellstr(string(classif.classes));
legacyNames = cellfun(@(name) [char(string(classif.strid)) '_' name], ...
    classes, 'UniformOutput', false);
channels = {gtName};
% Preserve historical multi-class mask merging when the selected GT is legacy.
legacy = any(strcmp(gtName, legacyNames));
if legacy, channels = legacyNames; end

mask = zeros(size(roiObj.image,1),size(roiObj.image,2),'uint16');
counter = uint16(0);
for index = 1:numel(channels)
    planes = roiObj.findChannelID(channels{index});
    if isempty(planes)
        if legacy, continue; end
        error('cellposesam:MissingGroundTruthChannel', ...
            ['Reviewed instance-mask channel "%s" is missing from ROI "%s". ' ...
             'Check the classifier GT binding and save its annotations before formatting.'], ...
            gtName,char(string(roiObj.id)));
    end
    labels = uint32(roiObj.image(:,:,planes,frame));
    maxId = max(labels(:));
    for id = 1:maxId
        pixels = labels == id;
        if any(pixels(:))
            counter = counter + 1;
            write = pixels & mask == 0;
            mask(write) = counter;
        end
    end
end
end
