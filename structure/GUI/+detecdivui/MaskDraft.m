classdef MaskDraft < handle
    % Isolated mask edits. Existing ROI/Score persistence remains authoritative.
    properties (SetAccess = private)
        Source
        Channel
        Pix
        Masks
        Dirty = false
        SaveFailed = false
        LastError = ''
        UndoStack = {}
        RedoStack = {}
        WorkingModel = struct()
    end
    properties (Access = private)
        Baseline
        Model
        Files
        PreviewCache = []
    end
    methods
        function obj = MaskDraft(source,channel)
            [provider,~,pix] = score_resolveMaskProvider(source,channel);
            assert(detecdivui.MaskDraft.isLabel(source,provider),'detecdivui:MaskType', ...
                'Select an indexed annotation mask; intensity and RGB channels cannot be edited here.');
            assert(~isfield(source.display,'write_abs_start') || isempty(source.display.write_abs_start) || ...
                source.display.write_abs_start == 0,'detecdivui:MaskFrameWindow', ...
                'Load the complete ROI sequence before editing contours.');
            physical = source.findChannelID(provider);
            assert(isscalar(physical) && isscalar(pix) && pix >= 1 && pix <= size(source.image,3), ...
                'detecdivui:MaskProvider','Load a single-plane mask provider first.');
            obj.Source = source; obj.Channel = provider; obj.Pix = pix;
            obj.Masks = source.image(:,:,pix,:); obj.Baseline = obj.Masks;
            validateattributes(obj.Masks,{'numeric'},{'real','finite','nonnegative','integer','<=',65535});
            [~,status] = score_getCellModel(source);
            assert(any(strcmp(status,{'ok','missing'})),'detecdivui:CellModel','Cannot edit this model: %s',status);
            obj.Model = source.cellModel; obj.WorkingModel = obj.Model; obj.Files = obj.fileState();
        end
        function plane = read(obj,frame)
            plane = obj.Masks(:,:,1,frame);
        end
        function edit(obj,frame,action,geometry,label,radius,overwrite)
            before = obj.read(frame);
            after = score_editMaskPlane(action,before,geometry,label,radius,overwrite);
            if isequal(before,after), return; end
            item = struct('kind','mask','frame',frame,'before',before,'after',after);
            obj.push(item);
            obj.Masks(:,:,1,frame) = after; obj.updateDirty();
        end
        function undo(obj)
            if isempty(obj.UndoStack), return; end
            item = obj.UndoStack{end}; obj.UndoStack(end) = [];
            obj.applyHistory(item,false); obj.RedoStack{end+1} = item; obj.updateDirty();
        end
        function redo(obj)
            if isempty(obj.RedoStack), return; end
            item = obj.RedoStack{end}; obj.RedoStack(end) = [];
            obj.applyHistory(item,true); obj.UndoStack{end+1} = item; obj.updateDirty();
        end
        function discard(obj)
            assert(~obj.SaveFailed,'detecdivui:PartialSave','A save was incomplete. Fix the reported error and retry Save Masks before discarding.');
            obj.Masks = obj.Baseline; obj.WorkingModel = obj.Model;
            obj.UndoStack = {}; obj.RedoStack = {}; obj.updateDirty();
        end
        function state = recovery(obj)
            state = struct('roiId',obj.Source.id,'roiPath',obj.Source.path,'channel',obj.Channel, ...
                'baseline',obj.Baseline,'masks',obj.Masks,'saveIncomplete',obj.SaveFailed, ...
                'baselineModel',obj.Model,'model',obj.WorkingModel);
        end
        function restore(obj,state)
            validateattributes(state.masks,{'numeric'},{'real','finite','nonnegative','integer','<=',65535});
            assert(strcmp(state.roiId,obj.Source.id) && strcmpi(state.roiPath,obj.Source.path) && ...
                strcmp(state.channel,obj.Channel) && ...
                strcmp(class(state.masks),class(obj.Masks)) && ...
                isequal(size(state.masks),size(obj.Masks)) && ...
                (isequal(obj.Baseline,state.baseline) || isequal(obj.Baseline,state.masks)), ...
                'detecdivui:MaskRecoveryConflict','Recovery belongs to another ROI/provider or conflicts with its current pixels.');
            if isfield(state,'model')
                assert(isequal(obj.Model,state.baselineModel) || isequal(obj.Model,state.model), ...
                    'detecdivui:TrackRecoveryConflict','Recovery conflicts with the current cellular model.');
                if isfield(state.model,'schema_version'), cellModel.validate(state.model,'Throw',true); end
                obj.WorkingModel = state.model;
            end
            obj.Masks = state.masks; obj.SaveFailed = logical(state.saveIncomplete);
            obj.UndoStack = {}; obj.RedoStack = {}; obj.updateDirty();
        end
        function followSave(obj,other)
            if obj == other || ~isequal(obj.Source,other.Source) || strcmp(obj.Channel,other.Channel), return; end
            assert(isequal(obj.Source.image(:,:,obj.Pix,:),obj.Baseline), ...
                'detecdivui:MaskConflict','Another provider save changed this draft target.');
            if ~isequal(obj.WorkingModel,obj.Model), return; end % Preserve conflicting model edits for explicit resolution.
            history = [obj.UndoStack obj.RedoStack];
            if ~isequal(obj.Model,obj.Source.cellModel) && any(cellfun(@(item)strcmp(item.kind,'model'),history))
                % Old whole-model snapshots cannot undo a different provider's committed edits.
                obj.UndoStack = {}; obj.RedoStack = {};
            end
            obj.Model = obj.Source.cellModel; obj.WorkingModel = obj.Model;
            obj.PreviewCache = []; obj.Files = obj.fileState();
        end
        function yes = matchesSource(obj)
            yes = isequal(obj.Source.image(:,:,obj.Pix,:),obj.Baseline) && isequal(obj.Source.cellModel,obj.Model);
        end
        function yes = hasModelEdits(obj)
            yes = ~isequal(obj.WorkingModel,obj.Model);
        end
        function yes = historyTouchesModel(obj,action)
            stack = obj.UndoStack; if strcmp(action,'redo'), stack = obj.RedoStack; end
            yes = ~isempty(stack) && strcmp(stack{end}.kind,'model');
        end
        function model = previewModel(obj)
            if ~isempty(obj.PreviewCache), model = obj.PreviewCache; return; end
            model = obj.WorkingModel;
            if ~isfield(model,'schema_version'), return; end
            scratch = obj.modelScratch(model);
            frames = find(any(reshape(obj.Masks ~= obj.Baseline,[],size(obj.Masks,4)),1));
            obj.syncModels(scratch,frames);
            model = scratch.cellModel; obj.PreviewCache = model;
        end
        function report = importLegacy(obj)
            assert(~isfield(obj.WorkingModel,'schema_version'),'detecdivui:ExistingModel', ...
                'A cellular model already exists; select one of its families.');
            scratch = obj.modelScratch(obj.WorkingModel); scratch.data = obj.Source.data;
            emptyData = isempty(scratch.data) || (isscalar(scratch.data) && ...
                isempty(scratch.data.groupid) && isempty(scratch.data.data));
            if emptyData && isfile(fullfile(scratch.path,['data_' scratch.id '.mat']))
                scratch.load('data','Silent');
            end
            [model,report] = cellModel.fromLegacy(scratch,'Channels',{obj.Channel});
            assert(report.validation.ok,'detecdivui:LegacyTracks','Legacy track import is invalid: %s', ...
                strjoin(cellstr(report.validation.errors),'; '));
            assert(~isempty(model.families.family_id),'detecdivui:LegacyTracks','No mask family was imported.');
            obj.commitModel(model,[],{},{});
        end
        function report = editTrack(obj,action,family,frame,label,target,scope)
            if nargin < 7, scope = 'frame'; end
            model = obj.previewModel();
            assert(isfield(model,'schema_version'),'detecdivui:MissingModel','Import legacy tracks or load a cellular model first.');
            [index,familyId] = cellModel.familyIndex(model,family);
            assert(~isempty(index) && strcmp(model.families.mask_provider{index},obj.Channel), ...
                'detecdivui:TrackProvider','The selected family uses another mask provider.');
            instance = cellModel.findInstance(model,familyId,frame,label);
            assert(~isempty(instance),'detecdivui:TrackSelection','Select an object on this frame.');
            frames = []; before = {}; after = {};
            switch action
                case {'assign','new'}
                    if strcmp(action,'new'), target = cellModel.nextTrackId(model,familyId); end
                    [model,report] = cellModel.reassignTrack(model,familyId,frame,label,target,scope);
                case 'swap'
                    assert(instance.track_id > 0,'detecdivui:UntrackedObject','Assign a track before swapping IDs.');
                    [model,report] = cellModel.swapTrackIds(model,familyId,instance.track_id,target);
                case {'parent','unparent'}
                    if strcmp(action,'unparent'), target = uint64(0); end
                    [model,report] = cellModel.setParentTrack(model,familyId,frame,instance.track_id,target);
                case 'delete'
                    assert(instance.track_id > 0,'detecdivui:UntrackedObject','Select an assigned track first.');
                    [model,report] = cellModel.removeTrack(model,familyId,instance.track_id);
                    frames = unique(report.instance_frames); before = cell(1,numel(frames)); after = before;
                    for k = 1:numel(frames)
                        before{k} = obj.read(frames(k)); after{k} = before{k};
                        labels = report.mask_labels(report.instance_frames == frames(k));
                        for value = labels
                            after{k} = score_editMaskPlane('delete',after{k},[],value);
                        end
                    end
                otherwise
                    error('detecdivui:TrackAction','Unknown track edit action.');
            end
            obj.commitModel(model,frames,before,after);
        end
        function save(obj)
            if ~obj.Dirty, return; end
            source = obj.Source;
            assert(isequal(source.findChannelID(obj.Channel),obj.Pix),'detecdivui:MaskMapping', ...
                'The ROI channel mapping changed. Reopen the authoritative ROI before saving.');
            assert(isequal(source.image(:,:,obj.Pix,:),obj.Baseline) && isequal(source.cellModel,obj.Model), ...
                'detecdivui:MaskConflict','This ROI changed in another tool. Keep the draft and resolve the conflict before saving.');
            assert(isequal(obj.Files,obj.fileState()),'detecdivui:MaskDiskConflict', ...
                'ROI files changed outside this editor. Keep the draft and reopen the authoritative ROI before saving.');
            assert(isfolder(source.path),'detecdivui:MaskPath','The ROI folder is missing. Relink its storage and retry Save Masks.');
            % Independent dataseries handles prevent draft review changes leaking.
            scratch = roi(source.id,source.value); scratch.path = source.path;
            scratch.image = source.image; scratch.image(:,:,obj.Pix,:) = obj.Masks;
            scratch.channelid = source.channelid; scratch.display = source.display;
            scratch.cellModel = obj.WorkingModel; scratch.cellModelInfo = source.cellModelInfo;
            if isfield(obj.WorkingModel,'schema_version'), scratch.cellModelInfo.loaded = true; end
            scratch.data = dataseries.empty;
            for k = 1:numel(source.data)
                ds = dataseries(); names = properties(source.data(k));
                for p = 1:numel(names), ds.(names{p}) = source.data(k).(names{p}); end
                scratch.data(end+1) = ds;
            end
            frames = find(any(reshape(obj.Masks ~= obj.Baseline,[],size(obj.Masks,4)),1));
            if obj.SaveFailed, frames = 1:size(obj.Masks,4); end
            obj.syncModels(scratch,frames);
            if ~isequal(obj.WorkingModel,obj.Model), frames = 1:size(obj.Masks,4); end
            [manifest,~] = annotationManager.readManifest(scratch);
            % Conservatively invalidate approved bundles dependent on this ROI.
            for k = 1:numel(manifest.entries)
                entry = annotationManager.resetValidationState(manifest.entries(k));
                entry.status = 'draft'; entry.approved_at = ''; entry.approved_hash = '';
                entry.revision = uint32(double(entry.revision)+1);
                for j = 1:numel(entry.review)
                    entry.review(j).complete = false;
                    if strcmp(entry.review(j).unit,'frame')
                        valid = frames(frames <= numel(entry.review(j).frames));
                        entry.review(j).frames(valid) = false;
                    end
                end
                manifest.entries(k) = entry;
            end
            if ~isempty(manifest.entries), annotationManager.writeManifest(scratch,manifest,'Save',false); end
            savedData = scratch.data; % roi.save intentionally purges its caches.
            try
                option = {obj.Channel};
                if isequal(obj.Masks,obj.Baseline) && ~obj.SaveFailed && ...
                        isfile(fullfile(source.path,['im_' source.id '.h5'])), option = 'data'; end
                % A model-only edit with no lifecycle manifest has no MAT
                % mutation. roi.save('data') legitimately returns false for
                % an empty placeholder dataseries; do not turn that into a failure.
                if ~ischar(option) || ~strcmp(option,'data') || ~isempty(manifest.entries)
                    assert(scratch.save(option,false),'detecdivui:MaskSave','ROI mask/model data save failed.');
                end
                if isfield(scratch.cellModel,'schema_version'), scratch.saveCellModel(scratch.cellModel); end
            catch err
                obj.SaveFailed = true; obj.LastError = err.message; obj.Files = obj.fileState(); rethrow(err);
            end
            source.image(:,:,obj.Pix,:) = obj.Masks; source.data = savedData;
            source.cellModel = scratch.cellModel; source.cellModelInfo = scratch.cellModelInfo;
            source.display = scratch.display;
            obj.Baseline = obj.Masks; obj.Model = source.cellModel; obj.Files = obj.fileState();
            obj.WorkingModel = obj.Model; obj.PreviewCache = [];
            obj.Dirty = false; obj.SaveFailed = false; obj.LastError = ''; obj.UndoStack = {}; obj.RedoStack = {};
        end
    end
    methods (Static)
        function yes = isLabel(source,name)
            index = find(strcmp(cellstr(string(source.display.channel)),name),1); yes = false;
            if isempty(index), return; end
            metadata = source.display;
            yes = (isfield(metadata,'indexed') && numel(metadata.indexed) >= index && metadata.indexed(index)) || ...
                (isfield(metadata,'intensity') && size(metadata.intensity,1) >= index && all(metadata.intensity(index,:) == 0));
        end
    end
    methods (Access = private)
        function updateDirty(obj)
            obj.PreviewCache = [];
            obj.Dirty = obj.SaveFailed || ~isequal(obj.Masks,obj.Baseline) || ~isequal(obj.WorkingModel,obj.Model);
        end
        function push(obj,item)
            obj.UndoStack{end+1} = item; obj.RedoStack = {};
            while numel(obj.UndoStack) > 1
                stack = obj.UndoStack; bytes = whos('stack');
                if numel(stack) <= 20 && bytes.bytes <= 64*1024^2, break; end
                obj.UndoStack(1) = [];
            end
        end
        function scratch = modelScratch(obj,model)
            source = obj.Source; scratch = roi(source.id,source.value);
            scratch.path = source.path; scratch.image = source.image;
            scratch.image(:,:,obj.Pix,:) = obj.Masks; scratch.channelid = source.channelid;
            scratch.display = source.display; scratch.cellModel = model;
            scratch.cellModelInfo = source.cellModelInfo;
            if isfield(model,'schema_version'), scratch.cellModelInfo.loaded = true; end
        end
        function syncModels(obj,scratch,frames)
            if isempty(frames) || ~isfield(scratch.cellModel,'schema_version'), return; end
            families = scratch.cellModel.families;
            rows = find(strcmp(families.mask_provider,obj.Channel));
            display = scratch.display;
            for row = reshape(rows,1,[])
                cfg = score_getObjectDisplayConfig(scratch,obj.Channel);
                cfg.objectFamily = families.name{row}; cfg.maskProvider = obj.Channel;
                score_setObjectDisplayConfig(scratch,obj.Channel,cfg);
                score_syncCellModelFrames(scratch,obj.Channel,frames,'Save',false);
            end
            scratch.display = display;
        end
        function commitModel(obj,model,frames,before,after)
            if isequal(model,obj.WorkingModel) && isempty(frames), return; end
            item = struct('kind','model','before',obj.WorkingModel,'after',model, ...
                'frames',frames,'beforeMasks',{before},'afterMasks',{after});
            obj.push(item); obj.WorkingModel = model;
            for k = 1:numel(frames), obj.Masks(:,:,1,frames(k)) = after{k}; end
            obj.updateDirty();
        end
        function applyHistory(obj,item,forward)
            field = 'before'; if forward, field = 'after'; end
            if strcmp(item.kind,'mask'), obj.Masks(:,:,1,item.frame) = item.(field); return; end
            obj.WorkingModel = item.(field); masks = item.([field 'Masks']);
            for k = 1:numel(item.frames), obj.Masks(:,:,1,item.frames(k)) = masks{k}; end
        end
        function state = fileState(obj)
            state = zeros(3,2); names = {['im_' obj.Source.id '.h5'], ...
                ['data_' obj.Source.id '.mat'],['objects_' obj.Source.id '.h5']};
            for k = 1:3
                file = dir(fullfile(obj.Source.path,names{k}));
                if ~isempty(file), state(k,:) = [file(1).datenum file(1).bytes]; end
            end
        end
    end
end
