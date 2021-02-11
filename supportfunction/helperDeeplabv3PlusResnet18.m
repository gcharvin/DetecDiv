function lgraph = helperDeeplabv3PlusResnet18(imageSize, numClasses,nettype)
% lgraph = helperDeeplabv3PlusResnet18(imageSize, numClasses) creates a
% DeepLab v3+ layer graph object using a pre-trained ResNet-18 configured
% using the following inputs:
%
%   Inputs
%   ------
%   imageSize    - size of the network input image specified as a vector
%                  [H W] or [H W C], where H and W are the image height and
%                  width, and C is the number of image channels.
%
%   numClasses   - number of classes the network should be configured to
%                  classify.
%
% The output lgraph is a LayerGraph object.
%
% The steps used in this function can be used to create a DeepLab v3+
% network based on other pretrained network such as ResNet-50 or MobileNet
% v2.
%
% References
% ----------
% [1] Chen, Liang-Chieh et al. â€œEncoder-Decoder with Atrous Separable
% Convolution for Semantic Image Segmentation.â€? ECCV (2018).

% Copyright 2018 The MathWorks, Inc.

% Load pretrained network to use as the base network for DeepLab v3+.
%lgraph = loadPretrainedResNet18();
% Load ResNet-18 and return as LayerGraph.
%net50=nettype;

%if net50==1
net=nettype;
%else
%net = resnet18;
%end

lgraph = layerGraph(net);

if strcmp(nettype,'resnet50')
    test=lgraph.Layers(5);
    test.PaddingSize=[1 1 1 1];
    lgraph=replaceLayer(lgraph,'max_pooling2d_1',test);
end

% Select a feature extraction layer from ResNet-18. For DeepLab v3+, the
% feature extraction layer is typically towards the end of the network,
% right before the classification layers.
%featureExtractionLayer = 'res5b_relu';

if  strcmp(nettype,'resnet50')
featureExtractionLayer = 'activation_49_relu';
else
featureExtractionLayer = 'res5b_relu';    
end

% Remove all layers after the feature extraction layer.
%lgraph = removeLayersAfterFeatureExtractionLayer(lgraph);
% Remove layers after the feature extraction layer, res5b_relu, from
% ResNet-18.
%
% This list can be obtained by inspecting the lgraph using analyzeNetwork
% from Deep Learning Toolbox. 

%Remove all layers after the feature extraction layer in ResNet-18.

if  strcmp(nettype,'resnet50')
layerToRemove = ["avg_pool","fc1000","fc1000_softmax","ClassificationLayer_fc1000"];
else
layerToRemove = ["pool5","fc1000","prob","ClassificationLayer_predictions"]; 
end

lgraph = removeLayers(lgraph,layerToRemove);

% Update the network image input size.
%lgraph = updateImageInputLayerSize(lgraph,imageSize);
% Change image input layer to support desired input image size. Set the
% 'Normalization' to 'none' to match the value used in ResNet-18.

if  strcmp(nettype,'resnet50')
imageInputLayerName = 'input_1';
else
imageInputLayerName = 'data';
end

newLayer = imageInputLayer(imageSize,'Name',imageInputLayerName,'Normalization','none');

if  strcmp(nettype,'resnet50')
 lgraph = replaceLayer(lgraph,"input_1",newLayer);
else
 lgraph = replaceLayer(lgraph,"data",newLayer);   
end

% Reduce the network downsampling to 8 or 16 in order to preserve spatial
% resolution required for accurate segmentation. 
%lgraph = reduceNetworkDownSampling(lgraph);
% Reduce the downsampling in ResNet-18 from 32 to 16 by changing the last
% convolution layers 'Stride' value to 1 along all branches. Reducing the
% amount of downsampling preserves image features at a higher resolution
% and avoids loss of detail incurred during downsampling.
%
% Notes
% -----
% - In DeepLab v3+, the downsampling factor is typically reduced to either
%   16 or 8.
% - The same process can be applied to other types of downsampling layers
%   such as max pooling layers and average pooling layers.

