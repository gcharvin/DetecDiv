function listout = listROIDataID(datatype)
% LISTROIDATAID  Liste tous les groupid des ROI selon un filtre datatype
%   listout = listROIDataID()            % sans filtre
%   listout = listROIDataID('myType')    % filtre sur 'myType'
%
% Retourne un cell array de char, sans espaces ni tirets.

    %% 1) Préparation de l’entrée
    if nargin == 0
        datatype = {};
    else
        if ischar(datatype)
            datatype = { datatype };
        elseif isstring(datatype)
            datatype = cellstr(datatype);
        elseif iscell(datatype)
            datatype = cellfun(@ensureChar, datatype, 'UniformOutput', false);
        else
            error('datatype must be char, string or cell array of char');
        end
    end

    %% 2) Conteneur final
    list = {};   % on stocke des char

    %% 3) Récupère la structure workspace
    listproj = gatherVariablesFromWorkspace;

    %% 4) Parcours des projets
    for iProj = 1:numel(listproj.Project)
        proj = evalin('base', listproj.Project{iProj});

        % --- strid des classifications du projet ---
        if ~isempty(proj.processing.classification)
            rawStr = { proj.processing.classification.strid };
            classifiers = cellfun(@ensureChar, rawStr, 'UniformOutput', false);
        else
            classifiers = {};
        end

        %% 4a) Parcours des FOVs (Projectpos)
        for iPos = 1:numel(listproj.Projectpos{iProj})
            tmp0      = listproj.Projectpos{iProj}{iPos};
            tmp       = ensureChar(tmp0);

            rawpos    = { proj.fov.id };
            positions = cellfun(@ensureChar, rawpos, 'UniformOutput', false);

            pix = find( ismember(positions, tmp) );
            if isempty(pix), continue; end

            roiobj  = proj.fov(pix).roi;
            listcha = {};

            for k = 1:numel(roiobj)
                roiobj(k).load('data');
                if isempty(roiobj(k).data) || isempty(roiobj(k).data(1).data)
                    continue;
                end

            tmp=roiobj(k).data.groupid;

if ischar(tmp)
    g=tmp;
else
                g = ensureChar( [roiobj(k).data.groupid]) ;%roiobj(k).data.groupid );
end

                if isempty(datatype)
                    listcha{end+1} = g;
                else
                    rawcla = { roiobj(k).data.class };
                    cla    = cellfun(@ensureChar, rawcla, 'UniformOutput', false);
                    idx    = find( ismember(cla, datatype) );
                    for ii = idx
                        listcha{end+1} = ensureChar( roiobj(k).data(ii).groupid );
                    end
                end

                if numel(listcha) > 20 && k > 100
                    break;
                end
            end

            if ~isempty(listcha)
                list = [ list, unique(listcha, 'stable') ];
            end
        end

        %% 4b) Parcours des classifications dans proj.processing
        for iC = 1:numel(listproj.Projectclassi)
            rawCls0 = listproj.Projectclassi{iC};
            % déplier si c'est une cellule de plusieurs
            if iscell(rawCls0)
                clsSet = cellfun(@ensureChar, rawCls0, 'UniformOutput', false);
            else
                clsSet = { ensureChar(rawCls0) };
            end

            for ci = 1:numel(clsSet)
                cls = clsSet{ci};
                pix = find( ismember(classifiers, cls) );
                if isempty(pix), continue; end

                for jj = pix
                    roiobj  = proj.processing.classification(jj).roi;
                    listcha = {};

                    for k = 1:numel(roiobj)
                        if isempty(roiobj(k).data) || isempty(roiobj(k).data(1).data)
                            continue;
                        end

                        g = ensureChar( [roiobj(k).data.groupid] );

                        if isempty(datatype)
                            listcha{end+1} = g;
                        else
                            rawcla = { roiobj(k).data.class };
                            cla    = cellfun(@ensureChar, rawcla, 'UniformOutput', false);
                            idx    = find( ismember(cla, datatype) );
                            for ii = idx
                                listcha{end+1} = ensureChar( roiobj(k).data(ii).groupid );
                            end
                        end

                        if numel(listcha) > 20 && k > 100
                            break;
                        end
                    end

                    if ~isempty(listcha)
                        list = [ list, unique(listcha, 'stable') ];
                    end
                end
            end
        end
    end

    %% 5) Parcours des variables Classifier globales
    for iCl = 1:numel(listproj.Classifier)
        clsVar  = evalin('base', listproj.Classifier{iCl});
        roiobj  = clsVar.roi;
        listcha = {};

        for k = 1:numel(roiobj)
            if isempty(roiobj(k).data) || isempty(roiobj(k).data(1).data)
                continue;
            end

            g = ensureChar( [roiobj(k).data.groupid] );

            if isempty(datatype)
                listcha{end+1} = g;
            else
                rawcla = { roiobj(k).data.class };
                cla    = cellfun(@ensureChar, rawcla, 'UniformOutput', false);
                idx    = find( ismember(cla, datatype) );
                for ii = idx
                    listcha{end+1} = ensureChar( roiobj(k).data(ii).groupid );
                end
            end

            if numel(listcha) > 20 && k > 100
                break;
            end
        end

        if ~isempty(listcha)
            list = [ list, unique(listcha, 'stable') ];
        end
    end

    %% 6) Unicité finale + filtrage espaces/tirets
    if isempty(list)
        listout = {};
    else
        list = unique(list, 'stable');
        mask = cellfun(@(s) isempty(strfind(s,' ')) && isempty(strfind(s,'-')), list);
        listout = list(mask);
    end
end

%% Petite fonction utilitaire interne
function s = ensureChar(x)

    if iscell(x)
        if numel(x)==1
            s = ensureChar(x{1});
        else
            % si c'est un cell de plusieurs, on concatène avec '_' (ou autre séparateur)
            parts = cellfun(@ensureChar, x, 'UniformOutput', false);
            s = strjoin(parts, '_');
        end
    elseif isnumeric(x) || islogical(x)
        s = num2str(x);
    elseif isstring(x)
        s = char(x);
    elseif ischar(x)
        s = x;
    else
        error('Cannot convert type %s to char', class(x));
    end
end
