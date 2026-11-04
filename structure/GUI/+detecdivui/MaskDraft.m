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
    end
    properties (Access = private)
        Baseline
        Model
        Files
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
            obj.Model = source.cellModel; obj.Files = obj.fileState();
        end
        function plane = read(obj,frame)
            plane = obj.Masks(:,:,1,frame);
        end
        function edit(obj,frame,action,geometry,label,radius,overwrite)
            before = obj.read(frame);
            after = score_editMaskPlane(action,before,geometry,label,radius,overwrite);
            if isequal(before,after), return; end
            item = struct('frame',frame,'before',before,'after',after);
            obj.UndoStack{end+1} = item; obj.RedoStack = {};
            bytes = whos('item'); limit = max(1,min(20,floor(64*1024^2/max(1,bytes.bytes))));
            if numel(obj.UndoStack) > limit, obj.UndoStack = obj.UndoStack(end-limit+1:end); end
            obj.Masks(:,:,1,frame) = after; obj.updateDirty();
        end
        function undo(obj)
            if isempty(obj.UndoStack), return; end
            item = obj.UndoStack{end}; obj.UndoStack(end) = [];
            obj.Masks(:,:,1,item.frame) = item.before; obj.RedoStack{end+1} = item; obj.updateDirty();
        end
        function redo(obj)
            if isempty(obj.RedoStack), return; end
            item = obj.RedoStack{end}; obj.RedoStack(end) = [];
            obj.Masks(:,:,1,item.frame) = item.after; obj.UndoStack{end+1} = item; obj.updateDirty();
        end
        function discard(obj)
            assert(~obj.SaveFailed,'detecdivui:PartialSave','A save was incomplete. Fix the reported error and retry Save Masks before discarding.');
            obj.Masks = obj.Baseline; obj.UndoStack = {}; obj.RedoStack = {}; obj.Dirty = false;
        end
        function state = recovery(obj)
            state = struct('roiId',obj.Source.id,'roiPath',obj.Source.path,'channel',obj.Channel, ...
                'baseline',obj.Baseline,'masks',obj.Masks,'saveIncomplete',obj.SaveFailed);
        end
        function restore(obj,state)
            assert(strcmp(state.roiId,obj.Source.id) && strcmpi(state.roiPath,obj.Source.path) && ...
                strcmp(state.channel,obj.Channel) && ...
                isequal(size(state.masks),size(obj.Masks)) && ...
                (isequal(obj.Baseline,state.baseline) || isequal(obj.Baseline,state.masks)), ...
                'detecdivui:MaskRecoveryConflict','Recovery belongs to another ROI/provider or conflicts with its current pixels.');
            obj.Masks = state.masks; obj.SaveFailed = logical(state.saveIncomplete);
            obj.UndoStack = {}; obj.RedoStack = {}; obj.updateDirty();
        end
        function followSave(obj,other)
            if obj == other || ~isequal(obj.Source,other.Source) || strcmp(obj.Channel,other.Channel), return; end
            assert(isequal(obj.Source.image(:,:,obj.Pix,:),obj.Baseline), ...
                'detecdivui:MaskConflict','Another provider save changed this draft target.');
            obj.Model = obj.Source.cellModel; obj.Files = obj.fileState();
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
            scratch.cellModel = source.cellModel; scratch.cellModelInfo = source.cellModelInfo;
            scratch.data = dataseries.empty;
            for k = 1:numel(source.data)
                ds = dataseries(); names = properties(source.data(k));
                for p = 1:numel(names), ds.(names{p}) = source.data(k).(names{p}); end
                scratch.data(end+1) = ds;
            end
            frames = find(any(reshape(obj.Masks ~= obj.Baseline,[],size(obj.Masks,4)),1));
            if obj.SaveFailed, frames = 1:size(obj.Masks,4); end
            score_syncCellModelFrames(scratch,obj.Channel,frames,'Save',false);
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
                assert(scratch.save({obj.Channel},false),'detecdivui:MaskSave','ROI mask/data save failed.');
                if isfield(scratch.cellModel,'schema_version'), scratch.saveCellModel(scratch.cellModel); end
            catch err
                obj.SaveFailed = true; obj.LastError = err.message; obj.Files = obj.fileState(); rethrow(err);
            end
            source.image(:,:,obj.Pix,:) = obj.Masks; source.data = savedData;
            source.cellModel = scratch.cellModel; source.cellModelInfo = scratch.cellModelInfo;
            source.display = scratch.display;
            obj.Baseline = obj.Masks; obj.Model = source.cellModel; obj.Files = obj.fileState();
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
            obj.Dirty = obj.SaveFailed || ~isequal(obj.Masks,obj.Baseline);
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
