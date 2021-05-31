classdef tverskyPixelClassificationLayer < nnet.layer.ClassificationLayer
    % This layer implements the Tversky loss function for training
    % semantic segmentation networks.
    
    % References
    % Salehi, Seyed Sadegh Mohseni, Deniz Erdogmus, and Ali Gholipour.
    % "Tversky loss function for image segmentation using 3D fully
    % convolutional deep networks." International Workshop on Machine
    % Learning in Medical Imaging. Springer, Cham, 2017.
    % ----------
    
    
    properties(Constant)
        % Small constant to prevent division by zero.
        Epsilon = 1e-8;
    end
    
    properties
        % Default weighting coefficients for False Positives and False
        % Negatives
        Alpha = 0.5;
        Beta = 0.5;
    end

    
    methods
        
        function layer = tverskyPixelClassificationLayer(name, alpha, beta)
            % layer =  tverskyPixelClassificationLayer(name, alpha, beta) creates a Tversky
            % pixel classification layer with the specified name and properties alpha and beta.
            
            % Set layer name.          
            layer.Name = name;
            
            layer.Alpha = alpha;
            layer.Beta = beta;
            
            % Set layer description.
            layer.Description = 'Tversky loss';
        end
        
        
        function loss = forwardLoss(layer, Y, T)
            % loss = forwardLoss(layer, Y, T) returns the Tversky loss between
            % the predictions Y and the training targets T.   

            Pcnot = 1-Y;
            Gcnot = 1-T;
            TP = sum(sum(Y.*T,1),2);
            FP = sum(sum(Y.*Gcnot,1),2);
            FN = sum(sum(Pcnot.*T,1),2); 
            
            numer = TP + layer.Epsilon;
            denom = TP + layer.Alpha*FP + layer.Beta*FN + layer.Epsilon;
            
            % Compute tversky index
            lossTIc = 1 - numer./denom;
            lossTI = sum(lossTIc,3);
            
            % Return average tversky index loss.
            N = size(Y,4);
            loss = sum(lossTI)/N;
            
        end     
    end
end
