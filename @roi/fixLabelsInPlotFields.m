function obj = fixLabelsInPlotFields(obj)
% Corrige les noms 'labels' en 'label' dans :
% - plotGroup{6}
% - plotProperties(:,6)
% - groupProperties(:,1)

    % --- Corriger plotGroup{6}
    pg = obj.data.plotGroup;
    if numel(pg) >= 6 && iscell(pg{6})
        items = pg{6};
        items(strcmp(items, 'labels')) = {'label'};  % remplacer
        items = unique(items, 'stable');             % éviter doublons
        obj.data.plotGroup{6} = items;
    end

    % --- Corriger la 6e colonne de plotProperties
    pp = obj.data.plotProperties;
    if size(pp,2) >= 6
        for j = 1:size(pp,1)
            val = pp{j,6};
            if ischar(val) && strcmp(val, 'labels')
                pp{j,6} = 'label';
            end
        end
        obj.data.plotProperties = pp;
    end

    % --- Corriger la 1ère colonne de groupProperties
    gp = obj.data.groupProperties;
    if size(gp,2) >= 1
        for j = 1:size(gp,1)
            val = gp{j,1};
            if ischar(val) && strcmp(val, 'labels')
                gp{j,1} = 'label';
            end
        end
        obj.data.groupProperties = gp;
    end
end
