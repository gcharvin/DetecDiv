function series = areaSeries(roiObj,frames,baseName)
%AREASERIES Pixel areas from Viterbi's assigned mother and bud binary masks.
% No source image or dataseries is changed. Unmeasured frames stay missing;
% a tracked mother with no assigned bud has a bud area of zero.
if nargin<3||isempty(baseName),baseName='MotherLineageViterbi';end
assert(~isempty(roiObj.image),'trackMotherLineageViterbi:ImagesNotLoaded', ...
    'Load the Viterbi mother and bud channels before measuring areas.');
n=size(roiObj.image,4);
if nargin<2||isempty(frames),frames=1:n;end
assert(isnumeric(frames)&&isvector(frames)&&all(isfinite(frames))&& ...
    all(frames==fix(frames))&&all(frames>=1&frames<=n)&&numel(unique(frames))==numel(frames), ...
    'trackMotherLineageViterbi:AreaFrames','Use unique absolute frames within the loaded ROI.');
mother=roiObj.findChannelID([baseName '_cell']);bud=roiObj.findChannelID([baseName '_bud']);
assert(isscalar(mother)&&isscalar(bud),'trackMotherLineageViterbi:MissingAssignedMasks', ...
    'Expected separate Viterbi channels %s_cell and %s_bud.',baseName,baseName);
values=nan(n,2);group=[baseName '_areas'];data=roiObj.data;
% A partial image cache can coexist with an unloaded data cache. Read the
% authoritative data file without changing the caller's ROI in that case.
if isempty(data)||all(strlength(string({data.groupid}))==0)
    filename=fullfile(roiObj.path,['data_' roiObj.id '.mat']);
    if isfile(filename),stored=load(filename,'data');if isfield(stored,'data'),data=stored.data;end,end
end
previous=find(strcmp(string({data.groupid}),group));
assert(numel(previous)<=1,'trackMotherLineageViterbi:DuplicateAreaSeries','Duplicate area dataseries.');
if ~isempty(previous)
    t=data(previous).data;
    if all(ismember({'frame','Area_Mother','Area_Bud'},t.Properties.VariableNames))
        valid=t.frame>=1&t.frame<=n&t.frame==fix(t.frame);
        values(t.frame(valid),:)=[t.Area_Mother(valid) t.Area_Bud(valid)];
    end
end
for frame=frames(:)'
    m=roiObj.image(:,:,mother,frame);b=roiObj.image(:,:,bud,frame);
    assert(all(ismember(m(:),[0 1]))&&all(ismember(b(:),[0 1])), ...
        'trackMotherLineageViterbi:NonBinaryAssignedMasks', ...
        'Expected binary assigned Viterbi masks at frame %d; do not measure encoded instance labels.',frame);
    values(frame,:)=[NaN NaN];
    if any(m(:)),values(frame,:)=[nnz(m) nnz(b)];end
end
series=dataseries(table((1:n)',values(:,1),values(:,2), ...
    'VariableNames',{'frame','Area_Mother','Area_Bud'}));
series.groupid=group;series.class='processing';series.type='temporal';series.parentid=roiObj.id;
series.description='Area in pixels of Viterbi mother and assigned bud; no assigned bud = 0, no tracked mother = NaN.';
series.userData=struct('sourceChannels',{{[baseName '_cell'],[baseName '_bud']}},'units','pixel^2');
end
