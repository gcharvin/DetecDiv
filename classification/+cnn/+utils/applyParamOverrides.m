function tp = applyParamOverrides(tp, params)
% CNN.utils.applyParamOverrides
% Case-insensitive override of trainingParam fields.

    if isempty(tp) || ~isstruct(tp) || ~isstruct(params)
        return;
    end
    f = fieldnames(params);
    tpf = fieldnames(tp);
    for i = 1:numel(f)
        key = f{i};
        hit = find(strcmpi(tpf, key), 1, 'first');
        if ~isempty(hit)
            tp.(tpf{hit}) = params.(key);
        end
    end
end
