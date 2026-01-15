function [list, drift, score] = computeDrift(obj, varargin)
% COMPUTEDRIFT  XY drift correction for a FOV (legacy + block mode).
%
% Incremental (ref=previous): estimate per-frame delta shift, accumulate, apply.
% Robustness: PSR score, maxStep clamp/hold, optional jump gating, warmup ignore,
%             + corrAfter-based gate (tests step=0, step, -step BEFORE accumulating).
%
% Methods:
%   'circshift' : normxcorr2
%   'subpixel'  : phase correlation FFT + optional quadratic subpixel
%   'register'  : imregtform translation (no score)

% ---------- Defaults ----------
method      = 'circshift';
refMode     = '';
channel     = 1;
images      = [];
framesid    = [];
displayFlag = 0;
refimage    = [];
refframeid  = 1;
crop        = 1.0;
subpixel    = false;
maxshift    = 20;
hipasssigma = 3;
apodize     = true;
rollingref  = 0;
mask        = [];

% ---- Robustness ----
warmupFrames = 0;
psrRadius    = 6;
psrMin       = 15;
maxJump      = 3;
rejectMode   = 'hold';

maxStep     = 0.75;    % px
maxStepMode = 'clamp'; % 'clamp' | 'hold'

% ---- Smoothing ----
smoothWin     = 5;
smoothMethod  = 'median';

% ---- Debug/profile ----
debug       = false;
debugEvery  = 10;
debugFcn    = [];
doTiming    = true;

% ---- corrAfter gate ----
corrGateCrop = 0.8;
corrGateTol  = 0.01;

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
        case "refframeid",   refframeid = val;
        case "display",      displayFlag = 1;
        case "crop",         crop = val;
        case "subpixel",     subpixel = logical(val);
        case "maxshift",     maxshift = val;
        case "hipasssigma",  hipasssigma = val;
        case "apodize",      apodize = logical(val);
        case "rollingref",   rollingref = double(val);
        case "mask",         mask = val;

        case "warmupframes", warmupFrames = max(0, round(double(val)));
        case "psrradius",    psrRadius = max(1, round(double(val)));
        case "psrmin",       psrMin = double(val);
        case "maxjump",      maxJump = double(val);
        case "rejectmode",   rejectMode = char(val);

        case "maxstep",      maxStep = double(val);
        case "maxstepmode",  maxStepMode = char(val);

        case "smoothwin",    smoothWin = round(double(val));
        case "smoothmethod", smoothMethod = char(val);

        case "debug",        debug = logical(val);
        case "verbose",      debug = logical(val);
        case "debugevery",   debugEvery = max(1, round(double(val)));
        case "debugfcn",     debugFcn = val;
        case "timing",       doTiming = logical(val);

        case "corrgatecrop", corrGateCrop = double(val);
        case "corrgatetol",  corrGateTol  = double(val);
    end
end

% sanitize ref mode
if isempty(refMode)
    if strcmpi(method,'subpixel')
        refMode = 'previous';
    else
        refMode = 'first';
    end
end
refMode = lower(string(refMode));

% sanitize smoothing
if smoothWin < 0, smoothWin = 0; end
if smoothWin > 0 && mod(smoothWin,2)==0, smoothWin = smoothWin + 1; end
smoothMethod = lower(string(smoothMethod));
if smoothMethod ~= "median" && smoothMethod ~= "mean", smoothMethod = "median"; end

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
    if isempty(framesid)
        framesid = 1:size(list,4);
    end
end

nT = numel(framesid);

stepRow_hist = zeros(1,nT);
stepCol_hist = zeros(1,nT);

% ---------- drift struct ----------
if isempty(obj) || ~isprop(obj,'drift') || isempty(obj.drift)
    drift.x = zeros(1, max(framesid));
    drift.y = zeros(1, max(framesid));
else
    drift = obj.drift;
    if numel(drift.x) < max(framesid)
        drift.x(max(framesid)) = 0; drift.y(max(framesid)) = 0;
    end
end
score = zeros(1, nT);

% ---------- Debug header ----------
if wantObs
    if legacyMode, modeStr = 'legacy'; else, modeStr = 'block'; end
    localDebugPrint(debug, debugFcn, struct('stage','start'), ...
        sprintf(['[computeDrift] mode=%s method=%s ref=%s chan=%s frames=%d crop=%.3g subpixel=%d ' ...
                 'maxshift=%s hipass=%.3g apodize=%d rolling=%.3g mask=%d | ' ...
                 'PSR(rad=%d,min=%.3g) maxJump=%.3g reject=%s | maxStep=%.3g(%s) | warmup=%d | smooth=%d(%s)'], ...
            modeStr, method, char(refMode), mat2str(channel), nT, crop, subpixel, ...
            mat2str(maxshift), hipasssigma, apodize, rollingref, ~isempty(mask), ...
            psrRadius, psrMin, maxJump, rejectMode, maxStep, maxStepMode, warmupFrames, smoothWin, char(smoothMethod)));
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
refGray0 = toGray(refimage);
refProc0 = preprocess(cropCenter(refGray0, crop), hipasssigma, apodize, mask);
tPrepRef = toc(tPrepRef);

