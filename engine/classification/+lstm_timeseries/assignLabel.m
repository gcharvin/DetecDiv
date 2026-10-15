function frames = assignLabel(classif, roiIndex, label, currentFrame, varargin)
%ASSIGNLABEL Shared numeric annotation edit, independent from any GUI.
p=inputParser;p.addParameter('Frames',[],@isnumeric);p.addParameter('Save',true,@islogical);p.parse(varargin{:});
r=classif.roi(roiIndex);classifierBinding.numericSeries(r);
session=classif.annotationSession(roiIndex);n=annotationManager.frameCount(r);
index=find(strcmp({r.data.groupid},classif.strid),1);
if isempty(index)||~ismember('labels_training',r.data(index).data.Properties.VariableNames)
    session.startBlank('Save',false);
end
[frames,grouped]=lstm_timeseries.annotationFrames(classif,r,currentFrame,n);
if ~grouped&&~isempty(p.Results.Frames)
    frames=intersect(p.Results.Frames,trainingBounds.frames(classif,roiIndex,n,[]),'stable');
end
assert(~isempty(frames),'lstm_timeseries:IncompleteWindow','Select a frame inside a complete annotation unit and the training bounds.');
annotationManager.assignFrameLabel(r,classif.strid,classif.classes,label,frames);
session.markChanged('Frames',frames,'Save',p.Results.Save);
if any(strcmpi(string(label),["undefined","unclassified","", "<undefined>"]))
    session.markUnreviewed('Frames',frames,'Save',p.Results.Save);
end
% roi.save intentionally purges data; keep the annotation editor cache usable.
if p.Results.Save,r.load('Data','Silent');end
end
