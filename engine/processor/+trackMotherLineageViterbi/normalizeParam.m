function paramout = normalizeParam(param)
% trackMotherLineageViterbi.normalizeParam  Normalize legacy and ctx params.

if nargin < 1 || isempty(param)
    paramout = trackMotherLineageViterbi.setparam(struct());
    return;
end

paramout = param;

if isfield(paramout, 'inputChannelName') && ~isfield(paramout, 'instanceChannelName')
    paramout.instanceChannelName = paramout.inputChannelName;
end
if isfield(paramout, 'input_channel_name') && ~isfield(paramout, 'instanceChannelName')
    paramout.instanceChannelName = paramout.input_channel_name;
end
if isfield(paramout, 'outputName') && ~isfield(paramout, 'outputChannelName')
    paramout.outputChannelName = paramout.outputName;
end
if isfield(paramout, 'output_channel_name') && ~isfield(paramout, 'outputChannelName')
    paramout.outputChannelName = paramout.output_channel_name;
end

if ~isfield(paramout, 'instanceChannelName') || isempty(paramout.instanceChannelName)
    paramout.instanceChannelName = {'N/A'};
end
if ischar(paramout.instanceChannelName) || isstring(paramout.instanceChannelName)
    paramout.instanceChannelName = {char(string(paramout.instanceChannelName))};
end

if ~isfield(paramout, 'mode') || isempty(paramout.mode)
    paramout.mode = {'mother_trap'};
end
if ischar(paramout.mode) || isstring(paramout.mode)
    paramout.mode = {char(string(paramout.mode))};
end

if ~isfield(paramout, 'outputChannelName') || isempty(paramout.outputChannelName)
    paramout.outputChannelName = 'MotherLineageViterbi';
end
paramout.outputChannelName = char(string(paramout.outputChannelName));

if ~isfield(paramout, 'existingPolicy') || isempty(paramout.existingPolicy)
    paramout.existingPolicy = 'replace';
end
if ~isfield(paramout, 'debug')
    paramout.debug = true;
end
end
