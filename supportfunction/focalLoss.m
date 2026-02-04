function loss = focalLoss(Y, T, alpha, gamma, classNames)
% Y: dlarray AFTER softmax, with class dim labeled 'C' if possible
% T: categorical OR indices OR one-hot
% alpha: 1xC
% gamma: scalar

if nargin < 3 || isempty(alpha), alpha = []; end
if nargin < 4 || isempty(gamma), gamma = 0; end
if nargin < 5, classNames = []; end

% --- infer C and classDim robustly ---
if ~isempty(classNames)
    C = numel(classNames);
else
    % Prefer label 'C' if present
    if isa(Y,'dlarray') && any(dimnames(Y)=="C")
        C = size(Y, finddim(Y,"C"));
    else
        % fallback: take first non-singleton as class dim and its size as C
        classDim = find(size(Y)>1, 1, "first");
        C = size(Y, classDim);
    end
end

if isa(Y,'dlarray') && any(dimnames(Y)=="C")
    classDim = finddim(Y,"C");
else
    classDim = find(size(Y)>1, 1, "first");
end

% --- alpha ---
if isempty(alpha)
    alpha = ones(1, C, "single");
else
    alpha = single(alpha(:).'); % 1xC
end
gamma = single(gamma);
eps0  = single(1e-7);

% --- one-hot targets aligned with Y ---
T1 = targetToOneHot(T, C, classDim, classNames, size(Y));
T1 = dlarray(single(T1));   % constant mask

% --- pt = p(y_true) ---
pt = sum(Y .* T1, classDim);
pt = max(min(pt, 1-eps0), eps0);

% --- alpha_t ---
szA = ones(1, ndims(Y));
szA(classDim) = C;
a = reshape(alpha, szA);
alpha_t = sum(T1 .* a, classDim);

% --- focal loss ---
lossPer = - alpha_t .* ((1 - pt) .^ gamma) .* log(pt);
loss = mean(lossPer, "all");
end
