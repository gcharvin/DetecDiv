function I = CNN_photometricReadFcn(filename, trainingParam)
I = imread(filename);
I = photometricJitter(I, trainingParam);
end

function Iout = photometricJitter(Iin, trainingParam)
% Photometric jitter paramétrique : contraste, brightness, gamma,
% saturation, hue, bruit, defocus.
I = im2double(Iin);
isRGB = (ndims(I)==3) && (size(I,3)==3);

cr  = trainingParam.CNN_contrast_range;
br  = trainingParam.CNN_brightness_range;
gr  = trainingParam.CNN_gamma_range;
sr  = trainingParam.CNN_saturation_range;
hd  = trainingParam.CNN_hue_delta;
ns  = trainingParam.CNN_noise_sigma;
dsr = trainingParam.CNN_defocus_sigma_range;
dp  = trainingParam.CNN_defocus_prob;

% 1) Contraste + brightness : I*alpha + beta
alpha = cr(1) + (cr(2)-cr(1))*rand();
beta  = br(1) + (br(2)-br(1))*rand();
I = I .* alpha + beta;
I = max(min(I,1),0);

% 2) Gamma
gammaVal = gr(1) + (gr(2)-gr(1))*rand();
I = I .^ gammaVal;
I = max(min(I,1),0);

% 3) Saturation + Hue (RGB uniquement)
if isRGB
    HSV = rgb2hsv(I);

    % Saturation
    satJit = sr(1) + (sr(2)-sr(1))*rand();
    HSV(:,:,2) = max(min(HSV(:,:,2)*satJit,1),0);

    % Hue
    if hd > 0
        dH = (2*rand()-1)*hd;
        H  = HSV(:,:,1) + dH;
        H  = H - floor(H); % wrap [0,1)
        HSV(:,:,1) = H;
    end

    I = hsv2rgb(HSV);
    I = max(min(I,1),0);
end

% 4) Bruit gaussien
if ns > 0 && rand < 0.7
    I = I + ns * randn(size(I));
    I = max(min(I,1),0);
end

% 5) Defocus léger (blur gaussien)
smin = max(0, dsr(1));
smax = max(smin, dsr(2));
if smax > 0 && rand < dp
    sigma = smin + (smax - smin)*rand();
    if sigma > 0
        ksz   = max(3, 2*ceil(2*sigma)+1);
        I     = imgaussfilt(I, sigma, 'FilterSize', ksz);
    end
end

Iout = im2uint8(max(min(I,1),0));
end