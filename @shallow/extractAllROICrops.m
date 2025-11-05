
function extractAllROICrops(shallowObj, varargin)
% extractAllROICrops — version "streaming append HDF5"
%
% Usage:
%   extractAllROICrops(shallowObj)
%   extractAllROICrops(shallowObj, 'Frames', 1:100)
%
% - Lit la FOV par blocs
% - Crops chaque ROI
% - Append les blocs directement dans im_<roi.id>.h5 (sans réécrire l'historique)
%
% Hypothèses côté roi.save():
%   - save(obj, requestedChannels) appelle upsertH5Dataset_frames (append sur T)
%   - "" (chaîne vide) déclenche un full save => on évite !
%

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
    fprintf('  🧩 ROI Extraction (HDF5 append) Started\n');
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

        % ID FOV & dossier de sortie
        fovId    = safeStr(getprop(fovObj,'id',sprintf('FOV_%d',iFov)));
        fovOutDir = getFOVOutputPath(shallowObj, fovObj, fovId);
        fprintf('\n▶ FOV %d/%d (%s) — %d frame(s) × %d channel(s)\n', ...
                iFov, numel(shallowObj.fov), fovId, nFramesThisRun, nChannels);
        fprintf('   Output dir: %s\n', fovOutDir);

        if isempty(roiList)
            disp('   → no ROI in this FOV.');
            continue;
        end

        nROI = numel(roiList);

        % -------- Préparer les ROI (path + display minimal + bbox) --------
        ROI = struct('obj',[],'bbox',[],'h',0,'w',0,'id','', 'chanNames',{{}});
        ROI(nROI).obj = [];
        chanNamesFOV = getFOVChannelNames(fovObj, nChannels);

        for rIdx = 1:nROI
            r = roiList(rIdx);
            ROI(rIdx).obj = r;
            ROI(rIdx).id  = safeStr(getprop(r,'id',sprintf('%s_ROI_%02d',fovId,rIdx)));

            % Path projet/FOV
            r.path = fovOutDir;

            % BBox
            validBox = ~isempty(r.value) && numel(r.value) >= 4;
            if ~validBox
                ROI(rIdx).bbox = [];
                ROI(rIdx).h = 0; ROI(rIdx).w = 0;
            else
                bb = r.value;  % [xmin ymin w h]
                ROI(rIdx).bbox = struct('xmin',bb(1),'ymin',bb(2),'w',bb(3),'h',bb(4));
                ROI(rIdx).h = bb(4); ROI(rIdx).w = bb(3);
            end

            % Display minimal (si absent) + noms de canaux
            if ~isstruct(r.display) || ~isfield(r.display,'channel') || isempty(r.display.channel)
                r.display = defaultDisplay(nChannels, nChannels);
                r.display.channel = chanNamesFOV;   % noms logiques
            end
            ROI(rIdx).chanNames = r.display.channel;

            % channelid trivial 1..nChannels (un bloc par canal logique)
            if isempty(r.channelid) || numel(r.channelid) ~= nChannels
                r.channelid = 1:nChannels;
            end

            ROI(rIdx).T_written = getExistingT_H5(r.path, ROI(rIdx).id, chanNamesFOV);

            % Ecrire retour dans l'objet
            roiList(rIdx) = r;
        end

        % -------- Progression globale de la FOV --------
        doneFrames  = 0; totalFrames = nFramesThisRun;
        fprintf('      Loading frames  %s\n', progressBarString(doneFrames,totalFrames));
        fprintf('      Cropping ROIs   %s\n', progressBarString(doneFrames,totalFrames));

        % Découpage en blocs (cut)
        targetSteps = 2;
        cut = max(1, floor(nFramesThisRun / targetSteps));
        cut = min(cut, 20);
        if cut < 1, cut = 1; end

        frameStarts = 1:cut:nFramesThisRun;
        nBlocks     = numel(frameStarts);
        blockCount  = 0;

        % --------- Boucle bloc par bloc ---------
        for fs = frameStarts
            fe = min(fs+cut-1, nFramesThisRun);
            blockCount = blockCount + 1;

            localRange = fs:fe;             % indices temps locaux (dans framesToDo)
            frameBatch = framesToDo(localRange); % frames absolues

            % 1) Lire bloc sur la FOV : [H W C Tblock]
            blockImg = loadFOVBlock_readImage(fovObj, frameBatch, 1:nChannels);
            Tblock = size(blockImg,4);

            % 2) Crops + Append immédiat ROI par ROI
            for rIdx = 1:nROI
                r  = ROI(rIdx).obj;
                bb = ROI(rIdx).bbox;

                if isempty(bb)
                    fprintf('   • ROI %d/%d (%s): invalid bbox → skipped\n', rIdx, nROI, ROI(rIdx).id);
                    continue;
                end

                % --- Crops du bloc en [h w C Tblock]
                h = ROI(rIdx).h; w = ROI(rIdx).w;
                roiBlock = zeros(h, w, nChannels, Tblock, sampleClass);
                for it = 1:Tblock
                    for ic = 1:nChannels
                        roiBlock(:,:,ic,it) = cropWithPad(blockImg(:,:,ic,it), bb.xmin, bb.ymin, w, h);
                    end
                end

                % --- Taille déjà sauvegardée (T_old) côté HDF5 (si file/dataset existent)
                % on prend T_old par canal logique (doit être cohérent entre canaux)
               % T_old = getExistingT_H5(r.path, ROI(rIdx).id, ROI(rIdx).chanNames);
                T_old = ROI(rIdx).T_written;

                % --- Fabrique un tampon minimal [h w C (T_old + Tblock)]
                T_newTotal = T_old + Tblock;
                tmp = zeros(h, w, nChannels, T_newTotal, sampleClass);
                tmp(:,:,:,T_old+1:T_newTotal) = roiBlock;


                % Injecter et sauver en append (uniquement les canaux logiques demandés)
                r.image     = tmp;
                r.channelid = 1:nChannels;   % 1 logique par canal
                if ~isstruct(r.display) || ~isfield(r.display,'channel') || isempty(r.display.channel)
                    r.display = defaultDisplay(nChannels, nChannels);
                    r.display.channel = ROI(rIdx).chanNames;
                   
                end
                r.path = fovOutDir;

                % IMPORTANT : ne pas passer "", mais la liste des canaux → pas de full save
                didSave = r.save( r.display.channel, false );  % append sur T

                 if didSave
        % 🔹 MAJ du compteur local après écriture OK
        ROI(rIdx).T_written = T_newTotal;
    else
        fprintf('        ⚠ nothing written for ROI %s\n', ROI(rIdx).id);
    end

                % libérer RAM immédiatement
                r.image = [];
                ROI(rIdx).obj = r;
            end

            % 3) Progression
            doneFrames = fe;
            fprintf('\x1b[2A');
            fprintf('      Loading frames  %s   block %d/%d\n', ...
                    progressBarString(doneFrames,totalFrames), blockCount, nBlocks);
            fprintf('      Cropping ROIs   %s   block %d/%d\n', ...
                    progressBarString(doneFrames,totalFrames), blockCount, nBlocks);
        end

        fprintf('\n   ✔ done FOV %s (%d ROI)\n', fovId, nROI);
    end

    fprintf('\n✅ Extraction complete (append mode).\n');
    fprintf('=============================================\n\n');
