function [node, runtimeParams, info] = detecdiv_plugins_reset_link(node, runtimeParams, plugins)
%DETECDIV_PLUGINS_RESET_LINK Replace a bundled binding with an installed plugin.
% The conventional sibling DetecDiv-plugins checkout takes precedence over
% other registered roots. Analysis settings and channel bindings are retained.
if nargin<2 || ~isstruct(runtimeParams),runtimeParams=struct();end
if nargin<3,plugins=detecdiv_plugins_list();end
pkg=char(string(node.pkg));type=char(string(node.type));
candidates=find(strcmp({plugins.name},pkg) & strcmpi({plugins.type},type));
defaultDir=fullfile(detecdiv_plugins_default_root(),'plugins',type,['+' pkg]);
for i=candidates
    if strcmpi(canonical(plugins(i).path),canonical(defaultDir))
        candidates=[i candidates(candidates~=i)];break;
    end
end
chosen=[];
for i=candidates
    if isfolder(plugins(i).path) && isfile(fullfile(plugins(i).path,entryFile(plugins(i).entrypoint)))
        chosen=i;break;
    end
end
if isempty(chosen)
    error('detecdiv_plugins_reset_link:NotInstalled', ...
        ['The installed %s plugin "%s" was not found. Clone DetecDiv-plugins next to ' ...
        'DetecDiv, or register its folder in Browse plugins, then try Clear link again. ' ...
        'The existing link was kept.'],type,pkg);
end
plugin=plugins(chosen);packageDir=canonical(plugin.path);root=fileparts(packageDir);
% Prioritize this root even when a bundled copy was loaded in this session.
addpath(root,'-begin');
files=dir(fullfile(packageDir,'*.m'));
for i=1:numel(files)
    [~,name]=fileparts(files(i).name);clear([pkg '.' name]);
end
rehash;
actual=which(plugin.entrypoint);
if isempty(actual) || ~strcmpi(canonical(fileparts(actual)),packageDir)
    error('detecdiv_plugins_reset_link:ResolutionFailed', ...
        'MATLAB does not resolve the installed plugin at %s (resolved: %s).',packageDir,actual);
end
if ~isfield(node,'params') || ~isstruct(node.params),node.params=struct();end
% Fill newly introduced settings without replacing explicit user values.
if isfile(fullfile(packageDir,'setparam.m'))
    defaults=feval([pkg '.setparam'],struct());
    fields=fieldnames(defaults);
    for i=1:numel(fields)
        key=fields{i};
        if ~isfield(node.params,key),node.params.(key)=defaults.(key);end
    end
end
patch=struct('customPackageRoot',root,'customPackageDir',packageDir, ...
    'customPackageLoadedAt',char(datetime('now')));
fields=fieldnames(patch);
for i=1:numel(fields)
    key=fields{i};node.(key)=patch.(key);node.params.(key)=patch.(key);
    runtimeParams.(key)=patch.(key);
end
node.func=plugin.entrypoint;
info=struct('packageDir',packageDir,'entrypoint',plugin.entrypoint,'resolvedPath',actual);
end

function value=canonical(value)
value=char(java.io.File(char(string(value))).getCanonicalPath());
end

function value=entryFile(entrypoint)
parts=strsplit(char(string(entrypoint)),'.');value=[parts{end} '.m'];
end
