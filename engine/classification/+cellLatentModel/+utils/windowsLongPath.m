function value = windowsLongPath(value)
%CELLLATENTMODEL.UTILS.WINDOWSLONGPATH Make an absolute path Python-safe.
% Python installations without a longPathAware manifest still apply the
% historical MAX_PATH limit.  The Win32 extended-length prefix bypasses
% that limit and is accepted by pathlib, h5py and torch on Windows.
value = char(string(value));
if ~ispc || isempty(value) || startsWith(value, '\\?\')
    return;
end

if startsWith(value, '\\')
    absolutePath = value;
    if strlength(string(absolutePath)) >= 248
        value = ['\\?\UNC\' extractAfter(absolutePath, 2)];
    end
    return;
end

if isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once'))
    return;
end
absolutePath = char(java.io.File(value).getAbsolutePath());
if strlength(string(absolutePath)) >= 248
    value = ['\\?\' absolutePath];
end
end
