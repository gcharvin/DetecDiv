classdef weightedClassificationLayer < nnet.layer.ClassificationLayer
    properties
        % Vector of weights corresponding to the classes in the training data
        ClassWeights   % [K 1]
       
    end

    methods
        function layer = weightedClassificationLayer(classWeights, name, classes)
            % layer = weightedClassificationLayer(classWeights) creates a
            % weighted cross entropy loss layer. classWeights is a vector
            % of weights corresponding to the classes in the order that
            % they appear in the training data.
            %
            % layer = weightedClassificationLayer(classWeights, name)
            % additionally specifies the layer name.
            %
            % layer = weightedClassificationLayer(classWeights, name, classes)
            % permet de passer la liste des classes (optionnel).

            % Set class weights -> vecteur colonne [K 1]
            layer.ClassWeights = classWeights(:);

            % Set layer name
            if nargin >= 2 && ~isempty(name)
                layer.Name = name;
            end

            % Optional classes
            if nargin == 3
                layer.Classes = classes;
            end

            % Set layer description
            layer.Description = 'Weighted cross entropy';
        end

        % --------------------------------------------------------------
        function loss = forwardLoss(layer, Y, T)
            % loss = forwardLoss(layer, Y, T) returns the weighted cross
            % entropy loss between the predictions Y and the training
            % targets T.

            [Y2, T2, K, B, ~] = localTo2D(Y, T);

            % sécurité num
            epsVal = 1e-7;
            Y2 = max(min(Y2, 1 - epsVal), epsVal);

            % classWeights : [K 1] -> [K B]
            W = layer.ClassWeights(:);      % [K 1]
            if numel(W) ~= K
                error('weightedClassificationLayer:NumWeightsMismatch', ...
                    'Number of classWeights (%d) does not match number of classes (%d).', ...
                    numel(W), K);
            end
            Wmat = repmat(W, 1, B);         % [K B]

            % Loss = moyenne sur le batch de la cross-entropy pondérée
            loss = -sum(Wmat .* T2 .* log(Y2), 'all') / B;
        end

        % --------------------------------------------------------------
        function dLdY = backwardLoss(layer, Y, T)
            % dLdY = backwardLoss(layer, Y, T) returns the derivatives of
            % the weighted cross entropy loss with respect to the
            % predictions Y.

            [Y2, T2, K, B, is4D] = localTo2D(Y, T);

            epsVal = 1e-7;
            Y2 = max(min(Y2, 1 - epsVal), epsVal);

            % classWeights : [K 1] -> [K B]
            W = layer.ClassWeights(:);      % [K 1]
            if numel(W) ~= K
                error('weightedClassificationLayer:NumWeightsMismatch', ...
                    'Number of classWeights (%d) does not match number of classes (%d).', ...
                    numel(W), K);
            end
            Wmat = repmat(W, 1, B);         % [K B]

            % dL/dY = W .* (Y - T) / B   (forme softmax-crossentropy pondérée)
            dLdY2 = (Wmat .* (Y2 - T2)) / B;   % [K B]

            % On remonte au format original
            if is4D
                dLdY = reshape(dLdY2, 1, 1, K, B);   % [1 1 K B]
            else
                dLdY = dLdY2;                         % [K B]
            end
        end
    end
end

% ======================================================================
function [Y2, T2, K, B, is4D] = localTo2D(Y, T)
% Ramène Y, T au format [K B] quelle que soit la représentation fournie.

szY = size(Y);

if numel(szY) == 2
    % Format [K B]
    K = szY(1);
    B = szY(2);
    Y2 = Y;
    T2 = T;
    is4D = false;

elseif numel(szY) == 4
    % Format [1 1 K B]
    K = szY(3);
    B = szY(4);
    Y2 = reshape(Y, K, B);
    T2 = reshape(T, K, B);
    is4D = true;

else
    error('weightedClassificationLayer:UnsupportedDims', ...
        'Unexpected prediction array size: %s', mat2str(szY));
end
end
