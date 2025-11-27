function debugCompareTiffH5Samples(classif, N)
% Compare N premiers échantillons TIFF vs HDF5 framebank (mêmes indices)
if nargin < 2, N = 8; end

tp   = classif.trainingParam;
path = classif.path;

% --- TIFF imds ---
foldername = fullfile(path,'trainingdataset','images');
imds = imageDatastore(foldername, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

nTiff = numel(imds.Files);

% --- HDF5 framebank ---
h5File = fullfile(path,[classif.strid '_framebank.h5']);
infoFrames = h5info(h5File, '/frames');
sz = infoFrames.Dataspace.Size;   % [H W C N]
H = sz(1); W = sz(2);
if numel(sz)==3
    C = 1; Nobs = sz(3);
else
    C = sz(3); Nobs = sz(4);
end

N = min([N, nTiff, Nobs]);

fprintf('Comparaison sur %d échantillons (indices 1..%d)\n', N, N);

figure('Name','TIFF vs HDF5 (RAW)','NumberTitle','off');
tiledlayout(N,3,'Padding','compact','TileSpacing','compact');

for k = 1:N
    % --- TIFF ---
    Itiff = imread(imds.Files{k});
    ItiffD = im2double(Itiff);
    % resize au même HxW que le framebank si besoin
    if size(ItiffD,1)~=H || size(ItiffD,2)~=W
        ItiffD = imresize(ItiffD,[H W]);
    end

    % --- HDF5 ---
    start = [1 1 1 k];
    count = [H W C 1];
    Ih5 = h5read(h5File,'/frames',start,count);
    Ih5 = squeeze(Ih5);
    Ih5D = im2double(Ih5);

    % Si multi-canal, on peut prendre le canal 1 pour la comparaison brute
    if ndims(ItiffD)==3 && size(ItiffD,3)>1
        ItiffCmp = ItiffD(:,:,1);
    else
        ItiffCmp = ItiffD;
    end
    if ndims(Ih5D)==3 && size(Ih5D,3)>1
        Ih5Cmp = Ih5D(:,:,1);
    else
        Ih5Cmp = Ih5D;
    end

    % --- métriques ---
    diff = ItiffCmp - Ih5Cmp;
    mseVal = mean(diff(:).^2);
    maxAbs = max(abs(diff(:)));

    fprintf('Idx %d: MSE=%.3g, max|diff|=%.3g, ', k, mseVal, maxAbs);
    fprintf('TIFF [%.3g %.3g], H5 [%.3g %.3g]\n', ...
        min(ItiffCmp(:)), max(ItiffCmp(:)), ...
        min(Ih5Cmp(:)),   max(Ih5Cmp(:)));

    % --- affichage ---
    nexttile(3*k-2);
    imshow(ItiffCmp,[]); title(sprintf('TIFF #%d',k));

    nexttile(3*k-1);
    imshow(Ih5Cmp,[]);   title(sprintf('H5 #%d',k));

    nexttile(3*k);
    imshow(diff,[]);     title('Diff TIFF-H5');
end
end
