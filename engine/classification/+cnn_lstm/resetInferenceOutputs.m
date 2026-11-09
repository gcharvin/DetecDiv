function ds = resetInferenceOutputs(ds, classesTarget, useCNN, catsLabels, n)
    % classesTarget: string row (classes "truth" côté dataseries)
    % catsLabels  : string row, e.g. ["undefined", classes..., "unclassified"]
    % n           : nb total frames ROI

    % Resize the WHOLE table before replacing individual inference columns.
    % A resumed extraction may contain more frames than its saved classifier
    % table. Keep annotation types, categories, values and table properties.
    if ~istable(ds.data)
        if ~isempty(ds.data)
            error('cnn_lstm:InvalidInferenceTable','Existing classifier data must be a table.');
        end
        ds.data = table();
    end
    validateattributes(n,{'numeric'},{'scalar','integer','nonnegative','finite'});
    if height(ds.data) > n
        error('cnn_lstm:InferenceTableWouldTruncate', ...
            ['Existing classifier table has %d rows but the ROI has %d frames. ' ...
             'Refusing to discard annotations; reconcile the ROI frame range first.'], ...
            height(ds.data), n);
    end
    if height(ds.data) < n
        ds.data = resize(ds.data,n);
    end

    % --- Primary outputs ---
    % id
    if ~ismember("id", string(ds.data.Properties.VariableNames))
        ds.addData(zeros(n,1), 'id', 'groups', 'id');
    else
        ds.data.id = zeros(n,1);
    end

    % labels
    if ~ismember("labels", string(ds.data.Properties.VariableNames))
        ds.addData(categorical(repmat("undefined",n,1), catsLabels), 'labels', 'groups', 'labels');

    else
        ds.data.labels = categorical(repmat("undefined",n,1), catsLabels);
    end

    % prob_*
    for ii = 1:numel(classesTarget)
        nm = "prob_" + classesTarget(ii);
        if ~ismember(nm, string(ds.data.Properties.VariableNames))
           % ds.addData(zeros(n,1), char(nm));
            ds.addData(zeros(n,1), char(nm), 'groups', 'prob');
        else
            ds.data.(char(nm)) = zeros(n,1);
        end
    end

    % --- CNN secondary outputs ---
    if useCNN
        if ~ismember("idCNN", string(ds.data.Properties.VariableNames))
            ds.addData(zeros(n,1), 'idCNN');
        else
            ds.data.idCNN = zeros(n,1);
        end

        if ~ismember("labelsCNN", string(ds.data.Properties.VariableNames))
            ds.addData(categorical(repmat("undefined",n,1), catsLabels), 'labelsCNN');
        else
            ds.data.labelsCNN = categorical(repmat("undefined",n,1), catsLabels);
        end

        for ii = 1:numel(classesTarget)
            nm = "probCNN_" + classesTarget(ii);
            if ~ismember(nm, string(ds.data.Properties.VariableNames))
                ds.addData(zeros(n,1), char(nm));
            else
                ds.data.(char(nm)) = zeros(n,1);
            end
        end
    end
end
