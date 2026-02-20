function pixresults = findChannelID(obj, names, mode, varargin)
% pixresults = findChannelID(obj, names)
% pixresults = findChannelID(obj, names, mode)
% pixresults = findChannelID(obj, names, mode, 'IgnoreCase', true|false)
%
% names : char | string | string array | cellstr
% mode  : 'exact' (défaut si non fourni) ou 'contains' (si 3e arg présent)
%
% Sortie :
%  - Si names est scalaire (char/string)      -> vecteur d'indices C (sous-canaux)
%  - Si names est liste (cellstr/string array)-> cell array {1xN} de vecteurs d'indices C
%
% Remarque :
%  - Les indices retournés sont sur la 3e dimension (C) de obj.image,
%    dérivés de obj.channelid (mapping sous-canal -> canal logique).
%  - Matching insensible à la casse par défaut.

    % ---------- Normalisation des entrées ----------
    if nargin < 3 || isempty(mode)
        mode = 'exact';               % rétrocompat : 2 args => exact
    else
        % 3e arg fourni => rétrocompat : on force 'contains' si pas 'exact'
        % (si tu veux explicite, passe 'exact' ou 'contains')
        if ~ischar(mode) && ~isstring(mode), mode = 'contains'; end
    end
    mode = lower(string(mode));
    validMode = (mode=="exact" | mode=="contains");
    if ~validMode
        error('findChannelID:BadMode','Mode must be ''exact'' or ''contains''.');
    end

    % Paramètre optionnel: IgnoreCase (défaut true)
    p = inputParser;
    addParameter(p, 'IgnoreCase', true, @(x)islogical(x)&&isscalar(x));
    parse(p, varargin{:});
    ignoreCase = p.Results.IgnoreCase;

    % ---------- Récup canaux logiques ----------
    chanList = {};
    if isprop(obj,'display') && isstruct(obj.display) && isfield(obj.display,'channel') && ~isempty(obj.display.channel)
        chanList = obj.display.channel;
        if isstring(chanList), chanList = cellstr(chanList); end
        if ~iscell(chanList),  chanList = {char(string(chanList))}; end
    end
    nLog = numel(chanList);

    if nLog==0 || ~isprop(obj,'channelid') || isempty(obj.channelid)
        % rien à mapper
        if ischar(names) || (isstring(names) && isscalar(names))
            pixresults = [];
        else
            n = numel(names);
            pixresults = cell(1,n);
            [pixresults{:}] = deal([]);
        end
        return;
    end

    % ---------- Normalisation de 'names' ----------
    isScalarQuery = false;
    if ischar(names) || (isstring(names) && isscalar(names))
        queryList = {char(string(names))};
        isScalarQuery = true;
    else
        if isstring(names), names = cellstr(names); end
        if ~iscell(names),  names = {char(string(names))}; end
        queryList = names(:).';
    end

    % ---------- Préparer comparaison ----------
    if ignoreCase
        baseList = lower(chanList);
    else
        baseList = chanList;
    end

    % ---------- Matching canal logique -> indices C ----------
    function idxC = logicalToC(logIdx)
        % renvoie indices sous-canaux C pour UN canal logique
        if isempty(logIdx), idxC = []; return; end
        idxC = find(obj.channelid == logIdx);
        % garde trié et unique (au cas où)
        idxC = unique(idxC(:).','stable');
    end

    % ---------- Boucle sur les requêtes ----------
    resultsCell = cell(1, numel(queryList));
    for q = 1:numel(queryList)
        pat = queryList{q};
        if ignoreCase, pat = lower(pat); end

        matchedLogical = [];
        switch char(mode)
            case 'exact'
                % match exact (sur nom logique)
                for j = 1:nLog
                    if strcmp(baseList{j}, pat)
                        matchedLogical = j;
                        break; % un seul
                    end
                end

            case 'contains'
                % match "contient" (peut retourner plusieurs canaux logiques)
                for j = 1:nLog
                    if contains(baseList{j}, pat)
                        matchedLogical(end+1) = j; %#ok<AGROW>
                    end
                end
        end

        % Map vers indices C (sous-canaux)
        idxC_all = [];
        for j = matchedLogical
            idxC_all = [idxC_all, logicalToC(j)]; %#ok<AGROW>
        end
        % unicité + ordre stable
        idxC_all = unique(idxC_all, 'stable');

        resultsCell{q} = idxC_all;
    end

    % ---------- Formater la sortie ----------
    if isScalarQuery
        pixresults = resultsCell{1};
    else
        pixresults = resultsCell;
    end
end