% ---------- register config ----------
if strcmpi(method, 'register')
    tRegCfg = tic;
    [optimizer, metric] = imregconfig('monomodal');
    tRegCfg = toc(tRegCfg);
else
    optimizer = []; metric = [];
    tRegCfg = 0;
end

% ---------- timing ----------
if doTiming
    TT = struct('prepRef',tPrepRef,'regCfg',tRegCfg,'load',0,'prep',0,'estimate',0,'apply',0,'rolling',0,'total',0);
else
    TT = [];
end
tTotal = tic;

% ---------- state ----------
prevProc = refProc0;  % used for estimation in previous mode
cumRow = 0; cumCol = 0;

cumRow_hist = zeros(1, nT);
cumCol_hist = zeros(1, nT);

prevStepRow = 0; prevStepCol = 0; hasPrevStep = false;

cc = 1;
prevRawGray = [];
corrBefore_hist = NaN(1,nT);
corrAfter_hist  = NaN(1,nT);

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

    imGray = toGray(imFull);

    % corr BEFORE (raw consecutive)
    if wantObs && cc > 1 && ~isempty(prevRawGray)
        A = cropCenter(double(prevRawGray), corrGateCrop);
        B = cropCenter(double(imGray),      corrGateCrop);
        corrBefore = corr2(A,B);
    else
        corrBefore = NaN;
    end
    corrBefore_hist(cc) = corrBefore;

    % preprocess current
    tPrep = tic;
    imProc = preprocess(cropCenter(imGray, crop), hipasssigma, apodize, mask);
    if doTiming, TT.prep = TT.prep + toc(tPrep); end

    % choose reference for estimation
    if refMode == "first"
        refEst = refProc0;
    else
        if cc == 1
            refEst = imProc; % dummy; step forced to 0
        else
            refEst = prevProc;
        end
    end

    % estimate per-step
    tEst = tic;
    sc = NaN;
    if (cc == 1) && (refMode == "previous")
        stepRow = 0; stepCol = 0; sc = 0;
    else
        switch lower(method)
            case 'circshift'
                [stepRow, stepCol, sc] = xcorrShift(refEst, imProc, false);
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
    rawRow = stepRow;
    rawCol = stepCol;
    if doTiming, TT.estimate = TT.estimate + toc(tEst); end

    % ----- decision accumulator -----
    decisionParts = strings(1,0);

    % warmup
    if cc <= warmupFrames
        stepRow = 0; stepCol = 0;
        decisionParts(end+1) = "warmup";
    end

    % clamp absolute per-step
    if ~isempty(maxshift)
        stepRow = max(min(stepRow, maxshift), -maxshift);
        stepCol = max(min(stepCol, maxshift), -maxshift);
    end

    % maxStep prior (subpixel)
    isPhase = strcmpi(method,'subpixel');
    tooBig = false;
    if isPhase && ~isempty(maxStep) && maxStep > 0
        tooBig = (abs(stepRow) > maxStep) || (abs(stepCol) > maxStep);
        if tooBig
            if strcmpi(string(maxStepMode),"hold")
                stepRow = prevStepRow; stepCol = prevStepCol;
                decisionParts(end+1) = "maxStep|hold";
            else
                stepRow = max(min(stepRow, maxStep), -maxStep);
                stepCol = max(min(stepCol, maxStep), -maxStep);
                decisionParts(end+1) = "maxStep|clamp";
            end
        end
    end

    % jump/psr gating
    jumpBad = hasPrevStep && (abs(stepRow - prevStepRow) > maxJump || abs(stepCol - prevStepCol) > maxJump);
    psrBad  = isPhase && ~isnan(sc) && (sc > 0) && (sc < psrMin);

    accept = true;
    if ~strcmpi(rejectMode,'none')
        if jumpBad && psrBad
            accept = false;
        end
    end

    if ~accept
        if strcmpi(rejectMode,'hold')
            stepRow = prevStepRow; stepCol = prevStepCol;
        elseif strcmpi(rejectMode,'clamp')
            stepRow = prevStepRow + max(min(stepRow - prevStepRow,  maxJump), -maxJump);
            stepCol = prevStepCol + max(min(stepCol - prevStepCol,  maxJump), -maxJump);
        else
            stepRow = prevStepRow; stepCol = prevStepCol;
        end
        decisionParts(end+1) = "reject|" + string(rejectMode);
    end

    % corrAfter-based gate (ref=previous only)
    if refMode == "previous" && cc > 1
        PrevCorr = cropCenter(double(toGray(list(:,:,channel,cc-1))), corrGateCrop);
        fv = median(imGray(:));

        evalCand = @(dRow,dCol) corr2( ...
            PrevCorr, ...
            cropCenter(double(toGray( ...
                imtranslate(imGray, [-(cumCol+dCol) -(cumRow+dRow)], 'linear', 'FillValues', fv) ...
            )), corrGateCrop) ...
        );

        c0 = evalCand(0,0);
        c1 = evalCand(stepRow,  stepCol);
        c2 = evalCand(-stepRow, -stepCol);

        [cBest, kBest] = max([c0 c1 c2]);

        if cBest < (c0 - corrGateTol)
            stepRow = 0; stepCol = 0;
            decisionParts(end+1) = "hold|corrAfterWorse";
        else
            if kBest == 1
                stepRow = 0; stepCol = 0;
                decisionParts(end+1) = "hold|corrAfterBest0";
            elseif kBest == 3
                stepRow = -stepRow; stepCol = -stepCol;
                decisionParts(end+1) = "flip|corrAfterBestNeg";
            else
                decisionParts(end+1) = "ok|corrAfterBest";
            end
        end
    end

    % update per-step state
    prevStepRow = stepRow; prevStepCol = stepCol; hasPrevStep = true;
    stepRow_hist(cc) = stepRow;
    stepCol_hist(cc) = stepCol;

    % accumulate
    cumRow = cumRow + stepRow;
    cumCol = cumCol + stepCol;
    cumRow_hist(cc) = cumRow;
    cumCol_hist(cc) = cumCol;
    score(cc) = sc;

    % apply cumulative shift to all channels
    tApp = tic;
    for c = 1:size(list,3)
        fvC = median(list(:,:,c,cc), 'all');
        list(:,:,c,cc) = imtranslate(list(:,:,c,cc), [-cumCol -cumRow], 'linear', 'FillValues', fvC);
    end
    if doTiming, TT.apply = TT.apply + toc(tApp); end

    % corr AFTER (corrected consecutive)
    if wantObs && cc > 1
        A = cropCenter(double(toGray(list(:,:,channel,cc-1))), corrGateCrop);
        B = cropCenter(double(toGray(list(:,:,channel,cc))),   corrGateCrop);
        corrAfter = corr2(A,B);
    else
        corrAfter = NaN;
    end
    corrAfter_hist(cc) = corrAfter;

    % update estimation reference for next iteration (RAW/EMA processed)
    if refMode == "previous"
        prevProc_new = preprocess(cropCenter(imGray, crop), hipasssigma, apodize, mask);
        if rollingref > 0
            a = rollingref;
            prevProc = (1-a)*prevProc + a*prevProc_new;
        else
            prevProc = prevProc_new;
        end
    end

    % optional display
    if displayFlag
        imout = imtranslate(imFull, [-cumCol -cumRow]);
        figure, imshowpair(toGray(imFull), toGray(imout));
        title(sprintf('Cumulative drift row=%.3f col=%.3f (step %.3f,%.3f)', cumRow, cumCol, stepRow, stepCol));
    end

    % decision string
    if isempty(decisionParts)
        decision = "ok";
    else
        decision = strjoin(decisionParts, "|");
    end

    % debug print
    if wantObs && (cc == 1 || cc == nT || mod(cc, debugEvery) == 0)
        localDebugPrint(debug, debugFcn, struct('stage','frame'), ...
            sprintf(['[computeDrift] %d/%d frame=%d ' ...
                     'raw(row,col)=(%.3g,%.3g) step(row,col)=(%.3g,%.3g) ' ...
                     'cum=(%.3g,%.3g) PSR=%.3g corrBefore=%.3f corrAfter=%.3f ' ...
                     'decision=%s method=%s ref=%s'], ...
                cc, nT, j, ...
                rawRow, rawCol, stepRow, stepCol, ...
                cumRow, cumCol, sc, corrBefore, corrAfter, ...
                char(decision), method, char(refMode)));
    end

    prevRawGray = imGray;
    cc = cc + 1;
