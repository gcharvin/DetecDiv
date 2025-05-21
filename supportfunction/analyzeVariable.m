function analyzeWorkspaceVariableTopHeavy(varName, N)
% Analyse mémoire d'une variable du workspace (affiche top N éléments les plus lourds)

    if nargin < 2
        N = 10;
    end

    % Récupérer la variable du workspace
    if evalin('base', sprintf('~exist(''%s'', ''var'')', varName))
        error('Variable "%s" non trouvée dans le workspace.', varName);
    end
    var = evalin('base', varName);

    % Initialiser liste des tailles
    entries = analyzeRecursive(var, varName);

    % Trier par taille décroissante
    [~, idx] = sort([entries.bytes], 'descend');
    entries = entries(idx);

    % Afficher le top N
    fprintf('Top %d éléments les plus lourds dans "%s"\n\n', min(N, numel(entries)), varName);
    for i = 1:min(N, numel(entries))
        fprintf('%-60s %8.2f MB\t[%s]\n', entries(i).name, entries(i).bytes/1e6, entries(i).class);
    end
end

function entries = analyzeRecursive(var, varName)
% Renvoie une struct array avec les tailles de chaque sous-élément

    info = whos('var');
    entries = struct('name', varName, 'bytes', info.bytes, 'class', class(var));

    % Analyser récursivement si struct, cell ou objet
    try
        if isstruct(var)
            fields = fieldnames(var);
            for i = 1:numel(var)
                for f = 1:numel(fields)
                    fname = fields{f};
                    subname = sprintf('%s(%d).%s', varName, i, fname);
                    subvar = var(i).(fname);
                    entries = [entries; analyzeRecursive(subvar, subname)];
                end
            end
        elseif iscell(var)
            for i = 1:numel(var)
                subname = sprintf('%s{%d}', varName, i);
                subvar = var{i};
                entries = [entries; analyzeRecursive(subvar, subname)];
            end
        elseif isobject(var)
            props = properties(var);
            for i = 1:numel(var)
                for p = 1:numel(props)
                    pname = props{p};
                    subname = sprintf('%s(%d).%s', varName, i, pname);
                    subvar = var(i).(pname);
                    entries = [entries; analyzeRecursive(subvar, subname)];
                end
            end
        end
    catch
        % Ne rien faire si erreur (accès interdit par exemple)
    end
end
