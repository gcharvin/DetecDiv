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
    % X : [H x T x B] (TCB, dlarray formaté)

    % --- enlever temporairement les labels ---
    Xd = stripdims(X);   % devient dlarray non formaté

    % --- poids ---
    W = reshape(layer.W, [], 1, 1);   % [H x 1 x 1]

    % --- score linéaire par frame ---
    s = sum(Xd .* W, 1) + layer.b;    % [1 x T x B]

    % --- gate sigmoid ---
    g = 1 ./ (1 + exp(-s));           % [1 x T x B]

    % --- gating résiduel ---
    Zd = Xd .* (1 + g);               % [H x T x B]

    % --- remettre les labels d'origine ---
    Z = dlarray(Zd, dims(X));         % restaure "TCB"
end


    end
end
