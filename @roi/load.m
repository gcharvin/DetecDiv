function loadROI(obj, option)
% loadROI Robustly load image and data for a given ROI handle object.
%
%   loadROI(obj)
%       - charge toutes les couches image depuis im_<id>.h5 (nouveau format)
%         et reconstruit obj.image = [H W C T]
%       - sinon, si pas de .h5 mais un vieux im_<id>.mat existe,
%         charge ce .mat legacy (roiobj / im) et copie les propriétés.
%       - charge aussi obj.data depuis data_<id>.mat si dispo.
%
%   loadROI(obj,'data')
%       - charge uniquement les data (data_<id>.mat)
%
%   loadROI(obj,'GFP')
%       - charge uniquement le canal logique "GFP" depuis le .h5
%         dans obj.image = [H W k T]
%       - si pas de .h5 mais .mat legacy existe, charge l'image legacy complète.
%
% Comportement canal sélectif :
%   - si tu demandes 'GFP' et qu'on est en legacy (donc pas de .h5),
%     tu récupères tout le cube legacy (on ne peut pas isoler GFP proprement
%     sans la méta du HDF5).
%
% NOTE:
%   On ne purge pas obj.image ici. load == ram.

    narginchk(1,2);
    if nargin < 2
        option = "";
    end

    % Interpréter option :
    dataOnly = (ischar(option)   && strcmp(option,'data')) || ...
               (isstring(option) && strcmp(option,"data"));

    fullLoad = (isempty(option) || (isstring(option)&&option=="") || ...
               (iscell(option)&&isempty(option)));

    singleChannelMode = ~(dataOnly || fullLoad);
    if singleChannelMode && ~(ischar(option) || isstring(option))
        error('loadROI:InvalidOption', ...
            'Invalid option type. Use "data", "", or a channel name like "GFP".');
    end

    if isempty(obj.path)
        warning('loadROI:NoPath', 'ROI path is empty. Cannot load.');
        return;
    end

    % chemins fichiers
    h5File     = fullfile(obj.path, sprintf('im_%s.h5',  obj.id));
    legacyFile = fullfile(obj.path, sprintf('im_%s.mat', obj.id));
    dataFile   = fullfile(obj.path, sprintf('data_%s.mat', obj.id));

    disp(['Loading ROI : ' obj.id]);

    % ======================================
    % 1. IMAGE (nouveau HDF5 ou fallback .mat)
    % ======================================
    if ~dataOnly
        if isfile(h5File)
            % ----------- MODE HDF5 (nouveau format) -----------
            try
                if fullLoad
                    % Charger toutes les couches logiques et reconstruire le cube global
                    obj.image = loadAllDatasetsAndAssemble(h5File);
                else
                    % Charger seulement le dataset logique demandé
                    chanName = char(option);
                    obj.image = loadSingleDataset(h5File, chanName);
                end

                obj.log(sprintf('Loaded ROI image from %s.', h5File), 'Loading');
                disp(['Image for ROI ' obj.id ' successfully loaded (HDF5)']);

            catch ME
                warning('loadROI:ImageLoadFailed', ...
                    'Could not load ROI image (HDF5) for %s (%s).', obj.id, ME.message);
                obj.image = [];
            end

        elseif isfile(legacyFile)
            % ----------- MODE LEGACY .MAT -----------
            % Ancien format : im_<id>.mat contenait roiobj (et éventuellement im)
            try
                S = load(legacyFile);
                % Deux cas historiques :
                %  - roiobj struct/class avec les props complètes (dont image)
                %  - variable 'im' brute
                if isfield(S,'roiobj')
                    % copier les propriétés compatibles de l'ancien objet dans l'actuel
                    setProperties_legacy(obj, S.roiobj);

                  
                    % si l'ancien contenait directement les pixels dans roiobj.image
                    if isprop(S.roiobj,'image') && ~isempty(S.roiobj.image)
                        obj.image = S.roiobj.image;
                      
                    elseif isfield(S,'im') && ~isempty(S.im)
                        % fallback : variable séparée
                        obj.image = S.im;
                    end
                elseif isfield(S,'im')
                    % très vieux fallback: juste 'im'
                    obj.image = S.im;
                else
                    warning('loadROI:LegacyMissingImage', ...
                        'Legacy file %s has no roiobj/image/im.', legacyFile);
                    obj.image = [];
                end

                obj.log(sprintf('Loaded ROI image from legacy %s.', legacyFile), 'Loading');
                disp(['Image for ROI ' obj.id ' successfully loaded (legacy MAT)']);

       
            catch ME
                warning('loadROI:LegacyLoadFailed', ...
                    'Could not load legacy ROI image for %s (%s).', obj.id, ME.message);
                obj.image = [];
            end

        else
            % Ni .h5 ni .mat -> pas d'image dispo
            warning('loadROI:NoImageFile', ...
                'No image file (.h5 or legacy .mat) for ROI %s.', obj.id);
            obj.image = [];
        end
    end

    % ======================================
    % 2. DATA (toujours depuis data_<id>.mat)
    % ======================================
    if isfile(dataFile)
        try
            disp(['Loading ROI Data : ' obj.id]);
            S = load(dataFile, 'data');
            if isfield(S,'data')
                obj.data = S.data;
            else
                obj.data = dataseries.empty;
            end

            % call any post-fix routine
            if ismethod(obj,'fixLabelsInPlotFields')
                obj.fixLabelsInPlotFields;
            end

            obj.log(sprintf('Loaded ROI data from %s.', dataFile), 'Loading');
            disp(['Data from ROI: ' obj.id ' successfully loaded']);

        catch ME
            warning('loadROI:DataLoadFailed', ...
                'Could not load data for ROI %s (%s).', obj.id, ME.message);
            obj.data = dataseries.empty;
        end
    else
        obj.data = dataseries.empty;
        disp(['No ROI Data : ' obj.id ' available']);
    end