% Reduce 'Stride' of convolution layers: res5a_branch1 and res5a_branch2.
lgraph = reduceConvStrideToOne(lgraph,"res5a_branch1");
lgraph = reduceConvStrideToOne(lgraph,"res5a_branch2a");

% Increase the convolution layer dilation factors to increase the receptive
% field size required to extract features from larger image regions. This
% helps offset the reduction in network downsampling. 
%lgraph = increaseConvolutionDilationFactors(lgraph);
% Use dilated convolutions to recover large receptive fields lost by
% removing downsampling layers.
layersToDilate = ["res5a_branch2b","res5b_branch2a","res5b_branch2b"];
lgraph = dilateConvolutionalLayers(lgraph,layersToDilate);

% Add the artrous spatial pyramid pooling module (ASPP). 
lgraph = addASPPLayers(lgraph,featureExtractionLayer);

% Select the layer to use for adding a skip connection. For DeepLab v3+,
% the skip layer is typically a layer whose output size that is a factor of
% 4 smaller than the input size.

if  strcmp(nettype,'resnet50')
  skipLayer = 'activation_7_relu'; 
else
  skipLayer = 'res2b_relu';  
end
%

% Add the decoder sub-network.
lgraph = addDecoderToNetwork(lgraph,numClasses,skipLayer,net50);

% Add the pixel classification layers.

segmentationLayers = [
    softmaxLayer('Name','softmax-out' );
    pixelClassificationLayer('Name',"classification")
    ];

lgraph = addLayers(lgraph,segmentationLayers);
lgraph = connectLayers(lgraph,"dec_crop2",'softmax-out');


%--------------------------------------------------------------------------
function lgraph = addASPPLayers(lgraph, featureExtractionLayer)
% Add an ASPP module to the lgraph. An ASPP module transforms the input
% feature maps using convolutions along multiple branches. The ASPP is
% designed such that the receptive fields are different across each branch.
% This captures both fine grained and coarse grained information about the
% image.

% Each branch uses a filter with a unique dilation factor and filter size.
% The dilation factors and filter sizes for a downsampling factor of 16
% define as follows:
asppDilationFactors = [1, 6 ,12 ,18];
asppFilterSizes = [1, 3, 3, 3];

% The ASPP dilation and filter sizes are selected based on the values
% reported in [1]. Choosing the optimal values requires empirical
% evaluation.

% Create concatenation layer and connect it to the tail
tempLayer = depthConcatenationLayer(4,'Name',"catAspp");
lgraph = addLayers(lgraph,tempLayer);

% Create all convolution aspp branches
for i = 1:numel(asppDilationFactors)
    branchFilterSize = asppFilterSizes(i);
    branchDilationFactor = asppDilationFactors(i);
    asppConvName = "aspp_Conv_" + i;
    asppBNName = "aspp_BatchNorm_" + i;
    asppReluName = "aspp_Relu_" + i;
    
    layersToAdd = [
        convolution2dLayer(branchFilterSize, 256,...
        'DilationFactor',branchDilationFactor, 'Padding',...
        'same','Name', asppConvName,...
        'WeightsInitializer', 'glorot', ...
        'BiasInitializer', 'zeros', ...
        'BiasLearnRateFactor', 0);
        batchNormalizationLayer('Name',asppBNName);
        reluLayer('Name',asppReluName);
        ];
    
    lgraph = addLayers(lgraph, layersToAdd);
    lgraph = connectLayers(lgraph,featureExtractionLayer,asppConvName);
    lgraph = connectLayers(lgraph,asppReluName,strcat("catAspp","/in",string(i)));
end


%--------------------------------------------------------------------------
function lgraph = addDecoderToNetwork(lgraph,numClasses, lowLevelFeatureExtractor,net50)
% Add the decoder sub-network for DeepLab v3+. The decoder sub-network
% restores the feature maps to their original resolution by upsampling them
% by a factor of 16. Skip connections from low-level layers are used to
% recover details mid-way through the decoding process.
%
% Upsampling is done using transposed convolutions initialized with
% bilinear upsampling weights. The upsampling layer weights are fixed
% during training.

