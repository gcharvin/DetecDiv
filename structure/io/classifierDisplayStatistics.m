function classifierDisplayStatistics(classif,roiIndices)
%CLASSIFIERDISPLAYSTATISTICS Frontend selection for independently named outputs.
% The backend never guesses which classifier produced an arbitrary channel.
if cnn_lstm.isFrozenEncoder(classif) || ~classifierStats.supports(classif)
    classif.stats('Confusion','Classes','Rois',roiIndices,'Force');return;
end
spec=annotationManager.specForClassifier(classif);channelBindings=struct();groupBindings=struct();
for component=spec.components(:).'
    common={};first=true;
    for index=roiIndices(:).'
        r=classif.roi(index);
        if strcmp(component.storage,'channel')
            available=annotationManager.availableChannels(r);
            % Include declared names and pipeline result channels. GT/raw channels
            % never become an implicit fallback. The user selects custom outputs.
            declared=[{component.prediction.channel},component.prediction.channelCandidates(:).'];
            [resolved,exists]=annotationManager.resolveChannel(r,component.prediction);
            if exists,declared{end+1}=resolved;end
            candidates=available(startsWith(available,'results_','IgnoreCase',true)|ismember(available,declared));
            candidates(strcmpi(candidates,component.groundTruth.channel))=[];
        elseif strcmp(component.storage,'dataseries')&&any(strcmp(component.kind,{'frame_labels','sequence_label'}))
            data=classifierStats.series(r);candidates={};
            for k=1:numel(data)
                ds=data(k);
                fields=ds.data.Properties.VariableNames;
                if any(ismember({component.prediction.valueField,component.prediction.idField,'labels','id'},fields))
                    candidates{end+1}=ds.groupid; %#ok<AGROW>
                end
            end
        else,continue;
        end
        candidates=unique(candidates,'stable');
        if first,common=candidates;first=false;else,common=intersect(common,candidates,'stable');end
    end
    if first,continue;end
    assert(~isempty(common),'classifierStats:MissingPrediction', ...
        'No saved prediction for component %s is shared by the selected test ROIs. Run validation first.',component.id);
    chosen=1;
    if numel(common)>1
        [chosen,ok]=listdlg('PromptString',sprintf('Prediction to compare with reviewed GT (%s):',component.id), ...
            'SelectionMode','single','ListString',common,'InitialValue',1, ...
            'ListSize',[620 220],'Name','Classifier statistics');
        if ~ok,return;end
    end
    key=matlab.lang.makeValidName(component.id);
    if strcmp(component.storage,'channel'),channelBindings.(key)=common{chosen};
    else,groupBindings.(key)=common{chosen};end
end
classif.stats('Confusion','Classes','Rois',roiIndices,'Force', ...
    'PredictionChannel',channelBindings,'PredictionGroup',groupBindings);
end
