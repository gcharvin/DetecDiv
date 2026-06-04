function contract = pipelineNodeContract(nodeOrType, pkg)
% pipelineNodeContract  Shared semantic IO contract for pipeline nodes.

    node = struct();
    if nargin < 1 || isempty(nodeOrType)
        node.type = '';
    elseif isstruct(nodeOrType)
        node = nodeOrType;
    else
        node.type = char(string(nodeOrType));
    end

    if nargin >= 2 && ~isempty(pkg)
        node.pkg = char(string(pkg));
    elseif ~isfield(node, 'pkg') || isempty(node.pkg)
        node.pkg = '';
    end
    if ~isfield(node, 'type') || isempty(node.type)
        node.type = '';
    end
    if ~isfield(node, 'func') || isempty(node.func)
        node.func = '';
    end

    defaultContract = defaultContractForNode(node);
    existing = struct();
    if shouldMergeSavedContract(node) && isfield(node, 'contract') && isstruct(node.contract)
        existing = node.contract;
    end
    contract = mergeContracts(defaultContract, existing, node);
end

function tf = shouldMergeSavedContract(node)
% Saved contracts are compatibility metadata. Known DetecDiv modules are
% parameter-driven and must be recalculated from type/pkg/params every time.
nodeType = lower(char(string(getField(node, 'type', ''))));
pkgName = lower(char(string(getField(node, 'pkg', ''))));
knownTypes = {'dataloader','roiidentify','roipattern','roimanual','roigrid','roitracked','roiextract','processor','classifier'};
tf = ~any(strcmp(nodeType, knownTypes));
if strcmp(nodeType, 'processor') || strcmp(nodeType, 'classifier')
    tf = isempty(pkgName);
end
end

