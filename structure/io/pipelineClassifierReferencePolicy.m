function policy = pipelineClassifierReferencePolicy(node)
% pipelineClassifierReferencePolicy  Metadata-only classi reference policy.
% requiresClassifierReference describes the configuration/artifact link;
% requiresRuntimeClassifier is retained as a compatibility fallback. Trust
% either only beside the selected executable. Existing references remain
% visible and must still be checked, including broken ones.

policy = struct('required',true,'declared',false,'hasReference',false, ...
    'showReference',true,'specAvailable',false,'spec',struct(), ...
    'semanticContractDeclared',false,'semanticContractSource','', ...
    'metadataStatus','execution_unavailable','selectedExecutable','', ...
    'selectedPackageDir','','metadataPath','','requirementSource','','message','');
params = valueOr(node,'params',struct());
referenceKeys = {'modulePath','moduleVar','moduleId'};
for i = 1:numel(referenceKeys)
    if hasValue(valueOr(params,referenceKeys{i},[])) || ...
            hasValue(valueOr(node,referenceKeys{i},[]))
        policy.hasReference = true;
    end
end
pkg = textOr(valueOr(node,'pkg',''));
if isempty(pkg), pkg = textOr(valueOr(params,'pkg','')); end
if isempty(pkg), return; end
policy.selectedExecutable = which([pkg '.classify']);
if isempty(policy.selectedExecutable), return; end
policy.selectedPackageDir = fileparts(policy.selectedExecutable);
[policy.semanticContractDeclared,policy.semanticContractSource] = ...
    descriptorContract(policy.selectedPackageDir,pkg,policy.selectedExecutable);
policy.metadataPath = which([pkg '.executionSpec']);
policy.metadataStatus = 'metadata_unavailable';
if isempty(policy.metadataPath), return; end
if ~sameFolder(fileparts(policy.metadataPath),policy.selectedPackageDir)
    policy.metadataStatus = 'metadata_mismatch';
    policy.message = 'executionSpec does not belong to the selected classifier package.';
    return;
end
try
    spec = feval([pkg '.executionSpec'],[]);
catch
    try
        spec = feval([pkg '.executionSpec']);
    catch ME
        policy.metadataStatus = 'metadata_failed';
        policy.message = ME.message;
        return;
    end
end
if ~isstruct(spec) || ~isscalar(spec)
    policy.metadataStatus = 'metadata_invalid';
    policy.message = 'executionSpec must return one metadata struct.';
    return;
end
policy.specAvailable = true;
policy.spec = spec;
policy.metadataStatus = 'ok';
requirementKey = '';
if isfield(spec,'requiresClassifierReference')
    requirementKey = 'requiresClassifierReference';
elseif isfield(spec,'requiresRuntimeClassifier')
    requirementKey = 'requiresRuntimeClassifier';
end
if ~isempty(requirementKey)
    required = spec.(requirementKey);
    if isscalar(required) && (islogical(required) || ...
            (isnumeric(required) && isreal(required) && any(required == [0 1])))
        policy.required = logical(required);
        policy.declared = true;
        policy.requirementSource = requirementKey;
    elseif ~isempty(required)
        policy.metadataStatus = 'metadata_invalid';
        policy.message = [requirementKey ' must be one logical value.'];
    end
end
policy.showReference = policy.required || policy.hasReference;
for name = {'contract','pipelineContract'}
    declaration = valueOr(spec,name{1},struct());
    if isstruct(declaration) && isscalar(declaration) && ~isempty(fieldnames(declaration))
        policy.semanticContractDeclared = true;
        policy.semanticContractSource = ['executionSpec.' name{1}];
        return;
    end
end
end

function [declared,source] = descriptorContract(packageDir,pkg,selectedExecutable)
declared = false;
source = '';
descriptorPath = fullfile(packageDir,'module.json');
if ~isfile(descriptorPath), return; end
try
    manifest = jsondecode(fileread(descriptorPath));
    entrypoints = valueOr(manifest,'entrypoints',struct());
    compatibility = valueOr(manifest,'compatibility',struct());
    contractName = textOr(valueOr(entrypoints,'contract',''));
    executeName = textOr(valueOr(entrypoints,'execute',''));
    if ~strcmp(textOr(valueOr(manifest,'format','')),'detecdiv.module.v1') || ...
            ~samePackage(textOr(valueOr(manifest,'package','')),pkg) || ...
            ~strcmpi(textOr(valueOr(manifest,'type','')),'classifier') || ...
            ~strcmp(textOr(valueOr(compatibility,'pipelineContract','')), ...
                'detecdiv.module_contract.v1') || ...
            ~startsWith(contractName,[pkg '.'],'IgnoreCase',ispc) || ...
            ~startsWith(executeName,[pkg '.'],'IgnoreCase',ispc)
        return;
    end
    contractPath = which(contractName);
    executePath = which(executeName);
    if ~isempty(contractPath) && ~isempty(executePath) && ...
            sameFolder(fileparts(contractPath),packageDir) && ...
            sameFile(executePath,selectedExecutable)
        declared = true;
        source = descriptorPath;
    end
catch
    % Normal contract validation reports malformed descriptor diagnostics.
end
end

function value = valueOr(s,key,fallback)
value = fallback;
if isstruct(s) && isscalar(s) && isfield(s,key), value = s.(key); end
end

function tf = hasValue(value)
tf = ~isempty(value);
if ischar(value) || isstring(value)
    tf = any(strlength(strtrim(string(value(:)))) > 0);
end
end

function value = textOr(value)
if (ischar(value) && (isrow(value) || isempty(value))) || ...
        (isstring(value) && isscalar(value))
    value = char(value);
else
    value = '';
end
end

function tf = sameFolder(left,right)
tf = sameFile(left,right);
end

function tf = samePackage(left,right)
tf = strcmp(left,right);
if ispc, tf = strcmpi(left,right); end
end

function tf = sameFile(left,right)
try
    left = char(java.io.File(left).getCanonicalPath());
    right = char(java.io.File(right).getCanonicalPath());
catch
    tf = false;
    return;
end
tf = strcmp(left,right);
if ispc, tf = strcmpi(left,right); end
end
