function [counts, fig] = formattedTrainingSet(classif, varargin)
filename=fullfile(classif.path,'trainingdataset','lstm_timeseries_dataset.mat');
counts={};fig=[];if ~isfile(filename),return;end
s=load(filename,'dataset');d=s.dataset;
counts={'train',nnz(strcmp({d.samples.split},'train'));'validation',nnz(strcmp({d.samples.split},'val'))};
if any(strcmpi(string(varargin(cellfun(@(x)ischar(x)||isstring(x),varargin))),'Display'))
    fig=dataseriesLSTMTrainingPreview(d);
end
end
