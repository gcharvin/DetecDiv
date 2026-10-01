function p = referenceForFile(file, pipelineRoot)
% Turn a file-picker result into a qualified function and portable folder.
if nargin < 2, pipelineRoot = ''; end
if ~isfile(file), error('customModule:EntryPoint', 'File does not exist: %s.', file); end
[folder, name, ext] = fileparts(file);
if ~strcmpi(ext, '.m'), error('customModule:EntryPoint', 'Choose a MATLAB .m function.'); end
while true
    [parent, leaf] = fileparts(folder);
    if startsWith(leaf, '+')
        name = [leaf(2:end) '.' name]; %#ok<AGROW>
        folder = parent;
    else
        break;
    end
end
roots = {pipelineRoot, fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))};
codeFolder = char(java.io.File(folder).getCanonicalPath());
for i = 1:numel(roots)
    if isempty(roots{i}), continue; end
    root = char(java.io.File(char(roots{i})).getCanonicalPath());
    if strcmpi(codeFolder, root)
        codeFolder = '.';
        break;
    elseif startsWith(codeFolder, [root filesep], 'IgnoreCase', ispc)
        codeFolder = strrep(codeFolder(numel(root)+2:end), '\', '/');
        break;
    end
end
p = struct('entryPoint', name, 'codeFolder', codeFolder);
end