% Preprocess ASPP output before decoding.
tempLayerArray = [
    convolution2dLayer(1,256,'Name','dec_c1',...
    'WeightsInitializer','glorot',...
    'WeightLearnRateFactor',10,...
    'BiasInitializer','zeros',...
    'BiasLearnRateFactor',0)
    
    batchNormalizationLayer('Name','dec_bn1')
    
    reluLayer('Name','dec_relu1')
    
    bilinearUpsampling4xLayer(4, 256,'dec_upsample1')
    
    crop2dLayer('centercrop','Name','dec_crop1')
    ];
lgraph = addLayers(lgraph,tempLayerArray);

% Preprocess LowLevelFeatureLayer output before decoding.
tempLayerArray = [
    convolution2dLayer(1,48,'Name','dec_c2',...
    'WeightsInitializer','glorot',...
    'WeightLearnRateFactor',10,...
    'BiasInitializer','zeros',...
    'BiasLearnRateFactor',0)
    batchNormalizationLayer('Name','dec_bn2')
    reluLayer('Name','dec_relu2')
    ];
lgraph = addLayers(lgraph,tempLayerArray);

% Concatenate and final steps.
tempLayerArray = [
    depthConcatenationLayer(2,'Name',"dec_cat1")
    
    convolution2dLayer(3,256,'Name','dec_c3','Padding','same',...
    'WeightsInitializer','glorot',...
    'WeightLearnRateFactor',10,...
    'BiasInitializer','zeros',...
    'BiasLearnRateFactor',0)
    
    batchNormalizationLayer('Name','dec_bn3');
    
    reluLayer('Name','dec_relu3')
    
    convolution2dLayer(3,256,'Name','dec_c4','Padding','same',...
    'WeightsInitializer','glorot',...
    'WeightLearnRateFactor',10,...
    'BiasInitializer','zeros',...
    'BiasLearnRateFactor',0)
    
    batchNormalizationLayer('Name','dec_bn4');
    
    reluLayer('Name','dec_relu4')
    
    convolution2dLayer(1,numClasses,'Name','scorer',...
    'WeightsInitializer','glorot',...
    'WeightLearnRateFactor',10,...
    'BiasInitializer','zeros',...
    'BiasLearnRateFactor',0)
    
    bilinearUpsampling4xLayer(4.0, numClasses,"dec_upsample2")
    
    crop2dLayer('centercrop','Name','dec_crop2')
    ];

lgraph = addLayers(lgraph,tempLayerArray);
lgraph = connectLayers(lgraph,"catAspp",'dec_c1');
lgraph = connectLayers(lgraph,'dec_relu2','dec_cat1/in1');
lgraph = connectLayers(lgraph,'dec_crop1','dec_cat1/in2');
lgraph = connectLayers(lgraph,lowLevelFeatureExtractor,'dec_c2');
lgraph = connectLayers(lgraph,'dec_relu2','dec_crop1/ref');

if net50==1
lgraph = connectLayers(lgraph,'input_1','dec_crop2/ref');
else
 lgraph = connectLayers(lgraph,'data','dec_crop2/ref');  
end


%--------------------------------------------------------------------------
function lgraph = reduceConvStrideToOne(lgraph,layerName)
% Finds the layer corresponding to the layerName in lgraph.Layers
idx = arrayfun(@(x) strcmp(x.Name,layerName),lgraph.Layers);
oldL = lgraph.Layers(idx);

