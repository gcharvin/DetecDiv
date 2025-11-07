function appendVirtualChannel(obj, logicalName, dataHWkT, indexed)
% appendVirtualChannel(obj, logicalName, dataHWkT, indexed)
% Ajoute (ou appende) un canal virtuel dans le HDF5 de la ROI.
% - logicalName : nom logique (ex. 'SegMaskRGB', 'testcha')
% - dataHWkT    : [H W k T] (k=1 ou 3)
% - indexed     : true/false pour affichage indexé (défaut: false)
%
% Politique d'index:
% → On place le (ou les) sous-canaux au prochain indice C libre:
%       baseC = max(channelid) + 1   (ou 1 si vide)
%   et si k>1 : channel_indices = baseC : baseC + k - 1
%
% Effets de bord:
% - Crée le fichier HDF5 s'il n'existe pas encore.
% - Met à jour les métadonnées d'affichage en mémoire (obj.display).
% - Met à jour obj.channelid en lui ajoutant k entrées pointant vers le
%   nouveau canal logique (nCh).

    if nargin < 4 || isempty(indexed), indexed = false; end

    % ---- Normaliser data en [H W k T]
    im = dataHWkT;
    sz = size(im);
    if numel(sz)==2, sz = [sz 1 1]; im = reshape(im,sz); end
    if numel(sz)==3, sz = [sz 1];    im = reshape(im,sz); end

    H = sz(1); W = sz(2); k = sz(3); T = sz(4);
    if ~(k==1 || k==3)
        error('appendVirtualChannel:BadK','k must be 1 or 3 (got %d).',k);
    end
    thisClass = class(im);

    % ---- Localiser le HDF5
    h5File = '';
    try
        [h5File, exists] = obj.getH5Filename();
    catch
        % fallback robuste si getH5Filename n'est pas dispo
        if ~isprop(obj,'path') || isempty(obj.path) || ~isfolder(obj.path)
            error('roi/appendVirtualChannel:NoPath', ...
                'ROI.path manquant ou invalide, impossible de déduire le HDF5.');
        end
        if ~isprop(obj,'id') || isempty(obj.id)
            error('roi/appendVirtualChannel:NoID', ...
                'ROI.id manquant, impossible de déduire le HDF5.');
        end
        h5File = fullfile(obj.path, ['im_' obj.id '.h5']);
        exists = isfile(h5File);
    end

    % S'assurer que le dossier/fichier existe
    pth = fileparts(h5File);
    if ~isfolder(pth), mkdir(pth); end
    if ~exists
        fid = H5F.create(h5File,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT');
        H5F.close(fid);
    end

    % ---- Calculer l'indice C de base (prochain libre)
    if isprop(obj,'channelid') && ~isempty(obj.channelid)
        baseC = max(double(obj.channelid)) + 1;
    else
        baseC = 1;
    end
    if k==1
        chanVec = baseC;                 % ex: 4
    else
        chanVec = baseC:(baseC+k-1);     % ex: [4 5 6] pour RGB
    end

    % ---- Ecriture HDF5 (append/upsert)
    dset = ['/' sanitizeDatasetName(logicalName)];

    absStart0 = [];
    if isfield(obj.display,'write_abs_start') && ~isempty(obj.display.write_abs_start)
        absStart0 = double(obj.display.write_abs_start); % 0-based
    end

    upsertH5Dataset_frames(h5File, dset, im, [H W k T], thisClass, absStart0);

    % Attributs utiles pour le loader
    try, h5writeatt(h5File, dset, 'roi_id',         obj.id);            end
    try, h5writeatt(h5File, dset, 'channel_name',   logicalName);       end
    try, h5writeatt(h5File, dset, 'channel_indices', chanVec);          end  % *** clé ***
    try, h5writeatt(h5File, dset, 'frames',         1:T);               end
    try, h5writeatt(h5File, dset, 'indexed',        uint8(indexed~=0)); end

    % ---- MAJ des métadonnées d'affichage en mémoire
    if ~isfield(obj,'display') || isempty(obj.display) || ~isstruct(obj.display)
        obj.display = struct;
    end

    % Ajouter le nom logique en fin de liste
    if ~isfield(obj.display,'channel') || isempty(obj.display.channel)
        obj.display.channel = {logicalName};
    else
        obj.display.channel(end+1) = {logicalName};
    end
    nCh = numel(obj.display.channel);  % nouvel index logique

    % Assurer des valeurs cohérentes pour chaque champ d'affichage
    obj.display = ensureFieldRow(obj.display,'intensity',       [1 1 1],          nCh);
    obj.display = ensureFieldRow(obj.display,'rgb',             [1 1 1],          nCh);
    obj.display = ensureFieldRow(obj.display,'selectedchannel', 1,                nCh);
    obj.display = ensureFieldRow(obj.display,'indexed',         uint8(indexed),   nCh);
    obj.display = ensureFieldRow(obj.display,'alpha',           1,                nCh);
    obj.display = ensureFieldRow(obj.display,'contour',         0,                nCh);
    obj.display = ensureFieldRow(obj.display,'width',           0,                nCh);
    obj.display = ensureFieldRow(obj.display,'log',             0,                nCh);

    % displaylim: ajouter k colonnes [0;1]
    if ~isfield(obj.display,'displaylim') || isempty(obj.display.displaylim)
        obj.display.displaylim = repmat([0;1], 1, k);
    else
        obj.display.displaylim = [obj.display.displaylim repmat([0;1],1,k)];
    end

    % ---- MAJ de channelid (mapping sous-canaux -> canal logique)
    if ~isprop(obj,'channelid') || isempty(obj.channelid)
        obj.channelid = uint16(ones(1,k) * nCh);
    else
        obj.channelid = [obj.channelid uint16(ones(1,k) * nCh)];
    end

  % Only rebuild if display has no channels yet (fresh/empty child)
if ~isfield(obj,'display') || ~isstruct(obj.display) || ~isfield(obj.display,'channel') || isempty(obj.display.channel)
    obj = rebuildDisplayFromH5(obj, h5File);
end

    % ---- Log
    obj.log(sprintf('Appended virtual channel "%s" (%dx%dx%dx%d) → C %s', ...
        logicalName,H,W,k,T, mat2str(chanVec)), 'Saving');
end

% ==================== Helpers locaux ====================

function S = ensureFieldRow(S, field, valueRow, nCh)
    % Garantit qu'il y a au moins nCh lignes, et écrit la ligne nCh.
    if ~isfield(S,field) || isempty(S.(field))
        S.(field) = repmat(valueRow, nCh, 1);
    else
        cur = S.(field);
        if size(cur,1) < nCh
            pad = repmat(valueRow, nCh - size(cur,1), 1);
            S.(field) = [cur; pad];
        end
        S.(field)(nCh,1:numel(valueRow)) = valueRow;
    end
end

function nameOut = sanitizeDatasetName(nameIn)
    s = char(string(nameIn));
    s = regexprep(s, '^\s+|\s+$', '');
    s = regexprep(s, '\s+', '_');
    s = regexprep(s, '[^A-Za-z0-9_\-\.]', '_');
    if isempty(s), s = 'channel'; end
    nameOut = s;
end

function upsertH5Dataset_frames(h5filename, datasetName, data, dims_mat, thisClass, absStart0)
    if nargin < 6, absStart0 = []; end
    H = dims_mat(1); W = dims_mat(2); k = dims_mat(3);
    Tblock = size(data,4);

    if exist(h5filename,'file')
        fid = H5F.open(h5filename,'H5F_ACC_RDWR','H5P_DEFAULT');
    else
        fid = H5F.create(h5filename,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT');
    end

    exists = H5L.exists(fid, datasetName, 'H5P_DEFAULT') > 0;

    t0 = 0; Told = 0;
    if ~exists
        createResizableDataset(fid, datasetName, thisClass, [H W k 0]);
    else
        dset_id  = H5D.open(fid, datasetName);
        space_id = H5D.get_space(dset_id);
        [~, cur_dims, ~] = H5S.get_simple_extent_dims(space_id);
        H5S.close(space_id);
        dims = double(cur_dims(:).'); dims(end+1:4)=1;
        Told  = dims(1); k_old = dims(2); W_old = dims(3); H_old = dims(4);
        H5D.close(dset_id);

        try, t0 = double(h5readatt(h5filename, datasetName, 'abs_t0')); catch, t0 = 0; end

        if H_old~=H || W_old~=W || k_old~=k
            if H5L.exists(fid, datasetName, 'H5P_DEFAULT')>0
                H5L.delete(fid, datasetName, 'H5P_DEFAULT');
            end
            createResizableDataset(fid, datasetName, thisClass, [H W k 0]);
            Told = 0;
        end
    end

    % point de départ absolu
    if ~isempty(absStart0)
        absStart = max(0, floor(absStart0));
    else
        absStart = t0 + Told; % append par défaut
    end

    % extension gauche (rare)
    if absStart < t0 && (Told > 0)
        new_t0 = absStart;
        shift  = (t0 - new_t0);
        dset_id = H5D.open(fid, datasetName);
        Tnew_tmp = Told + shift;
        H5D.set_extent(dset_id, double([Tnew_tmp k W H]));
        H5D.close(dset_id);
        t0 = new_t0;
    end

    startRel = absStart - t0;
    Tnew     = max(Told, startRel + Tblock);

    dset_id = H5D.open(fid, datasetName);
    if Tnew > Told
        H5D.set_extent(dset_id, double([Tnew k W H]));
    end

    fspace  = H5D.get_space(dset_id);
    start_f = double([startRel 0 0 0]);
    count_f = double([Tblock   k W H]);
    H5S.select_hyperslab(fspace,'H5S_SELECT_SET', start_f, [], count_f, []);

    mspace = H5S.create_simple(4, count_f, []);
    h5type = matlabClassToH5(thisClass);

    H5D.write(dset_id, h5type, mspace, fspace, 'H5P_DEFAULT', data(:,:,:,1:Tblock));

    try, h5writeatt(h5filename, datasetName, 'abs_t0', t0);             end
    try, h5writeatt(h5filename, datasetName, 'abs_T',  Tnew);           end
    try, h5writeatt(h5filename, datasetName, 'abs_range', [t0, t0+Tnew-1]); end
 

    H5S.close(mspace); H5S.close(fspace);
    H5D.close(dset_id); H5F.close(fid);
end

function createResizableDataset(fid, datasetName, thisClass, dims_mat, deflateLevel)
    if nargin < 5, deflateLevel = 2; end

    H = dims_mat(1); W = dims_mat(2); k = max(1,dims_mat(3)); T = dims_mat(4);
    maxT = H5ML.get_constant_value('H5S_UNLIMITED');

    space_id = H5S.create_simple(4, double([T k W H]), double([maxT k W H]));
    dcpl     = H5P.create('H5P_DATASET_CREATE');

    % --- SAFE chunking ---
    % Si T==0 (création d'un dataset extensible vide), chunkT DOIT rester >=1.
    bpp         = bytesPerClass(thisClass);
    pixPerFrame = max(1, H*W*k);                 % garde-fous
    targetBytes = 4*1024*1024;                   % ~4 MB

    if T > 0
        chunkT = floor(targetBytes/(pixPerFrame*bpp));
        if ~isfinite(chunkT) || chunkT < 1, chunkT = 1; end
        chunkT = min(chunkT, T);                 % ne pas dépasser T existant
    else
        chunkT = 1;                              % T==0 → chunk temps minimal
    end

    H5P.set_chunk(dcpl, double([chunkT k W H]));
    H5P.set_shuffle(dcpl);
    H5P.set_deflate(dcpl, deflateLevel);

    h5type  = matlabClassToH5(thisClass);
    dset_id = H5D.create(fid, datasetName, h5type, space_id, 'H5P_DEFAULT', dcpl, 'H5P_DEFAULT');

    H5D.close(dset_id);
    H5P.close(dcpl);
    H5S.close(space_id);
end

function h5type = matlabClassToH5(cls)
    switch cls
        case 'uint8',   h5type = 'H5T_NATIVE_UCHAR';
        case 'int8',    h5type = 'H5T_NATIVE_CHAR';
        case 'uint16',  h5type = 'H5T_NATIVE_USHORT';
        case 'int16',   h5type = 'H5T_NATIVE_SHORT';
        case 'uint32',  h5type = 'H5T_NATIVE_UINT';
        case 'int32',   h5type = 'H5T_NATIVE_INT';
        case 'single',  h5type = 'H5T_NATIVE_FLOAT';
        case 'double',  h5type = 'H5T_NATIVE_DOUBLE';
        otherwise,      h5type = 'H5T_NATIVE_DOUBLE';
    end
end

function bpp = bytesPerClass(cls)
    switch cls
        case {'uint8','int8'},                   bpp = 1;
        case {'uint16','int16'},                 bpp = 2;
        case {'uint32','int32','single'},        bpp = 4;
        case {'uint64','int64','double'},        bpp = 8;
        otherwise,                               bpp = 2;
    end
end

function obj = rebuildDisplayFromH5(obj, h5File)
    info = h5info(h5File, '/');
    names  = {};
    idxMin = [];
    kList  = [];
    for d = 1:numel(info.Datasets)
        ds = info.Datasets(d);
        dsPath = ['/' ds.Name];
        % channel_name
        try
            nm = string(h5readatt(h5File, dsPath, 'channel_name'));
        catch
            nm = string(ds.Name); % fallback
        end
        % channel_indices (vecteur 1-based)
        try
            ci = double(h5readatt(h5File, dsPath, 'channel_indices'));
        catch
            % fallback: déduire k à partir de la 3e dim
            ci = 1:double(ds.Dataspace.Size(2));
        end
        names{end+1}  = char(nm); %#ok<AGROW>
        idxMin(end+1) = min(ci);  %#ok<AGROW>
        kList(end+1)  = numel(ci); %#ok<AGROW>
    end

    % Ordonner par indice C croissant (logique d'empilement)
    [~, ord] = sort(idxMin, 'ascend');
    names = names(ord);
    kList = kList(ord);

    % Mettre à jour display.channel
    if ~isfield(obj,'display') || ~isstruct(obj.display) || isempty(obj.display)
        obj.display = struct;
    end
    obj.display.channel = names;

    nCh = numel(names);
    totalK = sum(kList);

    % Assurer des tailles cohérentes pour les champs d'affichage
    obj.display = ensureFieldRow(obj.display,'intensity',       [1 1 1],        nCh);
    obj.display = ensureFieldRow(obj.display,'rgb',             [1 1 1],        nCh);
    obj.display = ensureFieldRow(obj.display,'selectedchannel', 1,              nCh);
    obj.display = ensureFieldRow(obj.display,'indexed',         uint8(0),       nCh);
    obj.display = ensureFieldRow(obj.display,'alpha',           1,              nCh);
    obj.display = ensureFieldRow(obj.display,'contour',         0,              nCh);
    obj.display = ensureFieldRow(obj.display,'width',           0,              nCh);
    obj.display = ensureFieldRow(obj.display,'log',             0,              nCh);

    % displaylim: doit avoir 2 x (somme des k)
    if ~isfield(obj.display,'displaylim') || isempty(obj.display.displaylim)
        obj.display.displaylim = repmat([0;1], 1, totalK);
    else
        curK = size(obj.display.displaylim, 2);
        if curK < totalK
            obj.display.displaylim = [obj.display.displaylim repmat([0;1],1,totalK-curK)];
        elseif curK > totalK
            obj.display.displaylim = obj.display.displaylim(:,1:totalK);
        end
    end
end
