function addChannel(obj, matrix, str, rgb, intensity)
% addChannel(obj, matrix, str, rgb, intensity)
% - matrix : [H W k T] avec k=1 ou 3 (sous-canaux)
% - str    : nom logique du channel (ex. 'GFP')
% - rgb    : 1x3 (par défaut [1 1 1])
% - intensity : 1x3 (par défaut [1 1 1])

    % Defaults
    if nargin < 4 || isempty(rgb),       rgb = [1 1 1];       end
    if nargin < 5 || isempty(intensity), intensity = [1 1 1]; end
    forceIndexed = isIndexedResultChannel(str);
    if forceIndexed
        intensity = [0 0 0];
    end

    % MATLAB drops trailing singleton dimensions, so [H W 1 1] often
    % arrives as a 2-D array. Normalize it back to the ROI channel shape.
    if ismatrix(matrix)
        matrix = reshape(matrix, size(matrix,1), size(matrix,2), 1, 1);
    elseif ndims(matrix) == 3
        matrix = reshape(matrix, size(matrix,1), size(matrix,2), size(matrix,3), 1);
    end

    % Validation basique du 3e dim (nb sous-canaux)
    if ndims(matrix) < 4 && size(matrix,4) ~= 1
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
    % ============== CAS 1 : INITIALISATION (image vide) ==============
if isempty(obj.image)
    % Initialisation brute de l'image
    obj.image = matrix;  % [H W k T]

    % Init display si manquant
    if ~isfield(obj, 'display') || isempty(obj.display)
        obj.display = struct();
    end

    % ---- channel : utiliser le premier élément, ne PAS agrandir ----
    if ~isfield(obj.display, 'channel') || isempty(obj.display.channel)
        obj.display.channel = {str};
    else
        % On se contente d'utiliser la première entrée
        obj.display.channel{1} = str;
    end

    % ---- frame ----
    if ~isfield(obj.display, 'frame') || isempty(obj.display.frame)
        obj.display.frame = 1;
    else
        % On ne touche pas si déjà défini
    end

    % ---- intensity : 1x3, utiliser la première ligne ----
    if ~isfield(obj.display, 'intensity') || isempty(obj.display.intensity)
        obj.display.intensity = intensity;
    else
        if size(obj.display.intensity,1) < 1
            obj.display.intensity(1,:) = intensity;
        else
            % Tu peux choisir de respecter le réglage existant ou de le
            % surcharger. Ici, je surcharge la première ligne :
            obj.display.intensity(1,:) = intensity;
        end
    end

    % ---- rgb : 1x3, utiliser la première ligne ----
    if ~isfield(obj.display, 'rgb') || isempty(obj.display.rgb)
        obj.display.rgb = rgb;
    else
        if size(obj.display.rgb,1) < 1
            obj.display.rgb(1,:) = rgb;
        else
            obj.display.rgb(1,:) = rgb;
        end
    end

    % ---- indexed : bool par channel logique ----
    idxVal = forceIndexed || (sum(intensity) == 0);
    if ~isfield(obj.display, 'indexed') || isempty(obj.display.indexed)
        obj.display.indexed = idxVal;
    else
        if numel(obj.display.indexed) < 1
            obj.display.indexed(1) = idxVal;
        else
            % à toi de voir si tu veux écraser ou pas ; ici je synchronise
            obj.display.indexed(1) = idxVal;
        end
    end

    % ---- alpha ----
    if ~isfield(obj.display, 'alpha') || isempty(obj.display.alpha)
        obj.display.alpha = 1;
    else
        if numel(obj.display.alpha) < 1
            obj.display.alpha(1) = 1;
        else
            % on laisse à 1 par défaut pour le premier channel
            obj.display.alpha(1) = 1;
        end
    end

    % ---- contour ----
    if ~isfield(obj.display, 'contour') || isempty(obj.display.contour)
        obj.display.contour = 0;
    else
        if numel(obj.display.contour) < 1
            obj.display.contour(1) = 0;
        end
        % sinon on laisse tel quel
    end

    % ---- width ----
    if ~isfield(obj.display, 'width') || isempty(obj.display.width)
        obj.display.width = 0;
    else
        if numel(obj.display.width) < 1
            obj.display.width(1) = 0;
        end
    end

    % ---- selectedchannel ----
    if ~isfield(obj.display, 'selectedchannel') || isempty(obj.display.selectedchannel)
        obj.display.selectedchannel = 1;
    else
        if numel(obj.display.selectedchannel) < 1
            obj.display.selectedchannel(1) = 1;
        else
            % on force le premier channel comme sélectionné par défaut
            obj.display.selectedchannel(1) = 1;
        end
    end

    % channelid : pour k sous-canaux, on répète le même id logique
    baseId = 1; % premier channel logique
    obj.channelid = baseId * ones(1, k, 'like', k);

    if idxVal
        obj.display.intensity(1,:) = [0 0 0];
        obj.display.indexed(1) = 1;
        obj.display.contour(1) = 1;
        obj.display.alpha(1) = 0.35;
        obj.display.width(1) = 1.5;
    end

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
    if isempty(obj.display)
        obj.display = struct();
    end
    if ~isfield(obj.display,'channel') || isempty(obj.display.channel)
        obj.display.channel = {};
    elseif ischar(obj.display.channel) || isstring(obj.display.channel)
        obj.display.channel = cellstr(obj.display.channel);
    end

    nOld = numel(obj.display.channel);
    obj.display = localEnsureDisplayCapacity(obj.display, nOld);
    nNew = nOld + 1;

    obj.display.channel{nNew} = str;
    obj.display.intensity(nNew,:) = double(intensity(:)).';
    obj.display.rgb(nNew,:) = double(rgb(:)).';
    idxVal = forceIndexed || sum(intensity)==0;
    obj.display.indexed(nNew) = idxVal;
    obj.display.alpha(nNew) = 1;
    obj.display.contour(nNew) = 0;
    obj.display.width(nNew) = 0;
    obj.display.selectedchannel(nNew) = 1;
    if idxVal
        obj.display.intensity(nNew,:) = [0 0 0];
        obj.display.contour(nNew) = 1;
        obj.display.alpha(nNew) = 0.35;
        obj.display.width(nNew) = 1.5;
    end

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

