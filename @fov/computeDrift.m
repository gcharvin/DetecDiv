function [list, drift, score] = computeDrift(obj, varargin)
% COMPUTEDRIFT  XY drift correction for a FOV (legacy + block mode).
%
% Incremental (Option B): ref=previous aligned frame, estimate delta shift, accumulate.
% Robustness: PSR score, temporal gating, maxStep clamp/hold, warmup ignore, optional smoothing.
%
% Methods:
%   'circshift' : normxcorr2
%   'subpixel'  : phase correlation FFT + optional quadratic subpixel
%   'register'  : imregtform translation (no score)
%
% Key options:
%   'Method'       : 'circshift'|'subpixel'|'register' (default 'circshift')
%   'RefMode'      : 'first'|'previous' (default: 'previous' if method='subpixel', else 'first')
%   'Subpixel'     : true/false (default false)
%   'MaxShift'     : clamp per-step (default 20)
%   'Crop'         : fraction (default 1)
%   'HipassSigma'  : (default 3)
%   'Apodize'      : (default true)
%   'Mask'         : (default [])
%   'RollingRef'   : EMA coeff (0..1) for prev reference (default 0)
%
% Robustness:
%   'WarmupFrames' : ignore correction on first N frames (default 3)
%   'PsrRadius'    : (default 6)
%   'PsrMin'       : (default 15)
%   'MaxJump'      : max change vs previous step to consider "jump" (default 3)
%   'RejectMode'   : 'hold'|'clamp'|'none' (default 'hold')
%   'MaxStep'      : max allowed absolute step magnitude in px (default 0.75)
%   'MaxStepMode'  : 'clamp'|'hold' (default 'clamp')
%
% Smoothing (cumulative):
%   'SmoothWin'    : odd window, 0 disables (default 5)
%   'SmoothMethod' : 'median'|'mean' (default 'median')
%
% Debug:
%   'Debug', 'DebugEvery', 'DebugFcn', 'Timing'

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
psrRadius   = 6;
psrMin      = 15;
maxJump     = 3;
rejectMode  = 'hold';

maxStep     = 0.75;    % px
maxStepMode = 'clamp'; % 'clamp' | 'hold'

% ---- Smoothing ----
smoothWin    = 5;
smoothMethod = 'median';

% ---- Debug/profile ----
debug       = false;
debugEvery  = 10;
debugFcn    = [];
doTiming    = true;



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
    end
end

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

stepRow_hist = zeros(1,numel(framesid));
stepCol_hist = zeros(1,numel(framesid));

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
score = zeros(1, numel(framesid));

% ---------- Debug header ----------
if wantObs
    localDebugPrint(debug, debugFcn, struct('stage','start'), ...
        sprintf('[computeDrift] mode=%s method=%s ref=%s chan=%s frames=%d crop=%.3g subpixel=%d maxshift=%s hipass=%.3g apodize=%d rolling=%.3g mask=%d | PSR(rad=%d,min=%.3g) maxJump=%.3g reject=%s | maxStep=%.3g(%s) | warmup=%d | smooth=%d(%s)', ...
        tern(legacyMode,'legacy','block'), method, char(refMode), mat2str(channel), numel(framesid), crop, subpixel, mat2str(maxshift), hipasssigma, apodize, rollingref, ~isempty(mask), ...
        psrRadius, psrMin, maxJump, rejectMode, maxStep, maxStepMode, warmupFrames, smoothWin, char(smoothMethod)));
end

% ---------- initial reference (only needed as placeholder; previous mode uses prevProc) ----------
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

% ---------- state for incremental mode ----------
prevProc = refProc0;     % previous aligned processed reference (initial)
cumRow = 0; cumCol = 0;

cumRow_hist = zeros(1, numel(framesid));
cumCol_hist = zeros(1, numel(framesid));

prevStepRow = 0; prevStepCol = 0; hasPrevStep = false;

% ---------- loop ----------
cc = 1;
prevRawGray = [];     % previous raw grayscale frame (before correction)
corrBefore_hist = NaN(1, numel(framesid));
corrAfter_hist  = NaN(1, numel(framesid));


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

    % --- correlation BEFORE correction (raw frame-to-frame similarity)
if wantObs && cc > 1 && ~isempty(prevRawGray)
    A = cropCenter(double(prevRawGray), 0.8);
    B = cropCenter(double(imGray),      0.8);
    corrBefore = corr2(A, B);
else
    corrBefore = NaN;
