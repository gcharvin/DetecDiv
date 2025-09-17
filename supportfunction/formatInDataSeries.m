function formatInDataSeries(roiobj)
% Non-destructive: ne réinitialise plus roiobj(i).data

for i = 1:numel(roiobj)
    % On ne touche pas aux séries existantes (RLS, channel_quantification, mask_*, ...)
    formatData(roiobj(i), "classification", "temporal");

    % Optionnel: ne supprimer que les placeholders complètement vides
    emptyMask = arrayfun(@(ds) (isempty(ds.groupid) || all(ds.groupid=="" )) && ...
                                   (isempty(ds.data) || height(ds.data)==0), roiobj(i).data);
    if any(emptyMask)
        roiobj(i).data = roiobj(i).data(~emptyMask);
    end
end
end

function formatData(roiobj, class, type) %#ok<INUSD>

    % ------- TRAIN -> dataseries -------
    train = roiobj.train;
    if ~isempty(train)
        p = fieldnames(train);
        for i = 1:numel(p)
            grp = p{i};
            disp(['Converting training set ' grp ' in dataseries...']);

            cc = ensureSeries(roiobj, grp, class); % crée OU récupère la série
            if isfield(train.(grp), 'classes')
                roiobj.data(cc).userData.classes = train.(grp).classes;
            end
            if isfield(train.(grp), 'bounds')
                roiobj.data(cc).userData.bounds = train.(grp).bounds;
            end

            q = fieldnames(train.(grp));
            for k = 1:numel(q)
                if any(strcmp(q{k}, {'bounds','classes','label'})), continue; end
                tmp = train.(grp).(q{k});  tmp = tmp';

                switch q{k}
                    case 'id'
                        roiobj.data(cc).addData(tmp,'id_training','groups','id');
                        if isfield(roiobj.data(cc).userData,'classes') && ~isempty(roiobj.data(cc).userData.classes)
                            classes = roiobj.data(cc).userData.classes;
                            catArr  = categorical(tmp, 1:numel(classes), classes);
                            roiobj.data(cc).addData(catArr,'labels_training','groups','labels','plot',true);
                        end
                    otherwise
                        sz = size(roiobj.data(cc).data,1);
                        if isempty(roiobj.data(cc).data) || numel(tmp)==sz
                            roiobj.data(cc).addData(tmp, q{k});
                        else
                            % tailles incompatibles → ne pas écraser; stocker en meta si utile
                            % roiobj.data(cc).userData.(q{k}) = tmp;
                        end
                end
            end
        end
    end

    % ------- RESULTS -> dataseries -------
    res = roiobj.results;
    if ~isempty(res)
        p = fieldnames(res);
        for i = 1:numel(p)
            grp = p{i};
            disp(['Converting dataset ' grp ' in dataseries...']);

            cc = ensureSeries(roiobj, grp, class); % crée OU récupère la série
            if isfield(res.(grp), 'classes')
                roiobj.data(cc).userData.classes = res.(grp).classes;
            end

            q = fieldnames(res.(grp));
            for k = 1:numel(q)
                if any(strcmp(q{k}, {'bounds','classes','label'})), continue; end
                disp(['Found dataset : ' q{k}])
                tmp = res.(grp).(q{k}); tmp = tmp';

                switch q{k}
                    case 'id'
                        roiobj.data(cc).addData(tmp,'id','groups','id');
                        if isfield(roiobj.data(cc).userData,'classes') && ~isempty(roiobj.data(cc).userData.classes)
                            classes = roiobj.data(cc).userData.classes;
                            catArr  = categorical(tmp, 1:numel(classes), classes);
                            roiobj.data(cc).addData(catArr,'labels','groups','label','plot',true);
                        end

                    case 'prob'
                        if isfield(roiobj.data(cc).userData,'classes')
                            classes = roiobj.data(cc).userData.classes;
                            for j=1:size(tmp,2)
                                roiobj.data(cc).addData(tmp(:,j), ['prob_' classes{j}], 'groups','prob');
                            end
                        end

                    case 'probCNN'
                        if isfield(roiobj.data(cc).userData,'classes')
                            classes = roiobj.data(cc).userData.classes;
                            for j=1:size(tmp,2)
                                roiobj.data(cc).addData(tmp(:,j), ['probCNN_' classes{j}], 'groups','prob');
                            end
                        end

                    otherwise
                        sz = size(roiobj.data(cc).data,1);
                        if isempty(roiobj.data(cc).data) || numel(tmp)==sz
                            roiobj.data(cc).addData(tmp, q{k});
                        else
                            % tailles incompatibles → ne pas écraser
                            % roiobj.data(cc).userData.(q{k}) = tmp;
                        end
                end
            end
        end
    end
end

function cc = ensureSeries(roiobj, groupid, class)
% Retourne l'index d'une série existante (même groupid) ou crée une nouvelle entrée.
pix = find(arrayfun(@(x) strcmp(x.groupid, groupid), roiobj.data), 1, 'first');
if isempty(pix)
    cc = numel(roiobj.data) + 1;
    roiobj.data(cc) = dataseries();
    roiobj.data(cc).class    = class;
    roiobj.data(cc).groupid  = groupid;
    roiobj.data(cc).parentid = roiobj.id;
else
    cc = pix;
end
end
