classdef fov < handle
    properties
        % --- données d'acquisition / source ---
        srcpath    = {''};   % cell{ch} : dossier d'origine des images (ou du tiff)
        srclist    = {};     % cell{ch} : struct array façon dir() pour chaque frame de ce canal
        channel    = {};     % cell{ch} : noms utilisateurs des canaux ('Channel0', ...)
        frames     = [];     % frames(ch) = nb de frames pour ce canal
        interval   = [];     % interval(ch) = "période" relative d'acquisition
        binning    = [];
        orientation = 0;

        % --- annotations / suivi ---
        contours    = [];
        tag         = 'Field of view';
        comments    = '';
        flaggedROIs = [];
        display     = struct('intensity',1,'frame',1,'selectedchannel',1,'binning',1);
        id          = '';
        roi         = roi('',[]);
        number      = 1;
        crop        = [];
        pattern     = [];
        drift       = [];    % [dx dy] pour correction de dérive

        % --- NOUVEAU: support natif du multi-TIFF ---
        % Si true, ce FOV ne correspond pas à une série de fichiers individuels,
        % mais à un (ou plusieurs) gros TIFF empilés.
        % Dans ce cas srclist{i}(f).name est "virtuel" (ex: base_channel000_time...), pas physiquement présent.
        isMultiTiff = false;     % bool
        tiffSource  = {};        % cell{ch}: chemin complet du/ des gros .tif réels
        pageMap     = {};        % cell{ch}: pageMap{ch}(f) = index de page TIFF à lire via imread(tiffSource{ch}, page)
                                 % longueur(pageMap{ch}) == frames(ch)

        % --- NDTiff support ---
        isNDTiff       = false;  % bool
        ndtiffPath     = '';     % dataset folder (contains NDTiff.index)
        ndtiffPosition = 0;      % 0-based position index in dataset
        ndtiffChannels = [];     % 0-based channel indices
        ndtiffZ        = 0;      % 0-based z index (if present)

        % --- OME-Zarr support ---
        isOMEZarr           = false; % bool
        omeZarrPath         = '';    % dataset folder (*.ome.zarr)
        omeZarrSeries       = '';    % series/group name, e.g. '0'
        omeZarrArrayPath    = '0';   % multiscale array path inside series
        omeZarrShape        = [];    % array shape, usually [T C Y X]
        omeZarrChunkShape   = [];    % chunk shape
        omeZarrDtype        = '';    % zarr data_type
        omeZarrDimensionNames = {};  % dimension names, e.g. {'t','c','y','x'}
        omeZarrChannelIndices = [];  % 0-based source channel indices per display channel
        omeZarrZIndices       = [];  % 0-based source z indices per display channel
    end

    properties (Dependent)
        channels  % nb de canaux, juste un alias pratique
    end

    properties (Transient)
        parent = [];
    end

    methods
        function obj = fov(comments)
            if nargin==0
                comments = '';
            end
            obj.comments = comments;
        end

        function setpathlist(obj, pathname, number, filelist, name, varargin)
            % setpathlist :
            %   pathname : cell{ch} dossiers pour chaque canal
            %   number   : index interne du FOV dans le projet
            %   filelist : cell{ch} struct array (un élément par frame du canal)
            %   name     : base name style 'Pos0'
            %
            %   varargin (optionnel) = mtInfo struct avec champs:
            %       .isMultiTiff (bool)
            %       .tiffSource  (cell{ch} chemins du gros TIFF)
            %       .pageMap     (cell{ch} mapping frame->page TIFF)
            %
            % Rétro-compatible: si pas de mtInfo, on reste en mode "classique".

            obj.srcpath = pathname;
            obj.number  = number;
            obj.id      = [name '_' num2str(number)];

            % copier les listes de fichiers/frames par canal
            for i = 1:numel(pathname)
                obj.srclist(i) = filelist(i); % srclist{i} = struct array
            end

            % multi-tiff info ?
            if ~isempty(varargin)
                mtInfo = varargin{1};
                if isfield(mtInfo,'isMultiTiff'), obj.isMultiTiff = logical(mtInfo.isMultiTiff); end
                if isfield(mtInfo,'tiffSource'),  obj.tiffSource  = mtInfo.tiffSource;          end
                if isfield(mtInfo,'pageMap'),     obj.pageMap     = mtInfo.pageMap;             end
                if isfield(mtInfo,'isOMEZarr'),   obj.isOMEZarr   = logical(mtInfo.isOMEZarr);  end
            end

            % sécurité: toujours avoir une taille cohérente
            if isempty(obj.tiffSource)
                obj.tiffSource = cell(1, numel(pathname));
            end
            if isempty(obj.pageMap)
                obj.pageMap = cell(1, numel(pathname));
            end
        end

        function value = get.channels(obj)
            value = numel(obj.channel);
        end
    end
end
