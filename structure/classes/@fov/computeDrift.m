function [list, drift, score] = computeDrift(obj, varargin)
% COMPUTEDRIFT  XY drift correction for a FOV (legacy + block mode).
%
% Key points:
%   - method='robust' estimates displacement against an immutable anchor.
%     Temporal prealignment bounds the new motion, while spatial consensus
%     and pixel correlation validate it without a biological-domain model.
%     maxshift limits the new motion, not the total lifetime displacement.
%   - refMode='previous' remains available for legacy runs. It estimates a
%     residual step and integrates it over time.
%   - Blocks seed from the last earlier processed frame, including sparse runs.
%   - drift.accepted/decision/estimation, consensusCount/Spread and
%     anchorCorrelation are indexed by absolute frame IDs. A rejected robust
%     frame holds the last correction; a small residual alone is not proof
%     of accuracy against the anchor. No trap/cell template is required.
%   - A weak/changing anchor is cross-checked against the preceding raw frame.
%     Strong temporal consensus may temporarily bridge anchor failure;
%     estimation='temporalFallback' and anchorValidated=false expose this
%     provisional trajectory. Absolute anchor matching resumes when reliable.
%     Block callers pass the preceding raw image as 'previousimage'.
%   - Logs residual drift after correction at each frame:
%       residual(row,col) and residualNorm (px)
%
% Methods:
%   'robust'    : tiled anchor consensus with independent temporal validation
%   'circshift' : normxcorr2 (integer px)
%   'subpixel'  : phase correlation FFT + optional quadratic subpixel
%   'register'  : imregtform translation (no score)

% ---------- Defaults ----------
method      = 'robust';
refMode     = 'fixed';
channel     = 1;
images      = [];
framesid    = [];
displayFlag = 0;
refimage    = [];
previousimage = []; % raw preceding processed frame, for a block boundary
refframeid  = 1;
crop        = 1.0;
subpixel    = true;
maxshift    = 20;     % robust: new-motion search bound; legacy fixed: absolute bound
hipasssigma = 3;
apodize     = true;
mask        = [];

% ---- Robustness (simple) ----
warmupFrames = 0;
psrRadius    = 6;
psrMin       = 10;      % 0 => no PSR reject
maxStep      = 10;      % motion between processed frames (px); 0 => off
onReject     = 'hold';  % 'hold' | 'zero'  (when PSR too low)

% ---- Optional smoothing ----
smoothWin     = 0;        % 0 off; odd integer
smoothMethod  = 'median'; % 'median'|'mean'
smoothTarget  = 'step';   % 'step'|'cum'

% ---- Debug/profile ----
debug       = false;
debugEvery  = 1;
debugFcn    = [];
doTiming    = true;

% ---- Block stitch option (default ON) ----
stitchFromObjDrift = true;  % if true: seed cum from obj.drift at framesid(1)-1

% ---------- Parse ----------
for i = 1:2:numel(varargin)
    key = lower(string(varargin{i}));
    val = varargin{i+1};
    switch key
        case "method",       method = char(val);
        case "refmode",      refMode = char(val);
        case "channel",      channel = val;
        case "images",       images = val;
        case "framesid",     framesid = val;
        case "refimage",     refimage = val;
        case "previousimage", previousimage = val;
        case "refframeid",   refframeid = val;
        case "display",      displayFlag = 1;
        case "crop",         crop = val;
        case "subpixel",     subpixel = logical(val);
        case "maxshift",     maxshift = val;
        case "hipasssigma",  hipasssigma = val;
        case "apodize",      apodize = logical(val);
        case "mask",         mask = val;

        case "warmupframes", warmupFrames = max(0, round(double(val)));
        case "psrradius",    psrRadius = max(1, round(double(val)));
        case "psrmin",       psrMin = double(val);
        case "maxstep",      maxStep = double(val);
        case "rejectmode",   onReject = char(val);   % compat
        case "smoothwin",    smoothWin = round(double(val));
        case "smoothmethod", smoothMethod = char(val);
        case "smoothtarget", smoothTarget = char(val);

        case "debug",        debug = logical(val);
        case "verbose",      debug = logical(val);
        case "debugevery",   debugEvery = max(1, round(double(val)));
        case "debugfcn",     debugFcn = val;
        case "timing",       doTiming = logical(val);

        case "stitch",       stitchFromObjDrift = logical(val);
    end
end

% sanitize method / reference mode
method = lower(char(string(method)));
if strcmpi(method, 'integer')
    method = 'circshift';
end
if isempty(refMode)
    if strcmpi(method,'robust'), refMode = 'fixed';
    else,                         refMode = 'previous';
    end
end
refMode = lower(string(refMode));
if refMode == "anchor" || refMode == "first"
    refMode = "fixed";
end
if strcmpi(method, 'robust')
    refMode = "fixed";
end
absoluteMode = refMode == "fixed";

% sanitize smoothing
smoothMethod = lower(string(smoothMethod));
if smoothMethod ~= "median" && smoothMethod ~= "mean", smoothMethod = "median"; end
smoothTarget = lower(string(smoothTarget));
if smoothTarget ~= "step" && smoothTarget ~= "cum", smoothTarget = "step"; end
if smoothWin < 0, smoothWin = 0; end
if smoothWin > 0 && mod(smoothWin,2)==0, smoothWin = smoothWin + 1; end

wantObs = debug || ~isempty(debugFcn);
if ~wantObs, doTiming = false; end

% ---------- Prepare legacy/blk paths ----------
legacyMode = isempty(images);
if legacyMode
    if isempty(framesid)
        framesid = 1:numel(obj.srclist{1});
    end
    testIm = obj.readImage(framesid(1), channel);
    [H,W] = size(testIm);
    list = zeros(H, W, 1, numel(framesid), class(testIm));
else
    list = images; % H W C T
    % MATLAB drops trailing singleton dimensions from ndims(). Therefore,
    % valid HxWxCx1 blocks (and HxWx1x1 blocks) must not be rejected merely
    % because ndims(list) is smaller than four.
    if isempty(list) || size(list,1) == 0 || size(list,2) == 0 || size(list,4) == 0
        error('computeDrift:EmptyImageBlock', ...
            'Drift correction received an empty image block.');
    end
    if isempty(framesid)
        framesid = 1:size(list,4);
    end
