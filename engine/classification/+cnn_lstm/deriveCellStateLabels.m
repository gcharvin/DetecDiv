function out = deriveCellStateLabels(teacherLabels, varargin)
%DERIVECELLSTATELABELS Derive fixed-window cell states from div_1 predictions.
% A single dead frame wins. Otherwise a complete window wholly contained in
% a known period longer than WindowLength without small/large alternation is
% arrested; other fully observed windows are budding. Unknown frames never
% provide evidence, and incomplete windows remain unlabelled.
p = inputParser;
p.addParameter('WindowLength',60,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=1&&x==round(x));
p.addParameter('FrameRange',[],@(x)isnumeric(x)&&(isempty(x)||numel(x)==2));
p.parse(varargin{:});
labels = lower(strtrim(string(teacherLabels(:))));
n = numel(labels); L = p.Results.WindowLength;
classes = {'budding','arrested','dead'};
known = ismember(labels,["unbud","small","large","dead","empty","clog"]);
starts = find(diff([false;known;false])==1);
ends = find(diff([false;known;false])==-1)-1;
longPeriods = zeros(0,2); changes = zeros(1,0);
for si=1:numel(starts)
    events = zeros(1,0); previous = "";
    for f=starts(si):ends(si)
        if ~ismember(labels(f),["small","large"]),continue;end
        if strlength(previous)>0 && labels(f)~=previous
            events(end+1)=f; %#ok<AGROW>
        end
        previous=labels(f);
    end
    changes=[changes events]; %#ok<AGROW>
    a=[starts(si) events]; b=[events-1 ends(si)];
    keep=(b-a+1)>L;
    longPeriods=[longPeriods; a(keep).' b(keep).']; %#ok<AGROW>
end
range=p.Results.FrameRange;
if isempty(range),range=[1 n];end
assert(numel(range)==2 && all(isfinite(range)) && all(range==round(range)) && ...
    range(1)>=1 && range(2)>=range(1) && range(2)<=n, ...
    'cnn_lstm:InvalidFrameRange','FrameRange must belong to the teacher sequence.');
ids=zeros(n,1); windows=struct('startFrame',{},'endFrame',{},'state',{}, ...
    'reason',{},'deadFrameCount',{},'knownTeacherFrameCount',{});
for a=range(1):L:range(2)
    b=min(a+L-1,range(2)); state='undefined';reason='missing_teacher_predictions';
    deadCount=nnz(labels(a:b)=="dead");
    if b-a+1<L
        reason='partial_window';
    elseif deadCount>0
        state='dead';reason='at_least_one_dead_frame';
        ids(a:b)=3;
    elseif all(known(a:b))
        if any(longPeriods(:,1)<=a & longPeriods(:,2)>=b)
            state='arrested';reason='contained_in_no_alternation_period_longer_than_window';
        else
            state='budding';reason='otherwise';
        end
        ids(a:b)=find(strcmp(classes,state),1);
    end
    k=numel(windows)+1;
    windows(k)=struct('startFrame',a,'endFrame',b,'state',state,'reason',reason, ...
        'deadFrameCount',deadCount,'knownTeacherFrameCount',nnz(known(a:b)));
end
out=struct('classes',{classes},'ids',ids, ...
    'labels',categorical(ids,0:3,[{'undefined'} classes]), ...
    'windows',windows,'longNoAlternationPeriods',longPeriods, ...
    'alternationFrames',changes,'windowLength',L);
end
