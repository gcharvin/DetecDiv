function [classifier, model] = loadModel(classif)
filename=fullfile(classif.path,[classif.strid '.mat']);
assert(isfile(filename),'lstm_timeseries:NoModel','Train the numeric LSTM before inference: %s',filename);
s=load(filename,'classifier','model');
assert(isfield(s,'classifier')&&isfield(s,'model')&&s.model.schemaVersion==1&&strcmp(s.model.module,'lstm_timeseries'), ...
    'lstm_timeseries:InvalidModel','Model must contain a trained LSTM and its frozen feature normalization/schema.');
classifier=s.classifier;model=s.model;
end
