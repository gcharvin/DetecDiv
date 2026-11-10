function result=cellFateSequence(states,first,last,minWindows)
%CELLFATESEQUENCE Summarize observed states without fitting or rewriting them.
% GT callers use minWindows=1; prediction callers confirm multi-window episodes.
if nargin<4,minWindows=2;end
assert(isscalar(minWindows)&&isfinite(minWindows)&&minWindows>=1&&minWindows==fix(minWindows), ...
    'lstm_timeseries:FatePolicy','Confirmation windows must be a positive integer.');
states=string(states(:).');first=double(first(:).');last=double(last(:).');
assert(numel(states)==numel(first)&&numel(first)==numel(last),'lstm_timeseries:FateShape','Window identities and labels must align.');
result=struct('population','unresolved','reason','','terminalState','undefined', ...
    'confirmedArrest',false,'terminalRecovery',false,'ignoredShortArrestEpisodes',0);
if isempty(states),result.reason='No complete window';return;end
result.terminalState=char(states(end));
if any(~ismember(states,["budding","arrested","dead"]))
    result.reason='Missing or unreviewed window';return;
end
if any(last<first)||any(first(2:end)~=last(1:end-1)+1)
    result.reason='Gap between windows';return;
end
starts=[1 find(states(2:end)~=states(1:end-1))+1];ends=[starts(2:end)-1 numel(states)];
lengths=ends-starts+1;runStates=states(starts);
result.confirmedArrest=any(runStates=="arrested"&lengths>=minWindows);
result.ignoredShortArrestEpisodes=nnz(runStates=="arrested"&lengths<minWindows);
if states(end)=="dead",result.population='dead';return;end
if any(states=="dead"),result.reason='Non-dead state after a dead prediction';return;end
if states(end)=="arrested"
    if lengths(end)<minWindows,result.reason='Isolated terminal arrest';return;end
    result.population='persistent_arrest';return;
end
if result.confirmedArrest
    if lengths(end)<minWindows,result.reason='Terminal recovery not confirmed';return;end
    result.population='transient_arrest';result.terminalRecovery=true;
else
    result.population='adapted';
end
end
