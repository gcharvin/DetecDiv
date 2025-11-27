function [list, drift, score] = computeDrift(obj, varargin)
% COMPUTEDRIFT  XY drift correction for a FOV (legacy + block mode).
% Usage legacy:
%   list = obj.computeDrift('framesid', 1:100, 'channel', 1, 'method','circshift', ...)
%   (lit via obj.readImage et renvoie list corrigée par circshift)
%
% Usage bloc (recommandé pour extractAllROICrops):
%   [list_aligned, drift] = obj.computeDrift('images', blockImg, 'channel', refChanLocal, 'framesid', frameBatch, ...)
%   où blockImg: HxWxCselxTblock (uint16/…)
%
% Nouveaux options (compatibles):
%   'subpixel'      (logical, default false)   % sub-pixel via phase corr quad
%   'maxshift'      (double | [], default 20)  % borne de déplacement px ( [] = off )
%   'hipasssigma'   (double >=0, default 3)    % 0=off (HPF)
%   'apodize'       (logical, default true)    % fenêtre Hann bordure
%   'rollingref'    (0..1, default 0)          % EMA sur ref (0=off)
%   'mask'          (HxW logical, default [])  % pondération (optionnel)

% ---------- Defaults ----------
method      = 'circshift';   % 'circshift' | 'subpixel' | 'register'
channel     = 1;
images      = [];            % HxWxCxT (si vide: legacy -> readImage)
framesid    = [];            % frames absolues; si vide et images fourni: 1:T
displayFlag = 0;
refimage    = [];            % override ref frame content
refframeid  = 1;
crop        = 1.0;
fov         = [];            % juste pour logs
subpixel    = false;
maxshift    = 20;
hipasssigma = 3;
apodize     = true;
rollingref  = 0;
mask        = [];

for i = 1:2:numel(varargin)
    key = lower(string(varargin{i}));
    val = varargin{i+1};
    switch key
        case "method",       method = char(val);
        case "channel",      channel = val;
        case "images",       images = val;
        case "framesid",     framesid = val;
        case "refimage",     refimage = val;
        case "refframeid",   refframeid = val;
        case "display",      displayFlag = 1;
        case "fov",          fov = val;
        case "crop",         crop = val;
        case "subpixel",     subpixel = logical(val);
        case "maxshift",     maxshift = val;
        case "hipasssigma",  hipasssigma = val;
        case "apodize",      apodize = logical(val);
        case "rollingref",   rollingref = val;
        case "mask",         mask = val;
    end
end

% ---------- Prepare legacy/blk paths ----------
legacyMode = isempty(images);  % si pas d'images 4D → on lira via readImage
if legacyMode
    if isempty(framesid)
        framesid = 1:numel(obj.srclist{1});
    end
    % alloue cube local (H W C T) minimal pour compatibilité
    testIm = obj.readImage(framesid(1), channel);
    [H,W] = size(testIm);
    list = zeros(H, W, 1, numel(framesid), class(testIm));
else
    list = images; % H W C T
    if isempty(framesid)
        framesid = 1:size(list,4);
    end
end

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
score = zeros(1, numel(framesid)); % qualité (corr peak)

% ---------- reference image ----------
if isempty(refimage)
    if legacyMode
        refimage = obj.readImage(refframeid, channel);
    else
        refimage = list(:,:,channel,1);
    end
end
refimage = toGray(refimage);
refimage = cropCenter(refimage, crop);
refimage = preprocess(refimage, hipasssigma, apodize, mask);

% ---------- method 'register' config ----------
if strcmpi(method, 'register')
    [optimizer, metric] = imregconfig('monomodal');
end

