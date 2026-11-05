function recentPipelinesTest()
%RECENTPIPELINESTEST Classic schema, lexical references and isolated persistence.
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
file = fullfile(folder,'history','recentPipelines.mat');
absent = fullfile(folder,'missing acquisition','pipeline.json');
unc = '\\detecdiv-missing-host\unavailable-share\Workflow';
mapped = 'Z:\unavailable-detecdiv-pipeline';
memory = detecdivui.RecentPipelines('');
assert(isempty(memory.Paths) && isempty(memory.File));
memory.remember(mapped); memory.remember(unc);
assert(numel(memory.Paths)==2 && isempty(memory.LastError));
assert(detecdivui.RecentPipelines.samePath(memory.Paths(1),fullfile(unc,'pipeline.json')));
assert(detecdivui.RecentPipelines.samePath(memory.Paths(2),fullfile(mapped,'pipeline.json')));
assert(isempty(dir(fullfile(folder,'**','*.mat'))),'In-memory history unexpectedly wrote a file.');

history = detecdivui.RecentPipelines(file);
assert(isempty(history.Paths) && ~isfile(file),'Construction wrote or fabricated history.');
history.remember(absent); history.remember(fullfile(folder,'a folder.with.dots'));
assert(isfile(file) && numel(history.Paths)==2);
stored = load(file);
assert(isscalar(stored) && isfield(stored,'RecentPipelines') && isstring(stored.RecentPipelines));
assert(isequal(stored.RecentPipelines,history.Paths));
before = fileread(file); reopened = detecdivui.RecentPipelines(file);
assert(isequal(reopened.Paths,history.Paths) && strcmp(fileread(file),before));
assert(any(arrayfun(@(p)detecdivui.RecentPipelines.samePath(p,absent),reopened.Paths)));
history.remember(fullfile(folder,'missing acquisition','..','missing acquisition'));
assert(numel(history.Paths)==2 && detecdivui.RecentPipelines.samePath(history.Paths(1),absent));
if ispc
    history.remember(upper(absent));
    assert(numel(history.Paths)==2,'Case/slash aliases were duplicated.');
end
for k = 1:12, history.remember(fullfile(folder,sprintf('Pipeline %02d',k))); end
assert(numel(history.Paths)==10);
assert(detecdivui.RecentPipelines.samePath(history.Paths(1),fullfile(folder,'Pipeline 12','pipeline.json')));
assert(detecdivui.RecentPipelines.samePath(history.Paths(end),fullfile(folder,'Pipeline 03','pipeline.json')));

% Another window's file additions are read before prepending a new entry.
other = detecdivui.RecentPipelines(file); other.remember(mapped); history.remember(unc);
assert(detecdivui.RecentPipelines.samePath(history.Paths(2),mapped));
history.clear(); reopened.reload(); assert(isempty(reopened.Paths));
stored = load(file,'RecentPipelines'); assert(isempty(stored.RecentPipelines));
assert(isempty(dir([file '.*.tmp'])),'Atomic-save temporary files remain.');

% Legacy MAT strings/cellstr are accepted, malformed/empty values discarded,
% while unavailable network and mapped-drive references remain in the list.
RecentPipelines = {mapped,unc,mapped,'',absent}; save(file,'RecentPipelines');
history.reload(); assert(numel(history.Paths)==3 && isempty(history.LastError));
before = history.Paths; memory.remember(absent);
assert(isequal(detecdivui.RecentPipelines(file).Paths,before),'In-memory history changed the persisted list.');
assert(~detecdivui.RecentPipelines.samePath(fullfile(folder,'one.json'),fullfile(folder,'two.json')));
assert(endsWith(detecdivui.RecentPipelines.normalizePath(fullfile(folder,'one.json')),'one.json'));
assert(endsWith(detecdivui.RecentPipelines.normalizePath(fullfile(folder,'folder')),'pipeline.json'));
disp('Recent pipelines test passed: classic MAT schema, lexical missing references, folder/JSON aliases, MRU cap, persistence, multi-window updates and isolated in-memory history.');
end
