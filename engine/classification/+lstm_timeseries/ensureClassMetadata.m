function ensureClassMetadata(c)
comment='';try,comment=c.description{2};catch,end
c.classifierPkg='lstm_timeseries';c.trainingFun='lstm_timeseries.train';
c.classifyFun='lstm_timeseries.classify';c.category={'LSTM'};
c.channel=[];c.channelName={};
if isstruct(c.dataset),c.dataset.channels={};end
architecture='LSTM';
try
    selected=c.trainingParam.networkArchitecture;if iscell(selected),selected=selected{end};end
    if strcmp(selected,'tcn'),architecture='TCN';end
catch
end
c.description={['Numeric dataseries ' architecture],comment, ...
    'Numeric sequence classification with reviewed labels; LSTM or window TCN architecture.'};
try
    scope=c.trainingParam.sequenceScope;if iscell(scope),scope=scope{end};end
    if strcmp(scope,'trajectory'),c.description{1}='Numeric LSTM — continuous ROI trajectory';end
catch
end
end
