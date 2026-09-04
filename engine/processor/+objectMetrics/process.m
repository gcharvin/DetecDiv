function [paramout,dataout,imageout] = process(param,roiobj,ctx)
%OBJECTMETRICS.PROCESS Pipeline-compatible wrapper.
if nargin<3||~isstruct(ctx), ctx=struct(); end
defaults=objectMetrics.setparam(ctx);
if nargin==0||isempty(param)
    paramout=defaults; dataout=[]; imageout=[]; return;
end
paramout=defaults;
names=fieldnames(param);
for i=1:numel(names), paramout.(names{i})=param.(names{i}); end
frames=[];
if isfield(ctx,'frames'), frames=ctx.frames;
elseif isfield(ctx,'sel')&&isstruct(ctx.sel)&&isfield(ctx.sel,'frames'), frames=ctx.sel.frames; end
[paramout,dataout,imageout]=objectMetrics.core(paramout,roiobj,frames);
end
