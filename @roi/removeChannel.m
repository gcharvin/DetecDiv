function removeChannel(obj,channel)
% Remove one logical channel (by name or id) from a ROI.
% - "channel" can be a char/string (display.channel name)
%   or a numeric channel group id (as in obj.channelid)

    disp('--- removeChannel called with channel = ---');
    disp(channel);

    % Charger l'image si besoin
    if numel(obj.image)==0
        obj.load;
    end

    % Normaliser le type de "channel"
    if isstring(channel)
        channel = char(channel);
    end

    % Si on reçoit une cellule de plusieurs channels -> les enlever un par un
    if iscell(channel)
        for k = 1:numel(channel)
            obj.removeChannel(channel{k});
        end
        return;
    end

    % Déterminer les indices de sous-canaux à supprimer (pix) et le groupID
    if ischar(channel)
        % channel logique par son nom
        pix = obj.findChannelID(channel);      % indices 3D dans image
    elseif isnumeric(channel)
        pix = channel(:)';                     % indices de groupe -> on traitera juste après
    else
        disp('removeChannel: unsupported channel type; quitting...');
        return;
    end

    if isempty(pix)
        disp('Channel was not found; quitting !');
        return;
    end

    % Si pix correspond à des indices de plan (sous-canaux), on en déduit l'ID de groupe
    groupID = obj.channelid(pix(1));   % ID de channel logique à supprimer

    % Indices dans display.channel correspondant au channel à enlever
    pix2 = [];
    if isfield(obj,'display') && isfield(obj.display,'channel')
        try
            pix2 = find(matches(obj.display.channel, channel));
        catch
            chNames = cellfun(@char, obj.display.channel, 'UniformOutput', false);
            pix2 = find(matches(chNames, char(channel)));
        end
    end
    if isempty(pix2)
        % Pas trouvé dans display.channel => rien à faire côté display
        disp('removeChannel: name not found in display.channel; will only update image/channelid.');
    end

    % 1) Nouveau vecteur channelid (on enlève tous les sous-canaux du groupID)
    remainsdimid = obj.channelid ~= groupID;      % on garde tout sauf ce groupID
    newchannelid = obj.channelid(remainsdimid);   % channelid des sous-canaux restants

    % Renumérotation : tous les IDs > groupID sont décrémentés de 1
    newchannelid(newchannelid > groupID) = newchannelid(newchannelid > groupID) - 1;

    % 2) Quels channels d'affichage on garde ?
    allDisplayIdx = 1:numel(obj.display.channel);
    if ~isempty(pix2)
        remainscha = setxor(allDisplayIdx, pix2);
    else
        remainscha = allDisplayIdx;   % on ne touche pas à display.channel si pas trouvé
    end

    % 3) Quels sous-canaux (dims) correspondent aux channels d'affichage restants ?
    val = [];
    for i = 1:numel(remainscha)
        grp = remainscha(i);                                 % ID logique
        idx = find(obj.channelid == grp);                    % sous-canaux dans l'image originale
        val = [val idx]; %#ok<AGROW>
    end
    dims = val;

    % Sécurité : clamp si jamais dims déborde (dans un cas tordu)
    maxC = size(obj.image,3);
    dims = dims(dims >= 1 & dims <= maxC);

    % 4) Mise à jour des structures internes
    obj.channelid = newchannelid;
    if ~isempty(dims)
        obj.image = obj.image(:,:,dims,:);
    else
        % Cas extrême : plus aucun canal → on garde la taille mais on met une image vide
        obj.image = obj.image(:,:,1:min(1,maxC),:);
    end

    if ~isempty(remainscha)
        obj.display.channel         = obj.display.channel(remainscha);
        obj.display.intensity       = obj.display.intensity(remainscha,:);
        obj.display.rgb             = obj.display.rgb(remainscha,:);
        obj.display.selectedchannel = obj.display.selectedchannel(remainscha);

        if isfield(obj.display,'indexed')
            obj.display.indexed = obj.display.indexed(remainscha);
        end
        if isfield(obj.display,'alpha')
            obj.display.alpha = obj.display.alpha(remainscha);
        end
        if isfield(obj.display,'contour')
            obj.display.contour = obj.display.contour(remainscha);
        end
        if isfield(obj.display,'width')
            obj.display.width = obj.display.width(remainscha);
        end
    end

    obj.log(['Removed channel from ROI'],'Processing');
end
