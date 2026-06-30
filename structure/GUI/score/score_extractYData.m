function [ydata, varNames, yTickInfo, sourceIndex] = score_extractYData(T, dataIndices)
% Extract ydata from table T(:,dataIndices) into a numeric matrix.
% - numeric/logical: cast to double
% - categorical: use double(v) (0 for <undefined>) and keep categories(v) (GLOBAL)
% - string/cellstr/char: try numeric parsing; else categorical(string(v)) (LOCAL)
% - cell arrays containing numeric scalars/vectors: expand to one curve per
%   vector element, preserving scalar columns as one curve.
%
% yTickInfo:
%   - isLabel(k)=true when we want discrete ticks/labels on Y
%   - ticks: numeric tick positions corresponding to labels
%   - labels: cellstr of labels

if istable(T)
    nTotalVars = width(T);
    dataIndices = dataIndices(dataIndices >= 1 & dataIndices <= nTotalVars);
    if isempty(dataIndices)
        nRow = height(T);
        ydata = nan(nRow, 0);
        varNames = {};
        sourceIndex = [];
        yTickInfo = struct();
        yTickInfo.isLabel = false(1, 0);
        yTickInfo.ticks   = [];
        yTickInfo.labels  = {};
        return;
    end
end

Tsel = T(:, dataIndices);
sourceVarNames = Tsel.Properties.VariableNames;

nCol = width(Tsel);
nRow = height(Tsel);
ydata = nan(nRow, 0);
varNames = {};
sourceIndex = [];

yTickInfo = struct();
yTickInfo.isLabel = false(1, 0);
yTickInfo.ticks   = [];
yTickInfo.labels  = {};

for k = 1:nCol
    v = Tsel{:, k};
    baseName = sourceVarNames{k};

    % -------------------------
    % Numeric / logical
    % -------------------------
    if isnumeric(v) || islogical(v)
        [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
            ydata, varNames, sourceIndex, yTickInfo, double(v), baseName, dataIndices(k), false, [], {});
        continue
    end

    % -------------------------
    % Cell arrays containing numeric scalars/vectors
    % -------------------------
    if iscell(v)
        maskIdx = matchingMaskIndexColumn(T, baseName);
        [cellData, cellNames] = expandNumericCellColumn(v, baseName, maskIdx);
        if ~isempty(cellData)
            for j = 1:size(cellData, 2)
                [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
                    ydata, varNames, sourceIndex, yTickInfo, cellData(:, j), cellNames{j}, dataIndices(k), false, [], {});
            end
            continue
        end
    end

    % -------------------------
    % Char scalar/cellstr are handled as strings below.
    % Other non-numeric cells fall back to string/categorical.
    % -------------------------
    if ischar(v)
        v = cellstr(v);
    end

    if iscell(v) && ~all(cellfun(@ischar, v))
        try
            v = cellfun(@string, v, 'UniformOutput', false);
            v = vertcat(v{:});
        catch
            v = string(v);
        end
    end

    if iscell(v) && all(cellfun(@ischar, v))
        v = string(v);
    end

    if isstring(v) && isrow(v) && numel(v) == nRow
        v = v(:);
    end

    % -------------------------
    % String/cellstr numeric parsing
    % -------------------------
    if isstring(v)
        num = str2double(v);
        ok = ~isnan(num);

        if any(ok) && mean(ok) > 0.8
            u = unique(num(ok));
            u = u(:).';
            [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
                ydata, varNames, sourceIndex, yTickInfo, num, baseName, dataIndices(k), true, u, cellstr(string(u)));
            continue
        end

        c = categorical(v);
        cats = categories(c);
        [ticks, labels] = categoricalTicks(double(c), cats);
        [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
            ydata, varNames, sourceIndex, yTickInfo, double(c), baseName, dataIndices(k), true, ticks, labels);
        continue
    end

    % -------------------------
    % Categorical (IMPORTANT: keep ORIGINAL categories!)
    % -------------------------
    if iscategorical(v)
        cats = categories(v);     % GLOBAL categories carried by the variable
        [ticks, labels] = categoricalTicks(double(v), cats);
        [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
            ydata, varNames, sourceIndex, yTickInfo, double(v), baseName, dataIndices(k), true, ticks, labels);
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
        u = unique(num(ok));
        u = u(:).';
        [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
            ydata, varNames, sourceIndex, yTickInfo, num, baseName, dataIndices(k), true, u, cellstr(string(u)));
        continue
    end

    % Fallback: LOCAL categories (only those present in this series)
    c = categorical(s);
    cats = categories(c);
    [ticks, labels] = categoricalTicks(double(c), cats);
    [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
        ydata, varNames, sourceIndex, yTickInfo, double(c), baseName, dataIndices(k), true, ticks, labels);