function display = localEnsureDisplayCapacity(display, nLog)
    display.intensity = localEnsureRows(display, 'intensity', nLog, [1 1 1]);
    display.rgb = localEnsureRows(display, 'rgb', nLog, [1 1 1]);
    display.indexed = localEnsureVector(display, 'indexed', nLog, 0);
    display.alpha = localEnsureVector(display, 'alpha', nLog, 1);
    display.contour = localEnsureVector(display, 'contour', nLog, 0);
    display.width = localEnsureVector(display, 'width', nLog, 0);
    display.selectedchannel = localEnsureVector(display, 'selectedchannel', nLog, 1);
end

function value = localEnsureRows(display, fieldName, nLog, defaultRow)
    if isfield(display, fieldName) && ~isempty(display.(fieldName))
        value = double(display.(fieldName));
    else
        value = zeros(0, numel(defaultRow));
    end

    if isvector(value) && numel(value) == numel(defaultRow)
        value = reshape(value, 1, []);
    end
    if size(value, 2) ~= numel(defaultRow)
        value = reshape(value, [], numel(defaultRow));
    end
    if size(value, 1) < nLog
        value(end+1:nLog,:) = repmat(defaultRow, nLog - size(value,1), 1);
    elseif size(value, 1) > nLog
        value = value(1:nLog,:);
    end
end

function value = localEnsureVector(display, fieldName, nLog, defaultValue)
    if isfield(display, fieldName) && ~isempty(display.(fieldName))
        value = display.(fieldName);
        value = value(:).';
    else
        value = zeros(1, 0);
    end

    if numel(value) < nLog
        value(end+1:nLog) = defaultValue;
    elseif numel(value) > nLog
        value = value(1:nLog);
    end
end

function tf = isIndexedResultChannel(channelName)
tf = false;
try
    name = lower(string(channelName));
    tf = startsWith(name, "results_") || contains(name, "mask") || ...
        contains(name, "track") || contains(name, "viterbi") || ...
        contains(name, "lineage") || endsWith(name, "_cell") || ...
        endsWith(name, "_conf");
catch
    tf = false;
end
end