function contract = defaultContractForNode(node)
    in = struct('name',{},'type',{},'required',{},'source',{});
    out = struct('name',{},'type',{},'required',{},'source',{});
    selectors = defaultSelectors();
    parameters = defaultParameters();
    requirements = defaultRequirements();
    capabilities = defaultCapabilities();
    binding = defaultBinding();
    resources = defaultResources();
    summary = '';

    t = lower(char(string(node.type)));
    p = lower(char(string(node.pkg)));
    f = lower(char(string(node.func)));

    switch t
        case 'dataloader'
            out = [ ...
                portDef('images',   'imageSet',      true,  'edge'), ...
                portDef('fovList',  'fovList',       true,  'edge'), ...
                portDef('channels', 'channelSet',    false, 'edge'), ...
                portDef('shallow',  'projectHandle', false, 'context') ...
                ];
            selectors.channelsParam = 'channelFilter';
            parameters.run = {};
            selectors.defaultChannels = {};
            requirements.params.optional = {'path','positionFilter','channelFilter','stackFilter'};
            capabilities.outputsChannels = true;
            capabilities.outputsImages = true;
            capabilities.outputsFovList = true;
            binding.scope = 'images';
            binding.mode = 'inventory';
            binding.resolveAt = 'run';
            binding.transfer = 'sourceInventory';
            resources.out = resourceDef('channel', 'source', 'channels', 'channelFilter', 'channels', 'channelFilter', false, 'sourceInventory');
            summary = 'Loads positions/FOVs and exposes source image channels.';

        case {'roiidentify','roipattern'}
            in = portDef('images', 'imageSet', true, 'edge');
            out = portDef('roiList', 'roiList', true, 'edge');
            selectors.channelParam = 'channel';
            selectors.channelIndexParam = 'channelIndex';
            selectors.framesParam = 'referenceFrame';
            parameters.design = {'pattern','patternRect','patternImage','patternList','activePatternIndex','threshold'};
            parameters.run = {'fovIndex','referenceFrame','channel','channelIndex'};
            requirements.images.required = true;
            requirements.images.channelsMin = 1;
            requirements.params.optional = {'threshold','referenceFrame','fovIndex'};
            capabilities.createsRoiList = true;
            capabilities.preservesRoiList = true;
            binding.scope = 'images';
            binding.mode = 'singleChannel';
            binding.exactCount = 1;
            binding.selectorKeys = {'channel'};
            resources.in = resourceDef('channel', 'source', 'channel', 'channel', 'images', 'channel', true, '');
            summary = 'Detects ROIs from source images, usually on one selected channel.';

        case 'roimanual'
            in = portDef('images', 'imageSet', true, 'edge');
            out = portDef('roiList', 'roiList', true, 'edge');
            parameters.run = {'fovIndex'};
            requirements.images.required = true;
            requirements.params.optional = {'fovIndex'};
            capabilities.createsRoiList = true;
            capabilities.preservesRoiList = true;
            summary = 'Creates or edits ROIs manually from source FOV images.';

        case 'roigrid'
            in = portDef('images', 'imageSet', true, 'edge');
            out = portDef('roiList', 'roiList', true, 'edge');
            parameters.design = {'gridCount','mode'};
            parameters.run = {'fovIndex'};
            requirements.images.required = true;
            requirements.params.optional = {'fovIndex','mode','gridCount'};
            capabilities.createsRoiList = true;
            capabilities.preservesRoiList = true;
            summary = 'Generates ROIs from a full-frame or grid tiling strategy.';

        case 'roitracked'
            in = [ ...
                portDef('roiList', 'roiList', true, 'edge'), ...
                portDef('masks',   'maskSet', true, 'edge') ...
                ];
            out = portDef('roiList', 'roiList', true, 'edge');
            selectors.channelParam = 'channel';
            selectors.channelsParam = 'extractChannels';
            selectors.framesParam = 'extractFrames';
            parameters.run = {'fovIndex','roiIndex','channel','margin','extract','extractFrames','extractChannels'};
            requirements.roi.required = true;
            requirements.roi.masks = true;
            requirements.params.optional = {'fovIndex','roiIndex','margin','extract','extractFrames','extractChannels'};
            capabilities.createsRoiList = true;
            capabilities.preservesRoiList = true;
            capabilities.roiMasks = true;
            binding.scope = 'roi';
            binding.mode = 'channelSet';
            binding.selectorKeys = {'channel','extractChannels'};
            resources.in = [ ...
                resourceDef('mask', 'segmentation', 'channel', 'channel', 'masks', 'channel', true, ''), ...
                resourceDef('channel', 'roi_image', 'extractChannels', 'extractChannels', 'channels', 'extractChannels', false, '') ...
                ];
            summary = 'Builds tracked ROIs from existing ROIs and compatible mask outputs.';

        case 'roiextract'
            in = portDef('roiList', 'roiList', true, 'edge');
            out = [ ...
                portDef('roiList',    'roiList',       true,  'edge'), ...
                portDef('channels',   'channelSet',    false, 'edge') ...
                ];
            selectors.channelsParam = 'extractChannels';
            selectors.framesParam = 'frames';
            parameters.run = {};
            parameters.static = {'correctDrift','driftChannel','driftMethod','driftRefMode','driftSubpixel','driftMaxShift','scale','cropDrift','forceChannelNames'};
            requirements.roi.required = true;
            requirements.params.optional = {'fovIndex','frames','extractChannels','extend','correctDrift'};
            capabilities.preservesRoiList = true;
            capabilities.roiChannels = true;
            capabilities.outputsChannels = true;
            binding.scope = 'images';
            binding.outputScope = 'roi';
            binding.mode = 'channelSet';
            binding.selectorKeys = {'extractChannels'};
            binding.resolveAt = 'run';
            binding.transfer = 'imagesToRoi';
            resources.in = resourceDef('channel', 'source', 'extractChannels', 'extractChannels', 'images', 'extractChannels', false, '');
            resources.out = resourceDef();
            summary = 'Extracts ROI crops and materializes ROI image channels for downstream ROI processing.';

        case 'processor'
            in = portDef('roiList', 'roiList', true, 'edge');
            out = [ ...
                portDef('roiList',    'roiList',       true,  'edge'), ...
                portDef('dataSeries', 'dataSeriesSet', true,  'edge') ...
                ];
            parameters.template = {'pkg','moduleVar','modulePath','moduleId','description','category'};
            parameters.run = {'roiList','channels','channel','frames','outputName'};
            if strcmp(p, 'computemetrics') || contains(f, 'computemetrics')
                maskSlotCount = computeMetricsMaskSlotCount(node);
                scoreSlotCount = computeMetricsScoreSlotCount(node);
                maskNameKeys = computeMetricsSlotKeys('mask', '_name', maskSlotCount);
                scoreNameKeys = computeMetricsSlotKeys('channel', '_name', scoreSlotCount);
                maskStaticKeys = computeMetricsMaskStaticKeys(maskSlotCount);
                in = [ ...
                    portDef('roiList',    'roiList',       true, 'edge'), ...
                    portDef('channels',   'channelSet',    true, 'edge') ...
                    ];
                out = [ ...
                    portDef('roiList',    'roiList',       true,  'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', true,  'edge') ...
                    ];
                selectors.channelsParam = 'channels';
                selectors.channelParam = 'channel';
                selectors.framesParam = 'frames';
                selectors.outputNameParam = 'outputName';
                parameters.run = {};
                parameters.static = [{'maskChannelCount','scoreChannelCount'}, maskStaticKeys, {'BrightestPixels'}];
                requirements.roi.required = true;
                requirements.roi.dataSeries = false;
                requirements.params.optional = [{'pkg','maskChannelCount','scoreChannelCount'}, maskNameKeys, scoreNameKeys, maskStaticKeys, {'BrightestPixels'}];
                capabilities.preservesRoiList = true;
                capabilities.roiDataSeries = true;
                capabilities.outputsDataSeries = true;
                capabilities.roiMasks = false;
                capabilities.outputsMasks = false;
                binding.scope = 'roi';
                binding.outputScope = 'roi';
                binding.mode = 'channelSlots';
                binding.selectorKeys = [maskNameKeys, scoreNameKeys];
                binding.resolveAt = 'run';
                resources.in = computeMetricsInputResources(maskSlotCount, scoreSlotCount);
                resources.out = resourceDef('dataSeries', 'metrics', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries');
                summary = 'Computes mask-linked fluorescence metrics from selected ROI image or mask channels.';
            else
            selectors.channelsParam = 'channels';
            selectors.channelParam = 'channel';
            selectors.framesParam = 'frames';
            selectors.outputNameParam = 'outputName';
            requirements.roi.required = true;
            requirements.roi.channelsMin = 1;
            requirements.params.required = {'pkg'};
            capabilities.preservesRoiList = true;
            capabilities.roiDataSeries = true;
            capabilities.outputsDataSeries = true;
            binding.scope = 'roi';
            binding.outputScope = 'roi';
            binding.mode = 'channelSet';
            binding.selectorKeys = {'channels','channel'};
            binding.resolveAt = 'run';
            resources.in = resourceDef('channel', 'roi_image', 'channels', 'channels', 'channels', 'channels', false, '');
            resources.out = resourceDef('dataSeries', 'processor_output', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries');
            summary = 'Processes ROI content. Requires ROI support and usually at least one ROI image channel.';
            end

        case 'classifier'
            in = portDef('roiList', 'roiList', true, 'edge');
            out = [ ...
                portDef('roiList',    'roiList',       true,  'edge'), ...
                portDef('dataSeries', 'dataSeriesSet', false, 'edge') ...
                ];
            selectors.channelsParam = 'channels';
            selectors.channelParam = 'channel';
            selectors.framesParam = 'frames';
            selectors.outputNameParam = 'outputName';
            parameters.template = {'pkg','moduleVar','modulePath','moduleId','description','category','classes','classifyFun','trainingFun','trainingParam','outputType'};
            parameters.run = {};
            requirements.roi.required = true;
            requirements.roi.channelsMin = 1;
            requirements.params.required = {'pkg'};
            capabilities.preservesRoiList = true;
            capabilities.roiDataSeries = true;
            capabilities.outputsDataSeries = true;
            binding.scope = 'roi';
            binding.outputScope = 'roi';
            binding.mode = 'channelSet';
            binding.selectorKeys = {'channels','channel'};
            binding.resolveAt = 'run';
            resources.in = resourceDef('channel', 'roi_image', 'channels', 'channels', 'channels', 'channels', true, '');
            resources.out = resourceDef('dataSeries', 'classification', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries');
            summary = 'Classifies ROI content from selected ROI channels and writes derived outputs.';
            if classifierProducesMasks(p, f)
                out = [portDef('roiList', 'roiList', true, 'edge'), portDef('masks', 'maskSet', true, 'edge')];
                capabilities.roiMasks = true;
                capabilities.outputsMasks = true;
                capabilities.outputsChannels = true;
                if strcmp(p, 'cellposesam')
                    capabilities.roiDataSeries = false;
                    capabilities.outputsDataSeries = false;
                    resources.out = resourceDef('mask', 'segmentation', 'masks', 'outputName', 'masks', 'outputName', false, 'roiMasks');
                    summary = 'Segments ROI content into instance masks and optional result channels.';
                else
                    out = [out, portDef('dataSeries', 'dataSeriesSet', false, 'edge')];
                    resources.out = [ ...
                        resourceDef('mask', 'segmentation', 'masks', 'outputName', 'masks', 'outputName', false, 'roiMasks'), ...
                        resourceDef('dataSeries', 'classification', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries') ...
                        ];
                    summary = 'Segments ROI content and can emit mask outputs plus ROI-linked result channels.';
                end
            end

        otherwise
            if isfield(node, 'inputs') && ~isempty(node.inputs)
                in = genericPorts(node.inputs, 'in');
            end
            if isfield(node, 'outputs') && ~isempty(node.outputs)
                out = genericPorts(node.outputs, 'out');
            end
            summary = 'Generic pipeline node.';
    end

    contract = struct( ...
        'in', in, ...
        'out', out, ...
        'selectors', selectors, ...
        'parameters', parameters, ...
        'requirements', requirements, ...
        'capabilities', capabilities, ...
        'binding', binding, ...
        'resources', resources, ...
        'summary', char(string(summary)));

    contract = enrichContractFromPackage(contract, node);
    contract = backfillSelectorsFromNodeParams(contract, node);
end

function tf = classifierProducesMasks(pkgName, funcName)
    tf = false;
    if any(strcmp(pkgName, {'cellposesam'}))
        tf = true;
        return;
    end

    signatures = { ...
        'cpsam', ...
        'celltracktr', ...
        'deeplab', ...
        'solov2', ...
        'yoloseg', ...
        'unet', ...
        'seg', ...
        'mask' ...
        };

    for i = 1:numel(signatures)
        if contains(funcName, signatures{i})
            tf = true;
            return;
        end
    end
end

function ports = genericPorts(names, direction)
    ports = struct('name',{},'type',{},'required',{},'source',{});
    if nargin < 2
        direction = 'in';
    end
    names = cellstr(string(names(:)));
    for i = 1:numel(names)
        required = strcmp(direction, 'in');
        ports(end+1) = portDef(char(string(names{i})), 'generic', required, 'edge'); %#ok<AGROW>
    end
end

function contract = mergeContracts(defaultContract, existingContract, node)
    contract = defaultContract;
    if ~isempty(fieldnames(existingContract))
        if isfield(existingContract, 'in') && isstruct(existingContract.in)
            contract.in = mergePortArrays(defaultContract.in, existingContract.in, true);
        end
        if isfield(existingContract, 'out') && isstruct(existingContract.out)
            contract.out = mergePortArrays(defaultContract.out, existingContract.out, false);
        end
        if isfield(existingContract, 'selectors') && isstruct(existingContract.selectors)
            contract.selectors = mergeScalarStruct(defaultContract.selectors, existingContract.selectors);
        end
        if isfield(existingContract, 'requirements') && isstruct(existingContract.requirements)
            contract.requirements = mergeRequirementStruct(defaultContract.requirements, existingContract.requirements);
        end
        if isfield(existingContract, 'capabilities') && isstruct(existingContract.capabilities)
            contract.capabilities = mergeCapabilityStruct(defaultContract.capabilities, existingContract.capabilities);
        end
        if isfield(existingContract, 'binding') && isstruct(existingContract.binding)
            contract.binding = mergeBindingStruct(defaultContract.binding, existingContract.binding);
        end
        if isfield(existingContract, 'resources') && isstruct(existingContract.resources)
            contract.resources = mergeResourceStruct(getField(defaultContract, 'resources', defaultResources()), existingContract.resources);
        end
        if isfield(existingContract, 'summary') && ~isempty(existingContract.summary)
            contract.summary = char(string(existingContract.summary));
        end
    end

    contract = backfillFromNodeFields(contract, node);
    contract = backfillSelectorsFromNodeParams(contract, node);
    contract = applyContractPostRules(contract, node);
    contract = applyResourceDerivedState(contract);
    contract = normalizeContract(contract);
end

function contract = applyResourceDerivedState(contract)
resources = getField(contract, 'resources', defaultResources());
inputs = getField(resources, 'in', resourceDef());
outputs = getField(resources, 'out', resourceDef());

for i = 1:numel(inputs)
    r = inputs(i);
    type = lower(char(string(getField(r, 'type', ''))));
    role = lower(char(string(getField(r, 'role', ''))));
    if isempty(type)
        continue;
    end
    switch type
        case 'channel'
            if strcmp(role, 'source')
                contract.requirements.images.required = contract.requirements.images.required || logical(getField(r, 'required', false));
                if logical(getField(r, 'required', false))
                    contract.requirements.images.channelsMin = max(contract.requirements.images.channelsMin, 1);
                end
            else
                contract.requirements.roi.required = true;
                if logical(getField(r, 'required', false))
                    contract.requirements.roi.channelsMin = max(contract.requirements.roi.channelsMin, 1);
                end
            end
        case 'mask'
            contract.requirements.roi.required = true;
            if logical(getField(r, 'required', false))
                contract.requirements.roi.masks = true;
            end
        case {'dataseries','dataSeries'}
            contract.requirements.roi.required = true;
            if logical(getField(r, 'required', false))
                contract.requirements.roi.dataSeries = true;
            end
    end
end

for i = 1:numel(outputs)
    r = outputs(i);
    type = lower(char(string(getField(r, 'type', ''))));
    role = lower(char(string(getField(r, 'role', ''))));
    if isempty(type)
        continue;
    end
    switch type
        case 'channel'
            contract.capabilities.outputsChannels = true;
            if ~strcmp(role, 'source')
                contract.capabilities.roiChannels = true;
            end
        case 'mask'
            contract.capabilities.outputsMasks = true;
            contract.capabilities.roiMasks = true;
        case {'dataseries','dataSeries'}
            contract.capabilities.outputsDataSeries = true;
            contract.capabilities.roiDataSeries = true;
    end
end
end

function contract = applyContractPostRules(contract, node)
    nodeType = lower(char(string(getField(node, 'type', ''))));
    pkgName = lower(char(string(getField(node, 'pkg', ''))));
    if strcmp(nodeType, 'classifier') && strcmp(pkgName, 'cellposesam')
        % CellposeSAM outputs are controlled by node.params.outputType. Some
        % saved templates carry an older node.contract; regenerate this
        % package-owned contract after merge so stale resources cannot mask
        % the current static parameter selection.
        contract = enrichContractFromPackage(contract, node);
    end
    if strcmp(nodeType, 'roiextract')
        % roiExtract materializes ROI-local H5 channels, but the concrete
        % channel names are selected by its input channel binding. It does
        % not expose a separate user-editable output binding.
        contract.resources.out = resourceDef();
    end
end

function ports = mergePortArrays(defaultPorts, existingPorts, inputsAreRequired)
    ports = defaultPorts;
    if nargin < 3
        inputsAreRequired = false;
    end
    for i = 1:numel(existingPorts)
        p = normalizePort(existingPorts(i), inputsAreRequired);
        idx = find(strcmp({ports.name}, p.name), 1);
        if isempty(idx)
            ports(end+1) = p; %#ok<AGROW>
        else
            ports(idx) = p;
        end
    end
end

function contract = backfillFromNodeFields(contract, node)
    if isfield(node, 'inputs') && ~isempty(node.inputs)
        names = cellstr(string(node.inputs(:)));
        for i = 1:numel(names)
            if ~any(strcmp({contract.in.name}, names{i}))
                contract.in(end+1) = portDef(char(string(names{i})), 'generic', true, 'edge'); %#ok<AGROW>
            end
        end
    end
    if isfield(node, 'outputs') && ~isempty(node.outputs)
        names = cellstr(string(node.outputs(:)));
        for i = 1:numel(names)
            if ~any(strcmp({contract.out.name}, names{i}))
                contract.out(end+1) = portDef(char(string(names{i})), 'generic', true, 'edge'); %#ok<AGROW>
            end
        end
    end
end

function contract = backfillSelectorsFromNodeParams(contract, node)
    params = struct();
    if isfield(node, 'params') && isstruct(node.params)
        params = node.params;
    end
    if isempty(fieldnames(params))
        return;
    end

    defaultChannels = extractChannelDefaults(params, contract.selectors);
    if isempty(contract.selectors.defaultChannels) && ~isempty(defaultChannels)
        contract.selectors.defaultChannels = defaultChannels;
    end

    if isempty(contract.selectors.defaultChannelCount) && ~isempty(defaultChannels)
        contract.selectors.defaultChannelCount = numel(defaultChannels);
    end

    if isempty(contract.selectors.defaultOutputName)
        if isfield(params,'outputName') && ~isempty(params.outputName)
            contract.selectors.defaultOutputName = char(string(params.outputName));
        elseif isfield(params,'strid') && ~isempty(params.strid)
            contract.selectors.defaultOutputName = char(string(params.strid));
        end
    end

    if ~isempty(defaultChannels) && any(strcmp({contract.in.type}, 'imageSet'))
        contract.requirements.images.channelsMin = max(contract.requirements.images.channelsMin, numel(defaultChannels));
    end
    if ~isempty(defaultChannels) && any(strcmp({contract.in.type}, 'roiList'))
        contract.requirements.roi.channelsMin = max(contract.requirements.roi.channelsMin, numel(defaultChannels));
    end
    if isempty(contract.binding.selectorKeys)
        selectorKeys = {};
        if ~isempty(contract.selectors.channelsParam)
            selectorKeys{end+1} = char(string(contract.selectors.channelsParam)); %#ok<AGROW>
        end
        if ~isempty(contract.selectors.channelParam)
            selectorKeys{end+1} = char(string(contract.selectors.channelParam)); %#ok<AGROW>
        end
        if ~isempty(selectorKeys)
            contract.binding.selectorKeys = unique(selectorKeys, 'stable');
        end
    end
    if isempty(contract.binding.minCount)
        if any(strcmp({contract.in.type}, 'imageSet'))
            contract.binding.minCount = contract.requirements.images.channelsMin;
        elseif any(strcmp({contract.in.type}, 'roiList'))
            contract.binding.minCount = contract.requirements.roi.channelsMin;
        end
    end
    if isempty(contract.binding.exactCount) && ~isempty(contract.selectors.defaultChannelCount)
        contract.binding.defaultCount = contract.selectors.defaultChannelCount;
    end

    if isfield(params, 'pkg') && any(strcmp(contract.requirements.params.required, 'pkg'))
        contract.requirements.params.required = setdiff(contract.requirements.params.required, {'pkg'}, 'stable');
        contract.requirements.params.optional = unique([contract.requirements.params.optional {'pkg'}], 'stable');
    end
end

function defaults = extractChannelDefaults(params, selectors)
    defaults = {};
    candidates = {};

    if ~isempty(selectors.channelsParam) && isfield(params, selectors.channelsParam)
        candidates = normalizeChannelSpec(params.(selectors.channelsParam));
    end
    if isempty(candidates) && ~isempty(selectors.channelParam) && isfield(params, selectors.channelParam)
        candidates = normalizeChannelSpec(params.(selectors.channelParam));
    end
    if isempty(candidates) && isfield(params, 'channelName')
        candidates = normalizeChannelSpec(params.channelName);
    end
    if isempty(candidates) && isfield(params, 'channelFilter')
        candidates = normalizeChannelSpec(params.channelFilter);
    end

    defaults = candidates;
end

function spec = normalizeChannelSpec(v)
    spec = {};
    if isempty(v)
        return;
    end
    if ischar(v) || (isstring(v) && isscalar(v))
        s = char(string(v));
        if isempty(strtrim(s))
            return;
        end
        spec = {s};
        return;
    end
    if isstring(v)
        spec = cellstr(v(:));
        spec = spec(~cellfun(@(x) isempty(strtrim(x)), spec));
        return;
    end
    if iscell(v)
        tmp = {};
        for i = 1:numel(v)
            if isempty(v{i})
                continue;
            end
            try
                tmp{end+1} = char(string(v{i})); %#ok<AGROW>
            catch
            end
        end
        spec = tmp(~cellfun(@(x) isempty(strtrim(x)), tmp));
        return;
    end
    if isnumeric(v)
        vals = double(v(:)');
        vals = vals(isfinite(vals));
        for i = 1:numel(vals)
            spec{end+1} = num2str(vals(i)); %#ok<AGROW>
        end
    end
end

function contract = enrichContractFromPackage(contract, node)
    pkgName = lower(char(string(getField(node, 'pkg', ''))));
    funcName = lower(char(string(getField(node, 'func', ''))));
    nodeType = lower(char(string(getField(node, 'type', ''))));

    if strcmp(nodeType, 'classifier')
        switch pkgName
            case 'cellposesam'
                outputType = normalizeOutputMode(getNestedParam(node, {'outputType','outputMode'}, 'segmentation'), ...
                    {'segmentation','proba','probability','both'}, 'segmentation');
                if strcmp(outputType, 'probability')
                    outputType = 'proba';
                end
                contract.parameters.static = unique([contract.parameters.static ...
                    {'outputType','diameter','min_size','flow_threshold','cell_prob_threshold'}], 'stable');
                contract.requirements.roi.channelsMin = max(contract.requirements.roi.channelsMin, 1);
                contract.capabilities.outputsMasks = any(strcmp(outputType, {'segmentation','both'}));
                contract.capabilities.outputsChannels = any(strcmp(outputType, {'proba','both'}));
                contract.capabilities.roiMasks = contract.capabilities.outputsMasks;
                contract.capabilities.roiChannels = contract.capabilities.outputsChannels;
                contract.capabilities.roiDataSeries = false;
                contract.capabilities.outputsDataSeries = false;
                contract.binding.mode = 'singleChannel';
                contract.binding.exactCount = 1;
                contract.binding.resolveAt = 'design';
                contract.out = portDef('roiList', 'roiList', true, 'edge');
                outs = resourceDef();
                if any(strcmp(outputType, {'segmentation','both'}))
                    contract.out(end+1) = portDef('masks', 'maskSet', true, 'edge');
                    outs(end+1) = resourceDef('mask', 'segmentation', 'segmentation', 'outputName', 'masks', 'outputName', false, 'roiMasks'); %#ok<AGROW>
                end
                if any(strcmp(outputType, {'proba','both'}))
                    contract.out(end+1) = portDef('channels', 'channelSet', false, 'edge');
                    outs(end+1) = resourceDef('channel', 'probability', 'cellprob', 'probabilityOutputName', 'channels', 'probabilityOutputName', false, 'roiChannel'); %#ok<AGROW>
                end
                contract.resources.out = outs;
                contract.summary = 'CellposeSAM-like classifier: outputs segmentation masks, probability channels, or both.';
            case 'cnn_lstm'
                outputMode = normalizeOutputMode(getNestedParam(node, {'outputMode'}, 'lstm_only'), ...
                    {'lstm_only','cnn_only','both'}, 'lstm_only');
                contract.parameters.static = unique([contract.parameters.static {'outputMode'}], 'stable');
                contract.binding.mode = 'singleChannel';
                contract.binding.exactCount = 1;
                contract.binding.resolveAt = 'design';
                contract.capabilities.outputsMasks = false;
                contract.capabilities.outputsChannels = false;
                contract.capabilities.roiMasks = false;
                contract.capabilities.roiChannels = false;
                contract.capabilities.roiDataSeries = true;
                contract.capabilities.outputsDataSeries = true;
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', true, 'edge') ...
                    ];
                switch outputMode
                    case 'cnn_only'
                        contract.resources.out = resourceDef('dataSeries', 'classification', 'dataSeries', 'cnnOutputName', 'dataSeries', 'cnnOutputName', false, 'roiDataSeries');
                    case 'both'
                        contract.resources.out = [ ...
                            resourceDef('dataSeries', 'classification', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries'), ...
                            resourceDef('dataSeries', 'classification_cnn', 'dataSeriesCNN', 'cnnOutputName', 'dataSeries', 'cnnOutputName', false, 'roiDataSeries') ...
                            ];
                    otherwise
                        contract.resources.out = resourceDef('dataSeries', 'classification', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries');
                end
                contract.summary = 'CNN/LSTM classifier: outputs LSTM classification, CNN-only classification, or both depending on outputMode.';
        end

        if classifierProducesMasks(pkgName, funcName) && ~strcmp(pkgName, 'cellposesam')
            contract.capabilities.outputsMasks = true;
            contract.capabilities.outputsChannels = true;
            contract.capabilities.roiMasks = true;
        end
    end

    if strcmp(nodeType, 'processor')
        switch pkgName
            case 'combinemultiplechannels'
                maxChannelSlots = 5;
                channelSlotCount = combineMultipleChannelsSlotCount(node, maxChannelSlots);
                channelSlotKeys = combineMultipleChannelsSlotKeys('Channel', channelSlotCount);
                rgbSlotKeys = combineMultipleChannelsSlotKeys('RGB_Channel', channelSlotCount);
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('channels', 'channelSet', false, 'edge')];
                contract.capabilities.outputsChannels = true;
                contract.capabilities.roiChannels = true;
                contract.capabilities.roiDataSeries = false;
                contract.capabilities.outputsDataSeries = false;
                contract.binding.scope = 'roi';
                contract.binding.outputScope = 'roi';
                contract.binding.mode = 'channelSlots';
                contract.binding.selectorKeys = channelSlotKeys;
                contract.binding.resolveAt = 'run';
                contract.binding.exactCountParam = 'requiredChannelCount';
                contract.binding.outputChannelNameParam = 'outputChannelName';
                contract.binding.transfer = 'roiChannelsToRoiChannel';
                contract.parameters.run = {};
                contract.parameters.static = [{'requiredChannelCount'}, rgbSlotKeys, {'debug'}];
                contract.resources.in = combineMultipleChannelsInputResources(channelSlotCount);
                contract.resources.out = resourceDef('channel', 'derived_roi_image', 'channels', 'outputChannelName', 'channels', 'outputChannelName', false, 'roiChannel');
                contract.summary = 'Combines selected ROI channels into one derived ROI image channel.';
            case 'computerls'
                contract.in = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', true, 'edge') ...
                    ];
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', true, 'edge') ...
                    ];
                contract.parameters.run = {};
                contract.parameters.data = {};
                contract.parameters.static = { ...
                    'ArrestThreshold','DeathThreshold','ClogThreshold', ...
                    'EmptyThresholdDiscard','EmptyThresholdNext', ...
                    'StateDecoder','ExpectedDivisionPeriod','MinDivisionInterval', ...
                    'MinDivisionIntervalFactor','MedianFilterWindow', ...
                    'ViterbiLiveSwitchPenalty','ViterbiTerminalPenalty', ...
                    'ViterbiUnexpectedTransitionPenalty','ViterbiRefillPenalty', ...
                    'QCLowMarginThreshold','QCMinMeanMargin','QCMaxLowConfidenceFraction'};
                contract.requirements.roi.channelsMin = 0;
                contract.requirements.roi.dataSeries = true;
                contract.binding.scope = 'roi';
                contract.binding.outputScope = 'roi';
                contract.binding.mode = 'dataSeries';
                contract.binding.selectorKeys = {'classification_data'};
                contract.binding.resolveAt = 'run';
                contract.capabilities.roiDataSeries = true;
                contract.capabilities.outputsDataSeries = true;
                contract.resources.in = resourceDef('dataSeries', 'classification', 'classification_data', 'classification_data', 'dataSeries', 'classification_data', true, '');
                contract.resources.out = resourceDef('dataSeries', 'rls', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries');
                contract.summary = 'Computes RLS events from an upstream or existing classification dataseries.';
            case 'computelineage'
                contract.in = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', true, 'edge') ...
                    ];
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', true, 'edge') ...
                    ];
                contract.parameters.run = {};
                contract.parameters.data = {};
                contract.parameters.static = { ...
                    'postProcessing','errorDetection','ArrestThreshold','DeathThreshold', ...
                    'ClogThreshold','EmptyThresholdDiscard','EmptyThresholdNext'};
                contract.requirements.roi.channelsMin = 0;
                contract.requirements.roi.dataSeries = true;
                contract.binding.scope = 'roi';
                contract.binding.outputScope = 'roi';
                contract.binding.mode = 'dataSeries';
                contract.binding.selectorKeys = {'classification_data'};
                contract.binding.resolveAt = 'run';
                contract.capabilities.roiDataSeries = true;
                contract.capabilities.outputsDataSeries = true;
                contract.resources.in = resourceDef('dataSeries', 'classification', 'classification_data', 'classification_data', 'dataSeries', 'classification_data', true, '');
                contract.resources.out = resourceDef('dataSeries', 'lineage', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries');
                contract.summary = 'Computes lineage outputs from an upstream or existing classification dataseries.';
            case 'computemaxprojection'
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('channels', 'channelSet', false, 'edge') ...
                    ];
                contract.selectors.channelParam = 'channel';
                contract.selectors.outputNameParam = 'outputChannelName';
                contract.parameters.run = {};
                contract.parameters.static = {'method','zstacks'};
                contract.requirements.roi.required = true;
                contract.requirements.roi.channelsMin = 1;
                contract.binding.scope = 'roi';
                contract.binding.outputScope = 'roi';
                contract.binding.mode = 'singleChannel';
                contract.binding.selectorKeys = {'channel'};
                contract.binding.resolveAt = 'run';
                contract.binding.exactCount = 1;
                contract.capabilities.roiChannels = true;
                contract.capabilities.outputsChannels = true;
                contract.capabilities.roiDataSeries = false;
                contract.capabilities.outputsDataSeries = false;
                contract.resources.in = resourceDef('channel', 'roi_image', 'channel', 'channel', 'channels', 'channel', true, '');
                contract.resources.out = resourceDef('channel', 'derived_roi_image', 'channels', 'outputChannelName', 'channels', 'outputChannelName', false, 'roiChannel');
                contract.summary = 'Projects z-stacks from one ROI image channel into a derived ROI channel.';
            case 'basicobjecttracking'
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('channels', 'channelSet', false, 'edge') ...
                    ];
                contract.selectors.channelParam = 'inputChannelName';
                contract.selectors.outputNameParam = 'outputChannelName';
                contract.parameters.run = {};
                contract.parameters.static = {'inputMode','coefDist','coefSize','coefIoU','maxRelativeDistance','debug'};
                contract.requirements.roi.required = true;
                contract.requirements.roi.channelsMin = 1;
                contract.binding.scope = 'roi';
                contract.binding.outputScope = 'roi';
                contract.binding.mode = 'singleChannel';
                contract.binding.selectorKeys = {'inputChannelName'};
                contract.binding.resolveAt = 'run';
                contract.binding.exactCount = 1;
                contract.capabilities.roiChannels = true;
                contract.capabilities.outputsChannels = true;
                contract.capabilities.roiDataSeries = false;
                contract.capabilities.outputsDataSeries = false;
                contract.resources.in = resourceDef('channel', 'roi_image', 'inputChannelName', 'inputChannelName', 'channels', 'inputChannelName', true, '');
                contract.resources.out = resourceDef('channel', 'tracking', 'channels', 'outputChannelName', 'channels', 'outputChannelName', false, 'roiChannel');
                contract.summary = 'Tracks objects from a labeled/binary ROI channel and writes tracking labels.';
            case 'trackmotherlineageviterbi'
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('channels', 'channelSet', false, 'edge') ...
                    ];
                contract.selectors.channelParam = 'instanceChannelName';
                contract.selectors.outputNameParam = 'outputChannelName';
                contract.parameters.run = {};
                contract.parameters.static = { ...
                    'mode','debug', ...
                    'wM_center','wM_area','wM_bottom','wB_dist','wB_small', ...
                    'lambdaM_jump','lambdaM_area','lambdaM_appear','lambdaM_disapp', ...
                    'lambdaB_jump','lambdaB_area','lambdaB_appear','lambdaB_disapp', ...
                    'tempConf','bottomSign','ratioMin','bonusSwitch'};
                contract.requirements.roi.required = true;
                contract.requirements.roi.channelsMin = 1;
                contract.binding.scope = 'roi';
                contract.binding.outputScope = 'roi';
                contract.binding.mode = 'singleChannel';
                contract.binding.selectorKeys = {'instanceChannelName'};
                contract.binding.resolveAt = 'run';
                contract.binding.exactCount = 1;
                contract.capabilities.roiChannels = true;
                contract.capabilities.outputsChannels = true;
                contract.capabilities.roiDataSeries = false;
                contract.capabilities.outputsDataSeries = false;
                contract.resources.in = resourceDef('channel', 'roi_image', 'instanceChannelName', 'instanceChannelName', 'channels', 'instanceChannelName', true, '');
                contract.resources.out = resourceDef('channel', 'lineage_mask', 'channels', 'outputChannelName', 'channels', 'outputChannelName', false, 'roiChannel');
                contract.summary = 'Tracks mother/bud lineage from an instance-label ROI channel using Viterbi.';
            case 'formatindataseries'
                contract.in = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', false, 'edge') ...
                    ];
                contract.out = [ ...
                    portDef('roiList', 'roiList', true, 'edge'), ...
                    portDef('dataSeries', 'dataSeriesSet', true, 'edge') ...
                    ];
                contract.parameters.run = {};
                contract.requirements.roi.required = true;
                contract.requirements.roi.channelsMin = 0;
                contract.requirements.roi.dataSeries = false;
                contract.binding.mode = 'none';
                contract.binding.selectorKeys = {};
                contract.capabilities.roiDataSeries = true;
                contract.capabilities.outputsDataSeries = true;
                contract.resources.in = resourceDef();
                contract.resources.out = resourceDef('dataSeries', 'formatted', 'dataSeries', 'outputName', 'dataSeries', 'outputName', false, 'roiDataSeries');
                contract.summary = 'Formats ROI data into dataseries objects without additional user bindings.';
        end
    end
