function [processObj, shallowObj] = lifespan_setupClassifier(app, processorName,index)
    %% Préparation du processing

    % Récupérer l'objet shallow depuis l'espace de travail à partir du nom de projet
    projName = app.shallowObj.io.file;
    if evalin('base', sprintf('exist(''%s'', ''var'')', projName))
        shallowObj = evalin('base', projName);
    else
        uialert(app.LifespanizerUIFigure, 'Project not found in workspace.', 'Error');
        return;
    end

    % Vérifier si un processor dont le nom contient processorName existe déjà
    existingProcessors = [];
    if isprop(shallowObj, 'processing') && isfield(shallowObj.processing, 'processor')
        existingProcessors = shallowObj.processing.processor;
    end

    foundIdx = [];
    if ~isempty(existingProcessors)
        for i = 1:numel(existingProcessors)
            if isprop(existingProcessors(i), 'strid') && contains(existingProcessors(i).strid, processorName)
                foundIdx = i;
                break;
            end
        end
    end

    if ~isempty(foundIdx)
        % Un processor CombineChannel existe déjà : récupérer ses paramètres
        processObj = existingProcessors(foundIdx);
        disp(['Processor ' processorName ' found. Using existing parameters.']);
    else
        % Sinon, ajouter un nouveau processor avec le nom défini
        shallowObj.addProcessor('name', processorName);
        processObj = shallowObj.processing.processor(end);
    
        % Charger la liste des processors
        procListFile = fullfile(fileparts(which('shallowNew.m')), 'processor', 'processlist.mat');
        if exist(procListFile, 'file')
            load(procListFile, 'processlist'); 
        else
            uialert(app.LifespanizerUIFigure, 'Processor list not found.', 'Error');
            return;
        end

       
        processObj.processFun = processlist{index,5}{1};
        processObj.processArg = {};

        % Initialiser les arguments du processor en appelant la fonction sans input
        param = feval(processObj.processFun);
        processObj.processArg = param;
    
        % Sauvegarder la configuration du processor
        processSave(processObj);
        disp('Setting up processor with default parameters');
    end

end
