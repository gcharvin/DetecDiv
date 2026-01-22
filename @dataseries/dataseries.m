classdef dataseries < handle
    properties
        % default properties with values
        id=''; % unique to identify a a particular dataset : x = dec2hex(randi([1 2^52]));

        groupid=''; % if it belongs to a given group of data
        parentid=''; % object id from which it was derived

        data=table; % value is an array
        class (1,1) string {mustBeMember(class, ["classification","regression","processing","other"])} = "other";
        type (1,1) string {mustBeMember(type, ["temporal","generation","other"])} = "temporal";

        % interval=1; % time interval in case it's temporal data;

        plotGroup;
        plotProperties;
        groupProperties;
        description; % information about the dataset; this can be an object which specifiies classes for classificaiton
        history;
        userData;
        show=true ; % whether this dataset must be plotted when plot function is called
        parent; % handle of the parent roi


    end
    methods
        function obj = dataseries(data,datanames,varargin) % constructor function

            %%%% warining : data must me a table , otherwise this created
            %%%% an error 

            if nargin==0
                data=table;
            end

            obj.id= dec2hex(randi([1 2^52]));

            for i=1:numel(varargin)
                if strcmp(varargin{i},'class')
                    if numel(find(matches( ["classification","regression","processing","other"],varargin{i+1})))
                        obj.class=varargin{i+1};
                    else
                        disp('this class does not exist');
                        return;
                    end
                end
                
                if strcmp(varargin{i},'type')
                    if numel(find(matches(["temporal","","other"],varargin{i+1})))
                        obj.type=varargin{i+1};
                    else
                        disp('this type does not exist');
                        return;
                    end
                end
                 if strcmp(varargin{i},'groupid') % actual name of the dataseries
                    obj.groupid=varargin{i+1};
                 end
                  if strcmp(varargin{i},'parentid')
                    obj.parentid=varargin{i+1};
                  end

                  if strcmp(varargin{i},'groups') % cell array representing the different subgroups of the dataset
                    obj.plotGroup={[] [] [] [] [] varargin{i+1}};
                  end

            end


            if istable(data)
            obj.data=data;
            else
            obj.addData(data,datanames);
          %  obj=
            %disp('Input data is not a table, therefore the object is void of data');
            end

            % build default group and plotproperties 

     nVar = width(obj.data);
defplot = repmat({false}, 1, nVar);
groups  = repmat({''},    1, nVar);



            for i=1:numel(varargin)
                 if strcmp(varargin{i},'plot') % cell array representing the different subgroups of the dataset
                    defplot=varargin{i+1};
                 end

                 if strcmp(varargin{i},'groups')
                    groups=varargin{i+1};
                 end
            end

            t={};
            varnames=obj.data.Properties.VariableNames;

                 for i=1:numel(varnames)
       
                   t{i,1}= defplot{i};
                   t{i,2}= varnames{i};
               
                   t{i,3}= class(obj.data.(varnames{i}));
                   t{i,4}= 'k';
                   t{i,5}= 2;
                    
                   % here : how to manage default groups !
                   % add a property in varargin to deal with grouping
                   % subdata


