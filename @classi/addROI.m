function addROI(classif,obj,varargin)

% add ROI to object classif

% ROIs are imported from obj, which is either another classification, or a FOV from a shallow project

% Option : a vector that contains the list of ROIs to be added

rois=[];
convert={};
adjustName={}; %classif.channelName;
adjustChannel={};
ioMap=[];

for i=1:numel(varargin)
    if strcmp(varargin{i},'rois') % input rois
        rois=varargin{i+1};
    end
    if strcmp(varargin{i},'convert') % provide character to explain how all classes will be converted
        convert=varargin{i+1};
    end
    if strcmp(varargin{i},'adjustName') % provide character to explain how all classes will be converted
        adjustName=varargin{i+1};
    end

    if strcmp(varargin{i},'adjustChannel') % provide character to explain which channels should be preserved/transferred
        adjustChannel=varargin{i+1};
    end

    if strcmp(varargin{i},'ioMap')
        ioMap = varargin{i+1};
    end
end


disp('==== addROI ====');
disp('rois = '), disp(rois);
disp('adjustChannel = '), disp(adjustChannel);
disp('adjustName = '), disp(adjustName);


if isa(obj,'fov')
    objtype="fov";
    disp('You want to import ROIs from an existing @fov for training');
elseif isa(obj,'classi')
    objtype="classi";
    disp('You want to import ROIs from an existing @classi for training');
    %disp('Training datasets (ground truth) may be preserved when transferring ROIs');
else
    disp('The object to transfer from is incompatible ! quitting');
    return;
end

if numel(rois)==0
    rois=1:numel(obj.roi);
end


% if nargin==2
%     disp(['This ' objtype ' has ' num2str(numel(obj.roi)) ' ROIs available']);
%     disp('You did not specify which ROI you want to import.');
%     prompt='Please enter the ROIs tu use as training sets: [ROI1id ROI2id ROI3id] (Default: [1 2 3])';
%     rois= input(prompt);
%     if numel(rois)==0
%         rois=[1 2 3];
%     end
%
% end

% if nargin==3 % use ROI numbers provdied as an extra argument
%     rois=option;
% end

disp('These ROIs will be imported:');
disp(rois);

%classif.addTrainingData(rois);

% copy dedicated ROIs to local classification folder and change path
cc=numel(classif.roi);

if cc==1
    if  numel(classif.roi(1).id)==0
        cc=0;
    end
end

preserv='';

arr={};

