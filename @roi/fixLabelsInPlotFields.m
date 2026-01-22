function obj = fixLabelsInPlotFields(obj)
% Corrige les noms 'labels' en 'label' dans :
% - plotGroup{6}
% - plotProperties(:,6)
% - groupProperties(:,1)
% pour chaque dataseries de obj.data

    if isempty(obj.data), return; end

    % --- skip invalid dataseries handles ---
    try
        if isa(obj.data,'handle')
            obj.data = obj.data(isvalid(obj.data));
        end
    catch
    end
    if isempty(obj.data), return; end

    for k = 1:numel(obj.data)
        ds = obj.data(k);  % une instance de dataseries

       % ds = obj.data(i);
if isa(ds,'handle') && ~isvalid(ds)
    continue;
end


        % --- Corriger plotGroup{6}
        pg = ds.plotGroup;
        if numel(pg) >= 6 && iscell(pg{6})
            items = pg{6};
            items(strcmp(items, 'labels')) = {'label'};  % remplacer
            items = unique(items, 'stable');             % éviter doublons
            ds.plotGroup{6} = items;
        end

        % --- Corriger la 6e colonne de plotProperties
        pp = ds.plotProperties;
        if size(pp,2) >= 6
            for j = 1:size(pp,1)
                val = pp{j,6};
                if ischar(val) && strcmp(val, 'labels')
                    pp{j,6} = 'label';
                end
            end
            ds.plotProperties = pp;
        end

        % --- Corriger la 1ère colonne de groupProperties
        gp = ds.groupProperties;
        if size(gp,2) >= 1
            for j = 1:size(gp,1)
                val = gp{j,1};
                if ischar(val) && strcmp(val, 'labels')
                    gp{j,1} = 'label';
                end
            end
            ds.groupProperties = gp;
        end

        % Réassigner la version corrigée dans obj.data
        obj.data(k) = ds;
    end
end
