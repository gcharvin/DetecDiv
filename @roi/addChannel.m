function addChannel(obj, matrix, str, rgb, intensity)
% addChannel(obj, matrix, str, rgb, intensity)
% - matrix : [H W k T] avec k=1 ou 3 (sous-canaux)
% - str    : nom logique du channel (ex. 'GFP')
% - rgb    : 1x3 (par défaut [1 1 1])
% - intensity : 1x3 (par défaut [1 1 1])

    % Defaults
    if nargin < 4 || isempty(rgb),       rgb = [1 1 1];       end
    if nargin < 5 || isempty(intensity), intensity = [1 1 1]; end

    % Validation basique du 3e dim (nb sous-canaux)
    if ndims(matrix) < 4
        error('addChannel:BadSize', 'matrix must be [H W k T].');
    end
    k = size(matrix,3);
    if ~(k==1 || k==3)
        error('addChannel:BadK', '3rd dim (k) must be 1 or 3.');
    end

    % Typage homogène
    matrix = uint16(matrix);

    % Si l'image est vide, tente un chargement (comportement historique)
    if isempty(obj.image)
        try
            obj.load;
        catch
            % ne rien faire : on initialisera from scratch
        end
    end

    % ============== CAS 1 : INITIALISATION (image vide) ==============
    if isempty(obj.image)
        % Initialisation brute
        obj.image = matrix;  % [H W k T]

        % Init display si manquant
        if ~isfield(obj, 'display') || isempty(obj.display)
            obj.display = struct();
        end
        if ~isfield(obj.display, 'channel') || isempty(obj.display.channel)
            obj.display.channel = {str};
        else
            obj.display.channel{end+1} = str;
        end

        if ~isfield(obj.display, 'frame') || isempty(obj.display.frame)
            obj.display.frame=1;
        end

        if ~isfield(obj.display, 'intensity') || isempty(obj.display.intensity)
            obj.display.intensity = intensity;
        else
            obj.display.intensity(end+1,:) = intensity;
        end

        if ~isfield(obj.display, 'rgb') || isempty(obj.display.rgb)
            obj.display.rgb = rgb;
        else
            obj.display.rgb(end+1,:) = rgb;
        end

        % Champs optionnels / usuels
        if ~isfield(obj.display, 'indexed') || isempty(obj.display.indexed)
            obj.display.indexed = 0;
        end
        if ~isfield(obj.display, 'alpha')   || isempty(obj.display.alpha)
            obj.display.alpha   = 1;
        end
        if ~isfield(obj.display, 'contour') || isempty(obj.display.contour)
            obj.display.contour = 0;
        end
        if ~isfield(obj.display, 'width')   || isempty(obj.display.width)
            obj.display.width   = 0;
        end
        if ~isfield(obj.display, 'selectedchannel') || isempty(obj.display.selectedchannel)
            obj.display.selectedchannel = 1;
        else
            obj.display.selectedchannel(end+1) = 1;
        end

        % Mise à jour 'indexed' selon intensity == 0
        if sum(intensity)==0
            obj.display.indexed(end+1) = 1;
        else
            obj.display.indexed(end+1) = 0;
        end
        obj.display.alpha(end+1)   = 1;
        obj.display.contour(end+1) = 0;
        obj.display.width(end+1)   = 0;

        % channelid : pour k sous-canaux, on répète le même id logique
        baseId = 1; % premier channel logique
        obj.channelid = baseId * ones(1, k, 'like', k);

        obj.log(sprintf('Initialized ROI image and added first channel "%s".', str), 'Processing');
        return;
    end

    % ============== CAS 2 : AJOUT SUR IMAGE EXISTANTE ==============
    [H, W, C, T] = size(obj.image);
    [h2, w2, ~, t2] = size(matrix);

    if H~=h2 || W~=w2 || T~=t2
        error('addChannel:SizeMismatch', ...
            'Size mismatch: obj.image [%d %d %d %d] vs matrix [%d %d %d %d].', ...
            H, W, C, T, h2, w2, k, t2);
    end

    % Append du channel (k sous-canaux) sur la 3e dimension
    obj.image(:,:,C+(1:k),:) = matrix;

    % Métadonnées display (par channel logique, pas par sous-canal)
    obj.display.channel{end+1}   = str;
    obj.display.intensity(end+1,:) = intensity;
    obj.display.rgb(end+1,:)     = rgb;

    % S'assure de l'existence des champs
    if ~isfield(obj.display,'indexed'), obj.display.indexed = zeros(1, numel(obj.display.channel)-1); end
    if ~isfield(obj.display,'alpha'),   obj.display.alpha   = zeros(1, numel(obj.display.channel)-1); end
    if ~isfield(obj.display,'contour'), obj.display.contour = zeros(1, numel(obj.display.channel)-1); end
    if ~isfield(obj.display,'width'),   obj.display.width   = zeros(1, numel(obj.display.channel)-1); end
    if ~isfield(obj.display,'selectedchannel') || isempty(obj.display.selectedchannel)
        obj.display.selectedchannel = 1;
    end

    if sum(intensity)==0
        obj.display.indexed(end+1) = 1;
    else
        obj.display.indexed(end+1) = 0;
    end
    obj.display.alpha(end+1)   = 1;
    obj.display.contour(end+1) = 0;
    obj.display.width(end+1)   = 0;
    obj.display.selectedchannel(end+1) = 1;

    % channelid : on attribue un nouvel id logique pour ces k sous-canaux
    if isempty(obj.channelid)
        maxId = 0;
    else
        maxId = max(obj.channelid);
        if isempty(maxId) || isnan(maxId), maxId = 0; end
    end
    newId = maxId + 1;
    obj.channelid = [obj.channelid, newId * ones(1, k, 'like', k)];

    obj.log(sprintf('Added channel %d ("%s") to ROI', numel(obj.display.channel), str), 'Processing');
end