end

% drift history
drift.stepRow = stepRow_hist;
drift.stepCol = stepCol_hist;
drift.cumRow  = cumRow_hist;
drift.cumCol  = cumCol_hist;

% ---------- Optional smoothing on cumulative trajectory ----------
if smoothWin > 1
    switch smoothMethod
        case "median"
            cumRow_sm = movmedian(cumRow_hist, smoothWin);
            cumCol_sm = movmedian(cumCol_hist, smoothWin);
        otherwise
            cumRow_sm = movmean(cumRow_hist, smoothWin);
            cumCol_sm = movmean(cumCol_hist, smoothWin);
    end

    for kk = 1:nT
        dRow = cumRow_sm(kk) - cumRow_hist(kk);
        dCol = cumCol_sm(kk) - cumCol_hist(kk);
        if dRow ~= 0 || dCol ~= 0
            for c = 1:size(list,3)
                fvC = median(list(:,:,c,kk), 'all');
                list(:,:,c,kk) = imtranslate(list(:,:,c,kk), [-dCol -dRow], 'linear', 'FillValues', fvC);
            end
        end
        cumRow_hist(kk) = cumRow_sm(kk);
        cumCol_hist(kk) = cumCol_sm(kk);
    end

    drift.cumRow = cumRow_hist;
    drift.cumCol = cumCol_hist;
