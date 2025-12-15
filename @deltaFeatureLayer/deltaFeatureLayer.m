classdef deltaFeatureLayer < nnet.layer.Layer
    methods
        function layer = deltaFeatureLayer(name)
            % Construct the deltaFeatureLayer object.
            % A deltaFeatureLayer computes the difference between consecutive frames.
            layer.Name = name;
            layer.Description = 'Layer that computes the difference between consecutive frames (backward and forward).';
        end
        
        function Z = predict(layer, X)
            % X is expected to be [F x T], where F is the number of features, T the number of time steps (frames)
            [F, T] = size(X);
            
            % Compute the backward and forward differences
            dFm = [zeros(F, 1, 'like', X), diff(X, 1, 2)];  % backward difference: F(t) - F(t-1)
            dFp = [diff(X, 1, 2), zeros(F, 1, 'like', X)];  % forward difference: F(t+1) - F(t)
            
            % Concatenate the original features with the differences
            Z = [X; dFm; dFp];  % New output: [3F x T]
        end
    end
end
