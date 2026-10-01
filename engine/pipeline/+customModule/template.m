function ctx = template(ctx)
% TEMPLATE User function template for a DetecDiv custom module.
%
% Copy this file to myAnalysis.m and rename the function above:
%   function ctx = myAnalysis(ctx)
%
% Configuration in pipeline2 (Custom function):
%   entryPoint     : myAnalysis (or customModule.template to try this example)
%   codeFolder     : folder containing myAnalysis.m
%   callMode       : context
%   inputPorts     : empty for this example; roiList if your code uses it
%   outputPorts    : tables
%   parametersJson: {"value":3,"scale":2}
%   argumentsJson : []
%
% The function is called once per node. Return the incoming context with
% the declared outputs added; preserve the other fields of ctx.

%% 1. User parameters (from parametersJson)
% Adapt the defaults and validation checks to your analysis.
if ~isfield(ctx, 'params') || isempty(ctx.params)
    ctx.params = struct();
end
p = ctx.params;
if ~isfield(p, 'value'), p.value = 3; end
if ~isfield(p, 'scale'), p.scale = 2; end
validateattributes(p.value, {'numeric'}, {'scalar','real','finite'}, ...
    mfilename, 'value');
validateattributes(p.scale, {'numeric'}, {'scalar','real','finite'}, ...
    mfilename, 'scale');

%% 2. Pipeline inputs
% Declare each field used in inputPorts and connect its producer.
% Example for ROI analysis (uncomment and adapt):
% assert(isfield(ctx, 'roiList'), 'myAnalysis:MissingROI', ...
%     'A roiList input is required.');
% rois = ctx.roiList;
% The project is available through ctx.shallow; selections may include
% ctx.fovList and ctx.frames. Check the context actually supplied to your node.

%% 3. Your processing code
% Replace this calculation with your code. Workers must be able to run it
% without a GUI.
value = p.value * p.scale;

%% 4. Outputs available to subsequent nodes
% Create every field declared in outputPorts, even when the result is empty.
% Each field name must match its port name exactly.
ctx.tables = table(value, 'VariableNames', {'Value'});
% Other examples: ctx.dataSeries, ctx.masks, ctx.files, ctx.artifacts.
% Returning a result in ctx does not automatically save it in the ROIs.
% If your code writes files or changes the project, explicitly apply
% the policy supplied through ctx.io / ctx.executionPolicy.
end
