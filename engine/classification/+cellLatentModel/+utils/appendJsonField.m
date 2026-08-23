function appendJsonField(filename,name,value)
%APPENDJSONFIELD Add one top-level JSON field without renaming old keys.
% MATLAB jsondecode/jsonencode is not a lossless JSON round trip: legal
% dictionary keys such as "relations.npz" and "0.5" are converted into
% valid MATLAB field names.  Formatter manifests are external schemas, so
% preserve their original bytes and inject only the new field.

filename=char(string(filename));
name=char(string(name));
text=fileread(filename);
try
    decoded=jsondecode(text);
catch ME
    error('cellLatentModel:InvalidBundleJson', ...
        'Cannot parse JSON artifact %s: %s',filename,ME.message);
end
matlabName=matlab.lang.makeValidName(name);
if isstruct(decoded)&&isfield(decoded,matlabName)
    error('cellLatentModel:JsonFieldExists', ...
        'JSON artifact %s already contains top-level field %s.', ...
        filename,name);
end

openIndex=find(~isspace(text),1,'first');
closeIndex=find(~isspace(text),1,'last');
if isempty(openIndex)||isempty(closeIndex)||text(openIndex)~='{'|| ...
        text(closeIndex)~='}'
    error('cellLatentModel:InvalidBundleJson', ...
        'JSON artifact %s is not a top-level object.',filename);
end
body=text(openIndex+1:closeIndex-1);
if isempty(strtrim(body)),separator='';else,separator=',';end
encodedName=jsonencode(name);
encodedValue=jsonencode(value,'PrettyPrint',true);
insertion=[separator newline '  ' encodedName ': ' encodedValue newline];
updated=[text(1:closeIndex-1) insertion text(closeIndex:end)];
try
    jsondecode(updated);
catch ME
    error('cellLatentModel:InvalidBundleJson', ...
        'Cannot append field %s to JSON artifact %s: %s', ...
        name,filename,ME.message);
end
writeTextAtomic(filename,updated);
end

function writeTextAtomic(filename,text)
temporary=[filename '.tmp_' char(java.util.UUID.randomUUID)];
cleanup=onCleanup(@()deleteIfPresent(temporary));
fid=fopen(temporary,'w','n','UTF-8');
if fid<0
    error('cellLatentModel:BundleTextWriteFailed', ...
        'Cannot write temporary JSON artifact %s.',temporary);
end
fileCleanup=onCleanup(@()fclose(fid));
fwrite(fid,text,'char');
clear fileCleanup;
[ok,message]=movefile(temporary,filename,'f');
if ~ok
    error('cellLatentModel:BundleTextPublishFailed', ...
        'Cannot publish JSON artifact %s: %s',filename,message);
end
clear cleanup;
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