% ---------- Loop frames ----------
cc = 1;
for j = framesid
    if legacyMode
        im = obj.readImage(j, channel);
        list(:,:,1,cc) = im; % charge pour appli de shift homogène
    else
        im = list(:,:,channel,cc);
    end

    im_orig = im;
    im = toGray(im);
    im = cropCenter(im, crop);
    im = preprocess(im, hipasssigma, apodize, mask);

    switch lower(method)
        case 'circshift'
            % corrélation croisée sur patch central (normxcorr2)
            [row, col, sc] = xcorrShift(refimage, im, subpixel); % subpixel ne change rien ici
        case 'subpixel'
            % phase correlation + ajustement quadratique 1D
            [row, col, sc] = phasecorrShift(refimage, im, subpixel);
        case 'register'
            tform = imregtform(im, refimage, 'translation', optimizer, metric);
            row = tform.T(3,2); col = tform.T(3,1);
            sc  = 1; % pas de score direct
        otherwise
            error('Unknown method: %s', method);
    end

    % clamp
    if ~isempty(maxshift)
        row = max(min(row, maxshift), -maxshift);
        col = max(min(col, maxshift), -maxshift);
    end

    % applique le shift (tous canaux, frame cc)
    for c = 1:size(list,3)
        list(:,:,c,cc) = imtranslate(list(:,:,c,cc), [-col -row], 'linear', 'FillValues', 0);
    end

    if displayFlag
        imout = imtranslate(im_orig, [-col -row]);
        figure, imshowpair(toGray(im_orig), toGray(imout)); title(sprintf('Drift row=%.3f col=%.3f', row, col));
    end

    drift.x(j) = drift.x(j) + (-row);
    drift.y(j) = drift.y(j) + (-col);
    score(cc)  = sc;

    % rolling reference (EMA) sur la ref
    if rollingref > 0
        movAligned = imtranslate(toGray(im_orig), [-col -row], 'linear', 'FillValues', 0);
        movAligned = cropCenter(movAligned, crop);
        movAligned = preprocess(movAligned, hipasssigma, apodize, mask);
        a = rollingref;  refimage = (1-a)*refimage + a*movAligned;
    end

    cc = cc + 1;
end

% ---------- save back drift in obj if applicable ----------
if ~isempty(obj)
    obj.drift = drift;
end

end

% ===== Helpers =====
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
    if hipasssigma>0, im2 = im2 - imgaussfilt(im2, hipasssigma); end
    if apodize
        persistent win; 
        if isempty(win) || ~isequal(size(win), size(im2))
        [H,W] = size(im2);
wy = hann1d(H);      % Hx1 (colonne)
wx = hann1d(W);      % Wx1 (colonne)
win = wy * (wx.');   % HxW outer product
        end
        im2 = im2 .* win;
    end
    if ~isempty(mask), im2 = im2 .* double(mask); end
    im2 = im2 - mean(im2(:));
    s = std(im2(:)); if s>0, im2 = im2./s; end
end
function [row,col,score] = xcorrShift(ref, mov, ~)
    c = normxcorr2(ref, mov);
    [score, ix] = max(c(:));
    [row, col]  = ind2sub(size(c), ix);
    row = row - size(ref,1);
    col = col - size(ref,2);
end
function [row,col,score] = phasecorrShift(ref, mov, subpixel)
    FA = fft2(ref); FB = fft2(mov);
    R  = FA.*conj(FB); R = R ./ max(eps, abs(R));
    r  = real(ifft2(R));
    [score, ix] = max(r(:)); [py,px]=ind2sub(size(r),ix);
    [H,W] = size(r);
    if py>H/2, py=py-H; end
    if px>W/2, px=px-W; end
    row = py; col = px;
    if subpixel
        row = row + subpixQuad(r, py, px, 1);
        col = col + subpixQuad(r, py, px, 2);
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
        ofs = 0; if abs(d)>=1e-12, ofs = 0.5*(y1 - y3)/d; ofs = max(min(ofs,0.5),-0.5); end
    catch, ofs = 0; end
end
function w = hann1d(n)
    if n <= 1
        w = 1;      % 1x1 OK
        return;
    end
    w = 0.5*(1 - cos(2*pi*(0:n-1)/(n-1)));
    w = w(:);       % <- vecteur colonne (n x 1)
end