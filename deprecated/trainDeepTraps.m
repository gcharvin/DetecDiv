function trainDeepTraps(mov)

% train deep object detector using traps identified using identifyTraps
% technique

% use correlation method to identify traps in x images

ntraining=10; % number of images used for training

list=dir([mov.pathname{mov.PhaseChannel} '/*.jpg']);
list=[list dir([mov.pathname{mov.PhaseChannel} '/*.tif'])];

% convert image to RGB
mkdir([mov.pathname{mov.PhaseChannel}],'tempRGB8bits');
for j=1:numel(list)
    fprintf(['Normalizing frame ' num2str(j) '...\n']) 
   img=mov.readImage(j,mov.PhaseChannel);
   img = formatImage(img);
   %figure, imshow(img, []);
  % return
 % [mov.pathname{mov.PhaseChannel} '/tempRGB8bits/' list(j).name]
  
   imwrite(img,[mov.pathname{mov.PhaseChannel} '/tempRGB8bits/' list(j).name]);
end

for j=1:ntraining
   fprintf(['Processing frame ' num2str(j) '...\n']) 
img1=mov.readImage(j,mov.PhaseChannel);
positions=findTraps(img1,mov.pattern);
%positions=findTraps(img1,mov.pattern);

scale=1;

scaled=round(scale*positions);

% make all positions uniform
x=round(mean(scaled(:,2)-scaled(:,1)));
y=round(mean(scaled(:,4)-scaled(:,3)));
scaled(:,2)=scaled(:,1); %-x/2;
scaled(:,4)=scaled(:,3)+y;

for i=1:size(scaled,1)
   if  scaled(i,4)>size(img1,2)/2
       scaled(i,4)=scaled(i,4)-1;
       scaled(i,3)=scaled(i,3)-1;
   end
   if  scaled(i,2)>size(img1,1)/2
       scaled(i,1)=scaled(i,1)-1;
       scaled(i,2)=scaled(i,2)-1;
   end
   
   scaled(i,1)=scaled(i,3);
   scaled(i,3)=x;
   scaled(i,4)=y;
   % fix the ROI !!!!!
end

%aa=list(j)
%bb=mov.pathname{mov.PhaseChannel}
imlist{j}=[mov.pathname{mov.PhaseChannel} '/tempRGB8bits/' list(j).name];
roi{j}=scaled;

end


trapsDataset=table(imlist',roi','VariableNames',{'imlist','roi'})

trapsDataset.imlist = fullfile(pwd,trapsDataset.imlist);

% display sample images
% % Read one of the images.
% I = imread(trapsDataset.imlist{10});
% % Insert the ROI labels.
% I = insertShape(I,'Rectangle',trapsDataset.roi{10});
% % Resize and display image.
% I = imresize(I,3);
% imshow(I)

% Set random seed to ensure example training reproducibility.
rng(0);

% Randomly split data into a training and test set.
shuffledIndices = randperm(height(trapsDataset));
idx = floor(0.6 * length(shuffledIndices) );
trainingData = trapsDataset(shuffledIndices(1:idx),:);
testData = trapsDataset(shuffledIndices(idx+1:end),:);

% Define the image input size.
imageSize = [ size(img1) 3] %[224 224 3];

% Define the number of object classes to detect.
numClasses = width(trapsDataset)-1; % in this case, there is only class

anchorBoxes = [x y
]

baseNetwork = resnet50;
featureLayer = 'activation_40_relu';
lgraph = yolov2Layers(imageSize,numClasses,anchorBoxes,baseNetwork,featureLayer);
%analyzeNetwork(lgraph)

    options = trainingOptions('sgdm', ...
        'MiniBatchSize', 4, ....
        'InitialLearnRate',1e-3, ...
        'MaxEpochs',10,...
        'CheckpointPath', tempdir, ...
        'Shuffle','every-epoch'); 
    
%  options = trainingOptions('sgdm', ...
%         'MiniBatchSize', 4, ....
%         'InitialLearnRate',1e-3, ...
%         'MaxEpochs',10,...
%         'CheckpointPath', tempdir, ...
%          'VerboseFrequency',2,...
%     'Plots','training-progress',...
%     'ValidationFrequency', 5,...
%     'ValidationPatience', 4, ...
%         'Shuffle','every-epoch'); 
    
%     'LearnRateSchedule','piecewise',...
%     'LearnRateDropPeriod',10,...
%     'LearnRateDropFactor',0.7,...
%     'Momentum',0.9, ...
%     'InitialLearnRate',1e-2, ...
%     'L2Regularization',0.005, ...
%     'ValidationData',pximdsVal,...
%     'MaxEpochs',30, ...  
%     'MiniBatchSize',8, ...
%     'Shuffle','every-epoch', ...
%     'CheckpointPath', tempdir, ...
%     'VerboseFrequency',2,...
%     'Plots','training-progress',...
%     'ValidationFrequency', 10,...
%     'ValidationPatience', 4); ...
    
    
   [netDeepTraps,info] = trainYOLOv2ObjectDetector(trapsDataset,lgraph,options);
   
fprintf('Training is done...\n');
save([mov.path '/netDeepTraps.mat'],'netDeepTraps');








function positions=findTraps(img,pattern)

% position provides the list of boundaries for the traps
%img = rgb2gray(img);

c = normxcorr2(pattern,img);

%figure, imshow(img)
%figure, surf(c), shading flat

thr=0.7; % threshold for detected peaks

BW = im2bw(c,thr);

pp = regionprops(BW,'centroid');
pos = round(cat(1, pp.Centroid));
%positions=fliplr(positions);

positions=zeros(1,4);

%positions.minex=[];
%positions.maxex=[];
%positions.miney=[];
%positions.maxey=[];

cc=1;
%figure;

%size(img)
for ex=1:size(pos,1)
    
    minex=pos(ex,2)-size(pattern,2);
    maxex=pos(ex,2);
    miney=pos(ex,1)-size(pattern,1);
    maxey=pos(ex,1);
    
    if minex<1
        continue
    end
    if miney<1
        continue
    end
    if maxex>size(img,2)
        continue
    end
    if maxey>size(img,1)
        continue
    end
    
    positions(cc,1)=minex;
    positions(cc,3)=miney;
    positions(cc,2)=maxex;
    positions(cc,4)=maxey;
    
    %imgout=img(minex:maxex,miney:maxey);
    %imshow(imgout,[]);
    %title(num2str(ex));
    %pause(0.1);
    %close
    
    
    cc=cc+1;
end

function im=formatImage(gfp)

    totphc=gfp;
    meanphc=0.5*double(mean(totphc(:)));
    maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    
    %im=zeros(size(gfp,1),size(gfp,2),3);
    
    a = double(imadjust(gfp,[meanphc/65535 maxphc/65535],[0 1]))/256;
    
    im=repmat(a,[1 1 3]);
    %b = a; %double(imadjust(b,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    %c = a; %double(imadjust(c,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    
    
    
    %im(:,:,1)=a;im(:,:,2)=b;im(:,:,3)=c;
    im=uint8(im);

    
