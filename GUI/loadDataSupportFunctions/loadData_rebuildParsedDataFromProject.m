function parsedOut = loadData_rebuildParsedDataFromProject(shallowObj)

    % Sécurité : s'il n'y a pas de FOV du tout
    if ~isprop(shallowObj,'fov') || isempty(shallowObj.fov)
        parsedOut = struct();
        parsedOut.positions      = struct([]);
        parsedOut.numPositions   = 0;
        parsedOut.minFrame       = NaN;
        parsedOut.maxFrame       = NaN;
        parsedOut.currentMinFrame = NaN;
        parsedOut.currentMaxFrame = NaN;
        parsedOut.folder         = '';
        if isprop(shallowObj,'io')
            parsedOut.projectPath = fullfile(shallowObj.io.path, [shallowObj.io.file '.mat']);
        else
            parsedOut.projectPath = '';
        end
        % valeurs par défaut globales
        parsedOut.roitype        = 'full';
        parsedOut.roibb          = [];
        parsedOut.roipattern     = [];
        parsedOut.maxframeloading= 20;
        parsedOut.scale          = 1;
        parsedOut.correctdrift   = false;
        parsedOut.maxroidisplay  = 10;
        parsedOut.allpositions   = true;
        parsedOut.advancedMode   = false;
        parsedOut.files          = {};
        return
    end

    nFov = numel(shallowObj.fov);

    hasOldParsed = isprop(shallowObj,'parsedData') && ~isempty(shallowObj.parsedData);

    % --- 1) Construire un "template" de position avec tous les champs attendus
    emptyPosTemplate = struct( ...
        'folder',            '', ...
        'channelsDir',       {{}}, ...
        'numChannels',       0, ...
        'frames',            [], ...
        'minFrame',          NaN, ...
        'maxFrame',          NaN, ...
        'currentMinFrame',   NaN, ...
        'currentMaxFrame',   NaN, ...
        'userName',          '', ...
        'selected',          true, ...
        'extractROI',        true, ...
        'channelsSelected',  [], ...
        'userChanName',      {{}}, ...
        'channelFrequencies',[], ...
        'channelSizes',      {{}}, ...
        'roibb',             [] ...
        );

    % Pré-alloue parsedOut.positions avec le template pour chaque FOV
    parsedOut.positions = repmat(emptyPosTemplate, 1, nFov);

    % --- 2) Remplir chaque position
    for k = 1:nFov

        f = shallowObj.fov(k);

        % Récupération du template
        posStruct = emptyPosTemplate;

        % folder
        if ~isempty(f.srcpath)
            posStruct.folder = f.srcpath{1};
        else
            posStruct.folder = '';
        end

        % channelsDir = srclist (déjà un cell array {1 x nChannels})
        posStruct.channelsDir = f.srclist;

        % nombre de canaux
        nChan = numel(f.srclist);
        posStruct.numChannels = nChan;

        % frames: info temporelle par canal (f.frames)
        posStruct.frames = f.frames;

        if ~isempty(f.frames)
            posStruct.minFrame = 1;
            posStruct.maxFrame = max(f.frames);
        else
            posStruct.minFrame = NaN;
            posStruct.maxFrame = NaN;
        end

        % currentMinFrame / currentMaxFrame :
        if hasOldParsed && isfield(shallowObj.parsedData,'positions') ...
                        && k <= numel(shallowObj.parsedData.positions) ...
                        && isfield(shallowObj.parsedData.positions(k),'currentMinFrame') ...
                        && ~isempty(shallowObj.parsedData.positions(k).currentMinFrame)
            posStruct.currentMinFrame = shallowObj.parsedData.positions(k).currentMinFrame;
        else
            posStruct.currentMinFrame = posStruct.minFrame;
        end
        if hasOldParsed && isfield(shallowObj.parsedData,'positions') ...
                        && k <= numel(shallowObj.parsedData.positions) ...
                        && isfield(shallowObj.parsedData.positions(k),'currentMaxFrame') ...
                        && ~isempty(shallowObj.parsedData.positions(k).currentMaxFrame)
            posStruct.currentMaxFrame = shallowObj.parsedData.positions(k).currentMaxFrame;
        else
            posStruct.currentMaxFrame = posStruct.maxFrame;
        end

        % userName : on réutilise l'id du FOV (ex: 'Pos0_1')
        if isprop(f,'id') && ~isempty(f.id)
            posStruct.userName = f.id;
        else
            posStruct.userName = sprintf('Pos%d', k-1);
        end

        % selected / extractROI :
        if hasOldParsed && isfield(shallowObj.parsedData,'positions') && k <= numel(shallowObj.parsedData.positions)
            if isfield(shallowObj.parsedData.positions(k),'selected')
                posStruct.selected = shallowObj.parsedData.positions(k).selected;
            else
                posStruct.selected = true;
            end
            if isfield(shallowObj.parsedData.positions(k),'extractROI')
                posStruct.extractROI = shallowObj.parsedData.positions(k).extractROI;
            else
                posStruct.extractROI = true;
            end
        else
            posStruct.selected   = true;
            posStruct.extractROI = true;
        end

        % channelsSelected
        posStruct.channelsSelected = true(1, nChan);

        % userChanName : f.channel si dispo
        if isprop(f,'channel') && ~isempty(f.channel)
            posStruct.userChanName = f.channel;
        else
            posStruct.userChanName = arrayfun(@(c) sprintf('Channel%d',c-1), 1:nChan, ...
                                              'UniformOutput', false);
        end

        % channelFrequencies : f.interval si dispo, sinon 1
        if isprop(f,'interval') && ~isempty(f.interval)
            posStruct.channelFrequencies = f.interval;
        else
            posStruct.channelFrequencies = ones(1, nChan);
        end

        % channelSizes : essayer de déduire largeur/hauteur à partir de la première ROI extraite
        chSizes = cell(1, nChan);
        gotDims = false;
        if ~isempty(f.roi) && numel(f.roi)>=1 && ~isempty(f.roi(1).image)
            sz = size(f.roi(1).image);     % [H W C Frame]
            if numel(sz) >= 2
                w = sz(2);
                h = sz(1);
                gotDims = true;
            end
        end
        for c = 1:nChan
            if gotDims
                chSizes{c} = sprintf('%d %d', w, h);  % "width height"
            else
                chSizes{c} = '';
            end
        end
        posStruct.channelSizes = chSizes;

        % roibb :
        % priorité : bbox d'une ROI déjà extraite
        if ~isempty(f.roi) && numel(f.roi)>=1 && ~isempty(f.roi(1).value)
            posStruct.roibb = f.roi(1).value;
        elseif hasOldParsed && isfield(shallowObj.parsedData,'positions') ...
              && k <= numel(shallowObj.parsedData.positions) ...
              && isfield(shallowObj.parsedData.positions(k),'roibb')
            posStruct.roibb = shallowObj.parsedData.positions(k).roibb;
        else
            posStruct.roibb = [];
        end

        % enfin, assigner dans parsedOut.positions(k)
        parsedOut.positions(k) = posStruct;
    end

    % --- 3) champs globaux de parsedOut
    parsedOut.numPositions = nFov;

    % minFrame / maxFrame globaux
    allFrames = [];
    for k = 1:numel(parsedOut.positions)
        if ~isempty(parsedOut.positions(k).frames)
            allFrames = [allFrames(:); parsedOut.positions(k).frames(:)]; %#ok<AGROW>
        end
    end
    if ~isempty(allFrames)
        parsedOut.minFrame = min(allFrames);
        parsedOut.maxFrame = max(allFrames);
    else
        parsedOut.minFrame = NaN;
        parsedOut.maxFrame = NaN;
    end

    parsedOut.currentMinFrame = parsedOut.minFrame;
    parsedOut.currentMaxFrame = parsedOut.maxFrame;

    % folder / projectPath
    if isprop(shallowObj,'io')
        parsedOut.projectPath = fullfile(shallowObj.io.path, [shallowObj.io.file '.mat']);
        parsedOut.folder      = shallowObj.io.path;
    else
        parsedOut.projectPath = '';
        parsedOut.folder      = '';
    end

    % recopier (ou définir) les paramètres globaux du loader
    defaultFieldsFromOld = {'roitype','roibb','roipattern','maxframeloading','scale', ...
                            'correctdrift','maxroidisplay','allpositions','advancedMode','files'};
    for ff = 1:numel(defaultFieldsFromOld)
        fld = defaultFieldsFromOld{ff};
        if hasOldParsed && isfield(shallowObj.parsedData, fld)
            parsedOut.(fld) = shallowObj.parsedData.(fld);
        else
            switch fld
                case 'roitype'
                    parsedOut.roitype = 'full';
                case 'roibb'
                    parsedOut.roibb = [];
                case 'roipattern'
                    parsedOut.roipattern = [];
                case 'maxframeloading'
                    parsedOut.maxframeloading = 20;
                case 'scale'
                    parsedOut.scale = 1;
                case 'correctdrift'
                    parsedOut.correctdrift = false;
                case 'maxroidisplay'
                    parsedOut.maxroidisplay = 10;
                case 'allpositions'
                    parsedOut.allpositions = true;
                case 'advancedMode'
                    parsedOut.advancedMode = false;
                case 'files'
                    parsedOut.files = {};
            end
        end
    end

end