end


function setProperties_legacy(obj, srcObj)
    % copie les propriétés communes de srcObj -> obj,
    % sans écraser path/id de l'instance existante
    allProps = intersect(properties(obj), properties(srcObj));
    exclude = {'path','id','image','data'}; % on gère image/data à la main

    props = setdiff(allProps, exclude);
    for k = 1:numel(props)
        try
            val = srcObj.(props{k});
            % évite les effets "comma-separated list" sur objets/tableaux
            if isobject(val) && numel(val) > 1 && ~istable(val)
                val = reshape(val, 1, []);
            end
            obj.(props{k}) = val;
        catch ME
            warning('loadROI:LegacyPropAssign', ...
                'Could not assign legacy property "%s": %s', props{k}, ME.message);
        end
    end
end


function bigImg = loadAllDatasetsAndAssemble(h5File)
    info = h5info(h5File);

    % Récupère tous les datasets racine (chaque dataset = un canal logique)
    dsets = info.Datasets;
    if isempty(dsets)
        bigImg = [];
        return;
    end

    % On va:
    % 1. lire d'abord tous les attributs "channel_indices" pour savoir
    %    comment allouer le cube final,
    % 2. allouer bigImg à la bonne taille [H W C T],
    % 3. remplir bigImg(:,:,idxSet,:) pour chaque dataset.

    % Lire les index pour chaque dataset
    allIdx = cell(numel(dsets),1);
    sizes  = zeros(numel(dsets),4); % [H W k T] pour chaque dataset

    for k = 1:numel(dsets)
        dname = ['/' dsets(k).Name];
        dsinfo = h5info(h5File, dname);

        % attribut obligatoire qu'on a écrit au save()
        idxSet = h5readatt(h5File, dname, 'channel_indices'); % ex [3 4 5]
        idxSet = idxSet(:)';

        allIdx{k} = idxSet;

        sz = dsinfo.Dataspace.Size; % [H W k T]
        sizes(k,1:numel(sz)) = sz;
    end

    % Déduire dimensions globales
    H = sizes(1,1);
    W = sizes(1,2);
    T = sizes(1,4);

    % calculer le max C global
    allUsedIndices = [allIdx{:}];
    if isempty(allUsedIndices)
        C = sizes(1,3);
    else
        C = max(allUsedIndices);
    end

    % Allouer le gros cube final
    bigImg = zeros(H, W, C, T, 'like', h5read(h5File, ['/' dsets(1).Name]));

    % Remplir
    for k = 1:numel(dsets)
        dname = ['/' dsets(k).Name];
        block = h5read(h5File, dname);  % [H W k T]

        idxSet = allIdx{k};
        % on vérifie les tailles
        kBlock = size(block,3);
        if kBlock ~= numel(idxSet)
            error('loadROI:InconsistentIndexing', ...
                'Dataset %s: channel_indices length mismatch.', dname);
        end

        bigImg(:,:,idxSet,:) = block;
    end
