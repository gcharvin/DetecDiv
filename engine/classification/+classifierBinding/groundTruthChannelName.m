function name = groundTruthChannelName(classif,semantic,legacySuffix,configuredFields)
%CLASSIFIERBINDING.GROUNDTRUTHCHANNELNAME Migration-safe explicit GT name.
if nargin<2||isempty(semantic),semantic='labels';end
if nargin<3,legacySuffix='cell';end
if ischar(legacySuffix)||isstring(legacySuffix)
    legacySuffix=cellstr(string(legacySuffix));
elseif isempty(legacySuffix)
    legacySuffix={''};
end
if nargin<4||isempty(configuredFields)
    configuredFields={'groundTruthChannelName'};
elseif ischar(configuredFields)||isstring(configuredFields)
    configuredFields=cellstr(string(configuredFields));
end
for i=1:numel(configuredFields)
    value='';
    try
        tp=classif.trainingParam;
        if isstruct(tp)&&isfield(tp,configuredFields{i})
            value=textValue(tp.(configuredFields{i}));
        end
    catch
    end
    if isConcrete(value),name=value;return;end
end
classifierId='';
try classifierId=strtrim(char(string(classif.strid)));catch,end
if isempty(classifierId),name='';return;end
for i=1:numel(legacySuffix)
    suffix=char(string(legacySuffix{i}));
    if isempty(suffix),legacy=classifierId;else,legacy=[classifierId '_' suffix];end
    if classifierHasChannel(classif,legacy),name=legacy;return;end
end
safeId=regexprep(lower(classifierId),'[^a-z0-9]+','_');
safeSemantic=regexprep(lower(char(string(semantic))),'[^a-z0-9]+','_');
name=['gt_' safeId '_' safeSemantic];
end

function tf=classifierHasChannel(classif,name)
tf=false;
try rois=classif.roi;catch,rois=[];end
for i=1:numel(rois)
    try
        channels=rois(i).display.channel;
        if ischar(channels)||isstring(channels),channels=cellstr(string(channels));end
        if any(strcmp(channels,name)),tf=true;return;end
    catch
    end
end
end
function tf=isConcrete(value),tf=~isempty(value)&&~startsWith(value,'<')&&~strcmpi(value,'N/A');end
function value=textValue(value),while iscell(value),if isempty(value),value='';return;end,value=value{end};end,value=strtrim(char(string(value)));end
