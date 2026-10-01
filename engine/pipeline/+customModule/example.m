function ctx = example(ctx)
% Minimal runnable example: parametersJson = {"value":3,"scale":2},
% outputPorts = tables. No microscopy data or disk writes are required.
value = ctx.params.value * ctx.params.scale;
ctx.tables = table(value, 'VariableNames', {'Value'});
end
