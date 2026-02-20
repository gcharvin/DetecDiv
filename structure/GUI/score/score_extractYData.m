function [ydata, varNames, yTickInfo] = score_extractYData(T, dataIndices)
% Extract ydata from table T(:,dataIndices) into a numeric matrix.
% - numeric/logical: cast to double
% - categorical: use double(v) (0 for <undefined>) and keep categories(v) (GLOBAL)
% - string/cellstr/char: try numeric parsing; else categorical(string(v)) (LOCAL)
%
% yTickInfo:
%   - isLabel(k)=true when we want discrete ticks/labels on Y
%   - ticks: numeric tick positions corresponding to labels
%   - labels: cellstr of labels

Tsel = T(:, dataIndices);
varNames = Tsel.Properties.VariableNames;

nCol = width(Tsel);
nRow = height(Tsel);
ydata = nan(nRow, nCol);

yTickInfo = struct();
yTickInfo.isLabel = false(1, nCol);
yTickInfo.ticks   = [];
yTickInfo.labels  = {};

for k = 1:nCol
    v = Tsel{:, k};

    % -------------------------
    % Numeric / logical
    % -------------------------
    if isnumeric(v) || islogical(v)
        ydata(:, k) = double(v);
        continue
    end

    % -------------------------
    % Categorical (IMPORTANT: keep ORIGINAL categories!)
    % -------------------------
    if iscategorical(v)
        ydata(:, k) = double(v);  % 1..K, and 0 for <undefined>

        cats = categories(v);     % GLOBAL categories carried by the variable
        K = numel(cats);

        has0 = any(ydata(:,k) == 0);
        if has0
            yTickInfo.isLabel(k) = true;
            yTickInfo.ticks  = [0, 1:K];
            yTickInfo.labels = [{'undefined'}; cellstr(cats)];
        else
            yTickInfo.isLabel(k) = true;
            yTickInfo.ticks  = 1:K;
            yTickInfo.labels = cellstr(cats);
        end
        continue
    end

    % -------------------------
    % Strings / cellstr / char
    % -------------------------
    s = string(v);

    % Try numeric parsing
    num = str2double(s);
    ok = ~isnan(num);

    if any(ok) && mean(ok) > 0.8
        ydata(:, k) = num;

        u = unique(num(ok));
        u = u(:).';

        yTickInfo.isLabel(k) = true;
        yTickInfo.ticks  = u;
        yTickInfo.labels = cellstr(string(u));
        continue
    end

    % Fallback: LOCAL categories (only those present in this series)
    c = categorical(s);
    ydata(:, k) = double(c);

    cats = categories(c);
    K = numel(cats);

    has0 = any(ydata(:,k) == 0);
    if has0
        yTickInfo.isLabel(k) = true;
        yTickInfo.ticks  = [0, 1:K];
        yTickInfo.labels = [{'undefined'}; cellstr(cats)];
    else
        yTickInfo.isLabel(k) = true;
        yTickInfo.ticks  = 1:K;
        yTickInfo.labels = cellstr(cats);
    end
end
end
