function fig = annotationEditor(classif, roiIndex, session)
if nargin<2||isempty(roiIndex),roiIndex=1;end
if nargin<3,session=[];end
fig=dataseriesLSTMAnnotation(classif,roiIndex,session);
end
