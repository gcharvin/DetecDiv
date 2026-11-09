classdef AnnotationLayerDraft < handle
    % Staged layer creation. Canonical ROI changes only after all writes pass.
    properties (SetAccess=private)
        Source
        Plan
        SaveFailed=false
        LastError=''
        Saved=false
    end
    properties (Access=private)
        Image
        Display
        Channels
        Model
        Files
        Data
        Scratch
    end
    methods
        function obj=AnnotationLayerDraft(source,provider,varargin)
            assert(~isempty(source.image),'detecdivui:AnnotationImage','Load the complete ROI sequence first.');
            assert(~isfield(source.display,'write_abs_start')||isempty(source.display.write_abs_start)||source.display.write_abs_start==0, ...
                'detecdivui:AnnotationWindow','Load the complete ROI sequence before creating mask layers.');
            assert(size(source.image,4)==annotationManager.frameCount(source),'detecdivui:AnnotationWindow','The ROI sequence is only partly loaded.');
            assert(detecdivui.MaskDraft.isLabel(source,provider),'detecdivui:AnnotationLayer','Select an indexed mask layer.');
            pix=source.findChannelID(provider);
            assert(isscalar(pix)&&pix<=size(source.image,3),'detecdivui:AnnotationLayer','Load the selected single-plane mask layer.');
            model=source.cellModel;
            if ~isstruct(model)||~isfield(model,'schema_version'), model=cellModel.create(source.id); end
            obj.Source=source; obj.Image=source.image; obj.Display=source.display; obj.Channels=source.channelid;
            obj.Model=source.cellModel; obj.Data=source.data; obj.Files=obj.fileState();
            obj.Plan=cellModel.maskLayerPlan(model,provider,source.display.channel,varargin{:});
            scratch=roi(source.id,source.value); scratch.path=source.path; scratch.image=source.image;
            scratch.channelid=source.channelid; scratch.display=source.display; scratch.cellModel=obj.Plan.model;
            scratch.cellModelInfo=source.cellModelInfo; scratch.cellModelInfo.loaded=true;
            scratch.data=dataseries.empty;
            for k=1:numel(source.data)
                ds=dataseries(); fields=properties(source.data(k));
                for j=1:numel(fields), ds.(fields{j})=source.data(k).(fields{j}); end
                scratch.data(end+1)=ds;
            end
            pixels=source.image(:,:,pix,:);
            for change=reshape(obj.Plan.changes,1,[])
                scratch.addChannel(pixels,change.layer,[1 1 1],[0 0 0]);
                if change.initialize
                    for frame=1:size(pixels,4)
                        scratch.cellModel=cellModel.syncFrame(scratch.cellModel,change.familyId,frame,pixels(:,:,1,frame), ...
                            'TrackPolicy','preserve_frame_or_unassigned');
                    end
                end
                cfg=score_getObjectDisplayConfig(scratch,change.layer);
                cfg.maskProvider=change.layer; cfg.objectFamily=change.result;
                score_setObjectDisplayConfig(scratch,change.layer,cfg);
            end
            kept=find(strcmp(scratch.cellModel.families.mask_provider,provider),1);
            if ~isempty(kept) && ~any([obj.Plan.changes.initialize])
                cfg=score_getObjectDisplayConfig(scratch,provider); cfg.maskProvider=provider;
                cfg.objectFamily=scratch.cellModel.families.name{kept}; score_setObjectDisplayConfig(scratch,provider,cfg);
            end
            obj.Plan.model=scratch.cellModel;
            % Provider changes alter the managed annotation context. Keep GT
            % and reviewed coverage, requiring validation again before Ready.
            [manifest,~]=annotationManager.readManifest(scratch);
            for k=1:numel(manifest.entries)
                entry=annotationManager.resetValidationState(manifest.entries(k));
                entry.status='draft'; entry.approved_at=''; entry.approved_hash='';
                entry.revision=uint32(double(entry.revision)+1); manifest.entries(k)=entry;
            end
            if ~isempty(manifest.entries), annotationManager.writeManifest(scratch,manifest,'Save',false); end
            obj.Scratch=scratch;
        end
        function save(obj)
            if obj.Saved, return; end
            source=obj.Source;
            assert(isequaln(source.image,obj.Image)&&isequaln(source.display,obj.Display)&& ...
                isequaln(source.channelid,obj.Channels)&&isequaln(source.cellModel,obj.Model)&&isequaln(source.data,obj.Data), ...
                'detecdivui:AnnotationLayerConflict','This ROI changed. Reopen layer creation after saving its pending annotations.');
            assert(isequal(obj.Files,obj.fileState()),'detecdivui:AnnotationLayerDisk','ROI files changed outside this operation.');
            scratch=obj.Scratch; pixels=scratch.image; display=scratch.display; channels=scratch.channelid;
            data=scratch.data; model=scratch.cellModel;
            try
                names={obj.Plan.changes.layer};
                if ~isfile(fullfile(source.path,['im_' source.id '.h5'])), names=cellstr(string(scratch.display.channel)); end
                assert(scratch.save(names,false),'detecdivui:AnnotationLayerSave','The dedicated mask layers were not saved.');
                scratch.saveCellModel(model);
                for name=names
                    assert(~isempty(h5info(fullfile(source.path,['im_' source.id '.h5']),['/' name{1}])), ...
                        'detecdivui:AnnotationLayerSave','A mask layer is missing from the H5 store.');
                end
            catch err
                scratch.image=pixels; scratch.display=display; scratch.channelid=channels; scratch.data=data; scratch.cellModel=model;
                obj.SaveFailed=true; obj.LastError=err.message; obj.Files=obj.fileState(); rethrow(err);
            end
            source.image=pixels; source.display=scratch.display; source.channelid=channels; source.data=data;
            source.cellModel=scratch.cellModel; source.cellModelInfo=scratch.cellModelInfo;
            obj.Saved=true; obj.SaveFailed=false; obj.LastError='';
        end
        function recover(obj)
            if ~obj.SaveFailed, return; end
            recovery=struct('roiId',obj.Source.id,'path',obj.Source.path,'plan',obj.Plan, ...
                'display',obj.Scratch.display,'channels',obj.Scratch.channelid, ...
                'model',obj.Scratch.cellModel,'data',obj.Scratch.data,'masks',{{}},'error',obj.LastError);
            for change=reshape(obj.Plan.changes,1,[])
                pix=obj.Scratch.findChannelID(change.layer);
                recovery.masks{end+1}=obj.Scratch.image(:,:,pix,:);
            end
            folder=fullfile(prefdir,'DetecDivUI','annotation-layer-recovery');
            if ~isfolder(folder), mkdir(folder); end
            file=fullfile(folder,[char(matlab.lang.internal.uuid) '.mat']);
            save(file,'recovery','-v7.3');
            warning('detecdivui:AnnotationLayerRecovery','Incomplete layer save recovered to %s',file);
        end
    end
    methods (Access=private)
        function state=fileState(obj)
            state=zeros(3,2); names={['im_' obj.Source.id '.h5'],['data_' obj.Source.id '.mat'],['objects_' obj.Source.id '.h5']};
            for k=1:3
                file=dir(fullfile(obj.Source.path,names{k})); if ~isempty(file), state(k,:)=[file(1).datenum file(1).bytes]; end
            end
        end
    end
end
