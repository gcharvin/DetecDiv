function removeClassification(obj,id)
% removes a classification of an exisiting project
% id specifies the item to be removed

if id<length(obj.processing.classification)
    obj.processing.classification=[obj.processing.classification(1:id-1) obj.processing.classification(id+1:end)];
end

if id==length(obj.processing.classification)
    obj.processing.classification=obj.processing.classification(1:end-1);
end

