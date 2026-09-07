function report = removeROI(obj, indices)
%REMOVEROI Remove classifier-owned ROI assets and persist the new membership.
% Recovery copies are isolated under .removed_rois, never read by ROI loaders.
% External source datasets and historical training runs are not modified.

n = numel(obj.roi);
validateattributes(indices, {'numeric'}, {'vector','integer','positive','<=',n});
indices = unique(double(indices(:).'));
root = canonical(obj.path);
assert(isfolder(root), 'classi:RemovalPath', 'Classifier folder is missing.');
keep = setdiff(1:n, indices, 'stable');
old = struct('rois',obj.roi,'dataset',obj.dataset,'training',obj.trainingset, ...
    'bounds',obj.bounds,'score',obj.score,'channels',{obj.channelName});
ids = {obj.roi(indices).id};
retainedIds = {obj.roi(keep).id};
assert(~any(ismember(ids, retainedIds)), 'classi:SharedRoiId', ...
    'A retained ROI shares an ID with a removed ROI. Resolve duplicate IDs first.');
files = {};
external = {};
listing = dir(root);
for i = indices
    r = obj.roi(i);
    id = char(string(r.id));
    assert(~isempty(id) && isempty(regexp(id,'[\\/:*?"<>|]','once')) && ...
        ~any(strcmp(id,{'.','..'})), 'classi:RemovalId', 'Unsafe or empty ROI ID.');
    if isempty(r.path) || ~strcmpi(canonical(r.path), root)
        external{end+1} = id; %#ok<AGROW>
        continue;
    end
    bases = {['im_' id '.h5'],['im_' id '.mat'],['im_' id '.bak'], ...
        ['data_' id '.mat'],['data_' id '.bak'],['objects_' id '.h5']};
    for j = 1:numel(listing)
        name = listing(j).name;
        if listing(j).isdir, continue; end
        % Exact filename or backup suffix; R1 must never match R10.
        if any(strcmp(name,bases)) || any(startsWith(name,strcat(bases,'.')))
            path = fullfile(root,name);
            assert(strcmpi(fileparts(canonical(path)),root), ...
                'classi:RemovalPath','ROI asset resolves outside classifier folder.');
            files{end+1} = path; %#ok<AGROW>
        end
    end
end
files = unique(files,'stable');
% Previously formatted images/masks are a snapshot of the old membership.
% Retire that snapshot as a unit so training cannot consume deleted GT.
formatted = fullfile(root,'trainingdataset');
if isfolder(formatted)
    assert(strcmpi(fileparts(canonical(formatted)),root), ...
        'classi:RemovalPath','Training dataset resolves outside classifier folder.');
    files{end+1}=formatted;
end
dataset = obj.dataset;
if ~isstruct(dataset) || ~isscalar(dataset), dataset = struct(); end
if ~isfield(dataset,'split') || ~isstruct(dataset.split)
    dataset.split = struct();
end
for key = {'train','val','test'}
    name = key{1};
    values = [];
    if isfield(dataset.split,name), values = dataset.split.(name); end
    if strcmp(name,'train') && isempty(values), values = obj.trainingset; end
    dataset.split.(name) = find(ismember(keep, double(values)));
end
bounds = obj.bounds;
if isstruct(bounds) && isfield(bounds,'RoiValues') && isstruct(bounds.RoiValues)
    entries = bounds.RoiValues;
    drop = false(size(entries));
    for i=1:numel(entries)
        index = [];
        if isfield(entries,'roi_id') && ~isempty(entries(i).roi_id)
            index = find(strcmp({obj.roi.id},char(string(entries(i).roi_id))),1);
        elseif isfield(entries,'roi_index')
            index = entries(i).roi_index;
        end
        mapped = [];
        if isscalar(index), mapped = find(keep == index,1); end
        if isempty(mapped), drop(i)=true; else, entries(i).roi_index=mapped; end
    end
    bounds.RoiValues=entries(~drop);
end

% Stage everything before altering the active dataset, enabling rollback.
recovery = fullfile(root,'.removed_rois',char(java.util.UUID.randomUUID()));
assert(startsWith(canonical(recovery),[root filesep], 'IgnoreCase',true), ...
    'classi:RemovalPath','Recovery folder resolves outside classifier folder.');
mkdir(recovery);
report = struct('removedIds',{ids},'files',{files}, ...
    'externalSourcesPreserved',{external},'recoveryPath',recovery);
classiFile = fullfile(root,[obj.strid '_classification.mat']);
assert(strcmpi(fileparts(canonical(classiFile)),root), ...
    'classi:RemovalPath','Invalid classifier filename.');
jsonPaths = {fullfile(root,'dataset.json')};
hints = dir(fullfile(root,'review_hints*.json'));
for i=1:numel(hints), jsonPaths{end+1}=fullfile(root,hints(i).name); end %#ok<AGROW>
jsonPaths{end+1}=fullfile(root,'censor_suggestion_decisions.json');
changed = {};
moved = {};
try
    save(fullfile(recovery,'removal.mat'),'report','old');
    for i=1:numel(files)
        [~,name,ext]=fileparts(files{i});
        movefile(files{i},fullfile(recovery,[name ext]));
        moved{end+1}=files{i}; %#ok<AGROW>
    end
    obj.roi=old.rois(keep);
    if isempty(keep), obj.roi=roi(); obj.channelName={}; dataset.channels={}; end
    obj.dataset=dataset;
    obj.trainingset=dataset.split.train;
    obj.bounds=bounds;
    obj.score=[];
    for i=1:numel(jsonPaths)
        path=jsonPaths{i};
        if ~isfile(path), continue; end
        assert(strcmpi(fileparts(canonical(path)),root), ...
            'classi:RemovalPath','Metadata resolves outside classifier folder.');
        payload=jsondecode(fileread(path));
        if i==1
            payload=dataset;
        elseif isstruct(payload) && isfield(payload,'items') && ...
                isstruct(payload.items) && isfield(payload.items,'roi_id')
            payload.items=payload.items(~ismember(string({payload.items.roi_id}),string(ids)));
        else
            continue;
        end
        backupFile(path,recovery);
        changed{end+1}=path; %#ok<AGROW>
        writeJson(path,payload);
    end
    if isfile(classiFile), backupFile(classiFile,recovery); end
    changed{end+1}=classiFile;
    classiObj=obj; %#ok<NASGU>
    pending=fullfile(recovery,'pending_classifier.mat');
    save(pending,'classiObj');
    movefile(pending,classiFile,'f');
catch ME
    obj.roi=old.rois; obj.dataset=old.dataset; obj.trainingset=old.training;
    obj.bounds=old.bounds; obj.score=old.score; obj.channelName=old.channels;
    for i=1:numel(changed)
        [~,name,ext]=fileparts(changed{i});
        backup=fullfile(recovery,[name ext]);
        if isfile(backup), copyfile(backup,changed{i},'f'); end
    end
    for i=1:numel(moved)
        [~,name,ext]=fileparts(moved{i});
        movefile(fullfile(recovery,[name ext]),moved{i},'f');
    end
    rethrow(ME);
end
fprintf('Removed %d ROI(s), %d active files. Recovery: %s\n', ...
    numel(indices),numel(files),recovery);
if ~isempty(external)
    warning('classi:ExternalRoiPreserved', ...
        'External source files preserved for: %s',strjoin(external,', '));
end
end

function path=canonical(path)
path=char(java.io.File(char(string(path))).getCanonicalPath());
end

function backupFile(path,folder)
[~,name,ext]=fileparts(path);
copyfile(path,fullfile(folder,[name ext]));
end

function writeJson(path,value)
text=jsonencode(value);
fid=fopen(path,'w');
assert(fid>=0,'classi:RemovalWrite','Cannot write %s',path);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
count=fwrite(fid,text,'char');
assert(count==numel(text),'classi:RemovalWrite','Incomplete write: %s',path);
end
