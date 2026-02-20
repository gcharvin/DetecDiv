function L = localFocalCELoss(Y, Tcat, alphaVec, gamma, classNames)
% Retourne un loss scalaire (dlarray) compatible trainnet.
% - Y    : probs softmax (dlarray), typiquement format "CB"
% - Tcat : categorical labels (B×1 ou 1×B) OU one-hot numérique
% - alphaVec : poids par classe (C×1 ou 1×C)
% - gamma    : focal gamma
% - classNames : cellstr/string des classes (ordre cohérent avec softmax)

% ---- format de Y ----
if isa(Y,'dlarray') && ~isempty(dims(Y))
    fmt = string(dims(Y));     % ex "CB"
else
    fmt = "CB";
    if isa(Y,'dlarray')
        Y = dlarray(Y, fmt);
    end
end

% ---- construire T one-hot au même format que Y (suppose "CB") ----
if iscategorical(Tcat)
    if isrow(Tcat), Tcat = Tcat.'; end                    % Bx1
    T = onehotencode(Tcat, 1, "ClassNames", classNames);  % BxC
    T = single(T.');                                      % CxB
else
    T = single(Tcat);
end
T = dlarray(T, fmt);  % CxB avec labels "CB"

% ---- poids par classe (C×1) ----
wC = single(alphaVec(:));       % Cx1
wC = wC ./ max(eps('single'), mean(wC));  % optionnel: normaliser l'échelle

% ---- focal CE par élément (NON réduit) ----
if isa(Y,'dlarray') && ~isempty(dims(Y))
    Lelem = focalCrossEntropy(Y, T, Gamma=gamma, Alpha=1, ...
        TargetCategories="exclusive", Reduction="none");
else
    Lelem = focalCrossEntropy(Y, T, DataFormat=fmt, Gamma=gamma, Alpha=1, ...
        TargetCategories="exclusive", Reduction="none");
end

% ---- appliquer wC sur la dimension C + réduction en scalaire ----
% Lelem est de taille CxB (format "CB")
LelemW = Lelem .* wC;                    % broadcast Cx1 sur CxB
denom  = sum(T .* wC, "all");            % somme des poids des vrais labels (≈ B si wC~1)
L      = sum(LelemW, "all") ./ max(denom, eps('single'));

L = stripdims(L);                        % scalaire dlarray
end
