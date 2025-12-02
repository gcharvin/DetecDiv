function removeChannel(obj, channel)
%REMOVECHANNEL Supprime un canal logique d'un ROI, par nom ou identifiant.
%
% Usage typique ici : removeChannel('CombinedChannel')

    disp('--- removeChannel called with channel = ---');
    disp(channel)

    % Charger l'image si nécessaire
    if isempty(obj.image)
        obj.load;
    end

    % Normalisation du type d'entrée
    if isstring(channel)
        channel = char(channel);
    end

    % ---------------------------------------------------------------------
    % CAS 1 : on donne le nom du canal (cas utilisé dans addROI)
    % ---------------------------------------------------------------------
    if ischar(channel)
        % Récupérer tous les noms de canaux d'affichage sous forme de cellstr
        names = obj.display.channel;
        if ischar(names)
            names = {names};
        elseif isstring(names)
            names = cellstr(names);
        end

        % Trouver l'indice du canal dans display.channel
        idxDisp = find(strcmp(names, channel), 1);

        if isempty(idxDisp)
            disp('removeChannel: name not found in display.channel; quitting.');
            return;
        end

        % On suppose que l'indice logique du canal = idxDisp
        groupID = idxDisp;

        % Sous-canaux à supprimer dans image : ceux dont channelid == groupID
        pixSub = find(obj.channelid == groupID);

        if isempty(pixSub)
            disp('removeChannel: no subchannels found for this name; quitting.');
            return;
        end

        % -----------------------------------------------------------------
        % 1) Enlever les sous-canaux dans l'image
        % -----------------------------------------------------------------
        nC       = size(obj.image,3);
        allDims  = 1:nC;
        dimsKeep = setdiff(allDims, pixSub);

        if isempty(dimsKeep)
            warning('removeChannel: removing this channel would leave zero channels; aborting.');
            return;
        end

        obj.image = obj.image(:,:,dimsKeep,:);

        % -----------------------------------------------------------------
        % 2) Mettre à jour channelid
        % -----------------------------------------------------------------
        oldID = obj.channelid(dimsKeep);

        % On enlève le groupID et on renumérote de 1..N
        uniqueOld = unique(oldID,'stable');
        newID     = zeros(size(oldID));
        for ii = 1:numel(uniqueOld)
            newID(oldID == uniqueOld(ii)) = ii;
        end
        obj.channelid = newID;

        % -----------------------------------------------------------------
        % 3) Mettre à jour display.*
        % -----------------------------------------------------------------
        keepDisp = setdiff(1:numel(names), idxDisp);
        if isempty(keepDisp)
            keepDisp = 1;  % sécurité : on garde au moins un canal
        end

        obj.display.channel         = names(keepDisp);
        obj.display.intensity       = obj.display.intensity(keepDisp,:);
        obj.display.rgb             = obj.display.rgb(keepDisp,:);
        obj.display.selectedchannel = obj.display.selectedchannel(keepDisp);

        if isfield(obj.display,'indexed')
            obj.display.indexed = obj.display.indexed(keepDisp);
        end
        if isfield(obj.display,'alpha')
            obj.display.alpha = obj.display.alpha(keepDisp);
        end
        if isfield(obj.display,'contour')
            obj.display.contour = obj.display.contour(keepDisp);
        end
        if isfield(obj.display,'width')
            obj.display.width = obj.display.width(keepDisp);
        end

        obj.log(['Removed channel ' channel ' from ROI'],'Processing');
        return;
    end

    % ---------------------------------------------------------------------
    % CAS 2 : identifiant numérique (on garde quelque chose de simple)
    % ---------------------------------------------------------------------
    if isnumeric(channel)
        groupID = channel;
        pixSub = find(obj.channelid == groupID);
        if isempty(pixSub)
            disp('removeChannel: numeric id not found; quitting.');
            return;
        end

        nC       = size(obj.image,3);
        allDims  = 1:nC;
        dimsKeep = setdiff(allDims, pixSub);

        if isempty(dimsKeep)
            warning('removeChannel: removing this channel would leave zero channels; aborting.');
            return;
        end

        obj.image     = obj.image(:,:,dimsKeep,:);
        oldID         = obj.channelid(dimsKeep);
        uniqueOld     = unique(oldID,'stable');
        newID         = zeros(size(oldID));
        for ii = 1:numel(uniqueOld)
            newID(oldID == uniqueOld(ii)) = ii;
        end
        obj.channelid = newID;

        obj.log('Removed channel by numeric id','Processing');
    else
        disp('removeChannel: unsupported channel type; quitting.');
    end
end
