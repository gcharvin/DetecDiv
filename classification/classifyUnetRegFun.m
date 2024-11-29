function [results, imageout] = classifyUnetRegFun(roiobj, classif, classifier, varargin)
    % Classify using U-Net for regression (denoising, etc.)
    gpu = 0; % Default to CPU

    % Charger le classificateur si non fourni
    if isempty(classifier)
        path = classif.path;
        name = classif.strid;
        str = [path '/' name '.mat'];
        load(str, 'classifier'); % Charger le classificateur
    end

    % Extraire les options passées en arguments
    frames = [];
    channel = classif.channelName{1};

    for i = 1:numel(varargin)
        if strcmp(varargin{i}, 'Frames')
            frames = varargin{i + 1};
        elseif strcmp(varargin{i}, 'Channel')
            channel = varargin{i + 1};
            channel = channel{1};
        elseif strcmp(varargin{i}, 'Exec')
            gpu = varargin{i + 1};
        end
    end

    net = classifier; % Réseau U-Net chargé
    inputSize = net.Layers(1).InputSize;

    % Charger les images ROI si non déjà chargé
    if isempty(roiobj.image)
        roiobj.load;
    end

    % Identifier les canaux pour la classification
    pix = roiobj.findChannelID(channel);
    if iscell(pix)
        pix = cell2mat(pix);
    end

    % Charger les images associées aux canaux
    gfp = roiobj.image(:, :, pix, :);

    % Définir les frames si non spécifiés
    if isempty(frames)
        frames = 1:size(gfp, 4);
    end

    % Préparer les données pour traitement par lots
    batchSize = 10; % Taille du batch
    numFrames = numel(frames);
    outputImages = [];

    % Processus par batch
    for i = 1:batchSize:numFrames
        % Définir les indices du batch actuel
        batchEnd = min(i + batchSize - 1, numFrames);
        currentBatchFrames = frames(i:batchEnd);

        % Initialiser le batch
        batchGfp = double(zeros(inputSize(1), inputSize(2), inputSize(3), numel(currentBatchFrames)));

        % Traiter chaque frame du batch
        for fr = 1:numel(currentBatchFrames)
            frameIdx = currentBatchFrames(fr);
            batchFrame = roiobj.preProcessROIData(pix, frameIdx, []);
            batchGfp(:, :, :, fr) = imresize(batchFrame, inputSize(1:2));
        end

        
        % Convertir en GPU array si nécessaire
        if gpu == 1
            batchGfp = gpuArray(batchGfp);
        end

        % Prédictions via U-Net
        if gpu == 1
            batchOutput = predict(net, batchGfp, 'ExecutionEnvironment', 'gpu');
        else
            batchOutput = predict(net, batchGfp, 'ExecutionEnvironment', 'cpu');
        end

       % figure, imshow(batchOutput,[]);

        % Collecter les résultats
        if isempty(outputImages)
            outputImages = batchOutput;
        else
            outputImages = cat(4, outputImages, batchOutput);
        end
    end

   % Redimensionner les résultats pour correspondre à l'image d'origine
outputImagesResized = zeros(size(roiobj.image(:, :, pix, frames)));

for fr = 1:numel(frames)
    % Redimensionner la prédiction
    resizedPrediction = imresize(outputImages(:, :, :, fr), size(roiobj.image(:, :, 1)));

    % Si l'image d'entrée a un seul canal
    if numel(pix) == 1
        % Moyenne des canaux pour produire une image à un seul canal
        resizedPrediction = mean(resizedPrediction, 3);
        % Assigner la prédiction aplatie
        outputImagesResized(:, :, 1, fr) = resizedPrediction;
    else
        % Si plusieurs canaux, conserver la prédiction originale
        outputImagesResized(:, :, :, fr) = resizedPrediction;
    end
end

    % Mise à jour de l'objet ROI
    pixresults = roiobj.findChannelID(['results_' classif.strid]);
    if isempty(pixresults)
        pixresults = size(roiobj.image, 3) + 1; % Ajouter un nouveau canal si nécessaire
    end

   % figure, imshow(outputImagesResized,[])
  % figure, imshow(outputImagesResized,[]);

   outputImagesResized=uint16(65535*outputImagesResized);

    roiobj.image(:, :, pixresults, frames) = outputImagesResized;
    % Retourner les résultats

    imageout = roiobj.image;
    imageout(:, :, pixresults, frames) = outputImagesResized;

   
    results = roiobj.results;

    fprintf('\nClassification terminée.\n');
end
