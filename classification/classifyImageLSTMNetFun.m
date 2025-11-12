function [data,image]=classifyImageLSTMNetFun(roiobj,classif,classifier,varargin)

Crop       = false;      
CropCenter = [88 194];  
CropSize   = [60 60];   
channel=classif.channelName;
frames=[];
classifierCNN=[];
gpu=0;

for i=1:numel(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        key = lower(string(varargin{i}));
        switch key
            case "classifiercnn"
                classifierCNN = varargin{i+1};
                net = classifierCNN;
                inputSizeCNN = net.Layers(1).InputSize;
                classNamesCNN = net.Layers(end).ClassNames;
                numClassesCNN = numel(classNamesCNN);
            case "frames"
                frames = varargin{i+1};
            case "channel"
                channel = varargin{i+1};
            case "exec"
                gpu = varargin{i+1};
            case "crop"
                Crop = logical(varargin{i+1});
            case "cropcenter"
                CropCenter = varargin{i+1};
            case "cropsize"
                CropSize = varargin{i+1};
        end
    end
end

fprintf('Load videos...\n');

data=[];
image=[];

for i=1:numel(classifier.Layers)
    if strcmp(class(classifier.Layers(i)), 'nnet.cnn.layer.SequenceInputLayer')
        inputSize = classifier.Layers(i).InputSize(1:2);
        break
    end
end

if numel(roiobj.image)==0
    roiobj.load;
end

if numel(roiobj.image)==0
    disp('Could not find ROI ; Quitting...');
    return;
end

pix=roiobj.findChannelID(channel);
if iscell(pix), pix=cell2mat(pix); end
if numel(frames)==0, frames=1:size(roiobj.image,4); end

im=roiobj.image(:,:,pix,frames);

disp('Formatting video before classification....');
si=size(im);
vid=uint8(zeros(si(1),si(2),3,numel(frames)));
cc=1;
param=[]; 

for j=frames  
    tmp=roiobj.preProcessROIData(pix,j,param);
    if numel(tmp)==0
         vid(:,:,:,cc)=uint8(0);
    else
         vid(:,:,:,cc)=uint8(255*tmp);
    end
    cc=cc+1;
end

if Crop
    vid = cropAroundCenter4D(vid, CropCenter, CropSize);
end

video = centerCrop(vid,inputSize);

disp('Starting video classification...');

try
    if gpu==1
        [x, prob]=classify(classifier,video,'ExecutionEnvironment',"gpu");
        if numel(classifierCNN)
             [labelCNN,probCNN] = classify(classifierCNN,video,'ExecutionEnvironment',"gpu");
        end
    else
        [x, prob]=classify(classifier,video,'ExecutionEnvironment',"cpu");
        if numel(classifierCNN)
             [labelCNN,probCNN] = classify(classifierCNN,video,'ExecutionEnvironment',"cpu");
        end
    end
catch
    disp('Error with predict function  : GPU memory issue, trying CPU...');
    [x, prob]=predict(classifier,video,'ExecutionEnvironment','cpu');
    if numel(classifierCNN)
         [labelCNN,probCNN] = classify(classifierCNN,video,'ExecutionEnvironment','cpu');
    end
end

% ===================================================================
% --- NEW SECTION: Load bestThreshold if available ---
try
    lstmFile = fullfile(classif.path, ['netLSTM_' classif.strid '.mat']);
    if exist(lstmFile, 'file')
        S = load(lstmFile, 'bestThreshold');
        if isfield(S, 'bestThreshold')
            bestThreshold = S.bestThreshold;
            fprintf('Loaded bestThreshold = %.3f from %s\n', bestThreshold, lstmFile);
        else
            bestThreshold = 0.5;
            fprintf('No bestThreshold found in %s (using 0.5)\n', lstmFile);
        end
    else
        bestThreshold = 0.5;
        fprintf('LSTM file not found for threshold; using default 0.5\n');
    end
catch ME
    warning('Unable to load bestThreshold: %s', ME.message);
    bestThreshold = 0.5;
end
% ===================================================================

labels = classifier.Layers(end).Classes;
if size(prob,1) == numel(labels), prob = prob'; end

% --- NEW: apply bestThreshold instead of max ---
% suppose binary classifier (2 classes)
if numel(labels)==2
    posName = labels(2);
    posScore = prob(:,2);
    decision = posScore >= bestThreshold;
    label = categorical(decision, [false true], {char(labels(1)), char(labels(2))});
    fprintf('Thresholded classification applied (%.2f)\n', bestThreshold);
else
    % fallback multi-class = argmax
    [~, idx] = max(prob,[],2);
    label = labels(idx);
end
% ===================================================================

if numel(classifierCNN)
    labelCNN_all = classifierCNN.Layers(end).Classes;
    [tf, idxperm] = ismember(labels, labelCNN_all);
    missing = labels(~tf);
    if ~isempty(missing)
        warning('Classes absentes dans le CNN :');
        disp(missing);
    end
    valid = idxperm > 0;
    reducedLabels = labels(valid);
    reducedIdx = idxperm(valid);
    labelCNN_reordered = labelCNN_all(reducedIdx);
    probCNN_reordered = probCNN(:, reducedIdx);
    if size(probCNN_reordered, 1) == numel(labelCNN_reordered)
        probCNN_reordered = probCNN_reordered';
    end
    [~, idxCNN] = max(probCNN_reordered,[],2);
    labelCNN = labelCNN_reordered(idxCNN);
end

% --- suite de ton code d'enregistrement des résultats inchangée ---
data=roiobj.data;
if numel(data)==0
    roiobj.data=dataseries;
    data=roiobj.data;
end

pixdata=find(arrayfun(@(x) strcmp(x.groupid,classif.strid),roiobj.data));
if numel(pixdata)
    cc=pixdata;
else
    n=numel(roiobj.data);
    if n==1 && numel(roiobj.data.data)==0, cc=1; else, cc=numel(roiobj.data)+1; end
    data(cc)=dataseries;
    data(cc).class="classification";
    data(cc).groupid=classif.strid;
    data(cc).parentid=roiobj.id; 
end

data(cc).plotGroup={[] [] [] [] [] {'id' 'prob' 'labels'}}; 
data(cc).groupProperties={'id' 'Plot' 'auto' 'auto'; 'label' 'Plot' 'auto' 'auto'; 'prob' 'Plot' 'auto', 'auto'};
datatmp=data(cc);

if classif.output==0
    n=size(roiobj.image,4);
else
    n=1;
end

datatmp.addData(zeros(n,1),'id');
for i=1:numel(classif.classes)
    datatmp.addData(zeros(n,1),['prob_' classif.classes{i}]);
end
tmp=categorical(zeros(n,1),0,{'undefined'});
datatmp.addData(tmp,'labels');

datatmp.data.labels(frames)=label;
datatmp.userData.classes=classif.classes;

for i=1:numel(classif.classes)
    if size(prob,2)>=i
        datatmp.data.(['prob_' classif.classes{i}])(frames)=prob(frames,i);
    end
end


datatmp.data.id(frames)=double(label==labels(end)); % index binaire

data(cc)=datatmp;

image=roiobj.image;

fprintf('Inference complete. bestThreshold=%.3f used.\n', bestThreshold);

% ===================================================================
% --- helpers (inchangés) ---
function Vout = cropAroundCenter4D(Vin, center, winsz)
[H,W,C,T] = size(Vin);
cx = round(center(1)); cy = round(center(2));
w  = round(winsz(1)); h  = round(winsz(2));
halfw = floor(w/2); halfh = floor(h/2);
x1 = cx - halfw;  x2 = x1 + w - 1;
y1 = cy - halfh;  y2 = y1 + h - 1;
sx1 = max(1, x1);  sx2 = min(W, x2);
sy1 = max(1, y1);  sy2 = min(H, y2);
dx1 = 1 + (sx1 - x1); dy1 = 1 + (sy1 - y1);
dx2 = dx1 + (sx2 - sx1); dy2 = dy1 + (sy2 - sy1);
Vout = zeros(h, w, C, T, 'like', Vin);
Vout(dy1:dy2, dx1:dx2, :, :) = Vin(sy1:sy2, sx1:sx2, :, :);

function videoResized = centerCrop(video,inputSize)
videoResized = imresize(video,inputSize(1:2));
