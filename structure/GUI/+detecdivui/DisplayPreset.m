classdef DisplayPreset
    % Serializable display state; never contains pixels or scientific edits.
    methods (Static)
        function preset = capture(model,active,overlay,outlines)
            layers = model.Layers;
            styles = repmat(struct('mode','Fill','width',1),1,numel(layers));
            for k = 1:numel(layers)
                if strcmp(layers(k).kind,'Labels'), styles(k) = model.labelStyle(k); end
            end
            preset = struct('schema','detecdiv.ui.display-preset.v1', ...
                'layers',layers,'styles',styles,'active',layers(active).name, ...
                'overlay',logical(overlay),'outlines',logical(outlines));
            preset = detecdivui.DisplayPreset.validate(preset);
        end
        function [layers,styles,report] = plan(preset,layers,styles)
            preset = detecdivui.DisplayPreset.validate(preset);
            source = preset.layers; names = {layers.name};
            report = struct('matched',{{}},'missing',{{}},'incompatible',{{}});
            keep = false(1,numel(source));
            for k = 1:numel(source)
                at = find(strcmp(names,source(k).name),1);
                if isempty(at), report.missing{end+1} = source(k).name;
                elseif ~strcmp(layers(at).kind,source(k).kind)
                    report.incompatible{end+1} = source(k).name;
                else, keep(k) = true;
                end
            end
            assert(any(keep),'detecdivui:DisplayPresetMatch', ...
                'No matching layers with compatible types. Display was not changed.');
            % Reuse Score's name-based, channel-dimension-aware transfer on
            % detached display proxies, never on the live ROI.
            from = detecdivui.DisplayPreset.proxy(source(keep),preset.styles(keep));
            target = detecdivui.DisplayPreset.proxy(layers,styles);
            transfer = score_copyROIChannelPreset(from,target);
            report.matched = transfer.matched;
            d = target.display;
            for k = find(keep)
                at = find(strcmp(names,source(k).name),1);
                layers(at).visible = d.selectedchannel(at);
                limits = d.displaylim(:,at)';
                if all(isnan(limits)), limits = []; end
                layers(at).limits = limits;
                layers(at).opacity = d.alpha(at);
                % Preserve exact color text/precision; Score handles the
                % underlying color contract when validating this snapshot.
                layers(at).color = source(k).color;
                styles(at) = preset.styles(k);
            end
        end
        function preset = read(path)
            preset = detecdivui.DisplayPreset.validate(jsondecode(fileread(path)));
        end
        function write(path,preset)
            preset = detecdivui.DisplayPreset.validate(preset);
            [folder,~,extension] = fileparts(path);
            assert(strcmpi(extension,'.json'),'detecdivui:DisplayPresetFile','Use a .json display preset file.');
            if isempty(folder), folder = pwd; end
            temporary = [tempname(folder) '.json'];
            cleanup = onCleanup(@()detecdivui.DisplayPreset.removeTemporary(temporary));
            fid = fopen(temporary,'w','n','UTF-8');
            assert(fid>=0,'detecdivui:DisplayPresetFile','Cannot write the display preset.');
            closer = onCleanup(@()fclose(fid));
            written = fprintf(fid,'%s',jsonencode(preset));
            assert(written>0,'detecdivui:DisplayPresetFile','Cannot write the display preset.');
            clear closer;
            [ok,message] = movefile(temporary,path,'f');
            assert(ok,'detecdivui:DisplayPresetFile','%s',message);
        end
        function preset = validate(preset)
            assert(isstruct(preset)&&isscalar(preset)&&all(isfield(preset, ...
                {'schema','layers','styles','active','overlay','outlines'})), ...
                'detecdivui:DisplayPreset','Invalid display preset.');
            assert(strcmp(preset.schema,'detecdiv.ui.display-preset.v1'), ...
                'detecdivui:DisplayPreset','Unsupported display preset version.');
            assert(isstruct(preset.layers)&&~isempty(preset.layers)&&all(isfield(preset.layers, ...
                {'name','kind','visible','limits','color','opacity'})), ...
                'detecdivui:DisplayPreset','Invalid preset layers.');
            assert(isstruct(preset.styles)&&numel(preset.styles)==numel(preset.layers)&& ...
                all(isfield(preset.styles,{'mode','width'})), ...
                'detecdivui:DisplayPreset','Invalid preset mask styles.');
            preset.layers = reshape(preset.layers,1,[]); preset.styles = reshape(preset.styles,1,[]);
            scratch = roi('preset-validation',[]); scratch.display.channel = {'Layer'};
            for k = 1:numel(preset.layers)
                layer = preset.layers(k); style = preset.styles(k);
                assert(ischar(layer.name)&&isrow(layer.name)&&~isempty(layer.name), ...
                    'detecdivui:DisplayPreset','A layer name is missing.');
                assert(ischar(layer.kind)&&any(strcmp(layer.kind,{'Intensity','Labels','RGB'})), ...
                    'detecdivui:DisplayPreset','Invalid preset layer type.');
                validateattributes(layer.visible,{'logical'},{'scalar'});
                validateattributes(layer.opacity,{'numeric'},{'real','finite','scalar','>=',0,'<=',1});
                if ~isempty(layer.limits)
                    validateattributes(layer.limits,{'numeric'},{'real','finite','vector','numel',2});
                    assert(layer.limits(1)<layer.limits(2),'detecdivui:DisplayPreset','Invalid preset contrast limits.');
                    preset.layers(k).limits = double(reshape(layer.limits,1,2));
                end
                assert(ischar(layer.color)&&isrow(layer.color),'detecdivui:DisplayPreset','Invalid preset color.');
                if ~(strcmp(layer.kind,'Labels')&&strcmp(layer.color,'Labels')) && ...
                        ~(strcmp(layer.kind,'RGB')&&strcmp(layer.color,'RGB'))
                    [ok,message] = score_applyChannelColorSpec(scratch,1,layer.color);
                    assert(ok,'detecdivui:DisplayPreset','%s',message);
                    assert(~strcmp(layer.kind,'Labels')||strcmp(scratch.display.colorMode{1},'rgb'), ...
                        'detecdivui:DisplayPreset','Label colors must be Labels or an RGB triplet.');
                end
                assert(ischar(style.mode)&&any(strcmp(style.mode,{'Fill','Contours','Fill + Contours'})), ...
                    'detecdivui:DisplayPreset','Invalid preset contour style.');
                validateattributes(style.width,{'numeric'},{'real','finite','scalar','positive'});
            end
            assert(numel(unique({preset.layers.name}))==numel(preset.layers), ...
                'detecdivui:DisplayPreset','Preset layer names must be unique.');
            assert(ischar(preset.active)&&any(strcmp({preset.layers.name},preset.active)), ...
                'detecdivui:DisplayPreset','Invalid preset active layer.');
            validateattributes(preset.overlay,{'logical'},{'scalar'});
            validateattributes(preset.outlines,{'logical'},{'scalar'});
            % Keep only the contract, including when reading an extended file.
            preset = struct('schema',preset.schema,'layers',preset.layers,'styles',preset.styles, ...
                'active',preset.active,'overlay',preset.overlay,'outlines',preset.outlines);
        end
    end
    methods (Static, Access = private)
        function result = proxy(layers,styles)
            n = numel(layers); result = roi('display-preset',[]);
            d = struct('channel',{{layers.name}},'selectedchannel',[layers.visible], ...
                'alpha',[layers.opacity],'displaylim',nan(2,n),'rgb',ones(n,3), ...
                'colorMode',{repmat({'rgb'},1,n)},'colormapName',{repmat({''},1,n)});
            result.display = d;
            for k = 1:n
                if ~isempty(layers(k).limits), result.display.displaylim(:,k) = layers(k).limits(:); end
                if ~any(strcmp(layers(k).color,{'Labels','RGB'}))
                    score_applyChannelColorSpec(result,k,layers(k).color);
                end
            end
            result.display.contour = ~strcmp({styles.mode},'Fill');
            result.display.width = [styles.width];
        end
        function removeTemporary(path)
            if isfile(path), delete(path); end
        end
    end
end