end


function chanNames = getFOVChannelNames(fovObj, nChannels)
    % Essaie de récupérer des noms de canaux depuis la FOV
    chanNames = {};
    if isprop(fovObj,'channel') && ~isempty(fovObj.channel)
        ch = fovObj.channel;
        if isstring(ch), ch = cellstr(ch); end
        if ~iscell(ch), ch = {char(string(ch))}; end
        chanNames = ch;
    end
    if isempty(chanNames) || numel(chanNames) ~= nChannels
        chanNames = arrayfun(@(i)sprintf('channel_%03d',i), 1:nChannels, 'UniformOutput', false);
    end
end

function T_old = getExistingT_H5(roiPath, roiId, chanNames)
    % Renvoie T_old = nFrames déjà présents dans le HDF5 de la ROI (0 si absent).
    % Lit uniquement les DIMS/ATTRS (pas de data).
    T_old = 0;
    if isempty(roiPath) || isempty(roiId), return; end
    h5File = fullfile(roiPath, sprintf('im_%s.h5', roiId));
    if ~isfile(h5File), return; end

    try
        info  = h5info(h5File);
    catch
        return;
    end
    if isempty(info.Datasets), return; end

    % On tente par nom logique / attribut channel_name
    Tvals = [];
    for i = 1:numel(info.Datasets)
        p = ['/' info.Datasets(i).Name];
        d = info.Datasets(i);

        % retenir seulement datasets de cette ROI (normalement tous)
        % lire channel_name si dispo
        chn = d.Name;
        try
            chn = h5readatt(h5File, p, 'channel_name');
        catch
        end

        if ismember(chn, chanNames)
            % dims HDF5 en ordre [T k W H]
            try
                space_id = H5S.create('H5S_SIMPLE'); %#ok<NASGU>
                % plus simple : via h5info -> Size
                dims_h5 = d.Dataspace.Size; % [T k W H]
                Tvals(end+1) = dims_h5(1); %#ok<AGROW>
            catch
            end
        end
    end

    if ~isempty(Tvals)
        T_old = min(Tvals); % sécurité : cohérence T entre canaux
    end
