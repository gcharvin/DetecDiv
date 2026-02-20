function displayTrainingParam(obj)
%DISPLAYTRAININGPARAM  Affiche les trainingParam de manière lisible.
%
%   obj.displayTrainingParam()
%
%   Affiche proprement tous les champs de obj.trainingParam, en regroupant
%   en particulier :
%       - les champs qui commencent par "CNN"
%       - les champs qui commencent par "LSTM"
%   dans des sections dédiées. 
%   Les champs de type cell n'affichent que leur dernier élément
%   (sélection courante), et le champ 'tip' n'est pas affiché.

    if ~isprop(obj, 'trainingParam') && ~isfield(obj, 'trainingParam')
        fprintf('[classi] Aucun trainingParam défini (propriété introuvable).\n');
        return;
    end

    tp = obj.trainingParam;

    if isempty(tp)
        fprintf('[classi] trainingParam est vide.\n');
        return;
    end

    fprintf('=== Training Parameters for classi "%s" ===\n', obj.strid);

    fields = fieldnames(tp);
    % Ne jamais afficher le champ 'tip'
    fields(strcmpi(fields, 'tip')) = [];

    if isempty(fields)
        fprintf('[classi] Aucun champ à afficher dans trainingParam.\n');
        fprintf('\n===========================================\n');
        return;
    end

    % Groupes
    isCNN   = startsWith(fields, 'CNN');
    isLSTM  = startsWith(fields, 'LSTM');
    isOther = ~(isCNN | isLSTM);

    % --- SECTION CNN ---
    if any(isCNN)
        fprintf('\n-- CNN parameters --\n');
        printFieldList(tp, fields(isCNN), 4, 'CNN');
    end

    % --- SECTION LSTM ---
    if any(isLSTM)
        fprintf('\n-- LSTM parameters --\n');
        printFieldList(tp, fields(isLSTM), 4, 'LSTM');
    end

    % --- AUTRES PARAMS ---
    if any(isOther)
        fprintf('\n-- General / other parameters --\n');
        printFieldList(tp, fields(isOther), 4, '');
    end

    fprintf('\n===========================================\n');
end


% ========================================================================
% Affiche uniquement une liste de champs d'une struct, avec indentation
% et éventuellement suppression d'un préfixe (ex: "CNN" ou "LSTM").
% Pour les cell, n'affiche que le dernier élément (sélection courante).
% ========================================================================
function printFieldList(S, fieldList, indent, prefixToStrip)
    pad = repmat(' ', 1, indent);

    for i = 1:numel(fieldList)
        f = fieldList{i};

        % Ne jamais afficher 'tip'
        if strcmpi(f, 'tip')
            continue;
        end

        v = S.(f);

        % Label d'affichage : on peut enlever CNN ou LSTM pour alléger
        label = f;
        if ~isempty(prefixToStrip)
            % Enlève "CNN" ou "LSTM" + éventuel underscore
            len = numel(prefixToStrip);
            if strncmp(label, prefixToStrip, len)
                label = label(len+1:end);
                if startsWith(label, '_')
                    label = label(2:end);
                end
                if isempty(label)
                    label = f; % fallback
                end
            end
        end

        % Struct imbriquée
        if isstruct(v)
            fprintf('%s%s:\n', pad, label);
            printStruct(v, indent + 4);

        % Cell array -> on affiche uniquement le dernier élément (sélection)
        elseif iscell(v)
            if isempty(v)
                fprintf('%s%s: {}\n', pad, label);
            else
                selected = v{end};
                fprintf('%s%s: %s\n', pad, label, shortDisp(selected));
            end

        % Numeric
        elseif isnumeric(v)
            if isempty(v)
                fprintf('%s%s: []\n', pad, label);
            elseif isscalar(v)
                fprintf('%s%s: %g\n', pad, label, v);
            else
                fprintf('%s%s: [%s]\n', pad, label, num2str(v(:)'));
            end

        % Logical
        elseif islogical(v)
            fprintf('%s%s: %s\n', pad, label, mat2str(v));

        % String / char
        elseif ischar(v) || isstring(v)
            fprintf('%s%s: "%s"\n', pad, label, char(v));

        % Autres types
        else
            fprintf('%s%s: (%s)\n', pad, label, class(v));
        end
    end
end


% ========================================================================
% Affichage récursif d'une struct imbriquée
% ========================================================================
function printStruct(S, indent)
    pad  = repmat(' ', 1, indent);
    flds = fieldnames(S);

    % Ne pas afficher 'tip' dans les structs imbriquées non plus
    flds(strcmpi(flds, 'tip')) = [];

    for k = 1:numel(flds)
        f = flds{k};
        v = S.(f);

        % Struct imbriquée
        if isstruct(v)
            fprintf('%s%s:\n', pad, f);
            printStruct(v, indent + 4);

        % Cell array -> uniquement le dernier élément (sélection)
        elseif iscell(v)
            if isempty(v)
                fprintf('%s%s: {}\n', pad, f);
            else
                selected = v{end};
                fprintf('%s%s: %s\n', pad, f, shortDisp(selected));
            end

        % Numeric
        elseif isnumeric(v)
            if isempty(v)
                fprintf('%s%s: []\n', pad, f);
            elseif isscalar(v)
                fprintf('%s%s: %g\n', pad, f, v);
            else
                fprintf('%s%s: [%s]\n', pad, f, num2str(v(:)'));
            end

        % Logical
        elseif islogical(v)
            fprintf('%s%s: %s\n', pad, f, mat2str(v));

        % String / char
        elseif ischar(v) || isstring(v)
            fprintf('%s%s: "%s"\n', pad, f, char(v));

        % Autres types
        else
            fprintf('%s%s: (%s)\n', pad, f, class(v));
        end
    end
end


% ========================================================================
% Petit helper pour afficher les contenus de manière compacte
% ========================================================================
function out = shortDisp(x)
    if isnumeric(x)
        if isempty(x)
            out = '[]';
        elseif isscalar(x)
            out = num2str(x);
        else
            sz = size(x);
            if numel(sz) == 2
                out = sprintf('[%dx%d numeric]', sz(1), sz(2));
            else
                out = sprintf('[%s numeric]', sprintf('%dx', sz(1:end-1)) + ...
                              string(sz(end))); %#ok<NBRAK>
            end
        end
    elseif ischar(x) || isstring(x)
        out = char(x);
    elseif islogical(x)
        out = mat2str(x);
    elseif isstruct(x)
        out = '<struct>';
    elseif iscell(x)
        out = '<cell>';
    else
        out = sprintf('<%s>', class(x));
    end
end