end

function s = defaultSelectors()
    s = struct( ...
        'channelParam', '', ...
        'channelIndexParam', '', ...
        'channelsParam', '', ...
        'framesParam', '', ...
        'outputNameParam', '', ...
        'defaultChannels', {{}}, ...
        'defaultChannelCount', [], ...
        'defaultOutputName', '');
end

function p = defaultParameters()
    p = struct( ...
        'fixed', {{}}, ...
        'design', {{}}, ...
        'template', {{}}, ...
        'static', {{}}, ...
        'run', {{}}, ...
        'data', {{}}, ...
        'notes', {{}});
end

function r = defaultRequirements()
    r = struct( ...
        'images', struct('required', false, 'channelsMin', 0), ...
        'roi', struct('required', false, 'channelsMin', 0, 'masks', false, 'dataSeries', false), ...
        'params', struct('required', {{}}, 'optional', {{}}), ...
        'notes', {{}});
end

function c = defaultCapabilities()
    c = struct( ...
        'createsRoiList', false, ...
        'preservesRoiList', false, ...
        'roiChannels', false, ...
        'roiMasks', false, ...
        'roiDataSeries', false, ...
        'outputsImages', false, ...
        'outputsFovList', false, ...
        'outputsChannels', false, ...
        'outputsMasks', false, ...
        'outputsDataSeries', false, ...
        'notes', {{}});
