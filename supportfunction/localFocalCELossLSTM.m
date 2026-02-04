
function L = localFocalCELossLSTM(Y, T, alphaVec, gamma, classNames)
% localFocalCELoss  Universal focal CE for trainnet (CNN + LSTM).
% - Works when T is:
%   * categorical (seq2one, CNN)
%   * dlarray one-hot (trainnet may already provide it)
%   * cell array of categorical sequences (seq2seq LSTM)  <-- handled here
% - Returns a traced real dlarray scalar (required by trainnet).

% ---- infer format from Y (no DataFormat option if Y is already formatted) ----
fmt = "";
isYdl = isa(Y,'dlarray');
if isYdl
    try
        d = dims(Y);
        if ~isempty(d), fmt = string(d); end
    catch
        fmt = "";
    end
end
if fmt == ""
    fmt = "CB"; % safe fallback
end

% ---- build one-hot target aligned to Y + optional mask (for seq2seq padding) ----
[Tdl, mask] = localBuildTargetOneHotForTrainnet(Y, T, classNames, fmt);

% ---- per-class alpha (vector) implemented by scaling T (Alpha scalar left at 1) ----
alphaVec = reshape(single(alphaVec(:)), [], 1, 1);   % Cx1x1
Tdl = Tdl .* alphaVec;

% ---- focal CE map (same size as Y) ----
Lmap = focalCrossEntropy(Y, Tdl, ...
    Gamma = gamma, ...
    Alpha = 1, ...
    TargetCategories = "exclusive", ...
    Reduction = "none");

% ---- reduce to scalar ----
if isempty(mask)
    L = mean(Lmap, "all");
else
    % mask is [1 B T] or [1 B]; broadcast ok against [C B T] / [C B]
    num = sum(Lmap .* mask, "all");
    den = sum(mask, "all");
    L = num ./ max(den, eps('single'));
end

L = stripdims(L);
end

function [Tdl, mask] = localBuildTargetOneHotForTrainnet(Y, T, classNames, fmt)
mask = [];

% Case A: T already dlarray (trainnet often provides one-hot like Y)
if isa(T,'dlarray')
    Tdl = single(T);
    if ~isempty(dims(Tdl)) && any(dims(Tdl)=="T")
        % nonzero target along C => valid timestep
        mask = dlarray(single(sum(Tdl,1) > 0), "1BT"); % [1 B T]
    end
    return;
end

% Sizes from Y (works for both CNN CB and LSTM CBT)
szY = size(Y);
hasT = contains(fmt,"T");

% helper categorical -> indices 1..C
    function idx = cat2idx(tc)
        tc = categorical(tc, classNames, classNames); % enforce order
        idx = double(tc); % 1..C, 0 if undefined
    end

% Case B: seq2seq targets provided as cell array (one sequence per observation)
if iscell(T)
    if ~hasT
        error('localBuildTargetOneHotForTrainnet:CellTargetsButNoTimeDim', ...
            'Got cell targets (seq2seq) but Y has no time dimension (fmt=%s).', fmt);
    end

    % Assume Y is CBT => [C B T]
    C  = szY(1);
    B  = szY(2);
    TT = szY(3);

    Oh = zeros(C, B, TT, 'single');
    m  = zeros(1, B, TT, 'single');

    for b = 1:B
        tb = T{b};
        if isrow(tb), tb = tb.'; end
        idx = cat2idx(tb);
        Lb  = min(numel(idx), TT);

        for t = 1:Lb
            c = idx(t);
            if c >= 1 && c <= C
                Oh(c,b,t) = 1;
                m(1,b,t)  = 1;
            end
        end
    end

    Tdl  = dlarray(Oh, "CBT");
    mask = dlarray(m,  "1BT");
    return;
end

% Case C: categorical vector (seq2one / CNN)
if iscategorical(T)
    if isrow(T), T = T.'; end

    idx = cat2idx(T); % Bx1
    C = szY(1);
    B = szY(2);

    Oh = zeros(C, B, 'single');
    for b = 1:min(B, numel(idx))
        c = idx(b);
        if c >= 1 && c <= C
            Oh(c,b) = 1;
        end
    end

    Tdl = dlarray(Oh, "CB");
    mask = [];
    return;
end

error('localBuildTargetOneHotForTrainnet:UnsupportedTargetType', ...
    'Unsupported target type: %s', class(T));
end

