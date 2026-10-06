function out = pipelineRoiPatternLibrary(action, folder, varargin)
% Small pipeline-local catalogue. Runs always carry their own image copy.
file = fullfile(char(string(folder)), 'roi_pattern_library.json');
switch lower(char(string(action)))
    case 'load'
        if isempty(folder), file = ''; end
        out = readLibrary(file);
    case 'save'
        if isempty(folder) || ~isfolder(folder)
            error('pipelineRoiPatternLibrary:NoPath', 'Save the pipeline before saving library patterns.');
        end
        name = strtrim(char(string(varargin{1})));
        pattern = varargin{2};
        validatePattern(pattern);
        if isempty(name)
            error('pipelineRoiPatternLibrary:Name', 'Enter a pattern name.');
        end
        id = ''; revision = [];
        if numel(varargin) >= 3, id = char(string(varargin{3})); end
        if numel(varargin) >= 4, revision = varargin{4}; end
        lockFile = java.io.RandomAccessFile([file '.lock'],'rw');
        channel = lockFile.getChannel();
        lockCleanup = onCleanup(@()channel.close());
        try
            writerLock = channel.tryLock();
        catch
            writerLock = [];
        end
        if isempty(writerLock)
            error('pipelineRoiPatternLibrary:Busy', 'The pattern library is being saved. Retry shortly.');
        end
        library = readLibrary(file); % Reload under the lock: preserve other users' entries.
        entries = library.entries;
        idx = find(strcmp({entries.id}, id), 1);
        if ~isempty(id) && (isempty(idx) || ~isequal(entries(idx).revision, revision))
            error('pipelineRoiPatternLibrary:Conflict', 'This pattern changed since opening the library. Reopen it before replacing it.');
        end
        sameName = find(strcmpi({entries.name}, name));
        nameTaken = ~isempty(sameName);
        if ~isempty(idx), nameTaken = any(sameName ~= idx); end
        if nameTaken
            error('pipelineRoiPatternLibrary:NameExists', 'This name already exists. Choose another name or explicitly replace the existing pattern.');
        end
        nowText = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
        if isempty(idx)
            entry = struct('id',char(java.util.UUID.randomUUID()), 'name',name, ...
                'revision',1, 'createdAt',nowText, 'updatedAt',nowText, 'pattern',pattern);
            entries(end+1) = entry;
        else
            entry = entries(idx);
            entry.name = name; entry.pattern = pattern;
            entry.revision = entry.revision + 1; entry.updatedAt = nowText;
            entries(idx) = entry;
        end
        library.entries = entries;
        tmp = [tempname(folder) '.json'];
        tmpCleanup = onCleanup(@()deleteFile(tmp));
        fid = fopen(tmp,'w','n','UTF-8');
        if fid < 0, error('pipelineRoiPatternLibrary:IO','Cannot write the pattern library.'); end
        closeCleanup = onCleanup(@()fclose(fid));
        count = fprintf(fid,'%s',jsonencode(library,'PrettyPrint',true));
        if count < 0, error('pipelineRoiPatternLibrary:IO','Cannot write the pattern library.'); end
        clear closeCleanup;
        [ok,msg] = movefile(tmp,file,'f');
        if ~ok, error('pipelineRoiPatternLibrary:IO','Cannot save the pattern library: %s',msg); end
        out = entry;
    otherwise
        error('pipelineRoiPatternLibrary:Action','Unknown library action.');
end
end

function library = readLibrary(file)
library = struct('schema','roi_pattern_library_v1', 'entries',struct( ...
    'id',{},'name',{},'revision',{},'createdAt',{},'updatedAt',{},'pattern',{}));
if ~isfile(file), return; end
saved = jsondecode(fileread(file));
if ~isstruct(saved) || ~isfield(saved,'schema') || ~strcmp(saved.schema,library.schema) || ~isfield(saved,'entries')
    error('pipelineRoiPatternLibrary:Format','The pattern library format is not supported.');
end
if isempty(saved.entries), return; end
required = fieldnames(library.entries);
if ~isstruct(saved.entries) || ~all(isfield(saved.entries,required))
    error('pipelineRoiPatternLibrary:Format','The pattern library is incomplete.');
end
for i = 1:numel(saved.entries)
    validatePattern(saved.entries(i).pattern);
end
library.entries = saved.entries(:)';
end

function validatePattern(pattern)
if ~isstruct(pattern) || ~isscalar(pattern) || ~isfield(pattern,'image') || ...
        ~isnumeric(pattern.image) || isempty(pattern.image) || ~ismatrix(pattern.image) || ...
        ~isreal(pattern.image) || any(~isfinite(pattern.image(:)))
    error('pipelineRoiPatternLibrary:NoImage','Draw a pattern on an image before saving it to the library.');
end
end

function deleteFile(file)
if isfile(file), delete(file); end
end
