function [dataOut,info] = classificationAugmentationPipeline(dataIn,info,trainingParam)

dataOut = cell([size(dataIn,1),2]);

for idx = 1:size(dataIn,1)
  %  size(dataIn)
 %   class(dataIn)
    temp = dataIn{idx,1}{1};
 %   aa=class(temp)
%    size(temp)
    
    % Add randomized Gaussian blur
  %  temp = imgaussfilt(temp,1.5*rand);
    
    % Add salt and pepper noise
%    figure, imshow(temp,[]);
  %  temp = imnoise(temp,'salt & pepper');
 
%  max(temp(:))
%  min(temp(:))
  
    temp = imnoise(temp,'gaussian');
 %   figure, imshow(temp,[]);
  %  kl=klmkmklk
    
    % Add randomized rotation and scale
   % tform = randomAffine2d('Scale',[0.95,1.05],'Rotation',[-30 30]);
  %  outputView = affineOutputView(size(temp),tform);
   % temp = imwarp(temp,tform,'OutputView',outputView);
    
    % Form second column expected by trainNetwork which is the expected response,
    % the categorical label in this case
    dataOut(idx,:) = {temp,info.Label(idx)};
end

end

