function issues = validate(node, ctx)
% Preflight must not invoke the user function.
issues = {};
if isfield(node, 'enabled') && ~isempty(node.enabled) && ~logical(node.enabled), return; end
try
    cfg = customModule.configuration(node.params);
    [~, ~, cleanup] = customModule.resolve(cfg, ctx); %#ok<ASGLU>
catch ME
    issues = {sprintf('Custom node %s: %s', char(string(node.id)), ME.message)};
end
end
