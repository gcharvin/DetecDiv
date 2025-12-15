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
            layer.W = randn(1, hiddenSize, 'single') * 0.01;
            layer.b = single(0);
        end

        function Z = predict(layer, X)
            % X: [H x T x B]
            % gate g_t = sigmoid(W*h_t + b)

            % Linear projection → [1 x T x B]
            g = pagemtimes(layer.W, X) + layer.b;

            % Sigmoid
            g = 1 ./ (1 + exp(-g));

            % Residual gating
            Z = X .* (1 + g);
        end
    end
end
