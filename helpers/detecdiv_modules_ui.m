function [rows,items,diagnostics] = detecdiv_modules_ui(varargin)
%DETECDIV_MODULES_UI Read-only presentation of the common module catalogue.
% rows keeps the pipeline editor's {label,type,package,summary} columns.
% items is aligned with rows and retains the exact catalogue candidates.
% Discovery/selection never activates a package or inspects its runtime.
p=inputParser;
textScalar=@(x)(ischar(x)&&isrow(x))||(isstring(x)&&isscalar(x));
paths=@(x)isempty(x)||ischar(x)||isstring(x)||iscellstr(x);
addParameter(p,'Root',fileparts(fileparts(mfilename('fullpath'))),textScalar);
addParameter(p,'PluginRoots',{},paths);
addParameter(p,'PackagePaths',{},paths);
addParameter(p,'IncludeActivePackages',true,@(x)isscalar(x)&& ...
    (islogical(x)||(isnumeric(x)&&any(x==[0 1]))));
parse(p,varargin{:});
options=p.Results;
args={'Root',options.Root,'PackagePaths',options.PackagePaths};
if ~any(strcmp(p.UsingDefaults,'PluginRoots'))
    args=[args {'PluginRoots',options.PluginRoots}];
end
[modules,diagnostics]=detecdiv_modules_list(args{:});

% A registered release can differ from the copy already selected by MATLAB.
% Show that actual copy as another candidate, without selecting it silently.
% The common catalogue remains responsible for conflict diagnostics.
if options.IncludeActivePackages
    active={};
    % Catalogue paths are already canonical. Compare their keys directly;
    % canonicalizing every known path for every candidate makes discovery
    % quadratic and repeats network filesystem calls thousands of times.
    known={modules.path};
    if ispc, known=cellfun(@lower,known,'UniformOutput',false); end
    for i=1:numel(modules)
        m=modules(i);
        if ~any(strcmpi(m.type,{'classifier','processor'}))|| ...
                isempty(m.resolvedEntrypoint)||~isfile(m.resolvedEntrypoint)
            continue;
        end
        folder=canonical(fileparts(m.resolvedEntrypoint));
        key=folder;
        if ispc,key=lower(key);end
        if ~any(strcmp(known,key))
            active{end+1}=folder; %#ok<AGROW>
            known{end+1}=key; %#ok<AGROW>
        end
    end
    if ~isempty(active)
        explicit=pathList(options.PackagePaths);
        args{4}=[explicit active];
        [modules,diagnostics]=detecdiv_modules_list(args{:});
    end
end

rows=cell(numel(modules),4);
empty=struct('module',struct(),'label','','details',{{}}, ...
    'canAdd',false,'reason','','statusLabel','');
items=repmat(empty,1,numel(modules));
for i=1:numel(modules)
    m=modules(i);
    origin='Bundled';
    if strcmp(m.distribution,'external'), origin='External'; end
    version=versionText(m.adapterVersion);
    [canAdd,state,reason]=availability(m);
    label=sprintf('%s [%s; adapter %s]',m.name,origin,version);
    if sum(strcmp({modules.pkg},m.pkg))>1
        label=[label ' | ' m.path];
    end
    if ~canAdd, label=[label ' (' state ')']; end
    details={ ...
        ['Module: ' m.name]; ['Module ID: ' m.id]; ...
        ['Function: ' m.type]; ['MATLAB package: ' m.pkg]; ...
        ['Distribution: ' origin ' (' m.distribution ')']; ...
        ['Adapter version: ' version]; ...
        ['Descriptor: ' m.descriptorStatus]; ['Availability: ' state]; ...
        ['Folder: ' m.path]; ['Entrypoint: ' m.entrypoint]; ...
        ['Selected entrypoint: ' fallback(m.resolvedEntrypoint,'unavailable')]; ...
        ['Repository: ' fieldText(m.provenance,'repository','unspecified')]; ...
        ['Declared capabilities: ' fallback(strjoin(m.capabilities,', '),'unspecified')]; ...
        ['Pipeline contract: ' fieldText(m.compatibility,'pipelineContract','legacy')]; ...
        ['Runtime contract: ' fieldText(m.compatibility,'runtimeContract','legacy')]; ...
        'Runtime/dependencies: not checked by catalogue browsing.'; ...
        'Model release and scientific validation: not inferred from adapter metadata.'};
    if ~isempty(reason), details=[details; {''; reason}]; end %#ok<AGROW>
    if ~isempty(m.summary), details=[details; {''; m.summary}]; end %#ok<AGROW>
    items(i)=struct('module',m,'label',label,'details',{details}, ...
        'canAdd',canAdd,'reason',reason,'statusLabel',state);
    uiType=m.type;
    % The editor historically treats roiIdentify as its roiPattern alias.
    % Keep the underlying catalogue identity available in item.module.
    if strcmpi(uiType,'roiIdentify'), uiType='roiPattern'; end
    rows(i,:)={label,uiType,m.pkg,sprintf('%s | %s | Adapter %s | %s', ...
        m.summary,origin,version,state)};
end
end

function [allowed,state,reason]=availability(m)
allowed=false;
reason='';
if strcmp(m.status,'invalid')||strcmp(m.descriptorStatus,'invalid')
    state='Invalid descriptor';
    reason='This candidate cannot be added until its catalogue errors are resolved.';
elseif strcmp(m.status,'conflict')
    state='Conflict';
    reason=['Multiple or shadowed installations require explicit resolution. ' ...
        'The catalogue does not change the MATLAB path or select a release.'];
elseif ~m.onPath
    state='Not on MATLAB path';
    reason='This candidate is discovered but its executable is not selected on the MATLAB path.';
else
    state='Available on MATLAB path';
    allowed=true;
    % Prevent metadata from another installation configuring this candidate.
    names=struct2cell(m.entrypoints);
    for i=1:numel(names)
        if isempty(names{i}), continue; end
        resolved=which(names{i});
        if isempty(resolved)||~samePath(fileparts(resolved),m.path)
            allowed=false;
            state='Metadata unavailable';
            reason=['A declared metadata function is unavailable or selected from another package: ' names{i}];
            break;
        end
    end
end
if ~isempty(m.issues), reason=strjoin([{reason} m.issues],' | '); end
end

function value=versionText(raw)
value='unspecified';
if ischar(raw)&&~isempty(raw), value=raw;
elseif isstring(raw)&&isscalar(raw)&&~ismissing(raw)&&strlength(raw)>0
    value=char(raw);
end
end

function values=pathList(raw)
if isempty(raw), values={}; else, values=cellstr(string(raw)); values=values(:)'; end
end

function value=fieldText(source,name,defaultValue)
value=defaultValue;
if isstruct(source)&&isscalar(source)&&isfield(source,name)
    raw=source.(name);
    if (ischar(raw)&&isrow(raw))||(isstring(raw)&&isscalar(raw))
        value=fallback(char(raw),defaultValue);
    end
end
end

function value=fallback(value,defaultValue)
if isempty(value), value=defaultValue; end
end

function value=canonical(value)
value=char(java.io.File(value).getCanonicalPath());
end

function tf=samePath(a,b)
a=canonical(a); b=canonical(b);
tf=strcmp(a,b); if ispc, tf=strcmpi(a,b); end
end
