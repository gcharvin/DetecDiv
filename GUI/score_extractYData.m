function [ydata, varNames, yTickInfo] = score_extractYData(T, dataIndices)

% Extract ydata from a table T(:,dataIndices) into a numeric matrix.
% - numeric/logical: kept (cast to double)
% - categorical/string/cellstr/char: try numeric parsing first; fallback to grp2idx

yTickInfo = struct('isLabel', false(1, width(T(:,dataIndices))), ...
                   'ticks',  [], ...
                   'labels', {{}});

Tsel = T(:, dataIndices);
varNames = Tsel.Properties.VariableNames;

nCol = width(Tsel);
nRow = height(Tsel);
ydata = nan(nRow, nCol);

for k = 1:nCol
    v = Tsel{:, k};

    if isnumeric(v) || islogical(v)
        ydata(:, k) = double(v);
        continue;
    end

  s = string(v);

% Si c'est categorical, récupérer les catégories (noms)
if iscategorical(v)
    cats = categories(v);
else
    cats = unique(s(~ismissing(s)));
end

num = str2double(s);
ok = ~isnan(num);

if any(ok) && mean(ok) > 0.8
    % Valeurs numériques "réelles" -> ticks = valeurs uniques, labels = mêmes valeurs en string
    ydata(:, k) = num;

    u = unique(num(ok));
    u = u(:).';
    yTickInfo.isLabel(k) = true;
    yTickInfo.ticks = u;
    yTickInfo.labels = cellstr(string(u));

else
    % Fallback: coder par catégories, et garder les noms des catégories
    c = categorical(s);
    ydata(:, k) = double(grp2idx(c));

    % Mapping codes -> catégories (ordre de categories(c))
    yTickInfo.isLabel(k) = true;
    yTickInfo.ticks = 1:numel(categories(c));
    yTickInfo.labels = categories(c);
end


    % Last resort
    try
        ydata(:, k) = double(v);
    catch
        ydata(:, k) = nan(nRow, 1);
    end
end
end