end

function b = defaultBinding()
    b = struct( ...
        'scope', '', ...
        'outputScope', '', ...
        'mode', '', ...
        'selectorKeys', {{}}, ...
        'minCount', [], ...
        'exactCount', [], ...
        'exactCountParam', '', ...
        'defaultCount', [], ...
        'resolveAt', 'run', ...
        'outputChannelNameParam', '', ...
        'transfer', '', ...
        'notes', {{}});
end

function r = defaultResources()
    r = struct( ...
        'in', resourceDef(), ...
        'out', resourceDef());
end

function r = resourceDef(type, role, symbol, param, port, nameParam, required, transfer)
    if nargin == 0
        r = struct('type',{},'role',{},'symbol',{},'param',{},'port',{},'nameParam',{},'required',{},'transfer',{});
        return;
    end
    if nargin < 8, transfer = ''; end
    if nargin < 7 || isempty(required), required = false; end
    if nargin < 6, nameParam = ''; end
    if nargin < 5, port = ''; end
    if nargin < 4, param = ''; end
    if nargin < 3, symbol = ''; end
    if nargin < 2, role = ''; end
    r = struct( ...
        'type', char(string(type)), ...
        'role', char(string(role)), ...
        'symbol', char(string(symbol)), ...
        'param', char(string(param)), ...
        'port', char(string(port)), ...
        'nameParam', char(string(nameParam)), ...
        'required', logical(required), ...
        'transfer', char(string(transfer)));