end


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

    % estimate step
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

    % warmup: ignore early unstable frames (focus settling)
    if cc <= warmupFrames
        stepRow = 0; stepCol = 0;
    end

    % clamp per-step absolute
    if ~isempty(maxshift)
        stepRow = max(min(stepRow, maxshift), -maxshift);
        stepCol = max(min(stepCol, maxshift), -maxshift);
    end

    % maxStep (subpixel-grade prior): prevent implausible subpixel jumps
    isPhase = strcmpi(method,'subpixel');
    tooBig=false;
    
    if isPhase && ~isempty(maxStep) && maxStep > 0
        tooBig = (abs(stepRow) > maxStep) || (abs(stepCol) > maxStep);
        if tooBig
            switch lower(string(maxStepMode))
                case "hold"
                    stepRow = prevStepRow; stepCol = prevStepCol;
                otherwise % clamp
                    stepRow = max(min(stepRow, maxStep), -maxStep);
                    stepCol = max(min(stepCol, maxStep), -maxStep);
            end
        end
    end

    % gating: reject only if (jumpBad && psrBad) to avoid freezing
    jumpBad = hasPrevStep && (abs(stepRow - prevStepRow) > maxJump || abs(stepCol - prevStepCol) > maxJump);
    psrBad  = isPhase && ~isnan(sc) && (sc > 0) && (sc < psrMin);

    accept = true;
    if ~strcmpi(rejectMode,'none')
        if jumpBad && psrBad
            accept = false;
        end
    end

    if ~accept
        switch lower(rejectMode)
            case 'hold'
                stepRow = prevStepRow; stepCol = prevStepCol;
            case 'clamp'
                stepRow = prevStepRow + max(min(stepRow - prevStepRow,  maxJump), -maxJump);
                stepCol = prevStepCol + max(min(stepCol - prevStepCol,  maxJump), -maxJump);
            otherwise
                stepRow = prevStepRow; stepCol = prevStepCol;
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
        list(:,:,c,cc) = imtranslate(list(:,:,c,cc), [-cumCol -cumRow], 'linear', 'FillValues', 0);
    end
    if doTiming, TT.apply = TT.apply + toc(tApp); end

    % --- correlation AFTER correction (corrected frame-to-frame similarity)
if wantObs && cc > 1
    A = cropCenter(double(toGray(list(:,:,channel,cc-1))), 0.8);
    B = cropCenter(double(toGray(list(:,:,channel,cc))),   0.8);
    corrAfter = corr2(A, B);
else
    corrAfter = NaN;
end
corrAfter_hist(cc) = corrAfter;


    % update previous reference (aligned current)
   % update previous reference (RAW current frame, NOT aligned)
if refMode == "previous"
    prevProc_new = preprocess(cropCenter(imGray, crop), hipasssigma, apodize, mask);

    if rollingref > 0
        a = rollingref;
        prevProc = (1-a)*prevProc + a*prevProc_new;   % EMA on RAW frames
    else
        prevProc = prevProc_new;
    end
end


    % display
    if displayFlag
        imout = imtranslate(imFull, [-cumCol -cumRow]);
        figure, imshowpair(toGray(imFull), toGray(imout));
        title(sprintf('Cumulative drift row=%.3f col=%.3f (step %.3f,%.3f)', cumRow, cumCol, stepRow, stepCol));
    end

    

decision = "ok";
if cc <= warmupFrames
    decision = "warmup";
end

if isPhase && maxStep > 0 && tooBig
    decision = decision + "|maxStep";
    if strcmpi(maxStepMode,'hold')
        decision = decision + "|hold";
    else
        decision = decision + "|clamp";
    end
end

if ~accept
    decision = decision + "|reject";
    decision = decision + "|" + string(rejectMode);
end


  if wantObs && (cc == 1 || cc == numel(framesid) || mod(cc, debugEvery) == 0)
    localDebugPrint(debug, debugFcn, struct('stage','frame'), ...
        sprintf(['[computeDrift] %d/%d frame=%d ' ...
                 'raw(row,col)=(%.3g,%.3g) step(row,col)=(%.3g,%.3g) ' ...
                 'cum=(%.3g,%.3g) PSR=%.3g corrBefore=%.3f corrAfter=%.3f ' ...
                 'decision=%s method=%s ref=%s'], ...
            cc, numel(framesid), j, ...
            rawRow, rawCol, stepRow, stepCol, ...
            cumRow, cumCol, sc, corrBefore, corrAfter, ...
            char(decision), method, char(refMode)));
end


    prevRawGray = imGray;
    corrBefore_hist(cc) = corrBefore;


    cc = cc + 1;
end

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

    % adjust already-aligned frames by delta between smoothed and raw cumulative
    for cc = 1:numel(framesid)
        dRow = cumRow_sm(cc) - cumRow_hist(cc);
        dCol = cumCol_sm(cc) - cumCol_hist(cc);
        if dRow ~= 0 || dCol ~= 0
            for c = 1:size(list,3)
                list(:,:,c,cc) = imtranslate(list(:,:,c,cc), [-dCol -dRow], 'linear', 'FillValues', 0);
            end
        end
        cumRow_hist(cc) = cumRow_sm(cc);
        cumCol_hist(cc) = cumCol_sm(cc);
    end
end

% ---------- Write back drift (absolute frames) ----------
for k = 1:numel(framesid)
    jj = framesid(k);
    drift.x(jj) = drift.x(jj) + (-cumRow_hist(k));
    drift.y(jj) = drift.y(jj) + (-cumCol_hist(k));
end

% ---------- footer timing ----------
if doTiming
    TT.total = toc(tTotal);
    localDebugPrint(debug, debugFcn, struct('stage','end','timing',TT), ...
        sprintf('[computeDrift] DONE frames=%d total=%.2fs | prepRef=%.2fs regCfg=%.2fs load=%.2fs prep=%.2fs estimate=%.2fs apply=%.2fs rolling=%.2fs', ...
        numel(framesid), TT.total, TT.prepRef, TT.regCfg, TT.load, TT.prep, TT.estimate, TT.apply, TT.rolling));
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
