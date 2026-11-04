classdef LayerModel < handle
    % Per-session display state. Source images and ROI display metadata stay intact.
    properties (SetAccess = private)
        Layers = struct([])
    end
    properties (Access = private)
        Session
        Views
        Key = ''
        Frame = 0
        Planes = {}
        Scratch
    end
    methods
        function obj = LayerModel()
            obj.Views = containers.Map('KeyType','char','ValueType','any');
            obj.Scratch = roi('display-preview',[]);
        end
        function configure(obj,session,selected)
            [~,~,descriptors] = session.dimensions();
            key = sprintf('%d:%d',session.Position,session.Zone);
            if strcmp(key,obj.Key) && numel(descriptors) == numel(obj.Layers)
                if isempty(descriptors) || isequal({descriptors.name},{obj.Layers.name}), return; end
            end
            obj.Session = session; obj.Key = key; obj.invalidate();
            layers = struct('name',{},'visible',{},'kind',{},'limits',{},'color',{},'opacity',{});
            metadata = session.Project.fov(session.Position).display;
            if session.Zone > 0, metadata = session.Project.fov(session.Position).roi(session.Zone).display; end
            for k = 1:numel(descriptors)
                d = descriptors(k); kind = 'Intensity'; color = '1 1 1'; opacity = 1;
                if session.Zone > 0 && d.logicalId > 0
                    if isfield(metadata,'indexed') && numel(metadata.indexed) >= d.logicalId && metadata.indexed(d.logicalId)
                        kind = 'Labels';
                    elseif isfield(metadata,'intensity') && size(metadata.intensity,1) >= d.logicalId && ...
                            all(metadata.intensity(d.logicalId,:) == 0)
                        kind = 'Labels';
                    end
                    color = score_channelColorSpec(metadata,d.logicalId);
                end
                if strcmp(kind,'Labels')
                    color = 'Labels'; opacity = 0.45;
                    if isfield(metadata,'alpha') && numel(metadata.alpha) >= d.logicalId
                        alpha = double(metadata.alpha(d.logicalId));
                        if isfinite(alpha) && alpha >= 0 && alpha <= 1, opacity = alpha; end
                    end
                end
                if numel(d.planes) == 3, kind = 'RGB'; color = 'RGB'; end
                visible = k == selected;
                if session.Zone > 0 && isfield(metadata,'selectedchannel') && ...
                        numel(metadata.selectedchannel) >= numel(descriptors) && d.logicalId > 0 && ...
                        d.logicalId <= numel(metadata.selectedchannel)
                    visible = logical(metadata.selectedchannel(d.logicalId));
                end
                layers(k) = struct('name',d.name,'visible',visible,'kind',kind, ...
                    'limits',[],'color',color,'opacity',opacity);
            end
            if isKey(obj.Views,key)
                previous = obj.Views(key);
                for k = 1:numel(layers)
                    hit = find(strcmp({previous.name},layers(k).name),1);
                    if ~isempty(hit) && strcmp(previous(hit).kind,'RGB') == strcmp(layers(k).kind,'RGB')
                        layers(k) = previous(hit);
                    end
                end
            end
            obj.Layers = layers; obj.store();
        end
        function invalidate(obj)
            obj.Frame = 0; obj.Planes = {};
        end
        function plane = read(obj,index,frame)
            if obj.Frame ~= frame
                obj.Planes = cell(1,numel(obj.Layers)); obj.Frame = frame;
            end
            if numel(obj.Planes) < index || isempty(obj.Planes{index})
                plane = obj.Session.readPlane(frame,index);
                assert(~isempty(plane),'detecdivui:EmptyImage','Image unavailable. Check the source and selected channel.');
                obj.Planes{index} = plane;
            end
            plane = obj.Planes{index};
            if isempty(obj.Layers(index).limits) && ~strcmp(obj.Layers(index).kind,'Labels')
                if strcmp(obj.Layers(index).kind,'RGB') && isinteger(plane)
                    obj.Layers(index).limits = [0 double(intmax(class(plane)))];
                elseif strcmp(obj.Layers(index).kind,'RGB') && all(isfinite(plane(:))) && ...
                        min(plane(:)) >= 0 && max(plane(:)) <= 1
                    obj.Layers(index).limits = [0 1];
                else
                    obj.Layers(index).limits = obj.dataLimits(plane);
                end
                obj.store();
            end
        end
        function autoContrast(obj,index,frame)
            plane = obj.read(index,frame);
            assert(~strcmp(obj.Layers(index).kind,'Labels'),'detecdivui:LabelContrast','Label layers do not use intensity contrast.');
            obj.Layers(index).limits = obj.dataLimits(plane); obj.store();
        end
        function setVisible(obj,index,value)
            obj.Layers(index).visible = logical(value); obj.store();
        end
        function solo(obj,index)
            for k = 1:numel(obj.Layers), obj.Layers(k).visible = k == index; end
            obj.store();
        end
        function setLimits(obj,index,value)
            validateattributes(value,{'numeric'},{'vector','numel',2,'finite'});
            assert(value(1) < value(2),'detecdivui:Contrast','Minimum must be less than maximum.');
            obj.Layers(index).limits = double(reshape(value,1,2)); obj.store();
        end
        function setOpacity(obj,index,value)
            validateattributes(value,{'numeric'},{'scalar','finite','>=',0,'<=',1});
            obj.Layers(index).opacity = double(value); obj.store();
        end
        function setColor(obj,index,value)
            value = strtrim(char(string(value)));
            if strcmpi(value,'Labels') && strcmp(obj.Layers(index).kind,'Labels')
                value = 'Labels';
            else
                [ok,message] = score_applyChannelColorSpec(obj.Scratch,1,value);
                assert(ok,'detecdivui:Color','%s',message);
                if strcmp(obj.Layers(index).kind,'Labels')
                    assert(strcmp(obj.Scratch.display.colorMode{1},'rgb'), ...
                        'detecdivui:LabelColor','Use Labels or an RGB triplet for label layers.');
                end
            end
            obj.Layers(index).color = value; obj.store();
        end
        function setKind(obj,index,value)
            assert(any(strcmp(value,{'Intensity','Labels'})) && ~strcmp(obj.Layers(index).kind,'RGB'), ...
                'detecdivui:LayerKind','Invalid layer type.');
            obj.Layers(index).kind = value; obj.Layers(index).limits = [];
            if strcmp(value,'Labels'), obj.Layers(index).color = 'Labels';
            elseif strcmp(obj.Layers(index).color,'Labels'), obj.Layers(index).color = '1 1 1'; end
            obj.store();
        end
        function view = compose(obj,frame,selected)
            assert(~isempty(obj.Layers),'detecdivui:NoChannels','No image channels available for this FOV.');
            base = obj.read(selected,frame);
            visible = find([obj.Layers.visible]);
            view = struct('pixels',[],'limits',[0 1],'native',false,'names',{{obj.Layers(visible).name}});
            if isscalar(visible)
                k = visible(1); plane = obj.read(k,frame); layer = obj.Layers(k);
                rgbColor = sscanf(strrep(layer.color,',',' '),'%f');
                if strcmp(layer.kind,'Intensity') && isequal(rgbColor(:)',[1 1 1]) && layer.opacity == 1
                    view.pixels = plane; view.limits = layer.limits; view.native = true; return;
                elseif strcmp(layer.kind,'RGB') && layer.opacity == 1 && ...
                        ((isinteger(plane) && isequal(layer.limits,[0 double(intmax(class(plane)))])) || ...
                        (~isinteger(plane) && isequal(layer.limits,[0 1])))
                    view.pixels = plane; return;
                end
            end
            composite = zeros(size(base,1),size(base,2),3,'uint8');
            % Score puts intensities below indexed overlays, regardless of source order.
            labels = strcmp({obj.Layers.kind},'Labels');
            order = [visible(~labels(visible)),visible(labels(visible))];
            for k = order
                plane = obj.read(k,frame); layer = obj.Layers(k);
                assert(size(plane,1) == size(base,1) && size(plane,2) == size(base,2), ...
                    'detecdivui:LayerSize','Visible layers have different image sizes.');
                [rgb,overlay,alpha] = obj.renderWithScore(plane,layer);
                if strcmp(layer.kind,'Labels')
                    composite = uint8(double(composite).*(1-alpha) + 255*overlay.*alpha);
                else
                    composite = imlincomb(1,composite,layer.opacity,rgb);
                end
            end
            view.pixels = composite;
        end
    end
    methods (Access = private)
        function store(obj)
            if ~isempty(obj.Key), obj.Views(obj.Key) = obj.Layers; end
        end
        function [rgb,overlay,alpha] = renderWithScore(obj,plane,layer)
            proxy = obj.Scratch;
            proxy.display = struct('channel',{{'Layer'}},'rgb',[1 1 1],'indexed',false);
            proxy.channelid = ones(1,size(plane,3));
            param = score_collectDisplayOptions('mode','display','frames',1,'channel',1, ...
                'overlay',true,'RGB',{[1 1 1]});
            if strcmp(layer.kind,'Labels')
                values = double(plane(:));
                assert(all(isfinite(values) & values >= 0 & values == floor(values) & values <= flintmax), ...
                    'detecdivui:Labels','Label maps must contain finite nonnegative integer IDs.');
                proxy.image = plane; proxy.display.indexed = true;
                param.levels = {{'-1',0,layer.opacity,0,1}};
                if strcmp(layer.color,'Labels'), param.paintChannel = 1;
                else, score_applyChannelColorSpec(proxy,1,layer.color); end
            else
                % Contrast is expressed in source units; Score receives only a
                % temporary 16-bit display plane, never a modified source ROI.
                scaled = workflowui.stretchToUnit(plane,layer.limits,false);
                proxy.image = uint16(65535*scaled);
                param.levels = {[0 65535]};
                if ~strcmp(layer.kind,'RGB'), score_applyChannelColorSpec(proxy,1,layer.color); end
            end
            param.RGB = {proxy.display.rgb(1,:)};
            if isfield(proxy.display,'colorMode'), param.colorMode = proxy.display.colorMode; end
            if isfield(proxy.display,'colormapName'), param.colormapName = proxy.display.colormapName; end
            [rgb,~,overlay,alpha] = score_makeComposite(proxy,1,param);
        end
    end
    methods (Static, Access = private)
        function limits = dataLimits(plane)
            pixels = double(plane(isfinite(plane)));
            limits = [0 1];
            if ~isempty(pixels)
                limits = [min(pixels(:)) max(pixels(:))];
                if limits(2) <= limits(1), limits(2) = limits(1)+max(1,eps(limits(1))); end
            end
        end
    end
end
