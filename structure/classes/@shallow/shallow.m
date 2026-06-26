classdef shallow < handle
    % class that defines the structure of an image processing project
    properties
        % default properties with values
        io=struct('path','','file','');
        projectId=''; % stable id used by lightweight project manifests
        parsedData;
        fov=fov();%fov({},1,'');
        processing=struct('roi',[],'classification',[],'processor',[],'pipelineRun',[]);
        runProfiles = struct(); % pipeline/dataloading checkpoints and params
        
        
        tag='shallow project';
        
    end
    
    methods
        function obj = shallow(pathname,filename) % filename contains a list of path to images used in the movi project
            %  obj.props.path=pathname;
            % obj.props.name=filename;
            
            
        end
        function obj = setPath(obj,pathe,file) % filename contains a list of path to images used in the movi project
            %  obj.props.path=pathname;
            % obj.props.name=filename;
            
            
   
            oldpath=fixpath(obj.io.path);
            
           % oldpath(strfind(oldpath,'\'))='/';
            
            %oldpath,pathe
            
            oldfile=obj.io.file;
            
            obj.io.path=pathe;
            obj.io.file=file;
            
            % also adjust set path of dependencies
            
            oldfullpath=fullfile(oldpath,oldfile);
            
            newpath=fullfile(pathe,file);
            
            
%             if ispc
%                 oldfullpath=replace(oldfullpath,'/','\');
%                 newpath=replace(newpath,'/','\');
%             else
%                 oldfullpath=replace(oldfullpath,'\','/');
%                 newpath=replace(newpath,'\','/');
%             end
            
            
            
            for i=1:numel(obj.fov)
                for j=1:numel(obj.fov(i).roi)
                    if numel(obj.fov(i).roi(j).path)~=0
                        % oldpath
                        % pathe
                        
                        
                        obj.fov(i).roi(j).path=fixpath(fullfile(obj.fov(i).roi(j).path));
                        
%                         if ispc
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'/','\');
%                         else
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'\','/');
%                         end
                        
                        %    aa=obj.fov(i).roi(j).path
                        %       oldfullpath
                        % newpath
                        
                        obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,oldfullpath,newpath);
                        
%                         if ispc
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'/','\');
%                         else
%                             obj.fov(i).roi(j).path = replace(obj.fov(i).roi(j).path,'\','/');
%                         end

                    end
                end
            end
            

            for i=1:numel(obj.processing.classification)
                
              %  aa=obj.processing.classification(i).path;
     
    if ~isvalid(obj.processing.classification(i)) % sometimes this handle is deleted !
        continue
    end
                
                obj.processing.classification(i).path=fixpath(fullfile(obj.processing.classification(i).path));
                
            %    bb=obj.processing.classification(i).path;
                
            %    obj.processing.classification(i).path(
%                 if ispc
%                     obj.processing.classification(i).path= replace( obj.processing.classification(i).path,'/','\');
%                 else
%                     obj.processing.classification(i).path = replace( obj.processing.classification(i).path,'\','/');
%                 end
                
                
                obj.processing.classification(i).path = replace(obj.processing.classification(i).path,oldfullpath,newpath);
                
                
             %   bb=obj.processing.classification(i).path
          
                
                for j=1:numel(obj.processing.classification(i).roi)
                    
                    
                    obj.processing.classification(i).roi(j).path=fixpath(fullfile(obj.processing.classification(i).roi(j).path));
                    
                    
%                     if ispc
%                         obj.processing.classification(i).roi(j).path = replace( obj.processing.classification(i).roi(j).path,'/','\');
%                     else
%                         obj.processing.classification(i).roi(j).path = replace( obj.processing.classification(i).roi(j).path,'\','/');
%                     end
                    
                    
                    obj.processing.classification(i).roi(j).path = replace(obj.processing.classification(i).roi(j).path,oldfullpath,newpath);
                    
%                     if ispc
%                         obj.processing.classification(i).roi(j).path = replace(obj.processing.classification(i).roi(j).path,'/','\');
%                     else
%                         obj.processing.classification(i).roi(j).path = replace(obj.processing.classification(i).roi(j).path,'\','/');
%                     end
                    
                end
            end
            
            for i=1:numel(obj.processing.processor)
                obj.processing.processor(i).path=fixpath(fullfile(obj.processing.processor(i).path));
                obj.processing.processor(i).path = replace(obj.processing.processor(i).path,oldfullpath,newpath);
             end

             % pipeline run path update
             if isfield(obj.processing,'pipelineRun')
                 for i=1:numel(obj.processing.pipelineRun)
                     try
                         obj.processing.pipelineRun(i).path=fixpath(fullfile(obj.processing.pipelineRun(i).path));
                         obj.processing.pipelineRun(i).path = replace(obj.processing.pipelineRun(i).path,oldfullpath,newpath);
                     catch
                     end
                 end
             end

                
            
            function pathout=fixpath(pathin)
                pathout=pathin;
                if ~ispc
                    
                pathout(strfind(pathout,'\'))='/';
                
                else
                    
                pix=strfind(pathout,'\\');
                
                if numel(pix)
                  pathout=pathout(pix+1:end);  
                end
                
                pathout(strfind(pathout,'/'))='\';
                end
            end
            
        end

  function obj = setSrcPath(obj, option)
% setSrcPath met à jour le chemin source (srcpath) de chaque FOV en ne modifiant
% que la base du chemin.
%
% USAGE :
%   obj = obj.setSrcPath()              % Utilise le mode GUI par défaut
%   obj = obj.setSrcPath(option)        % option peut être 'GUI' ou 'command'
%
% Seule la partie de base du chemin sera modifiée pour tous les FOV et tous les canaux.
%
% Exemple :
%   Si le chemin actuel est :
%       'C:\AncienneBase\projet\images'
%   et que l'utilisateur souhaite remplacer 'C:\AncienneBase' par 'D:\NouvelleBase',
%   alors le chemin sera mis à jour en :
%       'D:\NouvelleBase\projet\images'

    % Par défaut, utiliser le mode GUI si aucun argument n'est fourni
    if nargin < 2
        option = 'GUI';
    end

    % Vérifier qu'au moins un chemin source existe
    if isempty(obj.fov) || isempty(obj.fov(1).srcpath) || isempty(obj.fov(1).srcpath{1})
        disp('Aucun chemin source n''a été défini pour les FOVs. Opération annulée.');
        return;
    end

    % Afficher le chemin source actuel du premier FOV pour référence
    disp('Chemin source actuel du premier FOV :');
    disp(obj.fov(1).srcpath{1});

    % Demander une seule fois le changement de la base du chemin
    switch lower(option)
        case 'gui'
            prompt = {'Saisissez la partie du chemin à remplacer (base) :', ...
                      'Saisissez la nouvelle base :'};
            dlgTitle = 'Mise à jour unique du chemin source';
            dims = [1 150];
            % Par défaut, on propose d'afficher le chemin complet actuel pour info
            defInput = {obj.fov(1).srcpath{1}, ''};
            answer = inputdlg(prompt, dlgTitle, dims, defInput);
            if isempty(answer)
                disp('Mise à jour annulée par l''utilisateur.');
                return;
            end
            oldBase = answer{1};
            newBase = answer{2};
        case 'command'
            oldBase = input('Saisissez la partie du chemin à remplacer (base) : ', 's');
            if isempty(oldBase)
                disp('Aucune saisie. Mise à jour annulée.');
                return;
            end
            newBase = input('Saisissez la nouvelle base : ', 's');
            if isempty(newBase)
                disp('Aucune saisie. Mise à jour annulée.');
                return;
            end
        otherwise
            error('Option inconnue. Utilisez "GUI" ou "command".');
    end

    % Pour chaque FOV et pour chaque canal de srcpath, remplacer la base spécifiée
    for i = 1:numel(obj.fov)
        
        for k = 1:numel(obj.fov(i).srcpath)
            
            currentPath = obj.fov(i).srcpath{k};
            % Remplacer l'ancienne base par la nouvelle base
            updatedPath = replace(currentPath, oldBase, newBase);
            
            % Normaliser les séparateurs de dossiers en fonction du système
            if ispc
                updatedPath = strrep(updatedPath, '/', '\');
            else
                updatedPath = strrep(updatedPath, '\', '/');
            end
    
            % Vérifier que le dossier mis à jour existe
            if isfolder(updatedPath)

                obj.fov(i).srcpath{k} = updatedPath;
            else
                'not ok'
     
                warning('Le dossier "%s" n''existe pas. Chemin non mis à jour pour FOV %d, canal %d.', ...
                        updatedPath, i, k);
            end
        end
    end

    disp('La mise à jour du chemin de base des FOVs est effectuée.');
end



        function [path,file]= getPath(obj) % filename contains a list of path to images used in the movi project
            %  obj.props.path=pathname;
            % obj.props.name=filename;

            path=obj.io.path;
            file=obj.io.file;
        end


function disp(obj)
    % Custom display for shallow objects

    if numel(obj) > 1
        fprintf('[%dx1] shallow objects array\n', numel(obj));
        return;
    end

    s = obj; % alias

    %================= HEADER =================
    fprintf('==============================\n');
    fprintf('  shallow project\n');
    fprintf('==============================\n');

    %% --- 1. Infos projet
    projPath = '';
    projFile = '';
    if isfield(s.io,'path') && ~isempty(s.io.path)
        projPath = strsafe(s.io.path);
    end
    if isfield(s.io,'file') && ~isempty(s.io.file)
        projFile = strsafe(s.io.file);
    end

    fprintf('Project file : %s\n', projFile);
    fprintf('Project path : %s\n', projPath);
    fprintf('\n');

    %% --- 2. Processing overview
    fprintf('Processing:\n');

    %=== Processors ===
    nProc = 0;
    if isfield(s.processing,'processor') && ~isempty(s.processing.processor)
        nProc = numel(s.processing.processor);
    end
    fprintf('  - %d processor(s)\n', nProc);

    if nProc > 0
        % header processors
        fprintf('      %-4s %-20s %-28s %-15s\n', 'Idx', 'Name', 'Function', 'Category');
        for ip = 1:nProc
            p = s.processing.processor(ip);

            % Index
            idxStr = num2str(ip);

            % Name (prefer strid, fallback id)
            pName = '';
            if isprop(p,'strid') && ~isempty(p.strid)
                pName = strsafe(p.strid);
            elseif isprop(p,'id')
                pName = ['id=' strsafe(num2str(p.id))];
            else
                pName = ['processor_' num2str(ip)];
            end

            % Function
            pFun = '';
            if isprop(p,'processFun') && ~isempty(p.processFun)
                pFun = strsafe(p.processFun);
            end

            % Category
            pCat = '';
            if isprop(p,'category') && ~isempty(p.category)
                pCat = strsafe(p.category);
            end

            fprintf('      %-4s %-20s %-28s %-15s\n', idxStr, pName, pFun, pCat);
        end
    end
    fprintf('\n');

    %=== Classifications ===
    nClass = 0;
    nClassRoiTotal = 0;
    if isfield(s.processing,'classification') && ~isempty(s.processing.classification)
        nClass = numel(s.processing.classification);
    end

    fprintf('  - %d classification(s)\n', nClass);
    if nClass > 0
        % header classifications
        fprintf('      %-4s %-25s %-12s %-6s\n', 'Idx', 'Name', 'Category', '#ROI');

        for ic = 1:nClass
            c = s.processing.classification(ic);

            % handle invalid
            if isobject(c) && isprop(c,'isvalid') && ~isvalid(c)
                fprintf('      %-4s %-25s %-12s %-6s\n', ...
                        num2str(ic), '[invalid]', '', '');
                continue;
            end

            % Name
            cName = '';
            if isprop(c,'strid') && ~isempty(c.strid)
                cName = strsafe(c.strid);
            elseif isprop(c,'id')
                cName = ['class_' strsafe(num2str(c.id))];
            else
                cName = ['classif_' num2str(ic)];
            end

            % Category
            cCat = '';
            if isprop(c,'category') && ~isempty(c.category)
                cCat = strsafe(c.category);
            end

            % #ROI
            nRoiC = 0;
            if isprop(c,'roi') && ~isempty(c.roi)
                try
                    nRoiC = numel(c.roi);
                catch
                end
            end
            nClassRoiTotal = nClassRoiTotal + nRoiC;

            fprintf('      %-4d %-25s %-12s %-6d\n', ic, cName, cCat, nRoiC);
        end
    end

    fprintf('    total classified ROI(s): %d\n', nClassRoiTotal);
    fprintf('\n');

    %% --- 3. Positions / FOVs
    nPos = 0;
    if ~isempty(s.fov)
        nPos = numel(s.fov);
    end

    fprintf('Positions (FOVs): %d\n', nPos);
    if nPos > 0
        % header FOVs
        fprintf('      %-4s %-20s %-25s %-6s\n', 'Idx', 'FOV_id', 'Name', '#ROI');

        for ip = 1:nPos
            thisFov = s.fov(ip);

            % #ROI
            nRoiHere = 0;
            if isprop(thisFov,'roi') && ~isempty(thisFov.roi)
                nRoiHere = numel(thisFov.roi);
            end

            % FOV id
            fov_id = '';
            if isprop(thisFov,'id') && ~isempty(thisFov.id)
                fov_id = strsafe(thisFov.id);
            end

            % user-visible name
            fov_name = '';
            if isprop(thisFov,'name') && ~isempty(thisFov.name)
                fov_name = strsafe(thisFov.name);
            elseif isprop(thisFov,'userName') && ~isempty(thisFov.userName)
                fov_name = strsafe(thisFov.userName);
            end

            fprintf('      %-4d %-20s %-25s %-6d\n', ip, fov_id, fov_name, nRoiHere);
        end
    end

    fprintf('==============================\n');

    %% --- helper local ---
    function out = strsafe(x)
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
end





    end
end
