function param = score_setDisplayParameters(varargin)
% score_setDisplayParameters - Initialise et retourne une structure de paramètres
%
% Cette fonction initialise les paramètres par défaut puis les met à jour
% en fonction des paires clé/valeur fournies en arguments.

% Initialisation des variables par défaut
tabTitle      = 0;                % Titre de l'onglet
shiftY        = [];               % Décalage vertical de l'image pour l'affichage d'infos (titre, etc.)
hideStamp     = false;            % Masquer le timestamp dans le film si true
crop          = [];               % Fenêtre de rognage
arraySize     = [];               % Taille du tableau de ROIs (lignes x colonnes)
snapRate      = [];               % Taux d'affichage relatif des images pour les différents canaux
scalingFactor = 1;                % Facteur de redimensionnement pour l'affichage
name          = [];               % Nom du fichier de sortie
ips           = 10;               % Vitesse d'affichage du film (images par seconde)
framerate     = 5;                % Vitesse d'acquisition (images par minute)
channel       = {};               % Liste des canaux à afficher
fontsize      = 12;               % Taille de police pour le texte sur la séquence ou le film
levels        = [];               % Cell array indiquant les niveaux pour chaque canal et infos complémentaires
titleStr      = [];               % Titre utilisé pour le film ou la séquence
rotate        = [];               % Indique s'il faut pivoter l'image et de combien
imageSize     = [];               % Redimensionnement de l'image à la taille finale
timeOffset    = false;            % Indique si le timestamp doit être décalé par rapport à la première image
weights       = [];               % Poids respectifs des canaux pour le mélange d'images
paintChannel  = 0;                % Canal indexé à afficher en "peint"
defaultClass  = 0;                % Indique si la classe '1' correspond au fond ou non
textColor     = [1 1 1];          % Couleur du texte (défaut blanc)
roiTitle      = false;            % Indique si le titre ROI doit être affiché
flip          = 0;                % Indique si l'image doit être inversée (split left/right)
rgb           = {};               % Cell array indiquant les valeurs RGB pour chaque canal
output      = "Sequence";       % Mode d'affichage : 'Sequence', 'Movie' ou 'Display'
background    = [0 0 0];          % Couleur de fond (défaut noir)
overlayMode   = false;            % Mode overlay désactivé par défaut
refresh       = false;            % false pour un affichage rapide, 'slow' pour reconstruire la figure
frames        = [];               % Liste des frames à traiter
nbrick = 1; 



% Parcours des arguments en paires (clé, valeur)
nArgs = length(varargin);
i = 1;
while i <= nArgs
    

    if ischar(varargin{i})
       
        switch varargin{i}
            case 'Frames'
                frames = varargin{i+1};  i = i + 2;
            case 'Name'
                name = varargin{i+1};  i = i + 2;
            case 'IPS'
                ips = varargin{i+1};  i = i + 2;
            case 'Framerate'
                framerate = varargin{i+1};  i = i + 2;
            case 'SnapRate'
                snapRate = varargin{i+1};  i = i + 2;
            case 'Channel'
                channel = varargin{i+1};  i = i + 2;
                if isempty(channel)
                    disp('Channel is not found; quitting!');
                    return;
                end
            case 'FontSize' 
                fontsize = varargin{i+1};  i = i + 2;
            case 'Levels'
                levels = varargin{i+1};  i = i + 2;
            case 'Title'
                titleStr = varargin{i+1};  i = i + 2;
            case 'Rotate'
                rotate = varargin{i+1};  i = i + 2;
            case 'ImageSize'
                imageSize = varargin{i+1};  i = i + 2;
            case 'TimeOffset'
                timeOffset = varargin{i+1};  i = i + 2;
            case 'Weights'
                
                weights = varargin{i+1};  i = i + 2;
            case 'PaintChannel'
                paintChannel = varargin{i+1};  i = i + 2;
            case 'DefaultClass' 
                defaultClass = true;  i = i + 1;
            case 'ROITitle'
                roiTitle = true;  i = i + 1;
            case 'Flip'
                flip = true;  i = i + 1;
            case 'RGB'
                rgb = varargin{i+1};  i = i + 2;
            case 'Output'
                output = varargin{i+1};  i = i + 2;
            case 'Background'
                background = varargin{i+1};  i = i + 2;
            case 'Text'
                textColor = varargin{i+1};  i = i + 2;
            case 'Overlay'
                overlayMode =varargin{i+1};  i = i + 2;
            case 'Refresh'
                refresh = true;  i = i + 1;
            case 'Crop'
                crop = varargin{i+1};  i = i + 2;
            case 'ArraySize'
                arraySize = varargin{i+1};  i = i + 2;
            case 'HideStamp'
                hideStamp = varargin{i+1};  i = i + 2;
                if hideStamp
                    shiftY = 1;
                end
            case 'ScalingFactor'
                scalingFactor = varargin{i+1};  i = i + 2;
                 case 'Nbrick'
                nbrick = varargin{i+1};  i = i + 2;  
            otherwise
                disp(['Unknown parameter: ', varargin{i}]);
                i=i+1;
        end
       
    else
        i = i + 1;
    end
end

% Si snapRate n'est pas défini, on le définit en fonction du nombre de canaux
if isempty(snapRate)
    snapRate = ones(1, numel(channel));
end

% Construction de la structure en assignant chaque champ individuellement
param = struct();
param.tabTitle      = tabTitle;
param.shiftY        = shiftY;
param.hideStamp     = hideStamp;
param.crop          = crop;
param.arraySize     = arraySize;
param.snapRate      = snapRate;
param.scalingFactor = scalingFactor;
param.name          = name;
param.ips           = ips;
param.framerate     = framerate;
param.channel       = channel;
param.fontsize      = fontsize;
param.levels        = levels;
param.titleStr      = titleStr;
param.rotate        = rotate;
param.imageSize     = imageSize;
param.timeOffset    = timeOffset;
param.weights       = weights;
param.paintChannel  = paintChannel;
param.defaultClass  = defaultClass;
param.textColor     = textColor;
param.roiTitle      = roiTitle;
param.flip          = flip;
param.rgb           = rgb;
param.output      = output;
param.background    = background;
param.overlayMode   = overlayMode;
param.refresh       = refresh;
param.frames        = frames;
param.nbrick = nbrick;
end
