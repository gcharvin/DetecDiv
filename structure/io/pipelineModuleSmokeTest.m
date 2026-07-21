function report = pipelineModuleSmokeTest()
% pipelineModuleSmokeTest  Read-only smoke test for pipeline module contracts.
%
% This intentionally avoids executing module engines. It checks that every
% discovered module can expose a contract, defaults can be inspected, and
% minimal synthetic nodes validate against a representative runtime context.

    audit = pipelineModuleAudit();
    bad = audit(strcmp(audit.ContractStatus, 'ERROR') | strcmp(audit.SetparamStatus, 'ERROR'), :);
    if ~isempty(bad)
        error('pipelineModuleSmokeTest:AuditFailed', ...
            'Module audit failed before smoke validation.');
    end

    ctx = representativeContext();
    rows = cell(height(audit), 5);

    for i = 1:height(audit)
        node = representativeNode(audit.Type{i}, audit.Package{i});
        pipe = struct('name', ['smoke_' node.id], 'nodes', node, 'edges', struct([]), 'branches', struct([]));
        try
            [ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
        catch ME
            ok = false;
            validation = struct('errors', {{ME.message}}, 'warnings', {{}});
        end

        rows{i,1} = char(string(audit.Type{i}));
        rows{i,2} = char(string(audit.Package{i}));
        rows{i,3} = logical(ok);
        rows{i,4} = joinMessages(getFieldLocal(validation, 'errors', {}));
        rows{i,5} = joinMessages(getFieldLocal(validation, 'warnings', {}));
    end

    report = cell2table(rows, 'VariableNames', {'Type','Package','OK','Errors','Warnings'});
    failed = report(~[report.OK], :);
    if ~isempty(failed)
        disp(failed);
        error('pipelineModuleSmokeTest:ValidationFailed', ...
            'At least one representative module node failed validation.');
    end
end

function ctx = representativeContext()
    ctx = struct();
    ctx.images = struct('stub', true);
    ctx.fovList = struct('channel', {{'TL', 'GFP', 'seg'}});
    ctx.roiList = 1;
    ctx.channels = {'TL', 'GFP', 'seg'};
    ctx.roiChannels = {'TL', 'GFP', 'seg', 'CombinedChannel', 'track_seg'};
    ctx.masks = {'seg'};
    ctx.dataSeries = {'div_1', 'RLS_div_1'};
    ctx.dataSeriesNames = ctx.dataSeries;
end

function node = representativeNode(typeName, pkgName)
    typeName = char(string(typeName));
    pkgName = char(string(pkgName));

    node = struct();
    node.id = lower(regexprep([typeName '_' pkgName], '[^a-zA-Z0-9]+', '_'));
    node.name = node.id;
    node.type = typeName;
    node.pkg = pkgName;
    node.params = representativeParams(typeName, pkgName);
    node.func = representativeFunction(typeName, pkgName);
    node.enabled = true;
    node = pipelineNormalizeNodes(node, 'persist');
end

function params = representativeParams(typeName, pkgName)
    typeKey = lower(char(string(typeName)));
    pkgKey = lower(char(string(pkgName)));
    params = struct('pkg', char(string(pkgName)));

    switch typeKey
        case 'dataloader'
            params.path = 'synthetic_raw_source';
            params.channelFilter = {'TL','GFP','seg'};

        case {'roipattern','roiidentify'}
            params.channel = 'TL';
            params.referenceFrame = 1;
            params.threshold = 0.5;
            params.patternImage = ones(8, 8, 'single');
            params.patternRect = [1 1 8 8];

        case 'roimanual'
            params.fovIndex = 1;

        case 'roigrid'
            params.gridCount = [8 8];
            params.mode = 'grid';

        case 'roitracked'
            params.channel = 'seg';
            params.extractChannels = {'TL','GFP'};
            params.margin = 0;

        case 'roiextract'
            params.extractChannels = {'TL','GFP'};
            params.frames = 1:3;
            params.correctDrift = false;

        case 'classifier'
            params.channels = {'TL'};
            params.outputName = 'div_1';
            switch pkgKey
                case 'cellposesam'
                    params.outputName = 'seg';
                    params.outputType = 'segmentation';
                case 'trackastra'
                    params.imageChannelName = 'TL';
                    params.instanceChannelName = 'seg';
                    params.outputName = 'trackastra';
                case 'cnn_lstm'
                    params.outputMode = 'lstm_only';
                case 'cnn'
                    params.outputType = 'classification';
            end

        case 'processor'
            params.outputName = 'processor_out';
            switch pkgKey
                case 'combinemultiplechannels'
                    params.Channel1 = 'TL';
                    params.Channel2 = 'GFP';
                    params.outputChannelName = 'CombinedChannel';
                    params.requiredChannelCount = 0;
                case 'computemetrics'
                    params.maskChannelCount = 1;
                    params.scoreChannelCount = 1;
                    params.mask1_name = 'seg';
                    params.mask1_label = 'cyto';
                    params.channel1_name = 'GFP';
                    params.channel2_name = 'N/A';
                    params.channel3_name = 'N/A';
                    params.channel4_name = 'N/A';
                    params.outputName = 'metrics';
                case 'computerls'
                    params.classification_data = 'div_1';
                    params.outputName = 'RLS_div_1';
                case 'computelineage'
                    params.classification_data = 'div_1';
                    params.outputName = 'lineage_div_1';
                case 'computemaxprojection'
                    params.channel = 'TL';
                    params.outputChannelName = 'TL_projection';
                    params.method = 'Max';
                case 'basicobjecttracking'
                    params.inputChannelName = 'seg';
                    params.outputChannelName = 'track_seg';
                case 'trackmotherlineageviterbi'
                    params.instanceChannelName = 'seg';
                    params.outputChannelName = 'MotherLineageViterbi';
                case 'formatindataseries'
                    params.outputName = 'formatted';
            end
    end
end

function f = representativeFunction(typeName, pkgName)
    typeKey = lower(char(string(typeName)));
    pkgName = char(string(pkgName));
    switch typeKey
        case 'dataloader'
            f = 'dataLoader.process';
        case {'roipattern','roiidentify'}
            f = 'roiPattern.process';
        case 'roimanual'
            f = 'roiManual.process';
        case 'roigrid'
            f = 'roiGrid.process';
        case 'roitracked'
            f = 'roiTracked.process';
        case 'roiextract'
            f = 'roiExtract.process';
        case 'classifier'
            f = [pkgName '.classify'];
        case 'processor'
            f = [pkgName '.process'];
        otherwise
            f = '';
    end
end

function txt = joinMessages(messages)
    if isempty(messages)
        txt = '';
        return;
    end
    if ischar(messages) || isstring(messages)
        txt = char(strjoin(string(messages(:)), ' | '));
        return;
    end
    if iscell(messages)
        txt = char(strjoin(string(messages(:)), ' | '));
    else
        txt = char(string(messages));
    end
end

function value = getFieldLocal(s, fieldName, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    end
end