for i=1:length(rois)
    disp(['Processing ROI ' num2str(i) '/' num2str(length(rois))]);

    duplicate=0;

    roitocopy=obj.roi(rois(i));

    if numel(roitocopy.image)==0
        roitocopy.load;

        if numel(roitocopy.image)==0
            disp('ROI cannot be loaded or does not exist; Quitting !')
            continue
        end
    end


    % checking ROIs are already existing in this classi, based on the name
    for j=1:numel(classif.roi)
        if strcmp(roitocopy.id,classif.roi(j).id)
            disp(['WARNING: The imported ROIs ' roitocopy.id ' has the same name as an existing ROI in ' classif.strid]);
            disp('Therefore, we will not  not create a new ROI !');
            duplicate=j;
            break
        end
    end


    if duplicate > 0 % in this case, the roi can just be updated and that's it !
        %   pth=classif.roi(j).path;
        % classif.roi(j)=roitocopy;
        % classif.roi(j).path = pth;

        %   classif.roi(j)=propValues(classif.roi(j),roitocopy);
        %   classif.roi(j).path=pth;
        %   classif.roi(j).save;
        %    classif.roi(j).clear;
        continue
    end

    if cc==0
        classif.roi=roi('',[]);
    else
        classif.roi(cc+1)=roi('',[]);
    end

    classif.roi(cc+1)=propValues(classif.roi(cc+1),roitocopy);
    classif.roi(cc+1).path = classif.path;

    classif.roi(cc+1).classes=classif.classes;

    if numel(adjustName) % adjust the name of the channels to fit that of the target classifier
        targetChannel=classif.channelName;

        for ii=1:numel(adjustName)
            thisName = adjustName{ii};

            if isempty(thisName)
                continue
            end

            if ~ischar(thisName) && ~isstring(thisName)
                thisName = string(thisName); % conversion prudente
            end
            pix = find(matches(classif.roi(cc+1).display.channel, thisName));

            classif.roi(cc+1).display.channel{pix}=targetChannel{ii};
        end
    end

    if ~isempty(adjustChannel)
        % Normaliser en cellstr
        currentChannels = classif.roi(cc+1).display.channel;
        if ischar(currentChannels)
            currentChannels = {currentChannels};
        elseif isstring(currentChannels)
            currentChannels = cellstr(currentChannels);
        end

        if ischar(adjustChannel)
            adjustChannel = {adjustChannel};
        elseif isstring(adjustChannel)
            adjustChannel = cellstr(adjustChannel);
        end

        % canaux que l'on souhaite vraiment garder ET qui existent dans la ROI
        channelsToKeep   = intersect(currentChannels, adjustChannel, 'stable');
        % tous les autres seront supprimés
        channelsToRemove = setdiff(currentChannels, channelsToKeep, 'stable');

        % DEBUG (optionnel)
        % disp('currentChannels = '), disp(currentChannels);
        % disp('adjustChannel  = '), disp(adjustChannel);
        % disp('channelsToKeep = '), disp(channelsToKeep);
        % disp('channelsToRemove = '), disp(channelsToRemove);

        for k = 1:numel(channelsToRemove)
            classif.roi(cc+1).removeChannel(channelsToRemove{k});
        end
    end


    %size(classif.roi(cc+1).image)

    %% Warning : there is still a "train" property here that has not been replaced !!!

    if strcmp(classif.category{1},'Image Regression') || strcmp(classif.category{1},'LSTM Regression')
        classif.roi(cc+1).train.(classif.strid)=[];
        classif.roi(cc+1).train.(classif.strid).id= nan*ones(1,size(classif.roi(cc+1).image,4));

        if classif.output==1 % sequence-to-one regression
            classif.roi(cc+1).train.(classif.strid).id= nan;
        end

        if isa(obj,'classi')
            if isfield(roitocopy.train,obj.strid) % test if previous ROI has training
                classif.roi(cc+1).train.(classif.strid).id=roitocopy.train.(obj.strid).id;
            end
        end
    end

    trainingSetTransfer=false; % flag to determine whether dataseries for training set has to be generated

    if strcmp(classif.category{1},'Image') | strcmp(classif.category{1},'LSTM') | strcmp(classif.category{1},'Timeseries')


        data=roitocopy.data;

        if objtype=="classi" && ~isempty(convert) % users resquest conversion from classi
            pixtransferdata=find(arrayfun(@(x) strcmp(x.groupid, obj.strid),data)); % index of data to be stransferred
            if numel(pixtransferdata) %
                trainingSetTransfer=true;
            end
        end


        % to be done if mapping between different classi must be done
        % if isfield(roitocopy.train,obj.strid) % test if previous ROI has training
        %     if numel(convert) % preserve training set
        %
        %
        %         nclasses1=length(classif.classes);
        %         nclasses2=length(obj.classes);
        %
        %         %if  nclasses1~=nclasses2
        %         if numel(arr)==0
        %
        %
        %             disp(['current @classi has ' num2str(nclasses1) 'classes:']);
        %             disp(classif.classes);
        %
        %             disp(['@classi to import from has ' num2str(nclasses2) 'classes:']);
        %             disp(obj.classes);
        %
        %             % disp('You must map the first set of classes to the second');
        %
        %             tmp = textscan(strip(convert{2},'left'),'%s','Delimiter',' ');
        %
        %             tmp=tmp{1};
        %
        %             arr=[];
        %             for j=1:nclasses1
        %
        %                 %                             str='';
        %                 %                             for k=1:nclasses2
        %                 %                                 str=[str num2str(k) ' - ' obj.classes{k} ';'];
        %                 %                             end
        %                 %
        %                 %                             disp(['Enter the id number(s) of the  class corresponding to ' classif.classes{j}  ]);
        %                 %
        %                 %                             prompt=['Among these classes: ' str '; Type 0 if this class has no match; Default :'  num2str(j)];
        %                 %                             idclass= input(prompt);
        %                 %
        %                 %                             if numel(idclass)==0
        %                 %                                 idclass=j;
        %                 %                             end
        %
        %                 %         arr{j}=idclass;
        %                 %   arr(j)=0;
        %                 %  aa=
        %
        %                 pix=find(contains(tmp,classif.classes{j}));
        %                 if numel(pix)==0
        %                     pix=0;
        %                 end
        %
        %                 arr(j)= pix;
        %             end
        %
        %         end
        %
        %         %         arr
        %         %arr
        %
        %         %classif.roi(cc+1).train.(classif.strid).id=roitocopy.train(obj.strid).id;
        %
        %         for j=1:nclasses1
        %             for k=1:numel(arr)
        %
        %                 if arr(j)~=0
        %                     pix=roitocopy.train.(obj.strid).id==arr(j);
        %                     %j
        %                     %aa=classif.roi(cc+1).train.(classif.strid).id
        %
        %                     classif.roi(cc+1).train.(classif.strid).id(pix)=j;
        %
        %                     %bb=classif.roi(cc+1).train.(classif.strid).id
        %                 end
        %
        %             end
        %         end
        %
        %         % else % classes are identical betwen old and new classes
        %         %     classif.roi(cc+1).train.(classif.strid).id=roitocopy.train.(obj.strid).id;
        %         % end
        %
        %     end
        % end

        if ~trainingSetTransfer % create new dataseries with empty arrays
            disp('No training set available, creating empty dataseries');


            classif.roi(cc+1).train=[];
            classif.roi(cc+1).results=[];
            classif.roi(cc+1).train.(classif.strid)=[];
            classif.roi(cc+1).train.(classif.strid).id= zeros(1,size(classif.roi(cc+1).image,4));
            if classif.output==1 % sequence-to-one classification
                classif.roi(cc+1).train.(classif.strid).id= 0;
            end
            classif.roi(cc+1).train.(classif.strid).classes=classif.classes;

            formatInDataSeries(classif.roi(cc+1)); % converts train object to datseries;


        end

    end



    disp('Transfer all dataseries from copied ROI');

    roiData = classif.roi(cc+1).data;

    if isempty(roiData)
        cd = 1;
    else
        % roiData peut être un tableau de dataseries ou autre classe, on ne suppose pas que c'est un struct
        try
            lastHasGroup = false;
            if isstruct(roiData) && isfield(roiData(end),'groupid')
                lastHasGroup = ~isempty(roiData(end).groupid);
            elseif isprop(roiData(end),'groupid')
                lastHasGroup = ~isempty(roiData(end).groupid);
            end

            if lastHasGroup
                cd = numel(roiData) + 1;
            else
                cd = 1;
            end
        catch
            % En cas de doute, on repart de 1
            cd = 1;
        end
    end

    data=roiData;

    for ij=1:numel(data)

        % find if object exists already

        % if numel(pixdata) % checks if dataset is available

        %  ij=pixdata(1);
        % copy all datasets

        if numel(data(ij).groupid) % dataseries is not empty

            classif.roi(cc+1).data(cd)=dataseries;
            classif.roi(cc+1).data(cd)=propValues(classif.roi(cc+1).data(cd),data(ij));
            %classif.roi(cc+1).data(ij).groupid=classif.strid;
            classif.roi(cc+1).data(cd).data = data(ij).data;

            %     if strcmp(class(obj),'classi') & strcmp(data(ij).groupid,obj.strid) % change data groupid to match the name of the  new classifier
            %         classif.roi(cc+1).data(ij).groupid=classif.strid;
            %     end

            if trainingSetTransfer % transfer dataset but modify data groupid
                if ij==pixtransferdata
                    disp('Found and transferred training set data from copied ROI');
                    classif.roi(cc+1).data(cd).groupid=classif.strid;
                    classif.roi(cc+1).data(cd).removeData('train','keep') % only keep training fields and remove previous classif results
                end
            end
            cd=cd+1;
        end
    end


    % classif.roi(cc+1).train= zeros(1,size(classif.roi(cc+1).image,4));

    if strcmp(classif.category{1},'Pedigree')
        classif.roi(cc+1).train.(classif.strid)=[];
        classif.roi(cc+1).train.(classif.strid).id= zeros(1,size(classif.roi(cc+1).image,4));
        classif.roi(cc+1).train.(classif.strid).classes=classif.classes;
        classif.roi(cc+1).train.(classif.strid).mother= [];%zeros(1,size(classif.roi(cc+1).image,4));
        % classif.roi(cc+1).train= zeros(1,size(classif.roi(cc+1).image,4));

        %   im=classif.roi(cc+1).image;
        %size(im)
        %   ch=classif.roi(cc+1).findChannelID(classif.channelName{2});
        %   matrix=im(:,:,ch,:);

        %   classif.roi(cc+1).addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
    end


    % ---------- Renommage générique des canaux selon destName ----------
        % ---------- Renommage générique des canaux selon destName ----------
    if ~isempty(ioMap) && isstruct(ioMap)

        chNames = [];
        if isfield(classif.roi(cc+1).display,'channel') && ...
                ~isempty(classif.roi(cc+1).display.channel)

            chNames = classif.roi(cc+1).display.channel;
            if ischar(chNames)
                chNames = {chNames};
            elseif isstring(chNames)
                chNames = cellstr(chNames);
            elseif ~iscell(chNames)
                chNames = {};
            end
        else
            chNames = {};
        end

        for mm = 1:numel(ioMap)
            % import flag robuste
            doImport = true;
            if isfield(ioMap,'import')
                val = ioMap(mm).import;
                if isempty(val)
                    doImport = false;
                elseif islogical(val) && isscalar(val)
                    doImport = val;
                elseif isnumeric(val) && isscalar(val)
                    doImport = (val ~= 0);
                else
                    doImport = false;
                end
            end
            if ~doImport
                continue;
            end

            % src/dest robustes
            src  = '';
            dest = '';

            if isfield(ioMap,'sourceName')
                src = ioMap(mm).sourceName;
            end
            if isstring(src), src = char(src); end
            if ~ischar(src) || isempty(strtrim(src))
                continue;
            end

            if isfield(ioMap,'destName')
                dest = ioMap(mm).destName;
            end
            if isstring(dest), dest = char(dest); end
            if ~ischar(dest)
                dest = '';
            end
            dest = strtrim(dest);

            if isempty(dest) || strcmp(dest, src)
                continue;  % pas de renommage si identique ou vide
            end

            % ioChannel pour filtrer output + inputs
            ioCh = '';
            if isfield(ioMap,'ioChannel')
                ioCh = ioMap(mm).ioChannel;
            end
            if isstring(ioCh), ioCh = char(ioCh); end
            if ~ischar(ioCh)
                ioCh = '';
            end
            ioCh = strtrim(ioCh);

            % 1) Ne pas toucher au canal d'annotation (output) : géré plus bas
            if ~isempty(ioCh) && strcmp(ioCh, classif.strid)
                continue;
            end

            % 2) Ne pas toucher aux canaux mappés sur les INPUTS du classif
            if ~isempty(ioCh) && ~isempty(classif.channelName) ...
                    && any(strcmp(classif.channelName, ioCh))
                continue;
            end

            if isempty(chNames)
                continue;
            end

            idx = find(matches(chNames, src));
            if ~isempty(idx)
                classif.roi(cc+1).display.channel(idx) = {dest};
            end
        end
    end



    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') |  strcmp(classif.category{1},'Delta')  |  strcmp(classif.category{1},'Pedigree')
        im = classif.roi(cc+1).image;


        % ----------- Détermination du nom du canal d'annotation final -----------
        if isempty(classif.classes)
            outName = [classif.strid '_cell'];   % fallback
        else
            outName = [classif.strid '_' classif.classes{1}];
        end

        % ----------- CAS SPECIAL Pixel : canal d'annotation déjà existant -----------
           % ----------- CAS SPECIAL Pixel : canal d'annotation déjà existant -----------
    reuseGT = false;

    if strcmp(classif.category{1},'Pixel') && ~isempty(ioMap) && isstruct(ioMap)

        % sécuriser les noms de canaux existants
        chNames = [];
        if isfield(classif.roi(cc+1).display,'channel') && ...
                ~isempty(classif.roi(cc+1).display.channel)

            chNames = classif.roi(cc+1).display.channel;
            if ischar(chNames)
                chNames = {chNames};
            elseif isstring(chNames)
                chNames = cellstr(chNames);
            elseif ~iscell(chNames)
                chNames = {};
            end
        else
            chNames = {};
        end

        for mm = 1:numel(ioMap)

            % --- flag "import" robuste ---
            doImport = true;
            if isfield(ioMap,'import')
                val = ioMap(mm).import;
                if isempty(val)
                    doImport = false;
                elseif islogical(val) && isscalar(val)
                    doImport = val;
                elseif isnumeric(val) && isscalar(val)
                    doImport = (val ~= 0);
                else
                    % forme bizarre -> on considère que ce n'est pas à importer
                    doImport = false;
                end
            end
            if ~doImport
                continue;
            end

            % --- ioChannel robuste ---
            if ~isfield(ioMap,'ioChannel')
                continue;
            end
            ioCh = ioMap(mm).ioChannel;
            if isstring(ioCh), ioCh = char(ioCh); end
            if ~ischar(ioCh) || isempty(strtrim(ioCh))
                continue;
            end

            % ce canal est-il mappé sur l'output logique du classif ?
            if ~strcmp(strtrim(ioCh), classif.strid)
                continue;
            end

            % --- source / destination robustes ---
            srcName  = '';
            destName = '';

            if isfield(ioMap,'sourceName')
                srcName = ioMap(mm).sourceName;
            end
            if isstring(srcName), srcName = char(srcName); end
            if ~ischar(srcName), srcName = ''; end

            if isfield(ioMap,'destName')
                destName = ioMap(mm).destName;
            end
            if isstring(destName), destName = char(destName); end
            if ~ischar(destName), destName = ''; end

            if isempty(destName)
                destName = srcName;
            end

            if isempty(chNames)
                continue;
            end

            % --- trouver le canal dans la ROI importée (par nom logique) ---
            idxGT = find(matches(chNames, destName));
            if isempty(idxGT) && ~isempty(srcName)
                idxGT = find(matches(chNames, srcName));
            end

            if ~isempty(idxGT)
                classif.roi(cc+1).display.channel(idxGT) = {outName};
                reuseGT = true;
                break;
            end
        end
    end



        % ----------- Si canal d'annotation existe déjà → ne pas en créer -----------
        pixOut = classif.roi(cc+1).findChannelID(outName);

        if isempty(pixOut)
            % ----------- Il faut créer les canaux d'annotation vierges -----------
            matrix = uint16(zeros(size(im,1),size(im,2),1,size(im,4)));

            for k = 1:numel(classif.classes)
                newName = [classif.strid '_' classif.classes{k}];
                classif.roi(cc+1).addChannel(matrix, newName, [1 1 1], [0 0 0]);
                classif.roi(cc+1).display.selectedchannel(end) = 1;
            end

            % Fallback si classif.classes vide → 1 canal
            if isempty(classif.classes)
                classif.roi(cc+1).addChannel(matrix, outName, [1 1 1], [0 0 0]);
                classif.roi(cc+1).display.selectedchannel(end) = 1;
            end
        end





        if isa(obj,'classi')
            %   if  strcmp(obj.category{1},'Pixel') % phenocopy the groundtruth

            %   aa=obj.strid



            pixid= roitocopy.findChannelID(obj.strid);
            pixidnew=classif.roi(cc+1).findChannelID(classif.strid);


            if numel(pixid) && numel(pixidnew) % copy the groundthruth to new classi
                classif.roi(cc+1).image(:,:,pixidnew,:)= roitocopy.image(:,:,pixid,:);
            end




            % pixid=      classif.roi(cc+1).findChannelID(obj.strid);
            % pixidnew=classif.roi(cc+1).findChannelID(classif.strid);
            %
            %
            % if numel(pixid) && numel(pixidnew) % copy the groundthruth to new classi
            %     classif.roi(cc+1).image(:,:,pixidnew,:)= classif.roi(cc+1).image(:,:,pixid,:);
            % end

            %classif.roi(i).display.channel{pixid}=classif.strid;
        end
        %  end
        %pixelchannel=size(obj.image,3);
    end


    %     if strcmp(classif.category{1},'Object') |  strcmp(classif.category{1},'Delta')  |  strcmp(classif.category{1},'Pedigree')
    %         im=classif.roi(cc+1).image;
    %         %size(im)
    %
    %         matrix=uint16(im(:,:,classif.channel(2),:)>0);
    %
    %         classif.roi(cc+1).addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
    %
    %         %     if isa(obj,'classi')
    %         %         pixid=classif.roi(i).findChannelID(obj.strid);
    %         %         classif.roi(i).display.channel{pixid}=classif.strid;
    %         %     end
    %         %pixelchannel=size(obj.image,3);
    %     end

    classif.roi(cc+1).save;
    classif.roi(cc+1).clear;

    cc=cc+1;
end


function newObj=propValues(newObj,orgObj)
pl = properties(orgObj);
for k = 1:length(pl)
    if isprop(newObj,pl{k}) && ~strcmp(pl{k},'data')
        newObj.(pl{k}) = orgObj.(pl{k});
    end
end

