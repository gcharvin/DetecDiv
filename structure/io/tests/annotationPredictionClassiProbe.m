classdef annotationPredictionClassiProbe < classi
    %ANNOTATIONPREDICTIONCLASSIPROBE Capture classifyData wiring in tests.
    methods
        function obj = annotationPredictionClassiProbe(path, name, id)
            obj@classi(path, name, id);
        end

        function logparf = classifyData(~, roiObj, varargin)
            channelArgument = [];
            ctx = struct();
            for i = 1:(numel(varargin)-1)
                key = varargin{i};
                if ~(ischar(key) || (isstring(key) && isscalar(key)))
                    continue;
                end
                if strcmpi(char(string(key)), 'Channel')
                    channelArgument = varargin{i+1};
                elseif strcmpi(char(string(key)), 'Ctx')
                    ctx = varargin{i+1};
                end
            end
            strictRequiredChannels = false;
            try
                strictRequiredChannels = logical( ...
                    ctx.io.strictRequiredChannels);
            catch
            end
            setappdata(0, 'DetecDivAnnotationPredictionProbe', struct( ...
                'channelArgument', {channelArgument}, ...
                'strictRequiredChannels', strictRequiredChannels));

            sourceName = char(string(ctx.params.instanceChannelName));
            sourceIndex = roiObj.findChannelID(sourceName, 'exact');
            stack = uint16(roiObj.image(:,:,sourceIndex(1),:));
            predictionChannel = char(string( ...
                ctx.params.outputTrackChannelName));
            if ~startsWith(predictionChannel, 'results_', ...
                    'IgnoreCase', true)
                predictionChannel = ['results_' predictionChannel];
            end
            existing = roiObj.findChannelID(predictionChannel, 'exact');
            if isempty(existing)
                roiObj.addChannel(stack, predictionChannel, ...
                    [1 1 1], [0 0 0]);
            else
                roiObj.image(:,:,existing,:) = stack;
            end

            model = cellModel.create(roiObj.id);
            [model, ~, ~] = cellModel.applyLineageResult(model, ...
                squeeze(stack), predictionChannel, '', ...
                char(string(ctx.params.outputFamilyName)), ...
                struct('edges', struct([])), true, ...
                'pred:cellLatentModel');
            roiObj.cellModel = model;
            roiObj.saveCellModel(model);
            logparf = 1;
        end
    end
end
