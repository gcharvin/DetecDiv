function identity = pipelineModuleFileIdentity(filename)
%PIPELINEMODULEFILEIDENTITY Fingerprint one explicit file without loading it.
filename = char(string(filename));
identity = struct('path',filename,'exists',false,'bytes',0,'sha256','');
if isempty(filename) || ~isfile(filename), return; end
identity.path = char(java.io.File(filename).getCanonicalPath());
fid = fopen(filename,'rb');
if fid < 0, error('pipelineModuleFileIdentity:Unreadable','Cannot read %s.',filename); end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
digest = java.security.MessageDigest.getInstance('SHA-256');
while true
    bytes = fread(fid,1024*1024,'*uint8');
    if isempty(bytes), break; end
    digest.update(bytes);
    identity.bytes = identity.bytes + numel(bytes);
end
identity.sha256 = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
identity.exists = true;
end