%                    if numel(find(contains(varnames{i},'id')))
%                    t{i,6}= 'id';
%                    end
%                    if numel(find(contains(varnames{i},'prob')))
%                    t{i,6}= 'prob';
%                    end
%                    if numel(find(contains(varnames{i},'labels')))
%                    t{i,6}= 'labels';
%                    end

                    t{i,6}=groups{i};
                 end

             obj.plotProperties=t;
             obj.plotGroup={[] [] [] [] [] unique(groups)};
        end

    function addData(obj, arr, arrname, varargin)

    sz = size(obj.data);

    groupitem = [];
    toplot = false;

    for i = 1:numel(varargin)
        if strcmp(varargin{i}, 'groups')
            groupitem = varargin{i+1};
        end
        if strcmp(varargin{i}, 'plot')
            toplot = varargin{i+1};
        end
    end

    % --------- IMPORTANT: normalize plotGroup{6} BEFORE using {end} ----------
    if isempty(obj.plotGroup) || numel(obj.plotGroup) < 6 || isempty(obj.plotGroup{6})
        obj.plotGroup = {[] [] [] [] [] {'id' 'prob' 'label'}};

    else
        if ischar(obj.plotGroup{6}) || isstring(obj.plotGroup{6})
            obj.plotGroup{6} = cellstr(obj.plotGroup{6});
        elseif ~iscell(obj.plotGroup{6})
            obj.plotGroup = {[] [] [] [] [] {'id' 'prob' 'label'}};

        end
        obj.plotGroup{6} = reshape(obj.plotGroup{6}, 1, []);
        if isempty(obj.plotGroup{6})
            obj.plotGroup = {[] [] [] [] [] {'id' 'prob' 'label'}};

        end
    end

    % --------- choose default groupitem safely ----------
    if isempty(groupitem)
        % si plotGroup{6} est vide malgré tout, fallback dur
        if isempty(obj.plotGroup{6})
            groupitem = 'id';
        else
            groupitem = obj.plotGroup{6}{end};
        end
    end

    if ischar(groupitem) || isstring(groupitem)
        groupitem = {char(groupitem)};
    elseif iscell(groupitem)
        % ok
    else
        groupitem = {'id'};
    end

    if ischar(arrname) || isstring(arrname)
        arrname = cellstr(arrname);
    end

    groups = [obj.plotGroup{6} groupitem];   % <- now safe

    % ... (le reste de ta fonction inchangé)



           %  if numel(obj.plotGroup{6})==0 || (numel(obj.plotGroup{6})==1 && numel(obj.plotGroup{6}{1})==0)
           % groups={groupitem};
           %  else
           % groups=[obj.plotGroup{6} groupitem];
           % 
           %  end

            if ischar(arrname)
                arrname={arrname};
            end

             outname={};
            if ( size(arr,2)~=numel(arrname)) %& sz(1)~=0 && | size(arr,1)~=sz(1) 
                disp('Wrong number of items in the list...Adjusting name of dataset');

                for i=1:size(arr,2)
                     outname{i}=[arrname{1} '_' num2str(i)];
                end
            else
                outname=arrname;
            end

currentHeight = height(obj.data);
newHeight = size(arr,1);
if newHeight > currentHeight
    numNewRows = newHeight - currentHeight;
    varNames = obj.data.Properties.VariableNames;
    % Créer une table avec numNewRows lignes et les mêmes variables, toutes remplies de missing
    newRows = table();
    for iVar = 1:numel(varNames)
        % Pour chaque colonne, remplir un vecteur de valeurs manquantes
        newRows.(varNames{iVar}) = repmat(missing, numNewRows, 1);
    end
    % Concaténer la table existante avec les nouvelles lignes
    obj.data = [obj.data; newRows];
elseif newHeight < currentHeight
    % Tronquer la table si besoin
    obj.data = obj.data(1:newHeight, :);
end

            for i=1:size(arr,2)
                    obj.data.(outname{i})=arr(:,i);

                    if numel(obj.plotProperties)
                    obj.plotProperties(end+1,:)=obj.plotProperties(end,:);
                    obj.plotProperties{end,1}=toplot;
                    obj.plotProperties{end,2}=outname{i};
                    obj.plotProperties{end,6}=groupitem;
                    else
                   t={};
       
                   t{1,1}= toplot;
                   t{1,2}= outname{i};
                   
                   t{1,3}= class(obj.data.(outname{i}));
                   t{1,4}= 'k';
                   t{1,5}= 2;
                   t{1,6}=groupitem;
               

                    obj.plotProperties=t;

                    end

            end

            obj.plotGroup={[] [] [] [] [] unique(groups)};
         
obj.ensurePlotProperties();

        end
        
        function newobj=copyData(obj)
            newobj=dataseries; 
            fields=fieldnames(obj);

            for i=1:numel(fields)
                if ~strcmp(fields{i},'id')
                    newobj.(fields{i})=obj.(fields{i});
                end
            end
        end

        function out=getData(obj,subdatasetname,varargin)
            % returns an array if the input is a char
            % returns a table if the input is cell array of string

            out=[];
            if numel(obj)==0
                return
            end

            data=obj.data;

            if nargin==2
                if iscell(subdatasetname)
                   out=table;

                    for i=1:numel(subdatasetname)
                        if numel(find(matches(data.Properties.VariableNames,subdatasetname{i})))
                            out.(subdatasetname{i})=data.(subdatasetname{i});
                        end
                    end
                elseif ischar(subdatasetname)
                    
                        if numel(find(matches(data.Properties.VariableNames,subdatasetname)))
                                 out=data.(subdatasetname);
                        end
                end
            else

              out=data;
              
            end

        end
        function out=dataSize(obj)
            out=size(obj.data);
        end


