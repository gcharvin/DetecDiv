function didSave = save(obj, option, verbose)
% didSave = save(obj, option, verbose)
% Retourne true si au moins un des deux fichiers (im_*.mat ou data_*.mat)
% a été réellement écrit sur disque.

    if nargin < 2 || isempty(option)
        option = "";
    end
    if nargin < 3 || isempty(verbose)
        verbose = true;
    end

    im      = obj.image;
    roiobj  = obj;
    data    = obj.data;
    resonly = strcmp(option, 'data');

    didSave = false;  % <--- valeur par défaut

    if isempty(obj.path) || ~isfolder(obj.path)
        if verbose
            disp('ERROR: Invalid or missing path for ROI save.');
        end
        return;
    end

    success      = false;
    attempts     = 0;
    max_attempts = 5;

    while ~success && attempts < max_attempts
        try
            % Track what we actually wrote
            imageSaved = false;
            dataSaved  = false;

            % === Sauvegarde im_*.mat ===
            if resonly == 0 && ~isempty(im)
                save(fullfile(obj.path, ['im_' obj.id '.mat']), 'roiobj');
                obj.log(['Saving ROI to ' fullfile(obj.path, ['im_' obj.id '.mat'])], 'Saving');
                imageSaved = true;
            end

            % === Sauvegarde data_*.mat ===
            hasDataToSave = ~isempty(data) && isfield(data,'groupid') && ~isempty(data.groupid);
            if resonly == 1 || hasDataToSave
                save(fullfile(obj.path, ['data_' obj.id '.mat']), 'data');
                obj.log(['Saving data to ' fullfile(obj.path, ['data_' obj.id '.mat'])], 'Saving');
                dataSaved = true;
            end

            % Message console seulement si quelque chose a été écrit
            if verbose
                if imageSaved && dataSaved
                    fprintf('ROI #%s: image and data saved.\n', obj.id);
                elseif imageSaved
                    fprintf('ROI #%s: image saved.\n', obj.id);
                elseif dataSaved
                    fprintf('ROI #%s: data saved.\n', obj.id);
                end
            end

            % <- est-ce qu'on a vraiment sauvé quelque chose ?
            didSave = imageSaved || dataSaved;

            success = true;

        catch ME
            attempts = attempts + 1;
            if verbose
                fprintf('Erreur lors de la sauvegarde (tentative %d/%d): %s\n', ...
                        attempts, max_attempts, ME.message);
            end
            pause(0.5);
        end
    end

    if ~success
        error(['Échec de la sauvegarde après ' num2str(max_attempts) ' tentatives.']);
    end
end