end


function subImg = loadSingleDataset(h5File, chanName)
    % chanName est le nom logique tel qu'il a été sauvegardé
    % On le sanitize pour trouver le dataset dans le h5.
    dsetNameSanitized = sanitizeDatasetName(chanName);
    h5Path = ['/' dsetNameSanitized];

    % Lire le bloc [H W k T] directement
    subImg = h5read(h5File, h5Path);
    % Pas besoin de reconstruire la position C globale ici.
    % On renvoie juste ce bloc tel quel,
    % donc obj.image = subImg ; (H W k T)
end



function nameOut = sanitizeDatasetName(nameIn)
    s = char(string(nameIn));
    s = regexprep(s,'\s+','_');
    s = regexprep(s,'[^A-Za-z0-9_\-\.]','_');
    if isempty(s)
        s = 'channel';
    end
    nameOut = s;
end











% function loadROI(obj, option)
% % LOADROI Robustly load image and data for a given ROI handle object.
% %   loadROI(OBJ) loads both image and data files associated with the ROI.
% %   loadROI(OBJ, 'data') loads only the data file.
% 
%     % Validate inputs
%     narginchk(1,2);
%     validOptions = {'data'};
%     if nargin == 2 && ~ismember(option, validOptions)
%         error('loadROI:InvalidOption', 'Unknown option "%s".', option);
%     end
%     resonly = (nargin == 2 && strcmp(option, 'data'));
% 
%     % Ensure path is set
%    % Ensure path is set
%     if isempty(obj.path)
%         warning('loadROI:NoPath', 'ROI path is empty. Extract ROI before loading.');
%         return;
%     end
% 
%     % Construct file paths
%     imFile   = fullfile(obj.path, sprintf('im_%s.mat', obj.id));
%     dataFile = fullfile(obj.path, sprintf('data_%s.mat', obj.id));
% 
%     disp(['Loading ROI : ' obj.id]);
% 
%     % Load image file if needed
%     if ~resonly
%         if isfile(imFile)
%             try
%                 S = load(imFile, 'roiobj');
%                 % Copy roiobj properties into handle object, excluding path and id
%                 if isfield(S, 'roiobj')
%                     setProperties(obj, S.roiobj);
%                 end
% 
%                 % Assign image if present
%                 if isfield(S, 'im')
%                     obj.image = S.im;
% 
%                 end
%                 obj.log(sprintf('Loaded ROI image from %s.', imFile), 'Loading');
%                  disp(['ROI: ' obj.id ' successfully loaded']);
%             catch ME
%                 disp(['Could not load ROI image for: ' obj.id ' (' ME.message ')']);
%             end
%         end
%     end
% 
%     % Load data file
%     if isfile(dataFile)
%         try
%             disp(['Loading ROI Data : ' obj.id]);
%             S = load(dataFile, 'data');
%             obj.data = S.data;
%             obj.log(sprintf('Loaded ROI data from %s.', dataFile), 'Loading');
%             obj.fixLabelsInPlotFields;
%             disp(['Data from ROI: ' obj.id ' successfully loaded']);
%         catch ME
%             disp(['Could not load data for ROI: ' obj.id ' (' ME.message ')']);
%         end
%     else
%         disp(['No ROI Data : ' obj.id ' available']);
%     end
% end
% 
% % function setProperties(obj, srcObj)
% % % SETPROPERTIES Copy matching properties from srcObj to obj (handle), excluding critical ones
% %     allProps = intersect(properties(obj), properties(srcObj));
% %     % Exclude properties that should not be overwritten
% %     exclude = {'path','id'};
% %     props = setdiff(allProps, exclude);
% %     for k = 1:numel(props)
% %         obj.(props{k}) = srcObj.(props{k});
% %     end
% % end
% 
% function setProperties(obj, srcObj)
%     allProps = intersect(properties(obj), properties(srcObj));
%     exclude = {'path', 'id'};
%     props = setdiff(allProps, exclude);
% 
%     for k = 1:numel(props)
%         try
%             val = srcObj.(props{k});
% 
%             % Surtout ne pas faire reshape si c'est une table
%             if isobject(val) && numel(val) > 1 && ~istable(val)
%                 val = reshape(val, 1, []);  % évite comma-separated list
%             end
% 
%             obj.(props{k}) = val;
% 
%         catch ME
%             warning('⛔️ Could not assign property "%s": %s', props{k}, ME.message);
%         end
%     end
% end
