function out = outInitSafe(stepId)
% CELLPOSesam.utils.outInitSafe
% Safe outInit wrapper (fallback when outInit not on path).

    if exist('outInit','file') == 2
        out = outInit(stepId);
    else
        out = struct('ok', true, 'status', "OK", 'stepId', stepId, ...
            'provides', {{}}, 'requires', {{}}, 'refs', struct(), ...
            'patch', [], 'artifacts', struct(), 'metrics', struct(), ...
            'warnings', {{}}, 'error', struct('id',"",'message',"",'stack',[]), 'logs', {{}} );
    end
end
