classdef roi < handle
    properties
        id=''; % name of the ROI
        value % indicates the x, y, width height of the ROI in the original image
        path % indicates the absolute path of the image to be loaded with load() method
        image=[]; % 4-D image of the roi : x, y, channel, time
        channelid=1; % nx1 array of numbers that indicates how the channels are organized within the image; exemple : channelid: [1 1 1 2 3 4 5 6] means that the first channel is composed of 3 subchannels, and there are 6 channels in total
       
        display=struct('intensity',[1 1 1],'frame',1,'selectedchannel',1,'binning',1,'rgb',[1 1 1],'channel',{'Channel 1'},'stretchlim',[],'displaylim',[0 ; 1], 'indexed', false, 'alpha', 1, 'contour', false, 'width', 1);

        % display struct structure : 
        % intensity: nx3 array, n is the number of channels; if all 3
        % elements are 0 for a given channel, then image is an indexed
        % image ; could be used t indicates the weight of an image. 
        % frame : current time frame to be displayed within the 4-D image
        % selectedchannel : nx1 array, n is the number of channels . If element == 1, then channel should be displayed, otherwise not. 
        %binning : n x 1 array, n is the number of channels. Indicats the binning number of the image 
        % rgb : n x 3 array, n is the number of channels, indicates the
        % color to use for display
        % channel : 1xn cell array of string; indicates the channel name; 
        %stretchlim : n x 2 array that indicates how the image limit are
        %computed before processing
        % displaylim : n x 2 array that indicates how the image limits are
        % computed 



        history=table('Size',[1 3],'VariableTypes',{'datetime','string','string'},'VariableNames',{'Date','Category','Message'});

        %unused properties : 
        proc=[];
        classes={};
        train=[] ; 
        results=[];

        data=dataseries; % array of dataseries objects

        extraction=struct('status','unknown','updatedAt','','runId',''); % extraction tracking flag

    end
    properties (Transient)
             parent=[] % reference of the parent field of view
    end
    methods
        function obj = roi(id,roiarr)
            %%%% here
            if nargin==0
                id='';
                roiarr=[];
            end

            obj.id=id;
            obj.value=roiarr;
            obj.setExtractionStatus('not_extracted');
        end

        function setExtractionStatus(obj, status, runId)
            if nargin < 2 || isempty(status)
                status = 'unknown';
            end
            st = lower(char(string(status)));
            if ~any(strcmp(st, {'unknown','not_extracted','extracted','stale'}))
                st = 'unknown';
            end

            if ~isstruct(obj.extraction) || isempty(obj.extraction)
                obj.extraction = struct();
            end

            obj.extraction.status = st;
            try
                obj.extraction.updatedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            catch
                obj.extraction.updatedAt = '';
            end

            if nargin >= 3 && ~isempty(runId)
                obj.extraction.runId = char(string(runId));
            elseif ~isfield(obj.extraction,'runId')
                obj.extraction.runId = '';
            end
        end

        function st = getExtractionStatus(obj)
            st = 'unknown';
            try
                if isstruct(obj.extraction) && isfield(obj.extraction,'status') && ~isempty(obj.extraction.status)
                    st = lower(char(string(obj.extraction.status)));
                end
            catch
                st = 'unknown';
            end
            if ~any(strcmp(st, {'unknown','not_extracted','extracted','stale'}))
                st = 'unknown';
            end
        end

        function tf = isExtracted(obj)
            tf = strcmp(obj.getExtractionStatus(), 'extracted');
        end

        function didSave = saveDisplayedChannels(obj, verbose)
            if nargin < 2 || isempty(verbose)
                verbose = true;
            end

            chanNames = {};
            try
                if isfield(obj.display,'channel') && isfield(obj.display,'selectedchannel')
                    names = obj.display.channel;
                    sel = logical(obj.display.selectedchannel(:)');
                    n = min(numel(names), numel(sel));
                    if n > 0
                        keep = find(sel(1:n));
                        if ~isempty(keep)
                            chanNames = names(keep);
                        end
                    end
                end
            catch
                chanNames = {};
            end

            if isempty(chanNames)
                didSave = save(obj, [], verbose);
            else
                didSave = save(obj, chanNames, verbose);
            end
        end

        function dataout=getData(roiobj,str)

            if numel(roiobj.data)==0 || (numel(roiobj.data)==1 && numel(roiobj.data(1).data)==0)
                roiobj.load('data');
            end

            if nargin==2
                switch class(str)
                    case "char"
                        pixdata=find(arrayfun(@(x) strcmp(x.groupid, str),roiobj.data)); % find if object exists already
                    case "uint8"
                        pixdata=str;
                    case "uint16"
                        pixdata=str;
                    case "double"
                        pixdata=str;
                    otherwise
                        disp('please specificy a valid argument!');
                        dataout=[];
                        return;
                end

                if numel(pixdata)
                    dataout=roiobj.data(pixdata);
                else
                    dataout=[];
                    disp('Could not find those data in the ROI')
                end
            else
                t={};

                for i=1:numel(roiobj.data)
                    t{i,1}=i;
                    t{i,2}=roiobj.data(i).groupid;
                    t{i,3}=roiobj.data(i).type;
                    t{i,4}=roiobj.data(i).class;
                end

                t=cell2table(t);
                t.Properties.VariableNames={'Index' 'Groupid' 'Type' 'Class'};
                disp(t)
                dataout=roiobj.data;
            end
        end

        function [dataout, labelout]=getTrainingData(roiobj,classistr)

            dataout=[];
            labelout=[];

            if numel(roiobj.data)==0 || (numel(roiobj.data)==1 && numel(roiobj.data(1).data)==0)
                roiobj.load('data');
            end

           pixdata=find(arrayfun(@(x) strcmp(x.groupid, classistr),roiobj.data)); % find if object exists already
            
           datas=roiobj.data(pixdata);

           if numel(find(matches(datas.data.Properties.VariableNames,'id_training')))
           dataout=datas.data.('id_training');
           end
           if numel(find(matches(datas.data.Properties.VariableNames,'labels_training')))
           labelout=datas.data.('labels_training');
           end
        end
         function setTrainingData(roiobj,classistr,id)

            dataout=[];
            labelout=[];

            if numel(roiobj.data)==0 || (numel(roiobj.data)==1 && numel(roiobj.data(1).data)==0)
                roiobj.load('data');
            end

           pixdata=find(arrayfun(@(x) strcmp(x.groupid, classistr),roiobj.data)); % find if object exists already
            
           datas=roiobj.data(pixdata);

           crea=0;
           if numel(datas)==0
            crea=1;
            datas=dataseries;
           else
            if numel(find(matches(datas.data.Properties.VariableNames,'id_training')))==0
                crea=1;
            end
           end

          if crea==0
           datas.data.('id_training')=id;
           classess=datas.data.userData.classes;
           categoryArray = categorical(id, 1:numel(classess), classess);
           datas.data.('labels_training')=id;
           else % create new training set
                 if numel(roiobj.image)==0 
                     roiobj.load,
                 end

                 sz=size(roiobj.image,4);
                 datas.addData(zeros(sz,1),{'id_training'},'group',{'id'});
           end

           
         end


        function hp=getTrainingHandle(roiobj,classistr)

            hp=[];
            htraj=findobj('Type','Figure');
            for j=1:numel(htraj)

                z= htraj(j).Name;

                if contains(z,roiobj.id) && contains(z,classistr)
                    
                    li=findobj(htraj(j),'Tag',[roiobj.id '_track']);

                    if numel(li)==0
                        continue
                    end

                    hp=findobj(htraj(j),'Tag','labels_training');
                end
            end

        end

                      function disp(obj)
            % Custom display for roi objects

            % Cas tableau : si l'utilisateur fait disp sur un array de ROI
            if numel(obj) > 1
                fprintf('[%dx1] roi objects array\n', numel(obj));
                ids = arrayfun(@(r) r.id, obj, 'UniformOutput', false);
                try
                    ids_str = strjoin(ids, ', ');
                    fprintf('IDs: %s\n', ids_str);
                catch
                end
                return;
            end

            r = obj; % alias court

            fprintf('==============================\n');
            fprintf('  ROI object\n');
            fprintf('==============================\n');

            %% ---- 1. Infos de base
            fprintf('ID        : %s\n', strsafe(r.id));

            % bounding box / value
            if ~isempty(r.value)
                try
                    bb = r.value;
                    if isnumeric(bb) && numel(bb) >= 4
                        fprintf('BBox      : [x=%g  y=%g  w=%g  h=%g]\n', bb(1), bb(2), bb(3), bb(4));
                    else
                        fprintf('BBox      : %s\n', strsafe(bb));
                    end
                catch
                    fprintf('BBox      : (unavailable)\n');
                end
            else
                fprintf('BBox      : []\n');
            end

            % path
            fprintf('Path      : %s\n', strsafe(r.path));

            % parent info (si dispo)
            if ~isempty(r.parent)
                parStr = '';
                if isprop(r.parent,'id') && ~isempty(r.parent.id)
                    parStr = sprintf('parent id=%s', strsafe(r.parent.id));
                elseif isprop(r.parent,'name') && ~isempty(r.parent.name)
                    parStr = sprintf('parent name=%s', strsafe(r.parent.name));
                else
                    parStr = class(r.parent);
                end
                fprintf('Parent    : %s\n', parStr);
            end

            fprintf('\n');

            %% ---- 2. Statut image
            if isempty(r.image)
                fprintf('Image     : NOT LOADED\n');
                fprintf('            -> call roi.load() to load image\n');
                fprintf('            -> call roi.load(''data'') to load ROI data only\n');
            else
                sz = size(r.image);
                % compléter à 4D
                while numel(sz) < 4
                    sz(end+1) = 1;
                end
                % rappel: MATLAB stocke classiquement [Y X C T]
                fprintf('Image     : loaded  [H=%d  W=%d  C=%d  T=%d]\n', sz(1), sz(2), sz(3), sz(4));
            end

            % channelid
            if ~isempty(r.channelid)
                fprintf('channelid : %s\n', num2str(r.channelid(:)'));
            end

            fprintf('\n');

            %% ---- 3. Display info détaillée (channels, mode, limites)
            fprintf('Display:\n');

            % frame courant
            if isfield(r.display,'frame')
                fprintf('  Current frame      : %s\n', num2str(r.display.frame));
            end

            % binning (peut être scalaire ou vecteur par canal)
            if isfield(r.display,'binning') && ~isempty(r.display.binning)
                fprintf('  Binning            : %s\n', num2str(r.display.binning(:)'));
            end

            % alpha / contour etc (optionnel, utile debug)
            if isfield(r.display,'alpha')
                fprintf('  Alpha              : %s\n', num2str(r.display.alpha));
            end
            if isfield(r.display,'contour')
                fprintf('  Contour overlay    : %s\n', bool2yn(r.display.contour));
            end

            % Maintenant on détaille canal par canal
            % On suppose cohérence dimensionnelle entre:
            %   display.channel        (1 x n cellstr)
            %   display.selectedchannel(n x 1)
            %   display.intensity      (n x 3)
            %   display.rgb            (n x 3)
            %   display.displaylim     (2 x n) ou (n x 2) selon ta convention
            %   display.indexed        (bool global ? ou par canal ? -> tu l'as défini globalement,
            %                            donc on déduira aussi à partir de intensity==0)

            chanNames = {};
            if isfield(r.display,'channel') && ~isempty(r.display.channel)
                chanNames = r.display.channel;
                if isstring(chanNames)
                    chanNames = cellstr(chanNames);
                end
                if ischar(chanNames)
                    chanNames = {chanNames};
                end
            end

            nChan = max([ ...
                sizeSafe(r.display,'selectedchannel',1), ...
                sizeSafe(r.display,'intensity',1), ...
                sizeSafe(r.display,'rgb',1), ...
                numel(chanNames) ...
            ]);

            if nChan==0
                fprintf('  (no channel display info)\n');
            else
                fprintf('  Channels (%d):\n', nChan);

                for ci = 1:nChan
                    % nom du canal
                    cname = '(unnamed)';
                    if ci <= numel(chanNames) && ~isempty(chanNames{ci})
                        cname = strsafe(chanNames{ci});
                    end

                    % actif ou masqué
                    activeTxt = '';
                    if isfield(r.display,'selectedchannel') && ~isempty(r.display.selectedchannel)
                        if ci <= numel(r.display.selectedchannel) && r.display.selectedchannel(ci)==1
                            activeTxt = 'ON';
                        else
                            activeTxt = 'OFF';
                        end
                    end

                    % intensité / rgb
                    intensRow = getRowSafe(r.display,'intensity',ci,[0 0 0]);
                    rgbRow    = getRowSafe(r.display,'rgb',ci,[1 1 1]);

                    % type de rendu
                    % règle:
                    %  - si intensité == [0 0 0]  OU display.indexed == true -> 'indexed'
                    %  - sinon si rgbRow genre [r g b] avec >1 composante non nulle -> 'rgb'
                    %  - sinon -> 'grayscale'
                    drawType = 'grayscale';

                    isIndexedGlobal = false;
                    if isfield(r.display,'indexed') && ~isempty(r.display.indexed)
                        % peut être bool ou tableau
                        if numel(r.display.indexed)==1
                            isIndexedGlobal = logical(r.display.indexed);
                        elseif ci <= numel(r.display.indexed)
                            isIndexedGlobal = logical(r.display.indexed(ci));
                        end
                    end

                    if (all(intensRow==0) && any(intensRow~=0)==false) || isIndexedGlobal
                        drawType = 'indexed';
                    else
                        nonZeroRGB = sum(rgbRow~=0);
                        if nonZeroRGB>1
                            drawType = 'rgb';
                        else
                            drawType = 'grayscale';
                        end
                    end

                    % display limits
                    dispLimStr = 'N/A';
                    if isfield(r.display,'displaylim') && ~isempty(r.display.displaylim)
                        dl = r.display.displaylim;
                        % tu l'as défini comme n x 2 ou 2 x n ?
                        % Dans ta def: 'displaylim',[0 ; 1] (donc 2 x nChannels)
                        % donc on lit colonne ci si possible
                        if size(dl,2) >= ci && size(dl,1) >= 2
                            dispLimStr = sprintf('[%g  %g]', dl(1,ci), dl(2,ci));
                        elseif size(dl,1) >= ci && size(dl,2) >= 2
                            % fallback si c'est n x 2
                            dispLimStr = sprintf('[%g  %g]', dl(ci,1), dl(ci,2));
                        end
                    end

                    % stretchlim (optionnel)
                    stretchStr = '';
                    if isfield(r.display,'stretchlim') && ~isempty(r.display.stretchlim)
                        sl = r.display.stretchlim;
                        if ~isempty(sl) && size(sl,1) >= ci && size(sl,2) >= 2
                            stretchStr = sprintf(' stretch=[%g %g]', sl(ci,1), sl(ci,2));
                        end
                    end

                    fprintf('    • Ch %d : %s\n', ci, cname);
                    fprintf('        status      : %s\n', activeTxt);
                    fprintf('        type        : %s\n', drawType);
                    fprintf('        displayLim  : %s%s\n', dispLimStr, stretchStr);
                end
            end

            fprintf('\n');

            %% ---- 4. Data / dataseries
            nDataObj = 0;
            if ~isempty(r.data)
                nDataObj = numel(r.data);
            end
            fprintf('Data objects linked: %d\n', nDataObj);

            for k = 1:nDataObj
                ds = r.data(k);

                g = '';
                if isprop(ds,'groupid')
                    g = strsafe(ds.groupid);
                end

                tp = '';
                if isprop(ds,'type')
                    tp = strsafe(ds.type);
                end

                clname = '';
                if isprop(ds,'class')
                    clname = strsafe(ds.class);
                end

                nRows = 0;
                if isprop(ds,'data') && ~isempty(ds.data)
                    if istable(ds.data)
                        nRows = height(ds.data);
                    elseif isnumeric(ds.data) || iscell(ds.data)
                        nRows = size(ds.data,1);
                    else
                        nRows = 1;
                    end
                end

                fprintf('  • [%d] %s', k, g);
                if ~isempty(tp)
                    fprintf(' | type=%s', tp);
                end
                if ~isempty(clname)
                    fprintf(' | class=%s', clname);
                end
                fprintf(' | entries in .data: %d\n', nRows);
            end

            fprintf('==============================\n');

            %% ---- helpers
            function out = strsafe(x)
                % Convertit divers types en texte pour affichage %s
                if isempty(x)
                    out = '';
                elseif ischar(x)
                    out = x;
                elseif isstring(x)
                    x = x(:);
                    out = strjoin(cellstr(x), ', ');
                elseif iscell(x)
                    try
                        out = strjoin(cellfun(@strsafe, x, 'UniformOutput', false), ', ');
                    catch
                        out = '[cell]';
                    end
                elseif isnumeric(x)
                    out = num2str(x);
                else
                    out = class(x);
                end
            end

            function n = sizeSafe(structIn, fieldName, dim)
                % renvoie size(structIn.(fieldName),dim) si dispo, sinon 0
                n = 0;
                if isfield(structIn, fieldName) && ~isempty(structIn.(fieldName))
                    try
                        n = size(structIn.(fieldName), dim);
                    catch
                        n = numel(structIn.(fieldName));
                    end
                end
            end

            function row = getRowSafe(structIn, fieldName, idx, defaultVal)
                % récupère la ligne idx d'un champ style (n x m), sinon defaultVal
                row = defaultVal;
                if isfield(structIn, fieldName) && ~isempty(structIn.(fieldName))
                    val = structIn.(fieldName);
                    if size(val,1) >= idx
                        row = val(idx,:);
                    elseif size(val,2) >= idx
                        % fallback si c'est transposé
                        row = val(:,idx)';
                    end
                end
                if ~isnumeric(row)
                    % sécurité
                    row = defaultVal;
                end
            end

            function out = bool2yn(b)
                try
                    if b
                        out = 'true';
                    else
                        out = 'false';
                    end
                catch
                    out = 'false';
                end
            end

        end



    end

    
end