function ensurePlotProperties(obj)
% ensurePlotProperties  Make obj.plotProperties consistent with obj.data table.
% - One row per table variable
% - Ordered exactly like obj.data.Properties.VariableNames
% - Keeps existing settings when possible (matched by variable name)
% - Adds default rows for missing variables
% - Drops orphan rows (vars no longer in the table)
%
% obj is a handle.

    if ~istable(obj.data)
        return
    end

    t = obj.data;
    vnames = t.Properties.VariableNames;

    % --------- read old pp (if any) ---------
    ppOld = [];
    hasOld = isprop(obj,'plotProperties') && ~isempty(obj.plotProperties) && iscell(obj.plotProperties);

    if hasOld
        ppOld = obj.plotProperties;

        % normalize to Nx6
        if size(ppOld,2) < 6
            ppOld(:, end+1:6) = {[]};
        elseif size(ppOld,2) > 6
            ppOld = ppOld(:,1:6);
        end
    else
        ppOld = cell(0,6);
    end

    % build map name -> row
    ppNames = ppOld(:,2);
    if isempty(ppNames)
        ppNames = {};
    else
        % normalize name cells
        if isstring(ppNames), ppNames = cellstr(ppNames); end
        ppNames = cellfun(@(x) char(string(x)), ppNames, 'UniformOutput', false);
    end

    used = false(size(ppOld,1),1);

    % --------- build new pp in table order ---------
    ppNew = cell(numel(vnames), 6);

    for k = 1:numel(vnames)
        nm = vnames{k};

        idx = find(strcmp(ppNames, nm), 1, 'first');

        if ~isempty(idx)
            % keep old row
            row = ppOld(idx,:);
            used(idx) = true;
        else
            % default row
            row = obj.localDefaultRow(t, nm);
        end

        % always enforce correct name + type (type may change over time)
        row{2} = nm;
        row{3} = obj.localTypeOf(t.(nm));

        % if show flag is empty, re-infer default
        if isempty(row{1})
            row{1} = obj.localDefaultShow(nm);
        end

        % if role is empty, infer
        if isempty(row{6})
            row{6} = obj.localDefaultRole(nm);
        end

        % if color empty, default
        if isempty(row{4})
            row{4} = 'k';
        end

        % if col5 empty, default to 2 (as in your conventions)
        if isempty(row{5})
            row{5} = 2;
        end

        ppNew(k,:) = row;
    end

    % drop orphans: rows in old pp not used (vars removed from table)
    obj.plotProperties = ppNew;

% ==========================================================
% Ensure plotGroup{6} & groupProperties consistency
% ==========================================================

% normaliser plotProperties(:,6) en char scalaire (pas de cell-in-cell)
for i = 1:size(obj.plotProperties,1)
    g = obj.plotProperties{i,6};
    if iscell(g)
        if isempty(g), g = ''; else, g = g{1}; end
    end
    obj.plotProperties{i,6} = char(string(g));
end

% roles utilisés (col 6)
roles = obj.plotProperties(:,6);
roles = cellfun(@(x) char(string(x)), roles, 'UniformOutput', false);
roles = roles(~cellfun(@isempty, roles));
roles = unique(roles, 'stable');

roles(strcmp(roles,'labels')) = {'label'};
% et aussi dans plotProperties(:,6) si besoin :
for i=1:size(obj.plotProperties,1)
    if ischar(obj.plotProperties{i,6}) || isstring(obj.plotProperties{i,6})
        if strcmp(char(string(obj.plotProperties{i,6})), 'labels')
            obj.plotProperties{i,6} = 'label';
        end
    end
end


defaultGroups = {'id','label','prob'};

% --- normaliser plotGroup en {[] [] [] [] [] {groups}} ---
if isempty(obj.plotGroup) || ~iscell(obj.plotGroup) || numel(obj.plotGroup) < 6
    obj.plotGroup = {[] [] [] [] [] defaultGroups};
end
if isempty(obj.plotGroup{6})
    obj.plotGroup{6} = defaultGroups;
end
if ischar(obj.plotGroup{6}) || isstring(obj.plotGroup{6})
    obj.plotGroup{6} = cellstr(obj.plotGroup{6});
