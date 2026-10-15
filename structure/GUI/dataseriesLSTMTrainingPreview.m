function fig = dataseriesLSTMTrainingPreview(dataset)
%DATASERIESLSTMTRAININGPREVIEW Inspect exactly the numeric training sequences.
fig=figure('Name','Formatted numeric LSTM sequences','NumberTitle','off');
count=min(9,numel(dataset.samples));layout=tiledlayout(fig,ceil(count/3),min(count,3));
for k=1:count
    s=dataset.samples(k);ax=nexttile(layout);plot(ax,s.frames,s.X');
    title(ax,sprintf('%s / %s: %s',s.split,s.roiId,strjoin(unique(string(s.Y)),', ')),'Interpreter','none');
    xlabel(ax,'Absolute ROI frame');ylabel(ax,'Input value');
end
end
