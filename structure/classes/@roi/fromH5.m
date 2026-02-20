function r = fromH5(h5file, varargin)
% r = roi.fromH5(h5file, 'headerOnly',true)
p = inputParser;
p.addParameter('headerOnly', true, @(x)islogical(x)||ismember(x,[0 1]));
p.parse(varargin{:});
headerOnly = logical(p.Results.headerOnly);

info = h5info(h5file);
[pth, base, ~] = fileparts(h5file);

r = roi();                 % constructeur par défaut
r.path  = pth;
r.name  = base;
r.h5path = h5file;

% id depuis le nom "im_<id>.h5"
tok = regexp(base,'^im_(?<id>.+)$','names');
if ~isempty(tok)
    try
        idnum = str2double(tok.id);
        r.id = isnan(idnum) ? tok.id : idnum; %#ok<*COLND>
    catch
        r.id = tok.id;
    end
end

% Lister datasets (sans lire pixels)
ds = cell(0,1);
for di = 1:numel(info.Datasets), ds{end+1,1} = info.Datasets(di).Name; end %#ok<AGROW>
for gi = 1:numel(info.Groups)
    G = info.Groups(gi);
    for di = 1:numel(G.Datasets), ds{end+1,1} = [G.Name '/' G.Datasets(di).Name]; end %#ok<AGROW>
end
if isprop(r,'datasets'), r.datasets = ds; end

% Dimensions depuis dataset de référence
ref = roiio.chooseRefDataset(info);
if ~isempty(ref) && isprop(r,'size')
    r.size = ref.Dataspace.Size;
end

% Attributs display globaux (si tu en as à la racine)
if isprop(r,'display')
    d = struct();
    d.rgb        = roiio.readAttOrDefault(h5file,'/','display_rgb',      []);
    d.intensity  = roiio.readAttOrDefault(h5file,'/','display_intensity',[]);
    d.displaylim = roiio.readAttOrDefault(h5file,'/','display_displaylim',[]);
    d.indexed    = roiio.readAttOrDefault(h5file,'/','display_indexed',  []);
    d.alpha      = roiio.readAttOrDefault(h5file,'/','display_alpha',    []);
    d.contour    = roiio.readAttOrDefault(h5file,'/','display_contour',  []);
    d.width      = roiio.readAttOrDefault(h5file,'/','display_contourwidth',[]);
    d.frame      = roiio.readAttOrDefault(h5file,'/','display_frame',    1);
    d.binning    = roiio.readAttOrDefault(h5file,'/','display_binning',  1);
    % Construire un display minimal cohérent si vide
    if isempty(d.rgb) || isempty(d.intensity)
        % Essai: reconstruire via datasets
        N = max(1, numel(info.Datasets));  % nb canaux logiques approx
        C = N;                              % sous-canaux inconnu -> approx
        r.display = roiio.defaultDisplay(N, C);
        r.display.frame   = d.frame;
        r.display.binning = d.binning;
    else
        r.display = d; % sera fusionné par roi.load si nécessaire
    end
end

% Pas d'image ni channelid en headerOnly
if ~headerOnly
    % recharge complet via API existante
    r.load(); % ou r.load("") -> full
else
    r.image = [];
    if isprop(r,'channelid'), r.channelid = 1; end
end
end
