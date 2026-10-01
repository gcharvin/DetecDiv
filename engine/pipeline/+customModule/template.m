function ctx = template(ctx)
% TEMPLATE Modele de fonction utilisateur pour un module custom DetecDiv.
%
% Copier ce fichier en monAnalyse.m et renommer la fonction ci-dessus :
%   function ctx = monAnalyse(ctx)
%
% Configuration dans pipeline2 (Custom function) :
%   entryPoint     : monAnalyse (ou customModule.template pour essayer)
%   codeFolder     : dossier contenant monAnalyse.m
%   callMode       : context
%   inputPorts     : vide pour cet exemple ; roiList si votre code l'utilise
%   outputPorts    : tables
%   parametersJson: {"value":3,"scale":2}
%   argumentsJson : []
%
% La fonction est appelee une fois par noeud. Elle retourne le contexte
% recu, enrichi des sorties declarees ; conserver les autres champs de ctx.

%% 1. Parametres utilisateur (issus de parametersJson)
% Adapter les valeurs par defaut et les controles a votre analyse.
if ~isfield(ctx, 'params') || isempty(ctx.params)
    ctx.params = struct();
end
p = ctx.params;
if ~isfield(p, 'value'), p.value = 3; end
if ~isfield(p, 'scale'), p.scale = 2; end
validateattributes(p.value, {'numeric'}, {'scalar','real','finite'}, ...
    mfilename, 'value');
validateattributes(p.scale, {'numeric'}, {'scalar','real','finite'}, ...
    mfilename, 'scale');

%% 2. Entrees du pipeline
% Declarer chaque champ utilise dans inputPorts et connecter son producteur.
% Exemple pour une analyse des ROI (decommenter et adapter) :
% assert(isfield(ctx, 'roiList'), 'monAnalyse:MissingROI', ...
%     'Une entree roiList est necessaire.');
% rois = ctx.roiList;
% Le projet est accessible via ctx.shallow ; les selections peuvent inclure
% ctx.fovList et ctx.frames. Consulter le contexte effectivement fourni.

%% 3. Votre traitement
% Remplacer ce calcul par votre code. Pas de GUI requise pour les workers.
value = p.value * p.scale;

%% 4. Sorties accessibles aux noeuds suivants
% Creer tous les champs declares dans outputPorts, meme si le resultat est
% vide. Le nom du champ doit correspondre exactement au nom du port.
ctx.tables = table(value, 'VariableNames', {'Value'});
% Autres exemples : ctx.dataSeries, ctx.masks, ctx.files, ctx.artifacts.
% Un resultat dans ctx n'est pas une sauvegarde automatique dans les ROI.
% Si votre traitement ecrit des fichiers ou modifie le projet, appliquer
% explicitement la politique fournie dans ctx.io / ctx.executionPolicy.
end
