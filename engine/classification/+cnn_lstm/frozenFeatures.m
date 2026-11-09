function [X,encoder] = frozenFeatures(c,r,p,frames)
%FROZENFEATURES Inference-mode CNN activations; no CNN fitting or ROI writes.
file=fullfile(c.path,['netCNN_' c.strid '.mat']);assert(isfile(file),'cnn_lstm:Encoder','Install the frozen CNN artifact first.');
encoder=cnn_lstm.encoderIdentity(c,p);
s=load(file,'classifier');net=s.classifier;inputSize=net.Layers(1).InputSize;
pix=[];for name=encoder.channels(:)',pix=[pix r.findChannelID(name{1})];end %#ok<AGROW>
assert(numel(pix)==inputSize(3),'cnn_lstm:EncoderChannels','The selected image bindings must supply the encoder input components in order.');
assert(~isempty(r.image),'cnn_lstm:Images','Load selected ROI image channels before extracting CNN features.');
X=[];batchSize=14;
for start=1:batchSize:numel(frames)
 selected=frames(start:min(start+batchSize-1,numel(frames)));
 video=zeros([inputSize numel(selected)],'single');
 for k=1:numel(selected)
  image=r.preProcessROIData(pix,selected(k),1);
  video(:,:,:,k)=single(im2uint8(imresize(image,inputSize(1:2))));
 end
 if isa(net,'dlnetwork')
  input=dlarray(video,'SSCB');if strcmp(p.executionEnvironment,'gpu'),input=gpuArray(input);end
  values=predict(net,input,'Outputs',p.encoderLayer);values=gather(extractdata(values));
 else
  values=activations(net,video,p.encoderLayer,'OutputAs','columns','ExecutionEnvironment',p.executionEnvironment);
 end
 values=reshape(values,[],numel(selected));
 if isempty(X),X=zeros(size(values,1),numel(frames),'single');end
 X(:,start:start+numel(selected)-1)=values;
end
assert(all(isfinite(X),'all'),'cnn_lstm:EncoderValues','CNN activations must be finite.');
end
