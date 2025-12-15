classdef temporalAttentionLayer < nnet.layer.Layer ...
                              & nnet.layer.Formattable
    % Temporal attention gate (frame-wise)
    % Input : [H x T x B]  (TCB)
    % Output: same size, gated

    properties (Learnable)
        W   % [1 x H]  linear projection
        b   % scalar bias
    end

    methods
        function layer = temporalAttentionLayer(name, hiddenSize)
            layer.Name = name;
            layer.Description = 'Temporal attention gate (scalar per frame)';
            layer.W = randn(hiddenSize,1,'single')*0.01;  % au lieu de 1xH

            layer.b = single(0);
        end

        function Z = predict(layer, X)
    % X : [H x T x B] (TCB, dlarray possiblement formaté)

    % Cast/shape W to broadcast over T and B
   W = reshape(layer.W, [], 1, 1); % [H 1 1]


    % Linear score per frame: s = sum_k W_k * X_k,t,b  + b
    s = sum(X .* W, 1) + layer.b;     % [1 x T x B]

    % Sigmoid gate
    g = 1 ./ (1 + exp(-s));           % [1 x T x B]

    % Residual gating
    Z = X .* (1 + g);                 % [H x T x B]
end

    end
end
