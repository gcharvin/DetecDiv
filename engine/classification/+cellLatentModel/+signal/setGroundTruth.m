function report = setGroundTruth(roiObj, definition, varargin)
%CELLLATENTMODEL.SIGNAL.SETGROUNDTRUTH Write scalar or segmentation GT.
% Scalar tasks use ObjectIds + Values. Segmentation uses Frames + Masks.

p=inputParser;
p.addParameter('ObjectIds',[],@isnumeric);
p.addParameter('Values',[],@(x)true);
p.addParameter('Frames',[],@isnumeric);
p.addParameter('Masks',[],@(x)isnumeric(x)||islogical(x));
p.addParameter('Save',true,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
def=definition;
cellLatentModel.signal.annotationSpec(def);
if strcmp(def.task,'segmentation')
    frames=round(double(p.Results.Frames(:)));
    masks=p.Results.Masks;
    idx=roiObj.findChannelID(def.ground_truth_channel,'exact');
    if isempty(idx), error('cellLatentModel:MissingSignalGroundTruth','Create the signal GT channel first.'); end
    if ismatrix(masks)&&isscalar(frames), masks=reshape(masks,size(masks,1),size(masks,2),1); end
    if size(masks,3)~=numel(frames), error('cellLatentModel:SignalMaskFrameMismatch','Masks must contain one plane per frame.'); end
    values=double(masks(:));
    if any(~isfinite(values)|values<0|values~=round(values)|values>numel(def.classes))
        error('cellLatentModel:InvalidSignalMask','Segmentation labels must be integers from 0 to %d.',numel(def.classes));
    end
    roiObj.image(:,:,idx(1),frames)=cast(masks,'like',roiObj.image);
    coverageIdx=find(arrayfun(@(x)strcmp(char(string(x.groupid)),def.ground_truth_group),roiObj.data),1);
    if isempty(coverageIdx)||~ismember('Reviewed',roiObj.data(coverageIdx).data.Properties.VariableNames)
        error('cellLatentModel:MissingSignalCoverage','Create the segmentation GT coverage table first.');
    end
    [found,coverageRows]=ismember(uint32(frames),roiObj.data(coverageIdx).data.Frame);
    if any(~found), error('cellLatentModel:SignalFrameOutOfRange','At least one frame is outside GT coverage.'); end
    roiObj.data(coverageIdx).data.Reviewed(coverageRows)=true;
    targetCount=numel(frames);
    if p.Results.Save
        roiObj.save(def.ground_truth_channel,false);
        roiObj.save('data',false);
    end
else
    objectIds=uint64(p.Results.ObjectIds(:)); values=p.Results.Values;
    if numel(values)~=numel(objectIds), error('cellLatentModel:SignalValueCountMismatch','Provide one value per ObjectId.'); end
    idx=find(arrayfun(@(x)strcmp(char(string(x.groupid)),def.ground_truth_group),roiObj.data),1);
    if isempty(idx), error('cellLatentModel:MissingSignalGroundTruth','Create the signal GT dataseries first.'); end
    tbl=roiObj.data(idx).data;
    [found,row]=ismember(objectIds,tbl.ObjectId);
    if any(~found), error('cellLatentModel:UnknownSignalObject','At least one ObjectId is absent from the target family.'); end
    if strcmp(def.task,'classification')
        text=string(values(:));
        if any(~ismember(text,string(def.classes)))
            error('cellLatentModel:InvalidSignalClass','Values must belong to the configured classes.');
        end
        tbl.(def.value_field)(row)=categorical(text,["undefined" string(def.classes)]);
    else
        numeric=double(values(:)); range=def.value_range;
        if any(~isfinite(numeric)|numeric<range(1)|numeric>range(2))
            error('cellLatentModel:InvalidSignalRegressionValue','Regression values must be finite and inside ValueRange.');
        end
        tbl.(def.value_field)(row)=numeric;
    end
    roiObj.data(idx).data=tbl; targetCount=numel(objectIds);
    if p.Results.Save, roiObj.save('data',false); end
end
report=struct('signal_name',def.name,'task',def.task,'updated_count',targetCount,'saved',logical(p.Results.Save));
end
