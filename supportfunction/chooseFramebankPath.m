function fbPath info = chooseFramebankPath(basePath)
        % Choisit un chemin de framebank "sain" :
        % - teste basePath, puis basePath_001, basePath_002, ...
        % - si un chemin existe et est supprimable -> on le réutilise
        % - si un chemin existe et n'est PAS supprimable -> on le considère vérolé et on passe au suivant
        [folder, baseName, ext] = fileparts(basePath);

        maxTries = 999;
        for kk = 0:maxTries
            if kk == 0
                candidateName = baseName;
            else
                candidateName = sprintf('%s_%03d', baseName, kk);
            end
            candidatePath = fullfile(folder, [candidateName ext]);

            if exist(candidatePath, 'file')
                fprintf('WARNING: candidate CNN framebank exists, trying delete: %s\n', candidatePath);
                if tryDeleteSafe(candidatePath)
                    fprintf('  -> old CNN framebank deleted, reusing path: %s\n', candidatePath);
                    fbPath = candidatePath;
                    return;
                else
                    fprintf('  -> cannot delete (locked/corrupted?), skipping this path.\n');
                    continue;
                end
            else
                fprintf('Using new CNN framebank path: %s\n', candidatePath);
                fbPath = candidatePath;
                return;
            end
        end

        error('formatLSTMTrainingSet:NoFramebankPath', ...
              'Could not find usable CNN framebank path after %d attempts starting from %s', ...
              maxTries+1, basePath);
    
    end