end

% === (reprend les helpers existants de ta version) ===

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
    frameIdxVec   = frameIdxVec(:)'; 
    channelIdxVec = channelIdxVec(:)';

    testIm = fovObj.readImage(frameIdxVec(1), channelIdxVec(1));
    H = size(testIm,1); W = size(testIm,2);

    C = numel(channelIdxVec);
    T = numel(frameIdxVec);

    blockImg = zeros(H,W,C,T,class(testIm));

    for ic = 1:C
        c = channelIdxVec(ic);
        for it = 1:T
            t = frameIdxVec(it);
            im = fovObj.readImage(t,c);
            if isempty(im), continue; end
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
    Hfull = size(frameImg,1); Wfull = size(frameImg,2);
    xRange = xmin + (0:w-1);  yRange = ymin + (0:h-1);
    xValid = xRange(xRange >= 1 & xRange <= Wfull);
    yValid = yRange(yRange >= 1 & yRange <= Hfull);
    outCrop = zeros(h,w,class(frameImg));
    if isempty(xValid) || isempty(yValid), return; end
    xOffsetOut = find(xRange==xValid(1),1);
    yOffsetOut = find(yRange==yValid(1),1);
    outCrop(yOffsetOut+(0:numel(yValid)-1), xOffsetOut+(0:numel(xValid)-1)) = frameImg(yValid,xValid);
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
        if isempty(val), val = defaultVal; end
    else
        val = defaultVal;
    end
end

function out = progressBarString(doneFrames,totalFrames)
    if totalFrames <= 0, totalFrames = 1; end
    pct = max(0,min(1, doneFrames/totalFrames));
    barLen = 20;
    nFull  = round(pct * barLen);
    nEmpty = barLen - nFull;
    barStr = ['[', repmat('#',1,nFull), repmat('-',1,nEmpty), ']'];
    out = sprintf('%s %3.0f%% (%d/%d)', barStr, pct*100, doneFrames, totalFrames);
end

function fovOutDir = getFOVOutputPath(shallowObj, fovObj, fovIdFallback)
    projRoot = '';
    if isprop(shallowObj,'io') && isstruct(shallowObj.io)
        hasPath = isfield(shallowObj.io,'path') && ~isempty(shallowObj.io.path);
        hasFile = isfield(shallowObj.io,'file') && ~isempty(shallowObj.io.file);
        if hasPath && hasFile
            rawPath = shallowObj.io.path;
            rawFile = shallowObj.io.file;
            [~, baseName, ext] = fileparts(rawFile);
            if strcmpi(ext,'.mat'), projectFolderName = baseName;
            else,                 projectFolderName = rawFile;
            end
            projRoot = fullfile(rawPath, projectFolderName);
        end
    end
    if isempty(projRoot), projRoot = detectProjectRoot(shallowObj); end
    if isprop(fovObj,'id') && ~isempty(fovObj.id), fovName = fovObj.id;
    else, fovName = fovIdFallback; end
    fovOutDir = fullfile(projRoot, fovName);
    if ~exist(fovOutDir,'dir'), mkdir(fovOutDir); end
end

function root = detectProjectRoot(shallowObj)
    root = '';
    if ismethod(shallowObj,'getPath')
        try, [pth, ~] = shallowObj.getPath; if exist(pth,'dir'), root = pth; end, catch, end
    end
    if isempty(root) && isprop(shallowObj,'path') && ~isempty(shallowObj.path)
        if exist(shallowObj.path,'dir'), root = shallowObj.path; end
    end
    if isempty(root), root = pwd; end
end

function d = defaultDisplay(N, C)
    d = struct();
    d.intensity       = repmat([1 1 1], N, 1);
    d.frame           = 1;
    d.selectedchannel = ones(1,N);
    d.binning         = 1;
    d.rgb             = repmat([1 1 1], N, 1);  % N x 3 (par canal logique)
    d.channel         = arrayfun(@(k)sprintf('channel_%d',k), 1:N, 'UniformOutput', false);
    d.stretchlim      = [];
    d.displaylim      = repmat([0;1], 1, C);
    d.indexed         = zeros(1,N);
    d.alpha           = ones(1,N);
    d.contour         = zeros(1,N);
    d.width           = ones(1,N);
    d.log             = zeros(1,N);
end
