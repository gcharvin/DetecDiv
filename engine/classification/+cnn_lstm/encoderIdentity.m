function encoder=encoderIdentity(c,p)
%ENCODERIDENTITY Checksum-pinned CNN artifact and image binding identity.
file=fullfile(c.path,['netCNN_' c.strid '.mat']);
encoder=struct('file',['netCNN_' c.strid '.mat'],'sha256',sha256File(file), ...
 'layer',p.encoderLayer,'channels',{cellstr(string(c.channelName(:).'))});
end

function hash=sha256File(file)
digest=java.security.MessageDigest.getInstance('SHA-256');
fid=fopen(file,'rb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
while ~feof(fid),digest.update(fread(fid,1024*1024,'*uint8'));end
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
