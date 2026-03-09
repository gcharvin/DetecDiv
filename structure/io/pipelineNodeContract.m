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
    if isfield(node, 'contract') && isstruct(node.contract)
        existing = node.contract;
    end
    contract = mergeContracts(defaultContract, existing, node);
end

function contract = defaultContractForNode(node)
    in = struct('name',{},'type',{},'required',{},'source',{});
    out = struct('name',{},'type',{},'required',{},'source',{});
    selectors = defaultSelectors();
    requirements = defaultRequirements();
    capabilities = defaultCapabilities();
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
            selectors.defaultChannels = {};
            requirements.params.optional = {'path','positionFilter','channelFilter','stackFilter'};
            capabilities.outputsChannels = true;
            capabilities.outputsImages = true;
            capabilities.outputsFovList = true;
            summary = 'Loads positions/FOVs and exposes source image channels.';

        case {'roiidentify','roipattern'}
            in = portDef('images', 'imageSet', true, 'edge');
            out = portDef('roiList', 'roiList', true, 'edge');
            selectors.channelParam = 'channel';
            selectors.channelIndexParam = 'channelIndex';
            selectors.framesParam = 'referenceFrame';
            requirements.images.required = true;
            requirements.images.channelsMin = 1;
            requirements.params.optional = {'threshold','referenceFrame','keepExisting','fovIndex'};
            capabilities.createsRoiList = true;
            capabilities.preservesRoiList = true;
            summary = 'Detects ROIs from source images, usually on one selected channel.';

        case 'roimanual'
            in = portDef('images', 'imageSet', true, 'edge');
            out = portDef('roiList', 'roiList', true, 'edge');
            requirements.images.required = true;
            requirements.params.optional = {'fovIndex','keepExisting','skipExisting','errorOnExisting'};
            capabilities.createsRoiList = true;
            capabilities.preservesRoiList = true;
            summary = 'Creates or edits ROIs manually from source FOV images.';

        case 'roigrid'
            in = portDef('images', 'imageSet', true, 'edge');
            out = portDef('roiList', 'roiList', true, 'edge');
            requirements.images.required = true;
            requirements.params.optional = {'fovIndex','mode','gridCount','keepExisting'};
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
            requirements.roi.required = true;
            requirements.roi.masks = true;
            requirements.params.optional = {'fovIndex','roiIndex','margin','extract','extractFrames','extractChannels'};
            capabilities.createsRoiList = true;
            capabilities.preservesRoiList = true;
            capabilities.roiMasks = true;
            summary = 'Builds tracked ROIs from existing ROIs and compatible mask outputs.';

        case 'roiextract'
            in = portDef('roiList', 'roiList', true, 'edge');
            out = [ ...
                portDef('roiList',    'roiList',       true,  'edge'), ...
                portDef('dataSeries', 'dataSeriesSet', false, 'edge'), ...
                portDef('channels',   'channelSet',    false, 'edge') ...
                ];
            selectors.channelsParam = 'channels';
            selectors.framesParam = 'frames';
            requirements.roi.required = true;
            requirements.params.optional = {'fovIndex','frames','channels','extend','correctDrift'};
            capabilities.preservesRoiList = true;
            capabilities.roiChannels = true;
            capabilities.outputsChannels = true;
            summary = 'Extracts ROI crops and materializes ROI image channels for downstream ROI processing.';

        case 'processor'
            in = portDef('roiList', 'roiList', true, 'edge');
            out = [ ...
                portDef('roiList',    'roiList',       true,  'edge'), ...
                portDef('dataSeries', 'dataSeriesSet', true,  'edge') ...
                ];
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
            summary = 'Processes ROI content. Requires ROI support and usually at least one ROI image channel.';

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
            requirements.roi.required = true;
            requirements.roi.channelsMin = 1;
            requirements.params.required = {'pkg'};
            capabilities.preservesRoiList = true;
            capabilities.roiDataSeries = true;
            capabilities.outputsDataSeries = true;
            summary = 'Classifies ROI content from selected ROI channels and writes derived outputs.';
            if classifierProducesMasks(p, f)
                out = [portDef('roiList', 'roiList', true, 'edge'), portDef('masks', 'maskSet', true, 'edge')];
                capabilities.roiMasks = true;
                capabilities.outputsMasks = true;
                capabilities.outputsChannels = true;
                if strcmp(p, 'cellposesam')
                    capabilities.roiDataSeries = false;
                    capabilities.outputsDataSeries = false;
                    summary = 'Segments ROI content into instance masks and optional result channels.';
                else
                    out = [out, portDef('dataSeries', 'dataSeriesSet', false, 'edge')];
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
        'requirements', requirements, ...
        'capabilities', capabilities, ...
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
        if isfield(existingContract, 'summary') && ~isempty(existingContract.summary)
            contract.summary = char(string(existingContract.summary));
        end
    end

    contract = backfillFromNodeFields(contract, node);
    contract = backfillSelectorsFromNodeParams(contract, node);
    contract = normalizeContract(contract);
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

    if strcmp(getField(node, 'type', ''), 'classifier')
        switch pkgName
            case 'cellposesam'
                contract.requirements.roi.channelsMin = max(contract.requirements.roi.channelsMin, 1);
                contract.capabilities.outputsMasks = true;
                contract.capabilities.outputsChannels = true;
                contract.capabilities.roiMasks = true;
                contract.summary = 'CellposeSAM-like classifier: segments ROI channels into instance masks and result channels.';
        end

        if classifierProducesMasks(pkgName, funcName)
            contract.capabilities.outputsMasks = true;
            contract.capabilities.outputsChannels = true;
            contract.capabilities.roiMasks = true;
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

    contract.selectors.defaultChannels = normalizeCellstr(contract.selectors.defaultChannels);
    contract.requirements.params.required = normalizeCellstr(contract.requirements.params.required);
    contract.requirements.params.optional = normalizeCellstr(contract.requirements.params.optional);
    contract.requirements.notes = normalizeCellstr(contract.requirements.notes);
    contract.capabilities.notes = normalizeCellstr(contract.capabilities.notes);

    if isempty(contract.selectors.defaultChannelCount) && ~isempty(contract.selectors.defaultChannels)
        contract.selectors.defaultChannelCount = numel(contract.selectors.defaultChannels);
    end

    if ~isfield(contract, 'summary') || isempty(contract.summary)
        contract.summary = '';
    else
        contract.summary = char(string(contract.summary));
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
