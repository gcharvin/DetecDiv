function p = driftDefaults()
% DRIFTDEFAULTS Canonical defaults shared by extraction and direct calls.
p = struct('method','robust','refMode','adaptive','subpixel',true, ...
    'maxShift',20,'maxStep',20,'psrMin',10,'referenceInterval',5);
end