end
obj.plotGroup{6} = cellfun(@(x) char(string(x)), obj.plotGroup{6}, 'UniformOutput', false);
obj.plotGroup{6} = unique(obj.plotGroup{6}(:)', 'stable');

% ajouter roles manquants
for k = 1:numel(roles)
    if ~any(strcmp(obj.plotGroup{6}, roles{k}))
        obj.plotGroup{6}{end+1} = roles{k}; %#ok<AGROW>
    end
end

% remettre defaultGroups en tête si présents
pg = obj.plotGroup{6};
pg2 = {};
for k = 1:numel(defaultGroups)
    if any(strcmp(pg, defaultGroups{k}))
        pg2{end+1} = defaultGroups{k}; %#ok<AGROW>
    end
end
pg = [pg2, setdiff(pg, pg2, 'stable')];
obj.plotGroup{6} = pg;

% --- groupProperties aligné sur plotGroup{6} ---
pg = obj.plotGroup{6};

if isempty(obj.groupProperties) || ~iscell(obj.groupProperties)
    gpOld = cell(0,4);
else
    gpOld = obj.groupProperties;
end
if size(gpOld,2) < 4, gpOld(:, end+1:4) = {[]}; end
if size(gpOld,2) > 4, gpOld = gpOld(:,1:4); end

gpNames = gpOld(:,1);
gpNames = cellfun(@(x) char(string(x)), gpNames, 'UniformOutput', false);

gpNew = cell(numel(pg),4);
for k = 1:numel(pg)
    gname = pg{k};
    idx = find(strcmp(gpNames, gname), 1, 'first');
    if ~isempty(idx)
        row = gpOld(idx,:);
    else
        row = {gname,'Plot','auto','auto'};
    end
    row{1} = gname;
    if isempty(row{2}), row{2}='Plot'; end
    if isempty(row{3}), row{3}='auto'; end
    if isempty(row{4}), row{4}='auto'; end
    gpNew(k,:) = row;
end
obj.groupProperties = gpNew;

% ==========================================================
% Ensure userData.classes for label-like variables (stable ref)
% ==========================================================
if isempty(obj.userData) || ~isstruct(obj.userData)
    obj.userData = struct();
end

% repère les colonnes de type label (via plotProperties col6 ou nom)
pp = obj.plotProperties;
varNames = obj.data.Properties.VariableNames;

isLabelVar = false(1, numel(varNames));
for k = 1:numel(varNames)
    nm = varNames{k};

    % critère 1: role/group déclaré
    if size(pp,2) >= 6
        idx = find(strcmp(pp(:,2), nm), 1);
        if ~isempty(idx)
            g = pp{idx,6};
            if iscell(g), g = g{1}; end
            g = char(string(g));
            if strcmp(g,'label') || strcmp(g,'labels')
                isLabelVar(k) = true;
                continue
            end
        end
    end

    % critère 2: fallback sur nom
    if contains(nm,'label','IgnoreCase',true)
        isLabelVar(k) = true;
    end
end

labelVars = varNames(isLabelVar);

% Si on a des labels et pas de classes -> on les construit
if ~isempty(labelVars)
    if ~isfield(obj.userData,'classes') || isempty(obj.userData.classes)
        allCats = {};
        for k = 1:numel(labelVars)
            col = obj.data.(labelVars{k});
            if iscategorical(col)
                allCats = [allCats, categories(col)]; %#ok<AGROW>
            else
                allCats = [allCats, categories(categorical(string(col)))]; %#ok<AGROW>
            end
        end
        allCats = unique(allCats, 'stable');

        % option: forcer unclassified à la fin si tu veux
        if ~any(strcmp(allCats,'unclassified'))
            allCats{end+1} = 'unclassified';
        end

        obj.userData.classes = allCats;
    else
        % normalisation
        obj.userData.classes = cellstr(string(obj.userData.classes(:)'));
    end

    % Option fortement conseillée: recaster toutes les colonnes label sur ces classes
    classes = obj.userData.classes;
    for k = 1:numel(labelVars)
        nm = labelVars{k};
        col = obj.data.(nm);
        if ~iscategorical(col)
            col = categorical(string(col));
        end
        obj.data.(nm) = categorical(col, classes); % même base, mêmes codes
    end
end




end



 function removeData(obj, str, keepMode)
% removeData  Supprime ou conserve des colonnes de l'objet dataseries
%
% Usage :
%   obj.removeData('var1')             % supprime var1
%   obj.removeData({'v1','v2'})        % supprime v1 et v2
%   obj.removeData()                   % supprime toutes les données
%   obj.removeData('partie', true)     % conserve toutes les variables dont le nom contient 'partie'

    if nargin < 2
        % pas d'argument str : tout supprimer
        obj.data = table();
        obj.plotProperties = {};
        obj.plotGroup = {[] [] [] [] [] {}};
        return;
    end

    if nargin < 3
        keepMode = false;
    end

    % ---- Normaliser str en cellstr de char ----
    if isstring(str)
        str = cellstr(str);
    elseif ischar(str)
        str = cellstr(string(str));
    end
    if ~iscell(str)
        error('removeData: str doit être une string/char ou un cell array.');
    end
    % force cellstr(char)
    str = cellfun(@(x) char(string(x)), str, 'UniformOutput', false);

    allVars = obj.data.Properties.VariableNames; % cellstr

    % ---- Déterminer varsToRemove ----
    if keepMode
        maskKeep = false(size(allVars));
        for i = 1:numel(str)
            maskKeep = maskKeep | contains(allVars, str{i});
        end
        varsToRemove = allVars(~maskKeep);
    else
        varsToRemove = {};
        for i = 1:numel(str)
            matched = allVars(contains(allVars, str{i}));
            varsToRemove = [varsToRemove, matched]; %#ok<AGROW>
        end
        varsToRemove = unique(varsToRemove);
    end

    % ---- Supprimer vars de la table ----
    if ~isempty(varsToRemove)
        obj.data = removevars(obj.data, varsToRemove);

        % Purger plotProperties si existe
        if ~isempty(obj.plotProperties)
            % col2 = PlotName
            ppNamesChar = cellfun(@(x) char(string(x)), obj.plotProperties(:,2), 'UniformOutput', false);
            toDel = ismember(ppNamesChar, varsToRemove);
            obj.plotProperties(toDel,:) = [];
        end
    end

    % ---- Resynchroniser plotProperties sur l'ordre EXACT de obj.data ----
    try
        vars = string(obj.data.Properties.VariableNames(:));  % colonne, ordre vérité

        if isempty(vars)
            obj.plotProperties = {};
            obj.plotGroup{6} = {};
            return;
        end

        % Si pas de plotProperties, init minimal
        if isempty(obj.plotProperties)
            obj.plotProperties = obj.localInitPlotProperties_(vars);
        else
            % Construire une nouvelle plotProperties dans l'ordre de vars
            oldPP = obj.plotProperties;
            oldNames = string(oldPP(:,2)); % accepte char/cell

            ncol = size(oldPP,2);
            newPP = cell(numel(vars), ncol);

            for k = 1:numel(vars)
                v = vars(k);
                idx = find(oldNames == v, 1, 'first');
                if ~isempty(idx)
                    newPP(k,:) = oldPP(idx,:);
                else
                    newPP(k,:) = obj.localDefaultPlotRow_(v, ncol);
                end
            end

            obj.plotProperties = newPP;
        end

    catch ME
        warning('dataseries:removeData:plotPropertiesSync', ...
            'Could not sync plotProperties after removeData: %s', ME.message);
    end

    % ---- Mettre à jour la liste des groupes disponibles (col 6) ----
    if ~isempty(obj.plotProperties) && size(obj.plotProperties,2) >= 6
        col6 = obj.plotProperties(:,6);
        col6 = cellfun(@(x) char(string(x)), col6, 'UniformOutput', false);
        obj.plotGroup{6} = unique(col6);
    else
        obj.plotGroup{6} = {};
    end
 end

    end
    methods (Access = private)

% ============================================================
% Helpers
% ============================================================

function pp = localInitPlotProperties_(obj,vars)
% vars: string column
n = numel(vars);
ncol = 6; % si ton plotProperties a plus de colonnes, augmente ici
pp = cell(n, ncol);
for k = 1:n
    pp(k,:) = obj.localDefaultPlotRow_(vars(k), ncol);
end
end

function row = localDefaultPlotRow_(obj,varName, ncol)
row = cell(1,ncol);
row{1} = false;                % Plot
row{2} = char(varName);        % PlotName
row{3} = 'double';             % Type (default)
row{4} = 'k';                  % Color
row{5} = 2;                    % Width
if ncol >= 6
    row{6} = '';               % PlotGroup
end
end

% ---------------- local helpers ----------------
function typ = localTypeOf(obj,col)
    if iscategorical(col), typ = 'categorical';
    elseif isnumeric(col), typ = 'double';
    elseif islogical(col), typ = 'logical';
    elseif isstring(col),  typ = 'string';
    elseif iscell(col),    typ = 'cell';
    else,                  typ = class(col);
    end
end

function show = localDefaultShow(obj,nm)
    if contains(nm,'label','IgnoreCase',true)
        show = 1;
    else
        show = 0;
    end
end

function role = localDefaultRole(obj,nm)
    if startsWith(nm,'prob_')
        role = 'prob';
    elseif startsWith(nm,'id')
        role = 'id';
    elseif contains(nm,'label','IgnoreCase',true)
        role = 'label';
    else
        role = 'value';
    end
end

function row = localDefaultRow(obj,t, nm) %#ok<INUSD>
    row = {localDefaultShow(obj,nm), nm, localTypeOf(obj,t.(nm)), 'k', 2, localDefaultRole(obj,nm)};
end

    end

end