%Reduces stride = 2 to stride = 1.
if oldL.FilterSize ==1
    newLayer = convolution2dLayer(oldL.FilterSize,oldL.NumFilters,...
        'Stride',1,...
        'DilationFactor',oldL.DilationFactor,...
        'Name',oldL.Name,...
        'Padding',0,...
        'WeightLearnRateFactor',oldL.WeightLearnRateFactor,...
        'BiasLearnRateFactor',oldL.BiasLearnRateFactor);
    newLayer.Weights = oldL.Weights;
    newLayer.Bias = oldL.Bias;
    
elseif oldL.FilterSize > 1
    newLayer = convolution2dLayer(oldL.FilterSize,oldL.NumFilters,...
        'Stride',1,...
        'DilationFactor',oldL.DilationFactor,...
        'Name',oldL.Name,...
        'Padding','same',...
        'WeightLearnRateFactor',oldL.WeightLearnRateFactor,...
        'BiasLearnRateFactor',oldL.BiasLearnRateFactor);
    newLayer.Weights = oldL.Weights;
    newLayer.Bias = oldL.Bias;
    
end
newLayer.Weights = oldL.Weights;
newLayer.Bias = oldL.Bias;

lgraph = replaceLayer(lgraph,oldL.Name,newLayer);

%--------------------------------------------------------------------------
function lgraph = dilateConvolutionalLayers(lgraph,layersToDilate)
% the dilation factor is set to 2 to correspond with the reduction in
% stride from 2 to 1.
for oldLayerName = layersToDilate
    % finds the layer corresponding to the layerName in lgraph.Layers
    idx = arrayfun(@(x) strcmp(x.Name,oldLayerName),lgraph.Layers);
    oldL = lgraph.Layers(idx);
    
    newLayer = useSamePadding(oldL);
    newLayer.Stride = 1;
    newLayer.DilationFactor = newLayer.DilationFactor*2;
    newLayer.Weights = oldL.Weights;
    newLayer.Bias = oldL.Bias;
    lgraph = replaceLayer(lgraph,oldLayerName,newLayer);
end

%--------------------------------------------------------------------------
function upsamplingLayer = bilinearUpsampling4xLayer(scaleFactor, numFilters, name)
% Configure a transposed convolution layer for bilinear up-sampling.
% Weights are frozen to bilinear interpolation weights.
numChannels = numFilters;
if isscalar(scaleFactor)
    scaleFactor = [scaleFactor , scaleFactor];
end

factor = scaleFactor;
filterSize = 2*factor - mod(factor,2);
cropping = (factor-mod(factor,2))/2;

upsamplingLayer = transposedConv2dLayer(filterSize,numFilters, ...
    'NumChannels',numChannels,'Stride',factor,'Cropping',cropping,'Name',name);

% Initialize weights using bilinear interpolation coefficients.
center = filterSize/2 + 0.5;
distX = abs(center(2) - (1:filterSize(2)));
distY = abs(center(1) - (1:filterSize(1)));

wX = distX/(filterSize(2)/2);
wX = 1 - wX;

wY = distY/(filterSize(1)/2);
wY = 1 - wY;

bilinearWeights = wY' * wX;
upsamplingLayer.Weights = zeros([size(bilinearWeights,1),size(bilinearWeights,1),numFilters,numFilters]);

for i=1:numFilters
    upsamplingLayer.Weights(:,:,i,i) = bilinearWeights;
end

% upsample.Weights = repmat(bilinearWeights,1,1,numFilters,numChannels);
upsamplingLayer.Bias = zeros(1,1,numFilters);

% Freeze weights.
upsamplingLayer.WeightLearnRateFactor = 0;
upsamplingLayer.BiasLearnRateFactor = 0;

%--------------------------------------------------------------------------
function newLayer = useSamePadding(oldL)
newLayer = convolution2dLayer(oldL.FilterSize,oldL.NumFilters,...
    'Stride',oldL.Stride,...
    'DilationFactor',oldL.DilationFactor,...
    'Name',oldL.Name,...
    'Padding','same',...
    'WeightLearnRateFactor',oldL.WeightLearnRateFactor,...
    'BiasLearnRateFactor',oldL.BiasLearnRateFactor);
