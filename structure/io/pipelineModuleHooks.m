function hooks = pipelineModuleHooks(pkg)
%PIPELINEMODULEHOOKS Resolve hooks beside the selected executable only.
pkg=char(string(pkg));
hooks=struct('package',pkg,'moduleId',['legacy.classifier.' pkg], ...
    'execute',[pkg '.classify'],'executePath','','manifestPath','', ...
    'manifest',struct(),'validate','','prepare','','supported',false);
if isempty(regexp(pkg,'^[A-Za-z]\w*(\.[A-Za-z]\w*)*$','once'))
    error('pipelineModuleHooks:Package','Invalid MATLAB package name.');
end
hooks.executePath=which(hooks.execute);
if isempty(hooks.executePath), return; end
folder=fileparts(hooks.executePath);
hooks.manifestPath=fullfile(folder,'module.json');
if ~isfile(hooks.manifestPath), hooks.manifestPath=''; return; end
fid=fopen(hooks.manifestPath,'rb');
if fid<0, error('pipelineModuleHooks:Descriptor','Cannot read %s.',hooks.manifestPath); end
cleanup=onCleanup(@()fclose(fid));
source=native2unicode(fread(fid,Inf,'*uint8')','UTF-8');
clear cleanup;
if ~isempty(source)&&double(source(1))==65279, source=source(2:end); end
manifest=jsondecode(source);
if ~isstruct(manifest)||~isscalar(manifest)||~isfield(manifest,'format')|| ...
        ~isequal(manifest.format,'detecdiv.module.v1')
    error('pipelineModuleHooks:Descriptor','Invalid module descriptor in %s.',hooks.manifestPath);
end
hooks.manifest=manifest;
if isfield(manifest,'id'), hooks.moduleId=manifest.id; end
entries=field(manifest,'entrypoints',struct());
compatibility=field(manifest,'compatibility',struct());
version=field(compatibility,'runtimeContract','legacy');
validate=field(entries,'validate',''); prepare=field(entries,'prepare','');
if strcmp(version,'legacy') && isempty(validate)&&isempty(prepare), return; end
if ~strcmp(version,'detecdiv.module_runtime.v1')
    error('pipelineModuleHooks:Version','Unsupported runtime contract in %s.',hooks.manifestPath);
end
declaredPackage=field(manifest,'package','');
samePackage=ischar(declaredPackage)&&strcmp(declaredPackage,pkg);
if ispc&&ischar(declaredPackage), samePackage=strcmpi(declaredPackage,pkg); end
declaredExecute=field(entries,'execute','');
sameExecute=ischar(declaredPackage)&&ischar(declaredExecute)&& ...
    strcmp(declaredExecute,[declaredPackage '.classify']);
if ispc&&ischar(declaredExecute)&&ischar(declaredPackage)
    sameExecute=strcmpi(declaredExecute,[declaredPackage '.classify']);
end
declaredExecutePath='';
if sameExecute, declaredExecutePath=which(declaredExecute); end
samePath=strcmp(declaredExecutePath,hooks.executePath);
if ispc, samePath=strcmpi(declaredExecutePath,hooks.executePath); end
if ~samePackage||~strcmpi(field(manifest,'type',''),'classifier')|| ...
        ~sameExecute||~samePath
    error('pipelineModuleHooks:Identity','Runtime hooks do not belong to selected package %s.',pkg);
end
% Windows may resolve a saved lowercase alias to a mixed-case package.
% Keep the manifest's canonical identity for pins consumed by that package.
hooks.package=declaredPackage;
hooks.execute=declaredExecute;
for item={validate,prepare}
    name=item{1};
    owned=ischar(name)&&startsWith(name,[declaredPackage '.']);
    if ispc&&ischar(name), owned=startsWith(name,[declaredPackage '.'],'IgnoreCase',true); end
    if ~owned||~isvarname(name(numel(declaredPackage)+2:end))
        error('pipelineModuleHooks:Declaration','Declare both owned validation and preparation hooks for %s.',pkg);
    end
    resolved=which(name);
    if isempty(resolved)
        error('pipelineModuleHooks:Missing','Declared runtime hook %s is unavailable.',name);
    end
    actual=char(java.io.File(fileparts(resolved)).getCanonicalPath());
    expected=char(java.io.File(folder).getCanonicalPath());
    same=strcmp(actual,expected); if ispc, same=strcmpi(actual,expected); end
    if ~same
        error('pipelineModuleHooks:Shadowed','Runtime hook %s resolves outside selected package %s.',name,folder);
    end
end
hooks.validate=validate; hooks.prepare=prepare; hooks.supported=true;
end

function value=field(source,key,fallback)
value=fallback;
if isstruct(source)&&isscalar(source)&&isfield(source,key), value=source.(key); end
end
