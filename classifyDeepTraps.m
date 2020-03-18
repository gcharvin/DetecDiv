function classifyDeepTraps(I,mov,net)
% I must be an RGB 8 bits image

if nargin ==2 % load exisiting cnn net
    load([mov.path '/netDeepTraps.mat']); 
    net=netDeepTraps;
end

% Read a test image.
%I = imread(testData.imageFilename{end});

% Run the detector.
tic;
[bboxes,scores] = detect(net,I,'MaxSize',[120 120]);%,'MinSize',[100 100]);
toc;

% Annotate detections in the image.
I = insertObjectAnnotation(I,'rectangle',bboxes,scores);
imshow(I)