end

function n = combineMultipleChannelsSlotCount(node, maxSlots)
    if nargin < 2 || isempty(maxSlots)
        maxSlots = 5;
    end
    n = maxSlots;
    params = getField(node, 'params', struct());
    if ~isstruct(params) || ~isfield(params, 'requiredChannelCount') || isempty(params.requiredChannelCount)
        return;
    end
    try
        requested = double(params.requiredChannelCount);
    catch
        requested = 0;
    end
    if ~isscalar(requested) || ~isfinite(requested) || requested <= 0
        return;
    end
    n = min(maxSlots, max(1, round(requested)));
end

function keys = combineMultipleChannelsSlotKeys(prefix, n)
    keys = cell(1, n);
    for i = 1:n
        keys{i} = sprintf('%s%d', char(string(prefix)), i);
    end
end

function resources = combineMultipleChannelsInputResources(n)
    resources = resourceDef();
    for i = 1:n
        key = sprintf('Channel%d', i);
        resources(end+1) = resourceDef('channel', 'roi_image', key, key, 'channels', key, false, ''); %#ok<AGROW>
    end
end

function n = computeMetricsMaskSlotCount(node)
    n = dynamicSlotCount(node, {'maskChannelCount','maskCount'}, 2, 1, 8);
end

function n = computeMetricsScoreSlotCount(node)
    n = dynamicSlotCount(node, {'scoreChannelCount','channelCount'}, 4, 0, 12);
