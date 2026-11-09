classdef ClassifierParameters
    % Read package contracts without initializing models or changing classifiers.
    methods (Static)
        function view = describe(c,stage,bindings,withCatalog)
            if nargin<4, withCatalog=false; end
            training=strcmp(stage,'Training');
            field='executionParam'; if training, field='trainingParam'; end
            params=c.(field); if ~isstruct(params)||~isscalar(params), params=struct(); end
            meta=classifierBinding.parameterSpecFromDefaults(params);
            spec=classifierBinding.trainingSpec(c); policy=struct();
            execution=struct(); pkg=char(string(c.classifierPkg));
            if isempty(pkg)
                fun=char(string(c.classifyFun)); parts=strsplit(fun,'.');
                if numel(parts)>1, pkg=parts{1}; end
            end
            defaultNumbers=struct();
            if ~isempty(pkg) && ~isempty(which([pkg '.executionSpec']))
                baseline=feval([pkg '.executionSpec'],[]);
                if isfield(baseline,'defaults'), defaultNumbers=baseline.defaults; end
            end
            if training
                [declared,policy]=classifierBinding.trainingParameterSpec(c);
                for item=reshape(declared,1,[])
                    at=find(strcmp({meta.param},item.param),1);
                    if isempty(at), meta(end+1)=item; else, meta(at)=item; end %#ok<AGROW>
                end
                bindingSpec=spec;
            else
                if ~isempty(pkg) && ~isempty(which([pkg '.executionSpec']))
                    execution=feval([pkg '.executionSpec'],c);
                end
                if isfield(execution,'defaults')
                    defaults=execution.defaults;
                    for key=reshape(fieldnames(params),1,[]), defaults.(key{1})=params.(key{1}); end
                    params=defaults;
                end
                node=struct('id','classifier','type','classifier','pkg',pkg,'params',params);
                contract=pipelineNodeContract(node);
                bindingSpec=classifierBinding.trainingSpec([]);
                inputs=contract.resources.in;
                for input=reshape(inputs,1,[])
                    if isempty(input.param), continue; end
                    existing=find(strcmp({spec.param},input.param) & ~strcmpi({spec.quality},'gt'),1);
                    if ~isempty(existing)
                        item=spec(existing); item.storage='executionParam';
                    else
                        item=classifierBinding.newBinding('param',input.param,'type',input.type, ...
                            'role',input.role,'label',strrep(input.param,'_',' '), ...
                            'required',input.required,'allowNone',~input.required,'storage','executionParam');
                    end
                    % Generic image-channel selection remains the classifier's
                    % canonical channel binding, rather than an unused node key.
                    if strcmp(item.param,'channels')
                        existing=find(strcmpi({spec.storage},'classifierInputChannels') & ~strcmpi({spec.quality},'gt'),1);
                        if isempty(existing)
                            item.storage='classifierInputChannels'; item.cardinality='many';
                        else, item=spec(existing);
                        end
                    end
                    if ~any(strcmp({bindingSpec.param},item.param)), bindingSpec(end+1)=item; end %#ok<AGROW>
                end
                meta=classifierBinding.parameterSpecFromDefaults(params);
                for k=1:numel(meta)
                    key=meta(k).param;
                    if isfield(execution,'labels')&&isfield(execution.labels,key), meta(k).label=execution.labels.(key); end
                    if isfield(execution,'tips')&&isfield(execution.tips,key), meta(k).tip=execution.tips.(key); end
                end
            end
            if isempty(bindingSpec) && isempty(pkg)
                bindingSpec=classifierBinding.newBinding('param','inputChannelName','type','channel', ...
                    'role','roi_image','label','Input channels','storage','classifierInputChannels', ...
                    'cardinality','many');
            end
            catalog=struct();
            if bindings&&withCatalog, catalog=classifierBinding.catalog(c); end
            records=struct('key',{},'label',{},'tip',{},'group',{},'value',{}, ...
                'choices',{},'choiceLabels',{},'editable',{},'binding',{},'advanced',{},'autoNumber',{},'wrapperDepth',{});
            if bindings
                for item=reshape(bindingSpec,1,[])
                    value=classifierBinding.value(c,item);
                    if strcmpi(item.storage,'executionParam')
                        value=''; if isfield(params,item.param), value=params.(item.param); end
                    end
                    choices={}; labels={};
                    if withCatalog
                        selected=classifierBinding.choices(item,catalog,value); choices=selected.values; labels=selected.labels;
                    end
                    editable=item.editable&&ismember(lower(item.storage),{'trainingparam','classifierinputchannels','executionparam'});
                    records(end+1)=struct('key',item.param,'label',item.label,'tip',item.tip, ...
                        'group',item.group,'value',{value},'choices',{choices},'choiceLabels',{labels}, ...
                        'editable',editable,'binding',item,'advanced',false,'autoNumber',false,'wrapperDepth',0); %#ok<AGROW>
                end
            else
                keys=fieldnames(params);
                keys=setdiff(keys,[{bindingSpec.param} {'tip'}],'stable');
                if training && ~isempty(declared)
                    common=intersect({declared.param},keys,'stable');
                    extra=setdiff(keys,{declared.param},'stable'); keys=[common(:);extra(:)];
                end
                if training&&isfield(policy,'showUnspecified')&&~policy.showUnspecified
                    keys=keys(ismember(keys,{declared.param}));
                elseif ~training && isfield(execution,'staticKeys')
                    allowed=[execution.staticKeys detecdivui.ClassifierParameters.list(execution,'outputKeys') detecdivui.ClassifierParameters.list(execution,'artifactKeys')];
                    keys=keys(ismember(keys,allowed));
                end
                for k=1:numel(keys)
                    key=keys{k}; at=find(strcmp({meta.param},key),1);
                    label=key; tip=''; group='';
                    if ~isempty(at), label=meta(at).label; tip=meta(at).tip; group=meta(at).group; end
                    choices={}; labels={}; value=params.(key); depth=0;
                    while iscell(value)&&isscalar(value)&&iscell(value{1})
                        value=value{1}; depth=depth+1;
                    end
                    if isfield(execution,'choices')&&isfield(execution.choices,key)
                        choices=cellstr(string(execution.choices.(key))); labels=choices;
                    elseif strcmp(detecdivui.RunDraft.valueKind(value),'choice')
                        choices=cellstr(string(value(1:end-1))); labels=choices;
                        if ~isempty(at)
                            pretty=meta(at).choiceLabels;
                            if numel(pretty)==numel(choices)+1, pretty=pretty(1:end-1); end
                            if numel(pretty)==numel(choices), labels=pretty; end
                        end
                    end
                    % Package declaration order defines the common settings;
                    % every other supported setting stays available in Advanced.
                    advanced=k>8 || any(contains(lower(group),{'runtime','recovery','reproducibility','augmentation'}));
                    if isnumeric(value)&&~isscalar(value) || isstruct(value), advanced=true; end
                    autoNumber=isnumeric(value)&&isscalar(value)&&~isfinite(value);
                    if isfield(defaultNumbers,key)
                        default=defaultNumbers.(key);
                        autoNumber=autoNumber || isnumeric(default)&&isscalar(default)&&~isfinite(default);
                    end
                    records(end+1)=struct('key',key,'label',label,'tip',tip,'group',group, ...
                        'value',{value},'choices',{choices},'choiceLabels',{labels},'editable',true, ...
                        'binding',struct(),'advanced',advanced,'autoNumber',autoNumber,'wrapperDepth',depth); %#ok<AGROW>
                end
            end
            view=struct('field',field,'records',records,'bindings',bindings,'stage',stage, ...
                'snapshot',detecdivui.ClassifierParameters.snapshot(c));
        end
        function state=snapshot(c)
            state=struct('trainingParam',{c.trainingParam},'executionParam',{c.executionParam}, ...
                'channelName',{c.channelName},'dataset',{c.dataset},'classifierPkg',c.classifierPkg, ...
                'trainingFun',c.trainingFun,'classifyFun',c.classifyFun,'rois',{c.roi});
        end
        function apply(c,view,changes)
            assert(isequaln(view.snapshot,detecdivui.ClassifierParameters.snapshot(c)), ...
                'detecdivui:ClassifierStale','Configuration changed. Reopen this editor.');
            keys=fieldnames(changes);
            for k=1:numel(keys)
                at=find(strcmp({view.records.key},keys{k}),1);
                assert(~isempty(at)&&view.records(at).editable,'detecdivui:ClassifierBinding','This value is managed by the package.');
                record=view.records(at); value=changes.(keys{k});
                if ~isempty(record.choices)
                    selected=value;
                    if ~view.bindings&&strcmp(detecdivui.RunDraft.valueKind(record.value),'choice'), selected=value{end}; end
                    assert(all(ismember(string(selected),string(record.choices))), ...
                        'detecdivui:ClassifierChoice','Choose a listed value for %s.',record.label);
                end
                if view.bindings && strcmpi(record.binding.storage,'executionParam')
                    binding=record.binding; binding.storage='trainingParam';
                    changes.(keys{k})=classifierBinding.applyValue(struct('trainingParam',struct()),binding,value);
                end
            end
            for k=1:numel(keys)
                at=find(strcmp({view.records.key},keys{k}),1); record=view.records(at); value=changes.(keys{k});
                if ~view.bindings
                    for depth=1:record.wrapperDepth, value={value}; end
                end
                if view.bindings&&~strcmpi(record.binding.storage,'executionParam')
                    classifierBinding.applyValue(c,record.binding,value);
                else
                    params=c.(view.field);
                    if ~isstruct(params)||~isscalar(params), params=struct(); end
                    params.(keys{k})=value; c.(view.field)=params;
                end
            end
        end
    end
    methods (Static,Access=private)
        function values=list(s,key)
            values={}; if isfield(s,key), values=reshape(cellstr(string(s.(key))),1,[]); end
        end
    end
end

