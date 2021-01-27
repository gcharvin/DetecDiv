classdef weightedLSTMClassificationLayer < nnet.layer.ClassificationLayer
   properties
        % Vector of weights corresponding to the classes in the training
        % data
        ClassWeights
    end
    
    
    methods
        function layer = weightedLSTMClassificationLayer(classWeights, name)
            % layer = weightedClassificationLayer(classWeights) creates a
            % weighted cross entropy loss layer. classWeights is a row
            % vector of weights corresponding to the classes in the order
            % that they appear in the training data.
            % 
            % layer = weightedClassificationLayer(classWeights, name)
            % additionally specifies the layer name. 

            % Set class weights
            layer.ClassWeights = classWeights;

            % Set layer name
            if nargin == 2
                layer.Name = name;
            end

            % Set layer description
            layer.Description = 'Weighted cross entropy';
        end
        
        function loss = forwardLoss(layer, Y, T)
            % this has been adjusted to work with sequence to sequence
            % problems
            %https://fr.mathworks.com/matlabcentral/answers/434918-weighted-classification-layer-for-time-series-lstm
            
            % loss = forwardLoss(layer, Y, T) returns the weighted cross
    % entropy loss between the predictions Y and the training
    % targets T.
    % Find observation and sequence dimensions of Y
% %     [~, N, S] = size(Y);
% %     
% %     % Reshape ClassWeights to KxNxS
% %     W = repmat(layer.ClassWeights(:), 1, N, S);
% %     
% %     % Compute the loss
% %     loss = -sum( W(:).*T(:).*log(Y(:)) )/N;
    
            N = size(Y,4);
            Y = squeeze(Y);
            T = squeeze(T);
            W = layer.ClassWeights;
    
            loss = -sum(W*(T.*log(Y)))/N;
            
        end
        
        function dLdY = backwardLoss(layer, Y, T)  
              % this has been adjusted to work with sequence to sequence
            % problems
            %https://fr.mathworks.com/matlabcentral/answers/434918-weighted-classification-layer-for-time-series-lstm
            
    % dLdY = backwardLoss(layer, Y, T) returns the derivatives of
    % the weighted cross entropy loss with respect to the
    % predictions Y.
    % Find observation and sequence dimensions of Y
    [~, N, S] = size(Y);
    
    % Reshape ClassWeights to KxNxS
    W = repmat(layer.ClassWeights(:), 1, N, S);
    
    % Compute the derivative
    dLdY = -(W.*T./Y)/N;
        end

     end 
    
    
end