end

function n = dynamicSlotCount(node, names, defaultValue, minValue, maxValue)
    n = defaultValue;
    params = getField(node, 'params', struct());
    if isstruct(params)
        for i = 1:numel(names)
            key = char(string(names{i}));
            if isfield(params, key) && ~isempty(params.(key))
                try
                    requested = double(params.(key));
                catch
                    requested = NaN;
                end
                if isscalar(requested) && isfinite(requested)
                    n = requested;
                    break;
                end
            end
        end
    end
    n = min(maxValue, max(minValue, round(n)));
end

function keys = computeMetricsSlotKeys(prefix, suffix, n)
    keys = cell(1, n);
    for i = 1:n
        keys{i} = sprintf('%s%d%s', char(string(prefix)), i, char(string(suffix)));
    end
end

function keys = computeMetricsMaskStaticKeys(n)
    keys = {};
    for i = 1:n
        keys = [keys, { ...
            sprintf('mask%d_class', i), ...
            sprintf('mask%d_label', i), ...
            sprintf('mask%d_stat', i)}]; %#ok<AGROW>
    end
end

function resources = computeMetricsInputResources(maskCount, scoreCount)
    resources = resourceDef();
    for i = 1:maskCount
        key = sprintf('mask%d_name', i);
        resources(end+1) = resourceDef('channel', 'roi_image', key, key, 'channels', key, true, ''); %#ok<AGROW>
    end
    for i = 1:scoreCount
        key = sprintf('channel%d_name', i);
        resources(end+1) = resourceDef('channel', 'roi_image', key, key, 'channels', key, true, ''); %#ok<AGROW>
    end
