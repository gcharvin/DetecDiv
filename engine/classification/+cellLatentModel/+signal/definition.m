function def = definition(name, task, varargin)
%CELLLATENTMODEL.SIGNAL.DEFINITION Define a custom fluorescence head.
% TASK is classification, regression, or segmentation. The head is an
% independently trainable temporal adapter over frozen latent tracking
% features; its input channels are user-defined biological observations.

p=inputParser;
p.addParameter('Channels',{},@(x)ischar(x)||isstring(x)||iscell(x));
p.addParameter('Family','',@(x)ischar(x)||isstring(x)||isnumeric(x));
p.addParameter('Classes',{},@(x)isnumeric(x)||ischar(x)||isstring(x)||iscell(x));
p.addParameter('ValueRange',[-Inf Inf],@(x)isnumeric(x)&&numel(x)==2&&x(1)<=x(2));
p.addParameter('TemporalContext',true,@(x)islogical(x)&&isscalar(x));
p.addParameter('Description','',@(x)ischar(x)||isstring(x));
p.addParameter('GroundTruthGroup','',@(x)ischar(x)||isstring(x));
p.addParameter('GroundTruthChannel','',@(x)ischar(x)||isstring(x));
p.parse(varargin{:});
name=char(string(name)); task=lower(char(string(task)));
if isempty(name), error('cellLatentModel:SignalNameRequired','Signal head name is required.'); end
if ~ismember(task,{'classification','regression','segmentation'})
    error('cellLatentModel:InvalidSignalTask','Task must be classification, regression, or segmentation.');
end
channels=normalizeTextList(p.Results.Channels);
if isempty(channels), error('cellLatentModel:SignalChannelsRequired','At least one raw input channel is required.'); end
classes=normalizeClasses(p.Results.Classes);
if strcmp(task,'classification') && numel(classes)<2
    error('cellLatentModel:SignalClassesRequired','Classification requires at least two classes.');
elseif strcmp(task,'segmentation') && isempty(classes)
    classes={'signal'};
end
safe=matlab.lang.makeValidName(lower(name));
group=char(string(p.Results.GroundTruthGroup));
if isempty(group), group=['latent_signal_gt_' safe]; end
channel=char(string(p.Results.GroundTruthChannel));
if isempty(channel), channel=['annotations_latent_signal_' safe]; end
valueField='Value';
if strcmp(task,'classification'), valueField='Label'; end
def=struct( ...
    'format','detecdiv_latent_signal_definition', ...
    'schema_version',uint16(1), ...
    'name',name, ...
    'task',task, ...
    'channels',{channels}, ...
    'family',p.Results.Family, ...
    'classes',{classes}, ...
    'value_range',double(p.Results.ValueRange(:).'), ...
    'temporal_context',logical(p.Results.TemporalContext), ...
    'description',char(string(p.Results.Description)), ...
    'ground_truth_group',group, ...
    'ground_truth_channel',channel, ...
    'value_field',valueField, ...
    'target_unit',targetUnit(task), ...
    'training_policy',struct( ...
        'freeze_tracking',true, ...
        'freeze_parentage',true, ...
        'independent_head_training',true, ...
        'may_change_parentage',false));
end

function values=normalizeTextList(value)
if isempty(value)
    values={};
elseif ischar(value)||isstring(value)
    values=cellstr(string(value));
else
    values=cellfun(@(x)char(string(x)),value,'UniformOutput',false);
end
values=reshape(values,1,[]);
end

function classes=normalizeClasses(value)
if isnumeric(value)&&isscalar(value)
    n=round(double(value));
    if n<0||~isfinite(n), error('cellLatentModel:InvalidClassCount','Class count must be non-negative.'); end
    classes=arrayfun(@(x)sprintf('class_%d',x),1:n,'UniformOutput',false);
else
    classes=normalizeTextList(value);
end
classes=unique(classes(~cellfun(@isempty,classes)),'stable');
end

function unit=targetUnit(task)
if strcmp(task,'segmentation'), unit='pixel_frame'; else, unit='object_frame'; end
end
