function ensureClassMetadata(c)
comment='';try,comment=c.description{2};catch,end
c.classifierPkg='lstm_timeseries';c.trainingFun='lstm_timeseries.train';
c.classifyFun='lstm_timeseries.classify';c.category={'LSTM'};
c.channel=[];c.channelName={};
if isstruct(c.dataset),c.dataset.channels={};end
c.description={'Numeric dataseries LSTM',comment, ...
    'LSTM classification from numeric ROI dataseries; reviewed frame, window or video labels.'};
end
