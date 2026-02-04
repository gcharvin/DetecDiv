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
    % Accept X as:
    %  - [F x T] 
    %  - [F x T x B]
    %  - [F x 1 x T x B] (possible after some sequence plumbing)
    %
    % We apply a scalar gate per time step (and per batch item).

    Xd = stripdims(X);
    sz = size(Xd);
    nd = ndims(Xd);

    % --- Normalize to [F x T x B] ---
    if nd == 2
        % [F x T] -> [F x T x 1]
        F = sz(1); T = sz(2); B = 1;
        Xn = reshape(Xd, [F T B]);

    elseif nd == 3
        % [F x T x B]
        F = sz(1); T = sz(2); B = sz(3);
        Xn = Xd;

    elseif nd == 4
        % Common case: [F x 1 x T x B] or [F x T x 1 x B]
        % We try to detect where T and B are.
        F = sz(1);

        % If second dim is singleton, assume [F x 1 x T x B]
        if sz(2) == 1
            T = sz(3); B = sz(4);
            Xn = reshape(Xd, [F T B]);
        % If third dim is singleton, assume [F x T x 1 x B]
        elseif sz(3) == 1
            T = sz(2); B = sz(4);
            Xn = reshape(Xd, [F T B]);
        else
            error('temporalAttentionLayer:UnsupportedShape', ...
                'Unsupported 4D shape: %s', mat2str(sz));
        end
    else
        error('temporalAttentionLayer:UnsupportedNdims', ...
            'Unsupported ndims=%d shape=%s', nd, mat2str(sz));
    end

    % --- Check feature dimension matches W ---
    W = layer.W;  % [F x 1] expected
    if size(W,1) ~= size(Xn,1)
        error('temporalAttentionLayer:FeatureMismatch', ...
            'Feature mismatch: size(X,1)=%d but size(W,1)=%d', size(Xn,1), size(W,1));
    end

    Wb = reshape(W, [], 1, 1);            % [F x 1 x 1]
    s  = sum(Xn .* Wb, 1) + layer.b;      % [1 x T x B]
    g  = 1 ./ (1 + exp(-s));              % [1 x T x B]
    Yn = Xn .* (1 + g);                   % [F x T x B]

    % --- Restore original shape ---
    if nd == 2
        Zd = reshape(Yn, [F T]);
    elseif nd == 3
        Zd = Yn;
    else % nd==4
        % return to the same 4D layout as input
        if sz(2) == 1
            Zd = reshape(Yn, [F 1 T B]);
        else
            Zd = reshape(Yn, [F T 1 B]);
        end
    end

    % restore labels if they existed
    Z = dlarray(Zd, dims(X));
end



    end
end
