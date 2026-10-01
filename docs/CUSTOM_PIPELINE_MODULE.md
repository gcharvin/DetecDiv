# Custom MATLAB pipeline module

The `custom` node calls a user MATLAB function from both `runPipeline` and
`runPipelineDetecDiv` (the worker runner). It can be saved in a pipeline
template, overridden in a `pipelineRun`, and configured in `pipeline2.mlapp`.

In pipeline2, use **Modules > Add built-in module > Custom > Custom function**.
The existing **Add custom package...** entry still imports external
processor/classifier packages. These are separate choices.

## Context mode

Set `entryPoint` to a function name, optionally qualified as `package.function`.
The Browse button accepts a `.m` function and sets its name and code folder.
`callMode=context` calls `ctx = myFunction(ctx)` once per node, with the
selected project, FOV/ROI inventory and execution settings in `ctx`.

User settings come from the `parametersJson` object and are supplied in
`ctx.params`. The runner restores the node configuration after the call.

```matlab
function ctx = myAnalysis(ctx)
    threshold = ctx.params.threshold;
    % Use ctx.shallow, ctx.roiList, ctx.frames, ctx.io, etc.
    ctx.tables = table(threshold, 'VariableNames', {'Threshold'});
end
```

Example configuration:

| Parameter | Value |
| --- | --- |
| entryPoint | `myAnalysis` |
| codeFolder | `code` |
| callMode | `context` |
| inputPorts | `roiList` |
| outputPorts | `tables` |
| parametersJson | `{"threshold":0.5}` |
| argumentsJson | `[]` |

For a dataset-free smoke test, use `customModule.example`, leave `codeFolder`
and `inputPorts` empty, declare `outputPorts=tables`, and set
`parametersJson={"value":3,"scale":2}`. The resulting table contains 6.

## Ready-to-copy function template

`engine/pipeline/+customModule/template.m` is an executable template with
English comments. Its sections explain parameter defaults and validation,
pipeline inputs, the user computation, and outputs shared with later nodes.

Copy it to your code folder and rename the first function to match the file:

```matlab
copyfile(which('customModule.template'), fullfile(myCodeFolder, 'myAnalysis.m'));
edit(fullfile(myCodeFolder, 'myAnalysis.m'));
% First line: function ctx = myAnalysis(ctx)
```

In pipeline2, browse to `myAnalysis.m`, keep `callMode=context`, leave
`inputPorts` empty, set `outputPorts=tables` and
`parametersJson={"value":3,"scale":2}`. The template produces a table with
`Value=6`; replace the computation with your analysis and adapt its ports.
The defaults also allow an empty parameter object `{}`.
You can try the original directly with `entryPoint=customModule.template`
and an empty codeFolder.

## Arguments mode

Set `callMode=arguments` to call an existing function with explicit arguments.
`argumentsJson` is an ordered JSON array. Numbers, strings, arrays and
booleans are literal values. Three single-key objects have special meaning:

- `{"context":"roiList"}` reads a context field (dotted struct fields allowed).
- `{"param":"threshold"}` reads the user parameter object.
- `{"value":...}` passes a literal JSON object instead of a reference.

For `function [measurements, fileList] = analyse(rois, threshold, verbose)`, use:

```json
[{"context":"roiList"},{"param":"threshold"},true]
```

Declare `inputPorts=roiList` and `outputPorts=tables, files`. MATLAB return
values are assigned to `ctx.tables` and `ctx.files` in that order. Empty
outputPorts supports functions called solely for their side effects.

Every referenced context root must be declared in inputPorts. MATLAB
expressions and automatic signature parsing are not used. `varargin` and
`varargout` functions are supported; user functions validate their own
required values and types. This version resolves file-backed MATLAB
functions; raw scripts need a small function wrapper.

## Connections, runs and code location

Ports are context field names separated by commas. Standard names receive
the existing pipeline types (`roiList`, `masks`, `channels`, `dataSeries`,
`images`, `fovList`, `shallow`, `tables`, `files`, `artifacts`). Other names
default to `generic`; `features:tableSet` declares an explicit type.
Connected modules share context fields with the same name. Graph edges
declare order and type compatibility; they do not rename context fields.
Context-mode functions must return every declared output field. In arguments
mode, the output declarations map MATLAB return positions to context fields.

The contract is regenerated from params after save/load. The default user
parameter object can be edited in Static parameters, and overridden in the
module's Runtime parameters for a run. An override replaces the whole JSON
object. For programmatic runs:

```matlab
ctx.run.nodeParams.custom_1.parametersJson = '{"threshold":0.8}';
[ctx, report] = runPipelineDetecDiv(pipe, ctx);
```

With an empty codeFolder, normal MATLAB function lookup applies. A relative
codeFolder is resolved under the pipeline template folder first, then under
the executing DetecDiv checkout. An absolute folder must exist on the
executing machine. Point to the folder containing the `.m` file or its
`+package`; the function must resolve inside that folder. Its temporary path
entry is restored after success or failure.

Worker execution requires the same user code to be available at that
location. Saving a pipeline does not copy external user code. Each successful
call records its resolved file, SHA-256 checksum and duration in
`ctx.customModuleRuns`, which is saved with the pipelineRun context.

Dry-run validates configuration, availability and input/output counts
without calling the user function. The common runner supplies selection,
logging, cancellation checks between nodes and execution policies. User
functions own their file/project mutations and must honor `ctx.io` policies;
the custom adapter does not infer persistence or append behavior from
arbitrary outputs. For long calls, user code can inspect `ctx.cancel`.

## Tests

```matlab
detecdiv_setup_path(pwd);
results = runtests({'structure/io/tests/testPipelineCustomModule.m', ...
    'structure/GUI/tests/testPipeline2CustomModule.m'});
assert(all([results.Passed]));
```

The tests cover both runners, chained context/argument modules, JSON and run
round trips, overrides, relative code resolution, path restoration, preflight
and output failures, worker payload execution, packed mlapp synchronization,
and editing/saving/adding custom nodes through the real App Designer app.