end

function out = mergeRequirementStruct(base, override)
    out = base;
    if ~isstruct(override)
        return;
    end
    if isfield(override, 'images') && isstruct(override.images)
        out.images = mergeScalarStruct(base.images, override.images);
    end
    if isfield(override, 'roi') && isstruct(override.roi)
        out.roi = mergeScalarStruct(base.roi, override.roi);
    end
    if isfield(override, 'params') && isstruct(override.params)
        out.params = mergeScalarStruct(base.params, override.params);
    end
    if isfield(override, 'notes') && ~isempty(override.notes)
        out.notes = normalizeCellstr(override.notes);
    end
end

function out = mergeCapabilityStruct(base, override)
    out = mergeScalarStruct(base, override);
    if isfield(override, 'notes') && ~isempty(override.notes)
        out.notes = normalizeCellstr(override.notes);
    end
end

function out = mergeBindingStruct(base, override)
    out = mergeScalarStruct(base, override);
    if isfield(override, 'selectorKeys') && ~isempty(override.selectorKeys)
        out.selectorKeys = normalizeCellstr(override.selectorKeys);
    end
    if isfield(override, 'notes') && ~isempty(override.notes)
        out.notes = normalizeCellstr(override.notes);
    end
end

function out = mergeResourceStruct(base, override)
    out = base;
    if ~isstruct(override)
        return;
    end
    if isfield(override, 'in')
        out.in = normalizeResourceArray(override.in);
    end
    if isfield(override, 'out')
        out.out = normalizeResourceArray(override.out);
    end
end

function out = mergeScalarStruct(base, override)
    out = base;
    if ~isstruct(override)
        return;
    end
    fn = fieldnames(override);
    for i = 1:numel(fn)
        k = fn{i};
        if isstruct(override.(k)) && isfield(base, k) && isstruct(base.(k))
            out.(k) = mergeScalarStruct(base.(k), override.(k));
        else
            out.(k) = override.(k);
        end
    end
end

