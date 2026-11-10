classdef WindowEndpointLoss < nnet.layer.ClassificationLayer
    % Native trainNetwork output loss, supervised only at complete endpoints.
    properties
        WindowLength
        ClassWeights
    end
    methods
        function layer=WindowEndpointLoss(windowLength,classes,weights)
            layer.Name='classes';layer.Description='Weighted cross entropy at window endpoints';
            layer.WindowLength=windowLength;layer.Classes=categorical(classes,classes,classes);
            layer.ClassWeights=weights;
        end
        function loss=forwardLoss(layer,Y,T)
            assert(mod(size(Y,3),layer.WindowLength)==0,'lstm_timeseries:TrajectoryLength','Trajectory must contain complete target windows.');
            steps=layer.WindowLength:layer.WindowLength:size(Y,3);
            targets=T(:,:,steps);scores=Y(:,:,steps);
            weights=reshape(cast(layer.ClassWeights,'like',Y),[],1,1);
            count=max(sum(targets,'all'),1); % zero-padded targets do not count
            loss=-sum(weights.*targets.*log(scores+eps('single')),'all')/count;
        end
        function gradient=backwardLoss(layer,Y,T)
            steps=layer.WindowLength:layer.WindowLength:size(Y,3);
            targets=T(:,:,steps);scores=Y(:,:,steps);
            weights=reshape(cast(layer.ClassWeights,'like',Y),[],1,1);
            count=max(sum(targets,'all'),1);
            gradient=zeros(size(Y),'like',Y);
            gradient(:,:,steps)=-weights.*targets./(scores+eps('single'))/count;
        end
    end
end
