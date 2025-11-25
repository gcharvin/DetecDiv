function progressBar(i, N, label)
% progressBar  Affiche une barre de progression sur une seule ligne, avec ETA.
%
%   progressBar(i, N)
%   progressBar(i, N, label)
%
%   i     : index courant (1..N)
%   N     : nombre total d'itérations
%   label : (optionnel) texte affiché après la barre
%
%   ⚠ À utiliser dans la Command Window (pas en Live Script).

    persistent reverseStr maxLen tStart

    if nargin < 3
        label = '';
    end

    if N <= 0
        return;
    end

    % ----- RESET propre au début d'une nouvelle boucle -----
    if isempty(reverseStr)
        reverseStr = '';
    end
    if isempty(maxLen)
        maxLen = 0;
    end

    % Nouveau cycle -> reset + démarrage chrono
    if i == 1
        reverseStr = '';
        maxLen     = 0;
        tStart     = tic;

        % IMPORTANT : forcer la barre à commencer sur une nouvelle ligne
        % (pour ne pas se coller au dernier fprintf précédent)
        fprintf('\n');
    end
    % -------------------------------------------------------

    % Proportion complétée
    frac = max(0, min(1, double(i) / double(N)));

    % Longueur de la barre
    barLen = 30;
    nFull  = floor(frac * barLen);
    nRest  = barLen - nFull;

    fullChar  = '#';   % ASCII simple
    emptyChar = '-';

    barStr = [repmat(fullChar, 1, nFull), repmat(emptyChar, 1, nRest)];
    pct    = frac * 100;

    % --- ETA (temps restant estimé) ---
    elapsed = toc(tStart);  % en secondes
    if frac > 0
        totalEst  = elapsed / frac;
        remaining = max(0, totalEst - elapsed);
    else
        remaining = NaN;
    end

    etaStr = formatETA(remaining);

    % Message de base
    if ~isempty(label)
        baseMsg = sprintf('[%s] %6.2f%%  (%d/%d)  %s', ...
                          barStr, pct, i, N, label);
    else
        baseMsg = sprintf('[%s] %6.2f%%  (%d/%d)', ...
                          barStr, pct, i, N);
    end

    if ~isempty(etaStr)
        msg = sprintf('%s  %s', baseMsg, etaStr);
    else
        msg = baseMsg;
    end

    % --- Normalisation de la longueur du message ---
    lenMsg = length(msg);
    if lenMsg > maxLen
        maxLen = lenMsg;
    end
    if lenMsg < maxLen
        msg = [msg, repmat(' ', 1, maxLen - lenMsg)];
    end

    % Écriture avec effacement via backspaces (+1 comme tu as constaté)
    fprintf('%s%s', reverseStr, msg);
    reverseStr = repmat(sprintf('\b'), 1, maxLen + 1);

    % À la fin : saut de ligne et reset
    if i == N
        fprintf('\n');
        reverseStr = '';
        maxLen     = 0;
        tStart     = [];
    end
end

% ---------------------------------------------------------
function etaStr = formatETA(remaining)
% remaining en secondes

    if isnan(remaining) || isinf(remaining)
        etaStr = '';
        return;
    end

    if remaining < 10
        etaStr = sprintf('ETA %.1fs', remaining);
    elseif remaining < 60
        etaStr = sprintf('ETA %.0fs', remaining);
    elseif remaining < 3600
        m = floor(remaining / 60);
        s = round(remaining - 60*m);
        etaStr = sprintf('ETA %02d:%02d', m, s);
    else
        h   = floor(remaining / 3600);
        rem = remaining - 3600*h;
        m   = floor(rem / 60);
        etaStr = sprintf('ETA %dh%02d', h, m);
    end
end