end

nT = numel(framesid);

% ---------- histories ----------
stepRow_hist = zeros(1,nT);
stepCol_hist = zeros(1,nT);
cumRow_hist  = zeros(1,nT);
cumCol_hist  = zeros(1,nT);
score        = NaN(1,nT);
consensusCount_hist = NaN(1,nT);
consensusSpread_hist = NaN(1,nT);
accepted_hist = false(1,nT);
decision_hist = cell(1,nT);
estimation_hist = cell(1,nT);
anchorCorrelation_hist = NaN(1,nT);
temporalCorrelation_hist = NaN(1,nT);
anchorValidated_hist = false(1,nT);

% residual effectiveness (after correction)
resRow_hist  = NaN(1,nT);
resCol_hist  = NaN(1,nT);
resNorm_hist = NaN(1,nT);

% ---------- drift struct ----------
% We keep existing obj.drift.x/y as "global correction history" over absolute frames.
if isempty(obj) || ~isprop(obj,'drift') || isempty(obj.drift) || ...
        ~isstruct(obj.drift) || ~isfield(obj.drift,'x') || ~isfield(obj.drift,'y')
    drift.x = zeros(1, max(framesid));
    drift.y = zeros(1, max(framesid));
else
    drift = obj.drift;
    % JSON persistence may load histories as columns. Keep one canonical
    % orientation to avoid implicit expansion in consumers and comparisons.
    historyNames={'x','y','score','frames','accepted','decision','estimation', ...
        'consensusCount','consensusSpread','anchorCorrelation', ...
        'temporalCorrelation','anchorValidated'};
    for hi=1:numel(historyNames)
        field=historyNames{hi};
        if isfield(drift,field), drift.(field)=reshape(drift.(field),1,[]); end
    end
    % Older extractors persisted compact arrays indexed by drift.frames.
    % Normalize them before accessing absolute frame IDs or stitching blocks.
    if isfield(drift,'frames') && numel(drift.frames) == numel(drift.x) && ...
            ~isempty(drift.frames) && ~isequal(drift.frames(:)',1:numel(drift.x))
        oldFrames = drift.frames(:)';
        oldX = drift.x; oldY = drift.y;
        drift.x = zeros(1,max([framesid(:)' oldFrames]));
        drift.y = zeros(size(drift.x));
        drift.x(oldFrames) = oldX;
        drift.y(oldFrames) = oldY;
        if isfield(drift,'score') && numel(drift.score) == numel(oldFrames)
            oldScore = drift.score;
            drift.score = nan(size(drift.x));
            drift.score(oldFrames) = oldScore;
        end
    end
    if numel(drift.x) < max(framesid)
        drift.x(max(framesid)) = 0; drift.y(max(framesid)) = 0;
    end
end

% ---------- Debug header ----------
if wantObs
    modeStr = tern(legacyMode,'legacy','block');
    localDebugPrint(debug, debugFcn, struct('stage','start'), ...
        sprintf(['[computeDrift] (simple+residual) mode=%s method=%s ref=%s chan=%s frames=%d crop=%.3g subpixel=%d ' ...
                 'maxshift=%s hipass=%.3g apodize=%d mask=%d | PSR(rad=%d,min=%.3g) maxStep=%.3g reject=%s | smooth=%d(%s,%s) | stitch=%d'], ...
            modeStr, method, char(refMode), mat2str(channel), nT, crop, subpixel, ...
            mat2str(maxshift), hipasssigma, apodize, ~isempty(mask), ...
            psrRadius, psrMin, maxStep, char(onReject), smoothWin, char(smoothMethod), char(smoothTarget), stitchFromObjDrift));
end

% ---------- initial reference ----------
tPrepRef = tic;
if isempty(refimage)
    if legacyMode
        refimage = obj.readImage(refframeid, channel);
    else
        refimage = list(:,:,channel,1);
    end
end
if isempty(refimage)
    error('computeDrift:EmptyReferenceImage', ...
        'Drift correction reference image is empty.');
end
refGray0 = toGray(refimage);
% Robust regions are windowed once, after temporal prealignment.
globalWindow = apodize && ~strcmpi(method,'robust');
denoiseSigma=0;
if strcmpi(method,'robust'), denoiseSigma=max(.5,hipasssigma/3); end
fixedRefProc = preprocess(cropCenter(refGray0,crop),hipasssigma,globalWindow,mask,denoiseSigma);
fixedRefEdges=[];
tPrepRef = toc(tPrepRef);

% register config
if strcmpi(method, 'register')
    tRegCfg = tic;
    [optimizer, metric] = imregconfig('monomodal');
    tRegCfg = toc(tRegCfg);
else
    optimizer = []; metric = [];
    tRegCfg = 0;
end

% timing
if doTiming
    TT = struct('prepRef',tPrepRef,'regCfg',tRegCfg,'load',0,'prep',0,'estimate',0,'apply',0,'residual',0,'total',0);
else
    TT = [];
end
tTotal = tic;

% ---------- state ----------
cumRow = 0; cumCol = 0;

% Seed the preceding correction for incremental stitching and for absolute
% hold/jump rejection at a block boundary. Accepted absolute estimates still
% replace this seed rather than accumulate it.
hasPreviousFrame = false;
if stitchFromObjDrift && ~legacyMode && framesid(1) > 1

    prevAbs = framesid(1) - 1;
    if isfield(drift,'frames')
        previous=drift.frames(drift.frames<framesid(1));
        if ~isempty(previous), prevAbs=max(previous); end
    end
    if isfield(drift,'frames') && ismember(prevAbs,drift.frames) && ...
            numel(drift.x) >= prevAbs && numel(drift.y) >= prevAbs
        cumRow = -double(drift.x(prevAbs));
        cumCol = -double(drift.y(prevAbs));
        hasPreviousFrame = true;
    elseif ~absoluteMode && numel(drift.x) >= prevAbs && numel(drift.y) >= prevAbs
        cumRow = -double(drift.x(prevAbs));
        cumCol = -double(drift.y(prevAbs));
        hasPreviousFrame = true;
    end
end

% prevProc is only used by the legacy incremental mode. fixedRefProc is
% immutable and is shared by every block of an anchored extraction.
prevProc = fixedRefProc;
previousRawProc=[];
previousGray=[];
if ~isempty(previousimage) && hasPreviousFrame
    previousGray=cropCenter(toGray(previousimage),crop);
    previousRawProc=preprocess(cropCenter(toGray(previousimage),crop),hipasssigma,false,mask,denoiseSigma);
end

cc = 1;
for j = framesid
    % load
    tLoad = tic;
    if legacyMode
        imFull = obj.readImage(j, channel);
        list(:,:,1,cc) = imFull;
    else
        imFull = list(:,:,channel,cc);
    end
    if doTiming, TT.load = TT.load + toc(tLoad); end
    if isempty(imFull)
        error('computeDrift:EmptyFrameImage', ...
            'Drift correction received an empty image at frame index %d.', j);
    end

    imGray = toGray(imFull);
    if isempty(imGray)
        error('computeDrift:EmptyFrameImage', ...
            'Drift correction image is empty after grayscale conversion at frame index %d.', j);
    end

    % -------- build estimation image --------
    % Incremental mode pre-aligns against the previous cumulative estimate.
    % Absolute mode always compares the untouched frame with fixedRefProc.
    if cc > 1 && ~absoluteMode
        fv0 = median(imGray(:));
        imGrayEst = imtranslate(imGray, [-cumCol -cumRow], 'linear', 'FillValues', fv0);
    else
        % At the first frame of an incremental stitched block, move the frame
        % into the same stabilized space as the preceding block.
        if (cc == 1) && ~absoluteMode && (cumRow ~= 0 || cumCol ~= 0)
            fv0 = median(imGray(:));
            imGrayEst = imtranslate(imGray, [-cumCol -cumRow], 'linear', 'FillValues', fv0);
        else
            imGrayEst = imGray;
        end
    end

    % preprocess for estimation
    tPrep = tic;
    imProc = preprocess(cropCenter(imGrayEst,crop),hipasssigma,globalWindow,mask,denoiseSigma);
    if doTiming, TT.prep = TT.prep + toc(tPrep); end

    % choose reference for estimation
    if absoluteMode
        refEst = fixedRefProc;
    else
        if cc == 1
            refEst = imProc; % step forced to 0 below
        else
            refEst = prevProc; % already in corrected frame
        end
    end

    % estimate residual step
    tEst = tic;
    sc = NaN;
    consensusCount = NaN;
    consensusSpread = NaN;
    estimationReason = '';
    anchorCorrelation = NaN;
    temporalCorrelation = NaN;
    movingEdges=[];
    anchorValidated = false;
    if (cc == 1) && ~absoluteMode
        stepRow = 0; stepCol = 0; sc = 0;
    else
        switch lower(method)
            case 'robust'
                stepGate=maxStep;
                if cc==1 && ~hasPreviousFrame, stepGate=0; end
                [stepRow, stepCol, sc, consensusCount, consensusSpread, estimationReason, anchorCorrelation] = ...
                    robustAnchorShift(refEst, imProc, subpixel, psrRadius, psrMin, maxshift, ...
                        [cumRow cumCol],apodize,stepGate);
                % Use polarity-independent contours when intensity appearance
                % has aged. Both cues use the same immutable anchor/grid and
                % must satisfy the same distributed-support/ambiguity checks.
                if ~isfinite(stepRow) || anchorCorrelation<.6 || consensusSpread>.35
                    if isempty(fixedRefEdges)
                        fixedRefEdges=roiExtract.structuralRegistrationImage( ...
                            cropCenter(refGray0,crop),hipasssigma,denoiseSigma,mask);
                    end
                    movingEdges=roiExtract.structuralRegistrationImage( ...
                        cropCenter(imGrayEst,crop),hipasssigma,denoiseSigma,mask);
                    [gr,gc,gs,gn,gspread,greason,gcorrelation]=robustAnchorShift( ...
                        fixedRefEdges,movingEdges,subpixel,psrRadius,psrMin,maxshift, ...
                        [cumRow cumCol],apodize,stepGate);
                    if isfinite(gr) && gspread<=.5 && (~isfinite(stepRow) || ...
                            gcorrelation>anchorCorrelation+.1 || ...
                            (gcorrelation>=anchorCorrelation-.05 && gspread<.5*consensusSpread))
                        if isfinite(stepRow) && anchorCorrelation>=.6 && gcorrelation>=.6 && ...
                                hypot(gr-stepRow,gc-stepCol)>1.5
                            stepRow=NaN; stepCol=NaN;
                            estimationReason='conflictingImageRepresentations';
                        else
                            stepRow=gr; stepCol=gc; sc=gs;
                            consensusCount=gn; consensusSpread=gspread;
                            anchorCorrelation=gcorrelation;
                            estimationReason=['structural:' greason];
                        end
                    end
                end
                % Biological changes can create a coherent false anchor mode.
                % Cross-check weak/discordant anchors against the untouched
                % preceding frame; keep the immutable anchor for reacquisition.
                if ~isempty(previousRawProc) && ...
                        (~isfinite(stepRow) || anchorCorrelation<.5)
                    [tr,tc,ts,tn,tspread,~,temporalCorrelation]=robustAnchorShift( ...
                        previousRawProc,imProc,subpixel,psrRadius,psrMin,maxshift, ...
                        [0 0],apodize,maxStep);
                    temporalKind='';
                    if ~isfinite(tr)||tn<6||temporalCorrelation<.8||tspread>.3
                        previousEdges=roiExtract.structuralRegistrationImage( ...
                            previousGray,hipasssigma,denoiseSigma,mask);
                        if isempty(movingEdges)
                            movingEdges=roiExtract.structuralRegistrationImage( ...
                                cropCenter(imGrayEst,crop),hipasssigma,denoiseSigma,mask);
                        end
                        [er,ec,es,en,espread,~,ecorrelation]=robustAnchorShift( ...
                            previousEdges,movingEdges,subpixel,psrRadius,psrMin,maxshift, ...
                            [0 0],apodize,maxStep);
                        if isfinite(er)&&en>=6&&ecorrelation>=.8&&espread<=.3
                            tr=er;tc=ec;ts=es;tn=en;tspread=espread;
                            temporalCorrelation=ecorrelation;temporalKind=':structural';
                        end
                    end
                    temporalValid=isfinite(tr)&&isfinite(tc)&&tn>=6&& ...
                        temporalCorrelation>=.8&&tspread<=.3;
                    if temporalValid && (~isfinite(stepRow) || consensusSpread>.5 || ...
                            hypot(stepRow-cumRow-tr,stepCol-cumCol-tc)>.5)
                        stepRow=cumRow+tr; stepCol=cumCol+tc;
                        sc=ts; consensusCount=tn; consensusSpread=tspread;
                        estimationReason=['temporalFallback' temporalKind];
                    elseif ~temporalValid && anchorCorrelation<.2
                        stepRow=NaN; stepCol=NaN;
                        estimationReason='weakAnchorAndTemporalEvidence';
                    end
                end
                anchorValidated=isfinite(stepRow)&&~startsWith(estimationReason,'temporalFallback');
            case 'circshift'
                [stepRow, stepCol, sc] = xcorrShift(refEst, imProc);
            case 'subpixel'
                [stepRow, stepCol, sc] = phasecorrShift(refEst, imProc, subpixel, psrRadius);
            case 'register'
                tform = imregtform(imProc, refEst, 'translation', optimizer, metric);
                stepRow = tform.T(3,2);
                stepCol = tform.T(3,1);
                sc = NaN;
            otherwise
                error('Unknown method: %s', method);
        end
    end
    if doTiming, TT.estimate = TT.estimate + toc(tEst); end

    rawRow = stepRow; rawCol = stepCol;

    % -------- accept / reject --------
    decisionParts = strings(1,0);
    prevCumRow = cumRow;
    prevCumCol = cumCol;

    % warmup
    if cc <= warmupFrames
        stepRow = 0; stepCol = 0;
        decisionParts(end+1) = "warmup";
    end

    % PSR reject (only meaningful for subpixel)
    if strcmpi(method,'subpixel') && psrMin > 0 && ~isnan(sc) && sc < psrMin
        if strcmpi(onReject,'zero')
            stepRow = 0; stepCol = 0;
            decisionParts(end+1) = "psrReject|zero";
        else
            % Holding a trajectory means applying no new incremental step.
            % Repeating the preceding step would keep moving indefinitely.
            if absoluteMode
                stepRow = prevCumRow;
                stepCol = prevCumCol;
            else
                stepRow = 0;
                stepCol = 0;
            end
            decisionParts(end+1) = "psrReject|hold";
        end
    end

    if absoluteMode
        targetRow = stepRow;
        targetCol = stepCol;

        if ~isfinite(targetRow) || ~isfinite(targetCol)
            targetRow = prevCumRow;
            targetCol = prevCumCol;
            decisionParts(end+1) = "invalid:"+string(estimationReason)+"|hold";
        end

        % An absolute outlier must be rejected. Clamping it to the boundary
        % would manufacture a plausible-looking but false correction.
        limitRow = targetRow; limitCol = targetCol;
        if strcmpi(method,'robust')
            % maxshift bounds a new motion, not the lifetime displacement.
            limitRow = targetRow-prevCumRow;
            limitCol = targetCol-prevCumCol;
        end
        if ~isempty(maxshift) && maxshift > 0 && ...
                (abs(limitRow) > maxshift || abs(limitCol) > maxshift)
            targetRow = prevCumRow;
            targetCol = prevCumCol;
            decisionParts(end+1) = "absShiftReject|hold";
        end

        if (cc > 1 || hasPreviousFrame) && ~isempty(maxStep) && maxStep > 0 && ...
                hypot(targetRow-prevCumRow, targetCol-prevCumCol) > maxStep
            targetRow = prevCumRow;
            targetCol = prevCumCol;
            decisionParts(end+1) = "jumpReject|hold";
        end

        cumRow = targetRow;
        cumCol = targetCol;
        stepRow = cumRow - prevCumRow;
        stepCol = cumCol - prevCumCol;
    else
        % Legacy incremental mode: bound only the new residual step.
        if ~isempty(maxshift) && maxshift > 0
            stepRow = max(min(stepRow, maxshift), -maxshift);
            stepCol = max(min(stepCol, maxshift), -maxshift);
        end
        if ~isempty(maxStep) && maxStep > 0
            stepRow = max(min(stepRow, maxStep), -maxStep);
            stepCol = max(min(stepCol, maxStep), -maxStep);
        end
        cumRow = cumRow + stepRow;
        cumCol = cumCol + stepCol;
    end

    % store accepted incremental step, absolute trajectory and diagnostics
    stepRow_hist(cc) = stepRow;
    stepCol_hist(cc) = stepCol;
    score(cc) = sc;
    consensusCount_hist(cc) = consensusCount;
    consensusSpread_hist(cc) = consensusSpread;
    accepted_hist(cc) = isempty(decisionParts);
    if isempty(decisionParts), decision_hist{cc}='ok';
    else, decision_hist{cc}=char(strjoin(decisionParts,"|")); end
    estimation_hist{cc}=estimationReason;
    anchorCorrelation_hist(cc)=anchorCorrelation;
    temporalCorrelation_hist(cc)=temporalCorrelation;
    anchorValidated_hist(cc)=anchorValidated && accepted_hist(cc);
    cumRow_hist(cc) = cumRow;
    cumCol_hist(cc) = cumCol;

    % apply cumulative shift to all channels (output)
    tApp = tic;
    for c = 1:size(list,3)
        fvC = median(list(:,:,c,cc), 'all');
        list(:,:,c,cc) = imtranslate(list(:,:,c,cc), [-cumCol -cumRow], 'linear', 'FillValues', fvC);
    end
    if doTiming, TT.apply = TT.apply + toc(tApp); end

    % update prevProc reference (use corrected frame)
    if ~absoluteMode
        prevCorr = toGray(list(:,:,min(channel,size(list,3)),cc));
        prevProc = preprocess(cropCenter(prevCorr, crop), hipasssigma, apodize, mask);
    end
    if strcmpi(method,'robust')
        previousRawProc=imProc;
        previousGray=cropCenter(imGrayEst,crop);
    end

    % -------- residual effectiveness metric (after correction) --------
    % Measure remaining shift between corrected (t-1) and corrected (t).
    if cc > 1
        tRes = tic;

        A = toGray(list(:,:,min(channel,size(list,3)),cc-1));
        B = toGray(list(:,:,min(channel,size(list,3)),cc));

        A = preprocess(cropCenter(A, crop), hipasssigma, apodize, mask);
        B = preprocess(cropCenter(B, crop), hipasssigma, apodize, mask);

        % residual shift should be near (0,0) if correction is effective
        [rRes, cRes, ~] = phasecorrShift(A, B, true, psrRadius);

        resRow_hist(cc)  = rRes;
        resCol_hist(cc)  = cRes;
        resNorm_hist(cc) = hypot(rRes, cRes);

        if doTiming, TT.residual = TT.residual + toc(tRes); end
    end

    % optional display
    if displayFlag
        imout = imtranslate(imFull, [-cumCol -cumRow]);
        figure, imshowpair(toGray(imFull), toGray(imout));
        title(sprintf('Cumulative drift row=%.3f col=%.3f (step %.3f,%.3f)', cumRow, cumCol, stepRow, stepCol));
    end

    % debug print (per frame)
    if wantObs && (cc == 1 || cc == nT || mod(cc, debugEvery) == 0)
        if isempty(decisionParts), decision = "ok"; else, decision = strjoin(decisionParts,"|"); end

        if cc > 1 && ~isnan(resNorm_hist(cc))
            resStr = sprintf(' residual(row,col)=(%.3g,%.3g)|%.3gpx', resRow_hist(cc), resCol_hist(cc), resNorm_hist(cc));
        else
            resStr = '';
        end

        localDebugPrint(debug, debugFcn, struct('stage','frame'), ...
            sprintf(['[computeDrift] %d/%d frame=%d raw(row,col)=(%.3g,%.3g) step(row,col)=(%.3g,%.3g) ' ...
                     'cum=(%.3g,%.3g)%s PSR=%.3g decision=%s method=%s ref=%s'], ...
                cc, nT, j, rawRow, rawCol, stepRow, stepCol, cumRow, cumCol, resStr, sc, char(decision), method, char(refMode)));
    end

    cc = cc + 1;
end

% ---------- Optional smoothing ----------
% Post-hoc smoothing and re-apply the delta implied by smoothing.
if smoothWin > 1
    switch smoothTarget
        case "step"
            sRow = stepRow_hist; sCol = stepCol_hist;
            if smoothMethod == "median"
                sRow2 = movmedian(sRow, smoothWin);
                sCol2 = movmedian(sCol, smoothWin);
            else
                sRow2 = movmean(sRow, smoothWin);
                sCol2 = movmean(sCol, smoothWin);
            end
            cumRow2 = cumsum(sRow2);
            cumCol2 = cumsum(sCol2);

        otherwise % "cum"
            if smoothMethod == "median"
                cumRow2 = movmedian(cumRow_hist, smoothWin);
                cumCol2 = movmedian(cumCol_hist, smoothWin);
            else
                cumRow2 = movmean(cumRow_hist, smoothWin);
                cumCol2 = movmean(cumCol_hist, smoothWin);
            end
    end

    for kk = 1:nT
        dRow = cumRow2(kk) - cumRow_hist(kk);
        dCol = cumCol2(kk) - cumCol_hist(kk);
        if dRow ~= 0 || dCol ~= 0
            for c = 1:size(list,3)
                fvC = median(list(:,:,c,kk), 'all');
                list(:,:,c,kk) = imtranslate(list(:,:,c,kk), [-dCol -dRow], 'linear', 'FillValues', fvC);
            end
        end
    end

    cumRow_hist = cumRow2;
    cumCol_hist = cumCol2;
    if smoothTarget == "step"
        stepRow_hist = [cumRow_hist(1) diff(cumRow_hist)];
        stepCol_hist = [cumCol_hist(1) diff(cumCol_hist)];
    end

    % NOTE: after smoothing, residual metrics are stale; recompute if you care.
end

% ---------- pack drift ----------
drift.stepRow = stepRow_hist;
drift.stepCol = stepCol_hist;
drift.cumRow  = cumRow_hist;
drift.cumCol  = cumCol_hist;

drift.residualRow  = resRow_hist;
drift.residualCol  = resCol_hist;
drift.residualNorm = resNorm_hist;

% ---------- Write back drift (absolute frames) ----------
% drift.x/y are the correction produced by this run for absolute frames.
% Assign rather than add: extraction always starts from raw frames, so adding
% an older trajectory compounds drift on every replacement run.
for k = 1:nT
    jj = framesid(k);
    drift.x(jj) = -cumRow_hist(k);
    drift.y(jj) = -cumCol_hist(k);
end
if ~isfield(drift,'frames'), drift.frames = []; end
drift.frames = union(drift.frames(:)',framesid(:)');
if ~isfield(drift,'score'), drift.score = nan(size(drift.x)); end
drift.score(framesid) = score;
drift.method = method;
drift.refMode = char(refMode);
drift.referenceFrame = refframeid;
if strcmpi(method,'robust'), drift.shiftLimitScope='step';
elseif absoluteMode, drift.shiftLimitScope='absolute';
else, drift.shiftLimitScope='step'; end
if ~isfield(drift,'accepted'), drift.accepted=false(size(drift.x)); end
if ~isfield(drift,'decision'), drift.decision=repmat({''},size(drift.x)); end
if ~isfield(drift,'estimation'), drift.estimation=repmat({''},size(drift.x)); end
if ~isfield(drift,'consensusCount'), drift.consensusCount=nan(size(drift.x)); end
if ~isfield(drift,'consensusSpread'), drift.consensusSpread=nan(size(drift.x)); end
if ~isfield(drift,'anchorCorrelation'), drift.anchorCorrelation=nan(size(drift.x)); end
if ~isfield(drift,'temporalCorrelation'), drift.temporalCorrelation=nan(size(drift.x)); end
if ~isfield(drift,'anchorValidated'), drift.anchorValidated=false(size(drift.x)); end
drift.accepted(framesid)=accepted_hist;
drift.decision(framesid)=decision_hist;
drift.estimation(framesid)=estimation_hist;
drift.consensusCount(framesid)=consensusCount_hist;
drift.consensusSpread(framesid)=consensusSpread_hist;
drift.anchorCorrelation(framesid)=anchorCorrelation_hist;
drift.temporalCorrelation(framesid)=temporalCorrelation_hist;
drift.anchorValidated(framesid)=anchorValidated_hist;

% ---------- footer timing ----------
if doTiming
    TT.total = toc(tTotal);
    localDebugPrint(debug, debugFcn, struct('stage','end','timing',TT), ...
        sprintf('[computeDrift] DONE frames=%d total=%.2fs | prepRef=%.2fs regCfg=%.2fs load=%.2fs prep=%.2fs estimate=%.2fs apply=%.2fs residual=%.2fs', ...
        nT, TT.total, TT.prepRef, TT.regCfg, TT.load, TT.prep, TT.estimate, TT.apply, TT.residual));
end

if ~isempty(obj)
    obj.drift = drift;
end
end

% ===== Helpers =====

function localDebugPrint(debug, debugFcn, msgStruct, msgLine)
try
    if debug, fprintf('%s\n', msgLine); end
catch
end
if ~isempty(debugFcn)
    try, debugFcn(msgStruct); catch, end
end
end

function y = tern(cond, a, b)
if cond, y = a; else, y = b; end
end

function img = toGray(img)
if ndims(img)==3 && size(img,3)==3
    img = rgb2gray(img);
elseif ndims(img)>2
    img = img(:,:,1);
end
end

function out = cropCenter(im, frac)
if frac==1, out = im; return; end
if ~(frac>0 && frac<=1), error('cropping factor must be ]0,1]'); end
[H,W] = size(im);
h = round(H*frac); w = round(W*frac);
r0 = floor((H-h)/2)+1; c0 = floor((W-w)/2)+1;
out = im(r0:r0+h-1, c0:c0+w-1);
end

function im2 = preprocess(im, hipasssigma, apodize, mask, denoiseSigma)
if nargin<5, denoiseSigma=0; end
im2 = double(im);
if denoiseSigma>0, im2=imgaussfilt(im2,denoiseSigma); end
if hipasssigma>0
    im2 = im2 - imgaussfilt(im2, hipasssigma);
end
if apodize
    persistent win;
    if isempty(win) || ~isequal(size(win), size(im2))
        [H,W] = size(im2);
        wy = hann1d(H);
        wx = hann1d(W);
        win = wy * (wx.');
    end
    im2 = im2 .* win;
end
if ~isempty(mask)
    im2 = im2 .* double(mask);
end
im2 = im2 - mean(im2(:));
s = std(im2(:));
if s>0, im2 = im2./s; end
end

function [row,col,score] = xcorrShift(ref, mov)
c = normxcorr2(ref, mov);
[score, ix] = max(c(:));
[row, col]  = ind2sub(size(c), ix);
row = row - size(ref,1);
col = col - size(ref,2);
end

function [row,col,score] = phasecorrShift(ref, mov, subpixel, psrRadius, shiftLimit, regularize)
if nargin<6, regularize=false; end
if nargin<5 || isempty(shiftLimit) || shiftLimit<=0, shiftLimit=inf; end
FA = fft2(ref);
FB = fft2(mov);
R  = FA.*conj(FB);
if regularize
    % Partial whitening preserves signal strength: full whitening magnifies
    % weak noisy frequencies as much as real structure in evolving images.
    R=R./max(eps,sqrt(abs(R)));
else
    R=R./max(eps,abs(R));
end
r  = real(ifft2(R));

[H,W] = size(r);
ys=0:H-1; ys(ys>H/2)=ys(ys>H/2)-H;
xs=0:W-1; xs(xs>W/2)=xs(xs>W/2)-W;
allowed=abs(ys(:))<=shiftLimit & abs(xs)<=shiftLimit;
search=r; search(~allowed)=-inf;
[peak, ix] = max(search(:));
% Exact periodic ties carry no absolute-position information. Continuity
% chooses the smallest residual after prealignment to the prior estimate.
ties=find(allowed & r>=peak-max(eps,abs(peak)*1e-8));
if numel(ties)>1
    [ty,tx]=ind2sub(size(r),ties);
    [~,nearest]=min(hypot(ys(ty),xs(tx)));
    ix=ties(nearest);
end
[py, px] = ind2sub(size(r), ix);

rad = max(1, round(psrRadius));
maskSB = true(size(r));
rr=mod((py-rad:py+rad)-1,H)+1;
cc=mod((px-rad:px+rad)-1,W)+1;
maskSB(rr,cc) = false;

sb = r(maskSB);
mu = mean(sb);
sd = std(sb);
% Identical textured images have a delta correlation and zero sidelobes:
% that is perfect confidence, rather than a reason to reject the anchor.
score = (peak - mu) / max(sd,eps);

[H,W] = size(r);
dy = py - 1;
dx = px - 1;
if dy > H/2, dy = dy - H; end
if dx > W/2, dx = dx - W; end

row = -dy;
col = -dx;

if subpixel
    row = row - subpixQuad(r, py, px, 1);
    col = col - subpixQuad(r, py, px, 2);
end
end

function [row,col,score,nInliers,spread,reason,anchorCorrelation] = robustAnchorShift(ref, mov, subpixel, psrRadius, psrMin, maxshift, prediction, apodize, stepGate)
%ROBUSTANCHORSHIFT Absolute displacement from a fixed anchor.
% The full-frame estimate is retained as a control. The accepted estimate is
% the spatial consensus of overlapping tiles, which prevents one changing
% biological region or one periodic correlation peak from moving the FOV.

% The reference remains immutable. Prealigning the moving frame makes the
% search a bounded residual around the previous absolute estimate, allowing
% long trajectories without integrating a new unconstrained reference.
[H,W]=size(ref);
refRaw=ref; movRaw=mov;
reason='insufficientTexture';
row=NaN; col=NaN; score=NaN; nInliers=0; spread=NaN;
anchorCorrelation=NaN;
if ~isfinite(std(ref(:))) || ~isfinite(std(mov(:))) || ...
        std(ref(:))<=eps || std(mov(:))<=eps, return; end
mov=imtranslate(mov,[-prediction(2) -prediction(1)],'linear','FillValues',0);
alignedMov=mov;
rr=ceil(max(1,1-prediction(1))):floor(min(H,H-prediction(1)));
cc=ceil(max(1,1-prediction(2))):floor(min(W,W-prediction(2)));
reason='insufficientOverlap';
if numel(rr)<32 || numel(cc)<32, return; end
ref=ref(rr,cc); mov=mov(rr,cc);
rowOrigin=rr(1)-1; colOrigin=cc(1)-1;
validRows=[rr(1) rr(end)]; validCols=[cc(1) cc(end)];
[fullRow, fullCol, fullScore] = phasecorrShift( ...
    localPhaseTile(ref,apodize),localPhaseTile(mov,apodize),subpixel,psrRadius,maxshift,true);

[H,W] = size(ref);
% Local patches keep unchanged texture from being diluted by a large evolving
% region. Sampling spans the entire field and uses no ROI/biological template.
% Tile coordinates belong to the immutable anchor. Moving the grid with the
% overlap/prediction changed which structures voted after added stage motion.
[anchorH,anchorW]=size(refRaw);
tileH=min(anchorH,max(64,min(128,round(anchorH/8))));
tileW=min(anchorW,max(64,min(128,round(anchorW/8))));
rowStarts = unique(round(linspace(1, max(1,anchorH-tileH+1), 6)));
colStarts = unique(round(linspace(1, max(1,anchorW-tileW+1), 6)));

rows = zeros(1, numel(rowStarts)*numel(colStarts));
cols = zeros(size(rows));
scores = zeros(size(rows));
tileRows=zeros(size(rows)); tileCols=zeros(size(rows));
n = 0;
tilePsrMin = max(3, 0.5*max(0,psrMin));
if isempty(maxshift) || ~isfinite(maxshift) || maxshift <= 0
    shiftLimit = inf;
else
    shiftLimit = double(maxshift);
end

for ir = 1:numel(rowStarts)
    rr = rowStarts(ir):(rowStarts(ir)+tileH-1);
    for ic = 1:numel(colStarts)
        cc = colStarts(ic):(colStarts(ic)+tileW-1);
        if rr(1)<validRows(1)||rr(end)>validRows(2)||cc(1)<validCols(1)||cc(end)>validCols(2), continue; end
        refTile = localPhaseTile(refRaw(rr,cc),apodize);
        movTile = localPhaseTile(alignedMov(rr,cc),apodize);
        if std(refTile(:)) < 0.05 || std(movTile(:)) < 0.05
            continue;
        end
        [r,c,s] = phasecorrShift(refTile, movTile, subpixel, psrRadius,maxshift,true);
        pixelQualified=false;
        proposalLimit=maxshift;
        if ~isempty(stepGate) && stepGate>0
            if isempty(maxshift)||maxshift<=0, proposalLimit=stepGate;
            else, proposalLimit=min(maxshift,stepGate); end
        end
        [pr,pc,ps,pixelMatch,pixelUnique]=roiExtract.anchorPatchProposal(refRaw,movRaw, ...
            rowStarts(ir),colStarts(ic),tileH,tileW, ...
            prediction,proposalLimit,psrRadius);
        if pixelMatch>=.25 && ~pixelUnique, continue; end
        if isfinite(pr)&&pixelMatch>=.25&&(ps>=tilePsrMin || pixelMatch>=.6)
            pixelQualified=true;
            pr=pr-prediction(1); pc=pc-prediction(2);
            if ~isfinite(r)||hypot(pr-r,pc-c)>.75, s=ps; end
            r=pr; c=pc;
            % Strong pixel agreement is an independent registration proposal;
            % broad peaks need not meet a Fourier-only PSR threshold.
        end
        if ~isfinite(r) || ~isfinite(c) || ...
                ((~isfinite(s) || s < tilePsrMin) && ~pixelQualified) || ...
                abs(r) > shiftLimit || abs(c) > shiftLimit
            continue;
        end
        n = n + 1;
        rows(n) = r;
        cols(n) = c;
        scores(n) = s;
        tileRows(n)=rowStarts(ir); tileCols(n)=colStarts(ic);
    end
end

rows = rows(1:n);
cols = cols(1:n);
scores = scores(1:n);
row = NaN;
col = NaN;
score = NaN;
nInliers = 0;
spread = NaN;

if n >= 3
    % A bounded mode replaces the unbounded MAD gate: contradictory modes
    % must never manufacture a median displacement supported by no tile.
    radius=1.5;
    supports=zeros(1,n);
    for k=1:n
        supports(k)=nnz(hypot(rows-rows(k),cols-cols(k))<=radius);
    end
    [~,order]=sort(supports,'descend');
    seeds=zeros(0,2); memberships={};
    for k=order
        if supports(k)<3, continue; end
        if ~isempty(seeds) && any(hypot(seeds(:,1)-rows(k),seeds(:,2)-cols(k))<=radius), continue; end
        members=find(hypot(rows-rows(k),cols-cols(k))<=radius);
        seeds(end+1,:)=[median(rows(members)) median(cols(members))]; %#ok<AGROW>
        memberships{end+1}=members; %#ok<AGROW>
    end
    % A global proposal is an extra hypothesis, not an unconditional escape
    % from disagreement. It must pass the same independent tile pixel check.
    if isfinite(fullRow) && isfinite(fullCol) && abs(fullRow)<=shiftLimit && abs(fullCol)<=shiftLimit && ...
            (isempty(seeds) || all(hypot(seeds(:,1)-fullRow,seeds(:,2)-fullCol)>radius))
        seeds(end+1,:)=[fullRow fullCol]; memberships{end+1}=1:n;
    end
    % Test continuity explicitly when Fourier whitening is dominated by
    % changing content. The prior is accepted only if untouched pixels from
    % several tiles validate it, never merely because it is the prior.
    if isempty(seeds) || all(hypot(seeds(:,1),seeds(:,2))>radius)
        seeds(end+1,:)=[0 0]; memberships{end+1}=1:n;
    end
    modes=struct([]);
    motionLimitHit=false;
    for m=1:size(seeds,1)
        % A tile must support the proposal in both Fourier and spatial
        % correlation; global/prior proposals receive a separate pixel check.
        members=memberships{m};
        refinedR=nan(size(members)); refinedC=nan(size(members)); correlations=nan(size(members));
        for k=1:numel(members)
            idx=members(k);
            [refinedR(k),refinedC(k),correlations(k)]=refineAnchorTile(refRaw,movRaw, ...
                tileRows(idx),tileCols(idx),tileH,tileW, ...
                seeds(m,1)+prediction(1),seeds(m,2)+prediction(2),subpixel);
        end
        valid=isfinite(refinedR)&isfinite(refinedC)&correlations>0& ...
            hypot(refinedR-prediction(1)-seeds(m,1),refinedC-prediction(2)-seeds(m,2))<=radius;
        if ~isempty(stepGate) && stepGate>0
            plausible=hypot(refinedR-prediction(1),refinedC-prediction(2))<=stepGate;
            motionLimitHit=motionLimitHit || nnz(valid&~plausible)>=3;
            valid=valid&plausible;
        end
        if nnz(valid)<3, continue; end
        % A handful of strongly persistent patches outweigh many marginal
        % matches in evolving content; confidence is based on pixels only.
        weights=correlations(valid).^4;
        % Count independent support rather than treating one dominant patch
        % and several negligible matches as a quorum. Support must also span
        % the field, excluding a localized moving foreground object.
        effectiveCount=sum(weights)^2/sum(weights.^2);
        significant=weights>=.1*max(weights);
        indices=members(valid); indices=indices(significant);
        centersR=tileRows(indices)+tileH/2;
        centersC=tileCols(indices)+tileW/2;
        span=[max(centersR)-min(centersR),max(centersC)-min(centersC)]./size(refRaw);
        if effectiveCount<2.5 || max(span)<.5 || min(span)<.2, continue; end
        candidate=struct('rows',refinedR(valid),'cols',refinedC(valid), ...
            'scores',scores(members(valid)),'correlations',correlations(valid), ...
            'weight',sum(weights),'row',weightedMedian(refinedR(valid),weights), ...
            'col',weightedMedian(refinedC(valid),weights));
        confidence=weightedMedian(candidate.correlations,weights);
        scatter=weightedMedian(hypot(candidate.rows-candidate.row,candidate.cols-candidate.col),weights);
        % Weak per-patch similarity needs a much larger, tightly agreeing
        % population. Three marginal matches cannot certify absolute motion.
        if confidence<.5 && (effectiveCount<8 || confidence<.25 || scatter>.25), continue; end
        if isempty(modes), modes=candidate; else, modes(end+1)=candidate; end %#ok<AGROW>
    end
    if isempty(modes)
        if motionLimitHit, reason='motionLimit'; else, reason='spatialCheckFailed'; end
        return;
    end
    [~,best]=max([modes.weight]); chosen=modes(best);
    for m=1:numel(modes)
        if m~=best && hypot(modes(m).row-chosen.row,modes(m).col-chosen.col)>radius && ...
                modes(m).weight>=.75*chosen.weight
            reason='ambiguousConsensus'; return;
        end
    end
    row=chosen.row; col=chosen.col;
    nInliers=numel(chosen.rows);
    weights=chosen.correlations.^4;
    spread=weightedMedian(hypot(chosen.rows-row,chosen.cols-col),weights);
    score=median(chosen.scores,'omitnan');
    anchorCorrelation=weightedMedian(chosen.correlations,weights);
    reason='tileConsensus';
    return;
end

% A full-frame fallback is used only when tiling cannot form a consensus.
if isfinite(fullRow) && isfinite(fullCol) && ...
        abs(fullRow) <= shiftLimit && abs(fullCol) <= shiftLimit && ...
        (psrMin <= 0 || (isfinite(fullScore) && fullScore >= psrMin))
    row = fullRow+prediction(1);
    col = fullCol+prediction(2);
    score = fullScore;
    nInliers = 1;
    spread = 0;
    reason='globalFallback';
    [row,col,anchorCorrelation]=refineAnchorTile(refRaw,movRaw,rowOrigin+1,colOrigin+1, ...
        H,W,row,col,subpixel);
    if ~isfinite(row) || ~isfinite(col) || anchorCorrelation<=0
        row=NaN; col=NaN; reason='spatialCheckFailed';
    end
else
    reason='lowConfidence';
end
end

function [row,col,match] = refineAnchorTile(ref,mov,r0,c0,tileH,tileW,estimateRow,estimateCol,subpixel)
[row,col,match]=roiExtract.refineAnchorShift(ref,mov,r0,c0,tileH,tileW,estimateRow,estimateCol,subpixel);
end

function value=weightedMedian(values,weights)
[values,order]=sort(values); weights=weights(order);
idx=find(cumsum(weights)>=sum(weights)/2,1);
value=values(idx);
end

function tile = localPhaseTile(tile,apodize)
tile = double(tile);
[H,W] = size(tile);
if apodize, tile = tile .* (hann1d(H) * hann1d(W).'); end
tile = tile - mean(tile(:));
s = std(tile(:));
if s > 0
    tile = tile ./ s;
end
end

function ofs = subpixQuad(r, py, px, dim)
try
    if dim==1
        before=mod(py-2,size(r,1))+1; after=mod(py,size(r,1))+1;
        y1=r(before,px); y2=r(py,px); y3=r(after,px);
    else
        before=mod(px-2,size(r,2))+1; after=mod(px,size(r,2))+1;
        y1=r(py,before); y2=r(py,px); y3=r(py,after);
    end
    d = (y1 - 2*y2 + y3);
    if abs(d)<1e-12, ofs=0; return; end
    ofs = 0.5*(y1 - y3)/d;
    ofs = max(min(ofs,0.5),-0.5);
catch
    ofs = 0;
end
end

function w = hann1d(n)
if n <= 1, w = 1; return; end
w = 0.5*(1 - cos(2*pi*(0:n-1)/(n-1)));
w = w(:);
end
