function extractAllROICrops(shallowObj, varargin)
% extractAllROICrops
%
% Usage:
%   extractAllROICrops(shallowObj)
%   extractAllROICrops(shallowObj, 'Frames', 1:100)
%
% Frames (optionnel) : vecteur d'indices temporels à extraire.
%
% Pour chaque FOV du shallowObj :
%   - on prépare un buffer 4D [h w C Tsubset] pour chaque ROI (selon sa bbox)
%   - on lit les frames en blocs (cut) UNE SEULE FOIS par bloc pour la FOV
%   - on découpe ces frames pour toutes les ROIs
%   - on affiche une barre de progression globale FOV (Loading/Cropping)
%   - à la fin on assigne les stacks aux ROI, on définit roi.path
%     = <[shallowObj.io.path shallowObj.io.file]>/<fovObj.id>
%     puis on appelle roi.save(), qui crée im_<roi.id>.mat et data_<roi.id>.mat
%     dans CE dossier unique (pas un sous-dossier par ROI).
%
% Pas de drift correction, pas de scaling.

    % ----------------- PARAMS -----------------
    FrameList = [];
    for i = 1:2:numel(varargin)
        key = lower(string(varargin{i}));
        switch key
            case "frames"
                FrameList = varargin{i+1};
        end
    end

    if ~isprop(shallowObj,'fov') || isempty(shallowObj.fov)
        disp('⚠️  No FOV found in shallow object.');
        return;
    end

    fprintf('\n=============================================\n');
    fprintf('  🧩 ROI Extraction Started\n');
    fprintf('=============================================\n');

    % =============== LOOP OVER FOV ===============
    for iFov = 1:numel(shallowObj.fov)
        fovObj = shallowObj.fov(iFov);

        % Lien parent ROI <-> FOV
        roiList = getprop(fovObj,'roi',[]);
        if ~isempty(roiList)
            for rIdx = 1:numel(roiList)
                if isempty(roiList(rIdx).parent)
                    roiList(rIdx).parent = fovObj;
                end
            end
        end

        % Infos temporelles / canaux pour la FOV
        [nFramesTotal, nChannels, sampleClass] = inferFOVTimeline(fovObj);

        % Appliquer sous-ensemble temporel si demandé
        if isempty(FrameList)
            framesToDo = 1:nFramesTotal;
        else
            framesToDo = FrameList;
            framesToDo = framesToDo(framesToDo >= 1 & framesToDo <= nFramesTotal);
            if isempty(framesToDo)
                disp('   ⚠️  Frame list outside range, skipping this FOV.');
                continue;
            end
        end
        nFramesThisRun = numel(framesToDo);

        % ID FOV
        fovId = safeStr(getprop(fovObj,'id',sprintf('FOV_%d',iFov)));

        % Dossier de sortie FOV :
        % Convention demandée :
        %   strpath = [obj.io.path obj.io.file]
        %   roi.path = fullfile(strpath, fovObj.id)
        fovOutDir = getFOVOutputPath(shallowObj, fovObj, fovId);
        fprintf('\n▶ FOV %d/%d (%s) — %d frame(s) × %d channel(s)\n', ...
                iFov, numel(shallowObj.fov), fovId, nFramesThisRun, nChannels);
        fprintf('   Output dir: %s\n', fovOutDir);

        if isempty(roiList)
            disp('   → no ROI in this FOV.');
            continue;
        end

        nROI = numel(roiList);

        % -------- Pré-allouer les buffers ROI --------
        roiBuffers = struct('obj',[],'stack',[],'bbox',[]);
        roiBuffers(nROI).obj = []; % pre-expand struct array

        for rIdx = 1:nROI
            r = roiList(rIdx);

            validBox = ~isempty(r.value) && numel(r.value) >= 4;
            roiBuffers(rIdx).obj  = r;
            roiBuffers(rIdx).stack = [];
            roiBuffers(rIdx).bbox  = [];

            if validBox
                bb = r.value;
                xmin = bb(1); ymin = bb(2); w = bb(3); h = bb(4);

                roiBuffers(rIdx).bbox = struct( ...
                    'xmin', xmin, ...
                    'ymin', ymin, ...
                    'w',    w, ...
                    'h',    h ...
                );
                roiBuffers(rIdx).stack = zeros(h, w, nChannels, nFramesThisRun, sampleClass);
            end
        end

        % -------- Progression globale de la FOV --------
        doneFrames  = 0;
        totalFrames = nFramesThisRun;

        fprintf('      Loading frames  %s\n', progressBarString(doneFrames,totalFrames));
        %fprintf('      Cropping ROIs   %s\n', progressBarString(doneFrames,totalFrames));

        % On choisit un cut dynamique pour avoir une progression visible :
        % On veut idéalement ~4-5 steps mini.
        targetSteps = 5;
        cut = max(1, floor(nFramesThisRun / targetSteps));
        cut = min(cut, 20);   % on ne monte pas au-delà de 20 pour ne pas charger des blocs énormes
        if cut < 1
            cut = 1;
        end

        % --------- Boucle bloc par bloc ---------
        frameStarts = 1:cut:nFramesThisRun;
        nBlocks     = numel(frameStarts);
        blockCount  = 0;

        for fs = frameStarts
            fe = min(fs+cut-1, nFramesThisRun);
            blockCount = blockCount + 1;

            localRange = fs:fe;             % indices temps locaux
            frameBatch = framesToDo(fs:fe); % frames absolues lues

            % 1. Lire le bloc UNE FOIS sur la FOV
            %    => blockImg: [H W C Tblock]
            blockImg = loadFOVBlock_readImage(fovObj, frameBatch, 1:nChannels);

            % 2. Distribuer ce bloc dans CHAQUE ROI
            for rIdx = 1:nROI
                if isempty(roiBuffers(rIdx).stack)
                    continue; % ROI sans bbox valide
                end
                bb = roiBuffers(rIdx).bbox;

                for it = 1:numel(localRange)
                    tLocal = localRange(it);
                    for ic = 1:nChannels
                        frameImg = blockImg(:,:,ic,it);
                        roiBuffers(rIdx).stack(:,:,ic,tLocal) = ...
                            cropWithPad(frameImg, bb.xmin, bb.ymin, bb.w, bb.h);
                    end
                end
            end

            % 3. Mettre à jour la progression
            doneFrames = fe;

            % tentative "live update" portable :
            % on remonte de 2 lignes pour réécrire les deux barres.
            % Si MATLAB ignore \x1b[2A, tu verras juste des lignes en plus,
            % mais tu verras aussi le numéro de bloc.
            fprintf('\x1b[2A'); % move cursor up 2 lines (si support ANSI)

            fprintf('      Loading frames  %s   block %d/%d\n', ...
                    progressBarString(doneFrames,totalFrames), blockCount, nBlocks);
            fprintf('      Cropping ROIs   %s   block %d/%d\n', ...
                    progressBarString(doneFrames,totalFrames), blockCount, nBlocks);
        end

        % Séparateur visuel après la barre
        fprintf('\n');

        % -------- Sauvegarde finale de chaque ROI --------
        for rIdx = 1:nROI
            roiObj = roiBuffers(rIdx).obj;
            rid    = safeStr(getprop(roiObj,'id',sprintf('%s_ROI_%02d',fovId,rIdx)));

            if isempty(roiBuffers(rIdx).stack)
                fprintf('   • ROI %d/%d (%s): invalid bbox → skipped\n', rIdx, nROI, rid);
                continue;
            end

            bb = roiBuffers(rIdx).bbox;
            fprintf('   • ROI %d/%d (%s) [x=%d y=%d w=%d h=%d]\n', ...
                    rIdx, nROI, rid, bb.xmin, bb.ymin, bb.w, bb.h);

            % injecter les données (image + metadata canal)
            roiObj.image     = roiBuffers(rIdx).stack;
            roiObj.channelid = 1:nChannels;

            % respecter EXACTEMENT la convention du projet :
            % roi.path = <[shallowObj.io.path shallowObj.io.file]>/<fovObj.id>
            roiObj.path = fovOutDir;

            % sauver via ta méthode officielle roi.save()
            fprintf('        → saving ROI %s ... ', rid);
            didSave = roiObj.save("", false);  % "" => image+data ; verbose=false
            if didSave
                fprintf('✔ saved in %s (im_%s.mat / data_%s.mat)\n', ...
                    fovOutDir, rid, rid);
            else
                fprintf('⚠ nothing written (check ROI content)\n');
            end

            % libérer la RAM
            roiObj.image = [];
        end

        fprintf('   ✔ done FOV %s (%d ROI)\n', fovId, nROI);
    end

    fprintf('\n✅ Extraction complete for all FOVs.\n');
    fprintf('=============================================\n\n');
end


function fovOutDir = getFOVOutputPath(shallowObj, fovObj, fovIdFallback)
    % Reproduit fidèlement saveCroppedImages :
    %   strpath = [obj.io.path obj.io.file];
    %   roi.path = fullfile(strpath, fovObj.id);
    %
    % Mais attention : dans ton shallowObj réel,
    %   shallowObj.io.file = 'test.mat'
    % alors que le dossier projet est 'test\' (sans .mat).
    % On doit donc retirer l'extension si elle existe.

    projRoot = '';

    if isprop(shallowObj,'io') && isstruct(shallowObj.io)
        hasPath = isfield(shallowObj.io,'path') && ~isempty(shallowObj.io.path);
        hasFile = isfield(shallowObj.io,'file') && ~isempty(shallowObj.io.file);

        if hasPath && hasFile
            rawPath = shallowObj.io.path;   % ex: 'C:\Users\...\Data\'
            rawFile = shallowObj.io.file;   % ex: 'test.mat' ou 'test'

            % enlever extension .mat si présente
            [~, baseName, ext] = fileparts(rawFile);
            if strcmpi(ext,'.mat')
                projectFolderName = baseName;   % 'test'
            else
                projectFolderName = rawFile;    % déjà sans extension
            end

            % dossier projet final : <io.path>/<projectFolderName>
            projRoot = fullfile(rawPath, projectFolderName);
        end
    end

    % si projRoot reste vide, fallback :
    if isempty(projRoot)
        projRoot = detectProjectRoot(shallowObj);
    end

    % nom FOV (= dossier où mettre toutes les ROIs de cette FOV)
    if isprop(fovObj,'id') && ~isempty(fovObj.id)
        fovName = fovObj.id;
    else
        fovName = fovIdFallback;
    end

    % chemin final : <projRoot>/<fovName>
    fovOutDir = fullfile(projRoot, fovName);

    if ~exist(fovOutDir,'dir')
        mkdir(fovOutDir);
    end
end


%% -------- other helpers --------
function root = detectProjectRoot(shallowObj)
    % Fallback général si pas de shallowObj.io.*
    root = '';
    if ismethod(shallowObj,'getPath')
        try
            [pth, ~] = shallowObj.getPath;
            if exist(pth,'dir')
                root = pth;
            end
        catch
        end
    end
    if isempty(root) && isprop(shallowObj,'path') && ~isempty(shallowObj.path)
        if exist(shallowObj.path,'dir')
            root = shallowObj.path;
        end
    end
    if isempty(root)
        root = pwd;
    end
end

function [nFrames, nChannels, sampleClass] = inferFOVTimeline(fovObj)
    if isprop(fovObj,'channel') && ~isempty(fovObj.channel)
        nChannels = numel(fovObj.channel);
    else
        nChannels = 1;
    end

    if isprop(fovObj,'frames') && ~isempty(fovObj.frames)
        try
            nFrames = max(double(fovObj.frames(:)));
        catch
            nFrames = double(fovObj.frames(1));
        end
    else
        nFrames = 1;
    end

    try
        testIm = fovObj.readImage(1,1);
        if isempty(testIm)
            sampleClass = 'uint16';
        else
            sampleClass = class(testIm);
        end
    catch
        sampleClass = 'uint16';
    end
end

function blockImg = loadFOVBlock_readImage(fovObj, frameIdxVec, channelIdxVec)
    % blockImg : [H W C Tblock]
    frameIdxVec   = frameIdxVec(:)'; 
    channelIdxVec = channelIdxVec(:)';

    testIm = fovObj.readImage(frameIdxVec(1), channelIdxVec(1));
    H = size(testIm,1);
    W = size(testIm,2);

    C = numel(channelIdxVec);
    T = numel(frameIdxVec);

    blockImg = zeros(H,W,C,T,class(testIm));

    for ic = 1:C
        c = channelIdxVec(ic);
        for it = 1:T
            t = frameIdxVec(it);
            im = fovObj.readImage(t,c);
            if isempty(im)
                continue;
            end
            if size(im,1)~=H || size(im,2)~=W
                im = safeResizeTo(im,H,W);
            end
            blockImg(:,:,ic,it) = im;
        end
    end
end

function im2 = safeResizeTo(im,H,W)
    im2 = zeros(H,W,class(im));
    h0 = min(H,size(im,1));
    w0 = min(W,size(im,2));
    im2(1:h0,1:w0) = im(1:h0,1:w0);
end

function outCrop = cropWithPad(frameImg, xmin, ymin, w, h)
    Hfull = size(frameImg,1);
    Wfull = size(frameImg,2);

    xRange = xmin + (0:w-1);
    yRange = ymin + (0:h-1);

    xValid = xRange(xRange >= 1 & xRange <= Wfull);
    yValid = yRange(yRange >= 1 & yRange <= Hfull);

    outCrop = zeros(h,w,class(frameImg));
    if isempty(xValid) || isempty(yValid)
        return;
    end

    xOffsetOut = find(xRange==xValid(1),1);
    yOffsetOut = find(yRange==yValid(1),1);

    outCrop(yOffsetOut+(0:numel(yValid)-1), ...
            xOffsetOut+(0:numel(xValid)-1)) = frameImg(yValid,xValid);
end

function s = safeStr(x)
    if isempty(x)
        s = '';
    elseif ischar(x)
        s = x;
    elseif isstring(x)
        s = strjoin(cellstr(x), ', ');
    else
        s = char(string(x));
    end
end

function val = getprop(obj, field, defaultVal)
    if isprop(obj,field)
        val = obj.(field);
        if isempty(val)
            val = defaultVal;
        end
    else
        val = defaultVal;
    end
end

function out = progressBarString(doneFrames,totalFrames)
    if totalFrames <= 0
        totalFrames = 1;
    end
    pct = max(0,min(1, doneFrames/totalFrames));

    barLen = 20;
    nFull  = round(pct * barLen);
    nEmpty = barLen - nFull;

    barStr = ['[', repmat('#',1,nFull), repmat('-',1,nEmpty), ']'];

    out = sprintf('%s %3.0f%% (%d/%d)', barStr, pct*100, doneFrames, totalFrames);
end
