function report = detecdiv_frontend_plugins(host, app, varargin)
%DETECDIV_FRONTEND_PLUGINS Attach registered packages to a native frontend.
% Generic host adapter; its canonical source is shipped by the plugin installer.
% Packages opt in with plugin.json: frontends.<host> = "package.callback".
% Missing/broken optional plugins must not prevent the host from opening.
p=inputParser;p.addParameter('Plugins',[],@(x)isstruct(x)||isempty(x));
p.parse(varargin{:});plugins=p.Results.Plugins;
host=char(string(host));assert(isvarname(host),'Invalid frontend name.');
if isempty(plugins),plugins=detecdiv_plugins_list();end
report=struct('package',{},'callback',{},'status',{},'message',{});
for k=1:numel(plugins)
    item=plugins(k);
    if ~isfield(item.manifest,'frontends')||~isstruct(item.manifest.frontends)|| ...
            ~isfield(item.manifest.frontends,host),continue;end
    callback=item.manifest.frontends.(host);
    row=struct('package',item.name,'callback','','status','failed','message','');
    try
        assert(ischar(callback)||(isstring(callback)&&isscalar(callback)), ...
            'A frontend callback must be a scalar qualified function name.');
        callback=char(callback);row.callback=callback;
        tokens=regexp(callback,'^([A-Za-z]\w*)\.([A-Za-z]\w*)$','tokens','once');
        assert(~isempty(tokens)&&strcmp(tokens{1},item.name), ...
            'The frontend callback must belong to the declaring package.');
        addpath(item.root);
        resolved=which(callback);
        assert(~isempty(resolved),'Frontend callback is unavailable.');
        expected=fullfile(item.path,[tokens{2} '.m']);
        assert(strcmpi(char(java.io.File(resolved).getCanonicalPath()), ...
            char(java.io.File(expected).getCanonicalPath())), ...
            'A different package on the MATLAB path shadows this frontend callback.');
        feval(callback,app);row.status='attached';
    catch err
        row.message=err.message;
        warning('detecdiv:FrontendPlugin','%s frontend plugin %s: %s',host,item.name,err.message);
    end
    report(end+1)=row; %#ok<AGROW>
end
end
