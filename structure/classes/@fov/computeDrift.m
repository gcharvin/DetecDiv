function [list, drift, score] = computeDrift(obj, varargin)
% COMPUTEDRIFT  Simple + robust XY drift correction for a FOV (legacy + block mode)
% + per-frame residual effectiveness metric.
%
% Key points:
%   - refMode='previous' estimates a *residual* step in a stabilized reference frame
%     (current pre-aligned by the previous cumulative drift).
%   - Handles block processing: if obj.drift exists and framesid(1)>1, we seed the
%     initial cumulative drift from the previous absolute frame, so blocks stitch.
%   - Logs residual drift after correction at each frame:
%       residual(row,col) and residualNorm (px)
%
% Methods:
%   'circshift' : normxcorr2 (integer px)
%   'subpixel'  : phase correlation FFT + optional quadratic subpixel
%   'register'  : imregtform translation (no score)

% ---------- Defaults ----------
method      = 'subpixel';
refMode     = 'previous';
channel     = 1;
images      = [];
framesid    = [];
displayFlag = 0;
refimage    = [];
refframeid  = 1;
crop        = 1.0;
subpixel    = true;
maxshift    = 20;     % hard per-frame clamp (catastrophic protection)
hipasssigma = 3;
apodize     = true;
mask        = [];

% ---- Robustness (simple) ----
warmupFrames = 0;
psrRadius    = 6;
psrMin       = 10;      % 0 => no PSR reject
maxStep      = 10;      % physically plausible per-frame step (px); 0 => off
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

% sanitize ref mode
if isempty(refMode)
    if strcmpi(method,'subpixel'), refMode = 'previous';
    else,                          refMode = 'first';
    end
end
refMode = lower(string(refMode));

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
refGray0 = toGray(refimage);
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

% ---- Seed cumRow/cumCol from obj.drift for block stitching ----
% drift.x/y store cumulative *applied correction* (in old code: drift.x += -cumRow).
% We invert: cumRow0 = -drift.x(prevAbsFrame), cumCol0 = -drift.y(prevAbsFrame)
if stitchFromObjDrift && ~legacyMode && refMode == "previous" && ~isempty(obj) ...
        && isprop(obj,'drift') && ~isempty(obj.drift) && isstruct(obj.drift) ...
        && isfield(obj.drift,'x') && isfield(obj.drift,'y') ...
        && ~isempty(framesid) && framesid(1) > 1

    prevAbs = framesid(1) - 1;
    if numel(obj.drift.x) >= prevAbs && numel(obj.drift.y) >= prevAbs
        cumRow = -double(obj.drift.x(prevAbs));
        cumCol = -double(obj.drift.y(prevAbs));
    end
end

% prevProc in corrected reference space (for refMode='previous')
prevProc = preprocess(cropCenter(refGray0, crop), hipasssigma, apodize, mask);

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

    imGray = toGray(imFull);

    % -------- build estimation image in a stable reference frame --------
    % Pre-align current raw frame by previous cumulative drift (global space).
    if cc > 1 && refMode == "previous"
        fv0 = median(imGray(:));
        imGrayEst = imtranslate(imGray, [-cumCol -cumRow], 'linear', 'FillValues', fv0);
    else
        % IMPORTANT: for cc==1 in a stitched block, we still want imGrayEst to be in
        % the global corrected space, otherwise the first corrected frame won't match
        % previous block. So if cum != 0, apply it even at cc==1.
        if (cc == 1) && (refMode == "previous") && (cumRow ~= 0 || cumCol ~= 0)
            fv0 = median(imGray(:));
            imGrayEst = imtranslate(imGray, [-cumCol -cumRow], 'linear', 'FillValues', fv0);
        else
            imGrayEst = imGray;
        end
    end

    % preprocess for estimation
    tPrep = tic;
    imProc = preprocess(cropCenter(imGrayEst, crop), hipasssigma, apodize, mask);
    if doTiming, TT.prep = TT.prep + toc(tPrep); end

    % choose reference for estimation
    if refMode == "first"
        refEst = preprocess(cropCenter(refGray0, crop), hipasssigma, apodize, mask);
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
    if (cc == 1) && (refMode == "previous")
        stepRow = 0; stepCol = 0; sc = 0;
    else
        switch lower(method)
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

    % -------- accept / clamp (simple) --------
    decisionParts = strings(1,0);

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
            stepRow = stepRow_hist(max(1,cc-1));
            stepCol = stepCol_hist(max(1,cc-1));
            decisionParts(end+1) = "psrReject|hold";
        end
    end

    % catastrophic clamp
    if ~isempty(maxshift) && maxshift > 0
        stepRow = max(min(stepRow, maxshift), -maxshift);
        stepCol = max(min(stepCol, maxshift), -maxshift);
    end

    % physical clamp
    if ~isempty(maxStep) && maxStep > 0
        stepRow = max(min(stepRow, maxStep), -maxStep);
        stepCol = max(min(stepCol, maxStep), -maxStep);
    end

    % store step + score
    stepRow_hist(cc) = stepRow;
    stepCol_hist(cc) = stepCol;
    score(cc) = sc;

    % integrate cumulative drift
    cumRow = cumRow + stepRow;
    cumCol = cumCol + stepCol;
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
    if refMode == "previous"
        prevCorr = toGray(list(:,:,min(channel,size(list,3)),cc));
        prevProc = preprocess(cropCenter(prevCorr, crop), hipasssigma, apodize, mask);
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
% drift.x/y are "global correction" histories stored over absolute frames.
for k = 1:nT
    jj = framesid(k);
    drift.x(jj) = drift.x(jj) + (-cumRow_hist(k));
    drift.y(jj) = drift.y(jj) + (-cumCol_hist(k));
end

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

function [row,col,score] = xcorrShift(ref, mov)
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
if sd < 1e-6
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
