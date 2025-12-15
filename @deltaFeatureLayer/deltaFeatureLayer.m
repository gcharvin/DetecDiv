classdef deltaFeatureLayer < nnet.layer.Layer
    methods
        function layer = deltaFeatureLayer(name)
            % Construct the deltaFeatureLayer object.
            % A deltaFeatureLayer computes the difference between consecutive frames.
            layer.Name = name;
            layer.Description = 'Layer that computes the difference between consecutive frames (backward and forward).';
        end
        
       function Z = predict(~, X)
    % X : [F x T x B]  (TCB)

    F = size(X,1);
    T = size(X,2);
    B = size(X,3);

    % ----- backward delta: F(t) - F(t-1) -----
    dFm = zeros(F, T, B, 'like', X);
    if T > 1
        dFm(:,2:end,:) = X(:,2:end,:) - X(:,1:end-1,:);
    end

    % ----- forward delta: F(t+1) - F(t) -----
    dFp = zeros(F, T, B, 'like', X);
    if T > 1
        dFp(:,1:end-1,:) = X(:,2:end,:) - X(:,1:end-1,:);
    end

    % ----- concatenate -----
    Z = cat(1, X, dFm, dFp);   % [3F x T x B]
end

    end
end