function contract = normalizeContract(contract)
    if ~isfield(contract, 'selectors') || ~isstruct(contract.selectors)
        contract.selectors = defaultSelectors();
    else
        contract.selectors = mergeScalarStruct(defaultSelectors(), contract.selectors);
    end

    if ~isfield(contract, 'parameters') || ~isstruct(contract.parameters)
        contract.parameters = defaultParameters();
    else
        contract.parameters = mergeParameterStruct(defaultParameters(), contract.parameters);
    end

    if ~isfield(contract, 'requirements') || ~isstruct(contract.requirements)
        contract.requirements = defaultRequirements();
    else
        contract.requirements = mergeRequirementStruct(defaultRequirements(), contract.requirements);
    end

    if ~isfield(contract, 'capabilities') || ~isstruct(contract.capabilities)
        contract.capabilities = defaultCapabilities();
    else
        contract.capabilities = mergeCapabilityStruct(defaultCapabilities(), contract.capabilities);
    end
    if ~isfield(contract, 'binding') || ~isstruct(contract.binding)
        contract.binding = defaultBinding();
    else
        contract.binding = mergeBindingStruct(defaultBinding(), contract.binding);
    end
    if ~isfield(contract, 'resources') || ~isstruct(contract.resources)
        contract.resources = defaultResources();
    else
        contract.resources = mergeResourceStruct(defaultResources(), contract.resources);
    end

    contract.selectors.defaultChannels = normalizeCellstr(contract.selectors.defaultChannels);
    contract.parameters.fixed = normalizeCellstr(contract.parameters.fixed);
    contract.parameters.design = normalizeCellstr(getField(contract.parameters, 'design', {}));
    contract.parameters.template = normalizeCellstr(contract.parameters.template);
    contract.parameters.static = normalizeCellstr(getField(contract.parameters, 'static', {}));
    contract.parameters.run = normalizeCellstr(contract.parameters.run);
    contract.parameters.data = normalizeCellstr(contract.parameters.data);
    contract.parameters.notes = normalizeCellstr(contract.parameters.notes);
    contract.requirements.params.required = normalizeCellstr(contract.requirements.params.required);
    contract.requirements.params.optional = normalizeCellstr(contract.requirements.params.optional);
    contract.requirements.notes = normalizeCellstr(contract.requirements.notes);
    contract.capabilities.notes = normalizeCellstr(contract.capabilities.notes);
    contract.binding.selectorKeys = normalizeCellstr(contract.binding.selectorKeys);
    contract.binding.notes = normalizeCellstr(contract.binding.notes);
    contract.resources.in = normalizeResourceArray(contract.resources.in);
    contract.resources.out = normalizeResourceArray(contract.resources.out);

    if isempty(contract.selectors.defaultChannelCount) && ~isempty(contract.selectors.defaultChannels)
        contract.selectors.defaultChannelCount = numel(contract.selectors.defaultChannels);
    end

    if ~isfield(contract, 'summary') || isempty(contract.summary)
        contract.summary = '';
    else
        contract.summary = char(string(contract.summary));
    end
end

function out = normalizeResourceArray(v)
    out = resourceDef();
    if isempty(v) || ~isstruct(v)
        return;
    end
    defaults = resourceDef('', '', '', '', '', '', false, '');
    for i = 1:numel(v)
        item = mergeScalarStruct(defaults, v(i));
        item.type = char(string(getField(item, 'type', '')));
        item.role = char(string(getField(item, 'role', '')));
        item.symbol = char(string(getField(item, 'symbol', '')));
        item.param = char(string(getField(item, 'param', '')));
        item.port = char(string(getField(item, 'port', '')));
        item.nameParam = char(string(getField(item, 'nameParam', '')));
        item.required = logical(getField(item, 'required', false));
        item.transfer = char(string(getField(item, 'transfer', '')));
        if isempty(item.type)
            continue;
        end
        out(end+1) = item; %#ok<AGROW>
    end
end

function out = mergeParameterStruct(base, override)
    out = mergeScalarStruct(base, override);
    if isfield(override, 'notes') && ~isempty(override.notes)
        out.notes = normalizeCellstr(override.notes);
    end
    if isfield(override, 'fixed') && ~isempty(override.fixed)
        out.fixed = normalizeCellstr(override.fixed);
    end
    if isfield(override, 'design') && ~isempty(override.design)
        out.design = normalizeCellstr(override.design);
    end
    if isfield(override, 'template') && ~isempty(override.template)
        out.template = normalizeCellstr(override.template);
    end
    if isfield(override, 'static') && ~isempty(override.static)
        out.static = normalizeCellstr(override.static);
    end
    if isfield(override, 'run') && ~isempty(override.run)
        out.run = normalizeCellstr(override.run);
    end
    if isfield(override, 'data') && ~isempty(override.data)
        out.data = normalizeCellstr(override.data);
    end
end

function list = normalizeCellstr(v)
    list = {};
    if isempty(v)
        return;
    end
    if ischar(v) || isstring(v)
        list = cellstr(string(v(:)));
        list = list(~cellfun(@(x) isempty(strtrim(x)), list));
        return;
    end
    if iscell(v)
        tmp = {};
        for i = 1:numel(v)
            if isempty(v{i})
                continue;
            end
            try
                tmp{end+1} = char(string(v{i})); %#ok<AGROW>
            catch
            end
        end
        list = tmp(~cellfun(@(x) isempty(strtrim(x)), tmp));
    end
end

function p = normalizePort(p, requiredFallback)
    if nargin < 2
        requiredFallback = false;
    end
    if ~isfield(p, 'name') || isempty(p.name)
        p.name = '';
    end
    if ~isfield(p, 'type') || isempty(p.type)
        p.type = 'generic';
    end
    if ~isfield(p, 'required') || isempty(p.required)
        p.required = logical(requiredFallback);
    else
        p.required = logical(p.required);
    end
    if ~isfield(p, 'source') || isempty(p.source)
        p.source = 'edge';
    end
    p.name = char(string(p.name));
    p.type = char(string(p.type));
    p.source = char(string(p.source));
end

function pdef = portDef(name, type, required, source)
    if nargin < 4 || isempty(source)
        source = 'edge';
    end
    pdef = struct( ...
        'name', char(string(name)), ...
        'type', char(string(type)), ...
        'required', logical(required), ...
        'source', char(string(source)));
end

function v = getField(S, fieldName, defaultValue)
    v = defaultValue;
    if isstruct(S) && isfield(S, fieldName)
        tmp = S.(fieldName);
        if ~isempty(tmp)
            v = tmp;
        end
    end
end

function value = getNestedParam(node, names, defaultValue)
    value = defaultValue;
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        return;
    end
    for i = 1:numel(names)
        name = char(string(names{i}));
        if isfield(params, name) && ~isempty(params.(name))
            value = params.(name);
            return;
        end
    end
end

function mode = normalizeOutputMode(value, allowed, defaultValue)
    mode = lower(strtrim(choiceToChar(value)));
    mode = strrep(mode, '-', '_');
    mode = strrep(mode, ' ', '_');
    if isempty(mode) || ~any(strcmp(mode, allowed))
        mode = defaultValue;
    end
end

function txt = choiceToChar(value)
    txt = '';
    if isempty(value)
        return;
    end
    if iscell(value)
        flat = value(~cellfun(@isempty, value));
        if isempty(flat)
            return;
        end
        txt = char(string(flat{end}));
    elseif ischar(value)
        txt = value;
    elseif isstring(value) || isnumeric(value) || islogical(value) || iscategorical(value)
        vals = string(value(:));
        if ~isempty(vals)
            txt = char(vals(end));
        end
    else
        try
            txt = char(string(value));
        catch
            txt = '';
        end
    end
end