end
end

function [ydata, varNames, sourceIndex, yTickInfo] = appendSeries( ...
    ydata, varNames, sourceIndex, yTickInfo, series, name, srcIdx, isLabel, ticks, labels)

series = double(series);
if isrow(series)
    series = series(:);
end

ydata(:, end+1) = series;
varNames{end+1} = name;
sourceIndex(end+1) = srcIdx;
yTickInfo.isLabel(end+1) = logical(isLabel);

if isLabel && isempty(yTickInfo.ticks)
    yTickInfo.ticks = ticks;
    yTickInfo.labels = labels;
end
end

function [cellData, cellNames] = expandNumericCellColumn(v, baseName, maskIdx)
maxLen = 0;
nRow = numel(v);

for i = 1:nRow
    item = unwrapCellValue(v{i});
    if isempty(item)
        continue
    end
    if isnumeric(item) || islogical(item)
        maxLen = max(maxLen, numel(item));
    else
        maxLen = 0;
        break
    end
end

if maxLen == 0
    cellData = [];
    cellNames = {};
    return
end

cellData = nan(nRow, maxLen);
for i = 1:nRow
    item = unwrapCellValue(v{i});
    if isempty(item)
        continue
    end
    values = double(item(:).');
    n = min(numel(values), maxLen);
    cellData(i, 1:n) = values(1:n);
end

if maxLen == 1
    cellNames = {baseName};
else
    cellNames = cell(1, maxLen);
    for j = 1:maxLen
        idxLabel = maskIndexLabel(maskIdx, j);
        if isempty(idxLabel)
            cellNames{j} = sprintf('%s_%d', baseName, j);
        else
            cellNames{j} = sprintf('%s_idx%s', baseName, idxLabel);
        end
    end
end
end

function item = unwrapCellValue(item)
while iscell(item) && isscalar(item)
    item = item{1};
end
end

function [ticks, labels] = categoricalTicks(y, cats)
K = numel(cats);
if any(y(:) == 0)
    ticks = [0, 1:K];
    labels = [{'undefined'}; cellstr(cats)];
else
    ticks = 1:K;
    labels = cellstr(cats);
end
end

function maskIdx = matchingMaskIndexColumn(T, baseName)
maskIdx = [];
varNames = T.Properties.VariableNames;
maskVars = varNames(startsWith(varNames, 'MaskIdx_'));
if isempty(maskVars)
    return
end

suffix = "";
parts = regexp(baseName, '_', 'split');
if numel(parts) >= 2
    suffix = string(parts{end});
end

if strlength(suffix) > 0
    candidate = ['MaskIdx_' char(suffix)];
    if any(strcmp(varNames, candidate))
        maskIdx = T.(candidate);
        return
    end
end

if isscalar(maskVars)
    maskIdx = T.(maskVars{1});
end
end

function label = maskIndexLabel(maskIdx, pos)
label = '';
if isempty(maskIdx) || ~iscell(maskIdx)
    return
end

for i = 1:numel(maskIdx)
    item = unwrapCellValue(maskIdx{i});
    if isempty(item) || ~(isnumeric(item) || islogical(item)) || numel(item) < pos
        continue
    end
    val = double(item(pos));
    if isnan(val)
        continue
    end
    label = num2str(val);
    return
end
end
