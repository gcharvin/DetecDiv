function dispOut = mergeDisplayStructs(dOld, dNew)
dispOut = dOld;
fn = fieldnames(dNew);
for i = 1:numel(fn)
    f = fn{i};
    if ~isfield(dispOut,f) || isempty(dispOut.(f))
        dispOut.(f) = dNew.(f); continue;
    end
    a = dispOut.(f); b = dNew.(f);
    if (isnumeric(a)||islogical(a)) && (isnumeric(b)||islogical(b))
        dispOut.(f) = b; continue;
    end
    if iscell(a) && iscell(b)
        dispOut.(f) = b; continue;
    end
    dispOut.(f) = b;
end
end
