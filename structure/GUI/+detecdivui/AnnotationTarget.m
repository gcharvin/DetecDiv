classdef AnnotationTarget
    % Presentation adapter for the ROI layer and optional classifier GT contract.
    methods (Static)
        function target=describe(source,layer,classifier)
            if nargin<3, classifier=[]; end
            target=struct('layer',layer,'role','Mask','semantic',false,'classes',{{}},'editable',true,'families',uint32([]));
            model=source.cellModel;
            if isstruct(model)&&isfield(model,'families')&&isfield(model.families,'mask_provider')
                target.families=model.families.family_id(strcmp(model.families.mask_provider,layer));
            end
            if isempty(classifier), return; end
            target.role='Result'; target.editable=false;
            spec=annotationManager.specForClassifier(classifier);
            for component=reshape(spec.components,1,[])
                gt=component.groundTruth; names={gt.channel,gt.maskProvider};
                if ~isempty(gt.family)
                    [at,~]=cellModel.familyIndex(model,gt.family);
                    if ~isempty(at), names{end+1}=model.families.mask_provider{at}; end %#ok<AGROW>
                end
                if any(strcmp(names,layer))
                    target.role='GT'; target.editable=true;
                    if strcmp(component.kind,'semantic_mask'), target.semantic=true; target.classes=component.classes; end
                elseif any(strcmp([{component.prediction.channel} component.prediction.channelCandidates],layer)) && ~target.editable
                    target.role='Prediction';
                end
            end
        end
    end
end
