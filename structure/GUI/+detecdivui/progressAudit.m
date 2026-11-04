function inventory = progressAudit(outputPath)
%PROGRESSAUDIT Read-only inventory of progress UI and frontend handoffs.
% Includes embedded runtime MLAPP code; never extracts over source files.
if nargin < 1, outputPath = ''; end
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
inventory = table('Size',[0 7],'VariableTypes',repmat({'string'},1,7), ...
    'VariableNames',{'File','Line','Function','API','Owner','CleanupHint','Kind'});
for folder = {'structure','engine','helpers'}
    files = dir(fullfile(root,folder{1},'**','*.m'));
    for k = 1:numel(files)
        path = fullfile(files(k).folder,files(k).name);
        if contains(path,[filesep 'tests' filesep]) || contains(path,[filesep 'layout' filesep]) || ...
                endsWith(lower(files(k).name),'test.m'), continue; end
        inventory = scan(inventory,fileread(path),relative(path,root),'source');
    end
end
apps = dir(fullfile(root,'structure','GUI','**','*.mlapp'));
for k = 1:numel(apps)
    path = fullfile(apps(k).folder,apps(k).name);
    if contains(path,[filesep 'layout' filesep]), continue; end
    reader = appdesigner.internal.serialization.FileReader(path);
    inventory = scan(inventory,reader.readMATLABCodeText(),relative(path,root),'embedded runtime');
end
if ~isempty(outputPath), writetable(inventory,outputPath,'Encoding','UTF-8'); end
end
function rows = scan(rows,code,file,kind)
lines = regexp(code,'\r\n|\n|\r','split');
headers = find(cellfun(@(line)~isempty(regexp(line,'^\s*function\>','once')),lines));
pattern = '\<(uiprogressdlg|waitbar|openRuntimeProgress|pipeline2|workflow2?|score|classifierGUI|pipelineRunInspector)\s*\(|\.\w*Progress\.begin\s*\(';
for k = 1:numel(lines)
    line = lines{k};
    if startsWith(strtrim(line),'%'), continue; end
    [start,finish] = regexp(line,pattern,'start','end');
    for j = 1:numel(start)
        before = line(1:start(j)-1);
        if contains(before,'function ') || contains(before,'%'), continue; end
        api = strtrim(regexprep(line(start(j):finish(j)),'[\s(]',''));
        section = find(headers <= k,1,'last'); header = 'script'; last = numel(lines);
        if ~isempty(section)
            header = strtrim(lines{headers(section)});
            if section < numel(headers), last = headers(section+1)-1; end
        end
        body = strjoin(lines(k:last),newline);
        owner = '';
        if strcmp(api,'uiprogressdlg')
            tail = strjoin(lines(k:min(k+5,numel(lines))),newline);
            value = regexp(tail,'uiprogressdlg\(\s*([^,\r\n]+)','tokens','once');
            if ~isempty(value), owner = value{1}; end
        elseif strcmp(api,'waitbar')
            owner = 'legacy waitbar; inspect Parent';
        elseif contains(api,'Progress.begin')
            owner = 'initiating widget';
        elseif strcmp(api,'openRuntimeProgress')
            owner = 'pipeline2 runtime dialog (shared/nested)';
        else
            owner = 'destination frontend; caller covers launch';
        end
        hint = 'review';
        if contains(body,'onCleanup'), hint = 'onCleanup in function; verify ownership';
        elseif ~isempty(regexp(body,'\<(close|delete)\(','once')), hint = 'manual close/delete; verify early exits'; end
        if ~isempty(regexp(before,'app\.\w+\s*=\s*$','once')), hint = 'stored dialog; verify callback lifecycle'; end
        rows(end+1,:) = {string(file),string(k),string(header),string(api),string(owner),string(hint),string(kind)}; %#ok<AGROW>
    end
end
end
function value = relative(path,root)
value = strrep(path(numel(root)+2:end),filesep,'/');
end
