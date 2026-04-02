function pipeObj = pipelineConstruct(path, name, id)
% pipelineConstruct  Instantiate the pipeline class without surfacing
% the legacy @folder precedence warning caused by external path conflicts.

    if nargin < 1
        path = '';
    end
    if nargin < 2
        name = '';
    end
    if nargin < 3
        id = 1;
    end

    warnId = 'MATLAB:class:AtFolderPrecedence';
    originalState = warning('query', warnId);
    cleanupObj = onCleanup(@() warning(originalState.state, warnId)); %#ok<NASGU>
    warning('off', warnId);

    % Resolve the constructor at runtime so MATLAB does not emit the
    % class-vs-function precedence warning before the warning state applies.
    pipeCtor = str2func('pipeline');
    pipeObj = pipeCtor(path, name, id);
end
