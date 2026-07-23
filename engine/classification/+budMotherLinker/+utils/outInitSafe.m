function out = outInitSafe(stepId)
%BUDMOTHERLINKER.UTILS.OUTINITSAFE Create a standard package result.
if exist('outInit','file') == 2
    out = outInit(stepId);
else
    out = struct('ok',true,'status',"OK",'stepId',stepId, ...
        'provides',{{}},'requires',{{}},'refs',struct(),'patch',[], ...
        'artifacts',struct(),'metrics',struct(),'warnings',{{}}, ...
        'error',struct('id',"",'message',"",'stack',[]),'logs',{{}});
end
end
