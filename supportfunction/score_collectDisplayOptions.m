function param = collectDisplayOptions(varargin)
% collectDisplayOptions Collecte et valide les paramètres d'affichage.
%
%   param = collectDisplayOptions('Param1', value1, ...)
%
% Cette fonction initialise une structure de paramètres avec des valeurs par
% défaut et met à jour ces valeurs en fonction des paires clé/valeur fournies.
%
% Paramètres généraux :
%   mode          : Mode d'affichage ('sequence', 'display', 'movie') (défaut : 'sequence')
%   Nrow          : Nombre de lignes de ROIs (pour sequence/movie) (défaut : 2)
%   Ncol          : Nombre de colonnes de ROIs (pour sequence/movie) (défaut : 2)
%   Nchannel      : Nombre de canaux par ROI (défaut : 3)
%   Nframes       : Nombre de frames (dimension temporelle) (défaut : 10)
%   Ndataseries  : Nombre de lignes pour les séries temporelles (défaut : 0)
%   Nbrick        : Nombre de cellules à occuper par image dans le tiledlayout (défaut : 1)
%   overlay       : Mode overlay pour combiner les canaux (défaut : false)
%   debug         : Active les messages de debug (défaut : false)
%
% Paramètres additionnels :
%   tabTitle      : Titre de l'onglet (défaut : 0)
%   shiftY        : Décalage vertical pour l'affichage d'infos (défaut : [])
%   hideStamp     : Masquer le timestamp (défaut : false)
%   crop          : Fenêtre de rognage (défaut : [])
%   arraySize     : Taille du tableau de ROIs (défaut : [])
%   snapRate      : Taux d'affichage relatif des images pour les canaux (défaut : [])
%   scalingFactor : Facteur de redimensionnement (défaut : 1)
%   Name          : Nom du fichier de sortie (défaut : [])
%   IPS           : Vitesse d'affichage du film (défaut : 10)
%   Framerate     : Vitesse d'acquisition (défaut : 5)
%   Channel       : Liste des canaux à afficher (défaut : {})
%   FontSize      : Taille de police pour le texte (défaut : 12)
%   Levels        : Niveaux pour chaque canal (défaut : [])
%   Title         : Titre utilisé pour le film ou la séquence (défaut : [])
%   Rotate        : Angle de rotation de l'image (défaut : [])
%   ImageSize     : Taille finale de l'image (défaut : [])
%   TimeOffset    : Décalage du timestamp (défaut : false)
%   Weights       : Poids des canaux pour le mélange (défaut : [])
%   PaintChannel  : Canal indexé à afficher en "peint" (défaut : 0)
%   DefaultClass  : Indique si la classe '1' correspond au fond (défaut : 0)
%   Text          : Couleur du texte (défaut : [1 1 1])
%   ROITitle      : Affichage du titre ROI (défaut : false)
%   Flip          : Inversion de l'image (défaut : 0)
%   RGB           : Valeurs RGB pour chaque canal (défaut : {})
%   Output        : Mode d'affichage ('Sequence', 'Movie', 'Display') (défaut : 'Sequence')
%   Background    : Couleur de fond (défaut : [0 0 0])
%   Refresh       : 'false' pour affichage rapide, 'slow' pour reconstruire la figure (défaut : false)
%   Frames        : Liste des frames à traiter (défaut : [])
%
% Exemple d'utilisation :
%   params = collectDisplayOptions('mode', 'movie', 'Nrow', 3, 'Channel', {'Red', 'Green', 'Blue'});

    % Paramètres spécifiques au rendu
    defaultMode         = 'sequence';
    defaultNrow         = 2;
    defaultNcol         = 2;
    defaultNchannel     = 3;
    defaultNframes      = 10;
    defaultNdataseries  = 0;
    defaultNbrick       = 1;
    defaultOverlay      = false;
    defaultDebug        = false;
    
    % Paramètres additionnels
    defaultTabTitle      = 0;
    defaultShiftY        = [];
    defaultHideStamp     = false;
    defaultCrop          = [];
    defaultArraySize     = [];
    defaultSnapRate      = [];
    defaultScalingFactor = 1;
    defaultName          = [];
    defaultIPS           = 10;
    defaultFramerate     = 5;
    defaultChannel       = {};
    defaultFontSize      = 12;
    defaultLevels        = [];
    defaultTitleStr      = [];
    defaultRotate        = [];
    defaultImageSize     = [];
    defaultTimeOffset    = false;
    defaultWeights       = [];
    defaultPaintChannel  = 0;
    defaultDefaultClass  = 0;
    defaultTextColor     = [1 1 1];
    defaultRoiTitle      = false;
    defaultFlip          = 0;
    defaultRGB           = {};
    defaultBackground    = [0 0 0];
    defaultRefresh       = false;
    defaultFrames        = [];
    
    p = inputParser;
    
    % Paramètres spécifiques
    addParameter(p, 'mode', defaultMode, @(x) ismember(lower(x),{'sequence','display','movie'}));
    addParameter(p, 'Nrow', defaultNrow, @isscalar);
    addParameter(p, 'Ncol', defaultNcol, @isscalar);
    addParameter(p, 'Nchannel', defaultNchannel, @isscalar);
    addParameter(p, 'Ndataseries', defaultNdataseries, @isscalar);
    addParameter(p, 'Nbrick', defaultNbrick, @isscalar);
    addParameter(p, 'overlay', defaultOverlay, @islogical);
    addParameter(p, 'debug', defaultDebug, @islogical);
    
    % Paramètres additionnels
    addParameter(p, 'tabTitle', defaultTabTitle);
    addParameter(p, 'shiftY', defaultShiftY);
    addParameter(p, 'hideStamp', defaultHideStamp, @islogical);
    addParameter(p, 'crop', defaultCrop);
    addParameter(p, 'arraySize', defaultArraySize);
    addParameter(p, 'snapRate', defaultSnapRate);
    addParameter(p, 'scalingFactor', defaultScalingFactor);
    addParameter(p, 'name', defaultName);
    addParameter(p, 'IPS', defaultIPS);
    addParameter(p, 'framerate', defaultFramerate);
    addParameter(p, 'channel', defaultChannel);
    addParameter(p, 'fontSize', defaultFontSize);
    addParameter(p, 'levels', defaultLevels);
    addParameter(p, 'title', defaultTitleStr);
    addParameter(p, 'rotate', defaultRotate);
    addParameter(p, 'imageSize', defaultImageSize);
    addParameter(p, 'timeOffset', defaultTimeOffset, @islogical);
    addParameter(p, 'weights', defaultWeights);
    addParameter(p, 'paintChannel', defaultPaintChannel);
    addParameter(p, 'defaultClass', defaultDefaultClass);
    addParameter(p, 'textColor', defaultTextColor);
    addParameter(p, 'ROITitle', defaultRoiTitle);
    addParameter(p, 'flip', defaultFlip);
    addParameter(p, 'RGB', defaultRGB);
    addParameter(p, 'background', defaultBackground);
    addParameter(p, 'refresh', defaultRefresh);
    addParameter(p, 'frames', defaultFrames);
    
    parse(p, varargin{:});
    param = p.Results;
    
    if param.debug
        fprintf('DEBUG: Display parameters collected:\n');
        disp(param);
    end
end
