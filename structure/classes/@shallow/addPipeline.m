function pipeObj = addPipeline(~, varargin)
% addPipeline  Backward-compatible wrapper to create an independent pipeline.
%
% This method is kept for shallow API compatibility. The creation logic now
% lives in pipelineNew. Historical behavior is preserved: addPipeline
% publishes the created pipeline to base workspace by default.


    hasWorkspaceArg = false;
    for i = 1:2:numel(varargin)
        if i <= numel(varargin) && (ischar(varargin{i}) || isstring(varargin{i}))
            if strcmpi(char(string(varargin{i})), 'workspace')
                hasWorkspaceArg = true;
                break;
            end
        end
    end

    if ~hasWorkspaceArg
        varargin = [varargin, {'workspace', true}];
    end

    pipeObj = pipelineNew(varargin{:});
end
