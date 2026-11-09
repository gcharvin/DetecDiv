function c = classifierTrainingRoiContext(c,reference,selectedRois)
%CLASSIFIERTRAININGROICONTEXT Retain identities owned by formatted datasets.
canonical=~isempty(reference)&&(strcmpi(c.classifierPkg,'lstm_timeseries')||cnn_lstm.isFrozenEncoder(c));
if canonical
    c.roi=reference.roi;
    c.dataset=reference.dataset;
    c.trainingset=reference.dataset.split.train;
    c.bounds=reference.bounds;
else
    c.roi=selectedRois;c.trainingset=1:numel(selectedRois);
    dataset=c.dataset;if ~isstruct(dataset),dataset=struct();end
    dataset.classes=c.classes;
    dataset.split=struct('train',1:numel(selectedRois),'val',[],'test',[]);
    c.dataset=dataset;
end
end
