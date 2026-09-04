function report = validateGroundTruth(roiObj, definition, varargin)
%CELLLATENTMODEL.SIGNAL.VALIDATEGROUNDTRUTH Validate custom signal GT.
p=inputParser;
p.addParameter('RequireComplete',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('Model',struct(),@isstruct);
p.parse(varargin{:});
def=definition; errors=strings(0,1); warnings=strings(0,1); defined=0; total=0;
try
    values=cellLatentModel.signal.readGroundTruth(roiObj,def);
    if strcmp(def.task,'classification')
        total=height(values); labels=string(values.(def.value_field));
        valid=~isundefined(values.(def.value_field))&labels~="undefined";
        defined=nnz(valid);
        if any(valid&~ismember(labels,string(def.classes))), errors(end+1)="Unknown classification label."; end
    elseif strcmp(def.task,'regression')
        total=height(values); numeric=double(values.(def.value_field));
        valid=isfinite(numeric); defined=nnz(valid); range=def.value_range;
        if any(valid&(numeric<range(1)|numeric>range(2))), errors(end+1)="Regression value outside ValueRange."; end
    else
        numeric=double(values);
        if any(~isfinite(numeric(:))|numeric(:)<0|numeric(:)~=round(numeric(:))|numeric(:)>numel(def.classes))
            errors(end+1)="Invalid semantic segmentation label.";
        end
        coverageIdx=find(arrayfun(@(x)strcmp(char(string(x.groupid)),def.ground_truth_group),roiObj.data),1);
        if isempty(coverageIdx)||~ismember('Reviewed',roiObj.data(coverageIdx).data.Properties.VariableNames)
            errors(end+1)="Segmentation review coverage is missing.";
        else
            reviewed=logical(roiObj.data(coverageIdx).data.Reviewed);
            total=numel(reviewed); defined=nnz(reviewed);
        end
    end
    if defined==0, warnings(end+1)="Ground truth contains no defined target."; end
    if p.Results.RequireComplete && defined<total, errors(end+1)="Ground truth is incomplete."; end
catch ME
    errors(end+1)=string(ME.message);
end
report=struct('valid',isempty(errors),'errors',errors,'warnings',warnings, ...
    'defined_count',defined,'target_count',total,'signal_name',def.name,'task',def.task);
end
