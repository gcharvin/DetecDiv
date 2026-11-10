function supported=supportsCellFate(classif)
%SUPPORTSCELLFATE Semantic window labels, independent of class order/model size.
supported=false;
try
    if ~strcmpi(string(classif.classifierPkg),'lstm_timeseries'),return;end
    p=lstm_timeseries.parameters(classif);
    supported=strcmp(p.outputMode,'window')&&numel(classif.classes)==3&& ...
        all(ismember({'budding','arrested','dead'},cellstr(string(classif.classes))));
catch
end
end