end

% ---------- Write back drift (absolute frames) ----------
for k = 1:nT
    jj = framesid(k);
    drift.x(jj) = drift.x(jj) + (-cumRow_hist(k));
    drift.y(jj) = drift.y(jj) + (-cumCol_hist(k));
end

% ---------- footer timing ----------
if doTiming
    TT.total = toc(tTotal);
    localDebugPrint(debug, debugFcn, struct('stage','end','timing',TT), ...
        sprintf('[computeDrift] DONE frames=%d total=%.2fs | prepRef=%.2fs regCfg=%.2fs load=%.2fs prep=%.2fs estimate=%.2fs apply=%.2fs rolling=%.2fs', ...
        nT, TT.total, TT.prepRef, TT.regCfg, TT.load, TT.prep, TT.estimate, TT.apply, TT.rolling));
end

if ~isempty(obj)
    obj.drift = drift;
end
end


% ===== Helpers =====

function localDebugPrint(debug, debugFcn, msgStruct, msgLine)
try
    if debug
        fprintf('%s\n', msgLine);
    end
catch
end
if ~isempty(debugFcn)
    try
        debugFcn(msgStruct);
    catch
    end
end
end

function y = tern(cond, a, b)
if cond, y = a; else, y = b; end
end

function img = toGray(img)
if ndims(img)==3 && size(img,3)==3
    img = rgb2gray(img);
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

function im2 = preprocess(im, hipasssigma, apodize, mask)
im2 = double(im);
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

function [row,col,score] = xcorrShift(ref, mov, ~)
c = normxcorr2(ref, mov);
[score, ix] = max(c(:));
[row, col]  = ind2sub(size(c), ix);
row = row - size(ref,1);
col = col - size(ref,2);
end

function [row,col,score] = phasecorrShift(ref, mov, subpixel, psrRadius)
FA = fft2(ref);
FB = fft2(mov);
R  = FA.*conj(FB);
R  = R ./ max(eps, abs(R));
r  = real(ifft2(R));

[peak, ix] = max(r(:));
[py, px] = ind2sub(size(r), ix);

rad = max(1, round(psrRadius));
maskSB = true(size(r));
r1 = max(1, py-rad); r2 = min(size(r,1), py+rad);
c1 = max(1, px-rad); c2 = min(size(r,2), px+rad);
maskSB(r1:r2, c1:c2) = false;

sb = r(maskSB);
mu = mean(sb);
sd = std(sb);
sdFloor = 1e-6;
if sd < sdFloor
    score = 0;
else
    score = (peak - mu) / sd;
end

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

function ofs = subpixQuad(r, py, px, dim)
try
    if dim==1
        if py<=1 || py>=size(r,1), ofs=0; return; end
        y1=r(py-1,px); y2=r(py,px); y3=r(py+1,px);
    else
        if px<=1 || px>=size(r,2), ofs=0; return; end
        y1=r(py,px-1); y2=r(py,px); y3=r(py,px+1);
    end
    d = (y1 - 2*y2 + y3);
    ofs = 0;
    if abs(d)>=1e-12
        ofs = 0.5*(y1 - y3)/d;
        ofs = max(min(ofs,0.5),-0.5);
    end
catch
    ofs = 0;
end
end

function w = hann1d(n)
if n <= 1
    w = 1;
    return;
end
w = 0.5*(1 - cos(2*pi*(0:n-1)/(n-1)));
w = w(:);
end
