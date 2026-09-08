function output = formatPixelTrainingSetCPSAM(foldername, classif, trainrois, ~, varargin)
% formatPixelTrainingSetCPSAM  Legacy entry point for CellposeSAM formatting.
%
% The implementation lives in the cellposesam package so GUI fallback and
% pipeline execution share the same variable-size ROI framebank contract.

if nargin < 1 || isempty(foldername)
    foldername = 'trainingdataset';
end
if nargin < 3 || isempty(trainrois)
    trainrois = classif.trainingset;
end

p = inputParser;
p.addParameter('Frames', [], @(x) isempty(x) || isnumeric(x) || islogical(x) || ...
    ischar(x) || isstring(x) || iscell(x) || isstruct(x));
p.parse(varargin{:});

ctx = struct();
ctx.params = struct('foldername', foldername, 'Frames', p.Results.Frames);
out = cellposesam.format(classif, trainrois, ctx);

output = 0;
if isstruct(out) && isfield(out, 'metrics') && isfield(out.metrics, 'outputCount')
    output = out.metrics.outputCount;
end

end
