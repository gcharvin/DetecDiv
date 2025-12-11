function adjustROIAdvanced(obj, varargin)

%ADJUSTROIADVANCED Ajuste une ROI en une seule opération (bbox, channels, dataseries, binning).
%
% Usage typique (GUI ou ligne de commande) :
%   r.adjustROIAdvanced('bbox',[0 0 w h], ...
%                       'keepChannels',   {'phase','GFP'}, ...
%                       'keepDataseries', {'mean_fluo','divduration'}, ...
%                       'binning',        2);
%
% - 'bbox' :
%      []          -> ne change pas la bbox
%      [x y w h]   -> passe tel quel à adjustROISize
%      [0 0 w h]   -> avec ton adjustROISize, change w,h en gardant le centre
%
% - 'keepChannels' : cellstr de noms de channels (display.channel) à CONSERVER.
%                    Tous les autres seront supprimés via removeChannel().
%                    [] ou {} => ne touche pas aux channels.
%
% - 'keepDataseries' : cellstr de groupid à CONSERVER dans obj.data.
%                      Tous les autres dataseries seront supprimés.
%                      [] ou {} => ne touche pas à obj.data.
%
% - 'binning' : scalaire > 0, stocké dans obj.display.binning (un par canal).
%               N'affecte pas l'image elle-même, seulement les settings de display.

    p = inputParser;
    addParameter(p,'bbox',[], @(x)isnumeric(x) && (numel(x)==4 || numel(x)==2));
    addParameter(p,'keepChannels',{}, @(c)iscellstr(c) || isstring(c));
    addParameter(p,'keepDataseries',{}, @(c)iscellstr(c) || isstring(c));
    addParameter(p,'binning',[], @(x)isnumeric(x) && isscalar(x) && x>0);
    parse(p,varargin{:});

    bbox         = p.Results.bbox;
    keepChannels = cellstr(p.Results.keepChannels);
    keepDS       = cellstr(p.Results.keepDataseries);
    binning      = p.Results.binning;

    % Nettoyage des listes : on vire les strings vides
    keepChannels = keepChannels(~cellfun(@isempty, keepChannels));
    keepDS       = keepDS(~cellfun(@isempty, keepDS));

    %% 1) Resize via ta méthode existante
    if ~isempty(bbox)
        % bbox est soit [x y w h], soit [0 0 w h] si tu veux garder le centre
        obj.adjustROISize(bbox);
    end

    %% 2) Binning : on ne touche qu'à obj.display.binning
    if ~isempty(binning)
        % Normalisation des noms de channels
        chNames = {};
        if isfield(obj.display,'channel') && ~isempty(obj.display.channel)
            chNames = obj.display.channel;
            if ischar(chNames)
                chNames = {chNames};
            elseif isstring(chNames)
                chNames = cellstr(chNames);
            end
        end

        nCh = numel(chNames);
        if nCh == 0
            % pas de canaux -> on stocke quand même quelque chose de cohérent
            obj.display.binning = binning;
        else
            obj.display.binning = repmat(binning, nCh, 1);
        end
    end

    %% 3) Filtrage des channels (via removeChannel qui gère image + display + channelid)
    if ~isempty(keepChannels)
        % Noms actuels
        names = obj.display.channel;
        if ischar(names)
            names = {names};
        elseif isstring(names)
            names = cellstr(names);
        end

        if isempty(names)
            % rien à faire
        else
            % Canaux qu'on veut VRAIMENT garder (intersection)
            toKeep = intersect(names, keepChannels, 'stable');

            % Si l'intersection est vide, on ne fait rien pour éviter de tuer la ROI
            if ~isempty(toKeep)
                % Canaux à supprimer = tous ceux qui ne sont pas dans toKeep
                toDrop = setdiff(names, toKeep, 'stable');

                % On supprime un par un en utilisant removeChannel(name)
                for i = 1:numel(toDrop)
                    obj.removeChannel(toDrop{i});
                end
            end
        end
    end

    %% 4) Filtrage des dataseries dans obj.data (par groupid)
    if ~isempty(keepDS) && ~isempty(obj.data)
        toRemove = [];
        for k = 1:numel(obj.data)
            gname = '';
            if isprop(obj.data(k),'groupid') && ~isempty(obj.data(k).groupid)
                gname = char(obj.data(k).groupid);
            end

            % Si pas de nom ou nom non présent dans keepDS => on supprime
            if isempty(gname) || ~ismember(gname, keepDS)
                toRemove(end+1) = k; %#ok<AGROW>
            end
        end

        if ~isempty(toRemove)
            obj.data(toRemove) = [];
        end
    end

    %% 5) Logging (optionnel, si tu as roi.log)
    try
        obj.log('ROI adjusted (bbox / channels / dataseries / binning)','Processing');
    catch
        % silencieux si log n'existe pas ou plante
    end
end
