% classdef l1LossLayer < nnet.layer.RegressionLayer
%     methods
%         function layer = l1LossLayer(name)
%             layer.Name = name;
%             layer.Description = 'L1 loss';
%         end
% 
%         function loss = forwardLoss(layer, Y, T)
%             % Poids plus élevés pour les régions brillantes
%             weight = 1 + 100 * (T > 0.1); % Par exemple, multiplier les pixels brillants par 10
%             loss = mean(weight .* abs(Y - T), 'all');
%         end
%     end
% end

classdef l1LossLayer < nnet.layer.RegressionLayer
    % L1 loss layer for regression tasks

    methods
        function layer = l1LossLayer(name)
            % Constructor for the layer
            layer.Name = name;
            layer.Description = 'L1 loss';
        end

        function loss = forwardLoss(layer, Y, T)
            % Calculate L1 loss
            % Y: Predicted outputs
            % T: Target outputs
            loss = mean(abs(Y - T), 'all');
        end
    end
end

% Exemple de fonction de perte pondérée