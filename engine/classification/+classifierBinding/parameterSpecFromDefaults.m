function spec = parameterSpecFromDefaults(defaults)
%CLASSIFIERBINDING.PARAMETERSPECFROMDEFAULTS Humanize legacy parameter structs.
% Keeps internal keys stable while exposing readable labels, groups, and the
% package-provided help text in classifierGUI.
template=struct('param','','label','','group','','tip','', ...
    'choiceLabels',{{}});
spec=repmat(template,0,1);
if nargin < 1 || isempty(defaults) || ~isstruct(defaults), return; end
keys = fieldnames(defaults);
keys = keys(~strcmp(keys,'tip'));
tips = {};
if isfield(defaults,'tip') && iscell(defaults.tip)
    tips = defaults.tip;
    while isscalar(tips) && iscell(tips{1}), tips=tips{1}; end
end
rawKeys = fieldnames(defaults);
rawKeys = rawKeys(~strcmp(rawKeys,'tip'));
spec=repmat(template,numel(keys),1);
for i=1:numel(keys)
    key=keys{i};
    tip=''; idx=find(strcmp(rawKeys,key),1);
    if ~isempty(idx) && idx<=numel(tips)
        try tip=char(string(tips{idx})); catch, end
    end
    spec(i)=struct( ...
        'param',key,'label',humanLabel(key),'group',parameterGroup(key), ...
        'tip',tip,'choiceLabels',{{}});
end
end

function label=humanLabel(key)
label=strrep(char(string(key)),'_',' ');
label=regexprep(label,'([a-z0-9])([A-Z])','$1 $2');
label=regexprep(label,'\s+',' ');
label=strtrim(label);
label=regexprep(label,'^Cnn\b','CNN','ignorecase');
label=regexprep(label,'^Lstm\b','LSTM','ignorecase');
label=regexprep(label,'\bGt\b','GT','ignorecase');
label=regexprep(label,'\bRoi\b','ROI','ignorecase');
if ~isempty(label) && ~any(startsWith(label,{'CNN','LSTM','GT','ROI'}))
    label(1)=upper(label(1));
end
end

function group=parameterGroup(key)
lowerKey=lower(key);
if startsWith(lowerKey,'format_')
    group='Dataset formatting';
elseif startsWith(lowerKey,'lstm_')
    if any(contains(lowerKey,{'minority','pos_neg','stride','distrib'}))
        group='LSTM class balancing';
    else
        group='LSTM architecture and optimization';
    end
elseif startsWith(lowerKey,'cnn_')
    if any(contains(lowerKey,{'augmentation','rand_','crop_','contrast', ...
            'brightness','gamma','saturation','hue','noise','defocus'}))
        group='CNN augmentation';
    else
        group='CNN architecture and optimization';
    end
elseif any(startsWith(lowerKey,{'train_','compute_','assemble_'}))
    group='Training stages';
elseif any(contains(lowerKey,{'validation','splitting','crossvalidation'}))
    group='Validation';
elseif any(contains(lowerKey,{'execution','device','backend','worker'}))
    group='Runtime';
elseif any(contains(lowerKey,{'transfer','initial','pretrained'}))
    group='Model initialization';
else
    group='Training';
end
end
