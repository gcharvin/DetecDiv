function userprefs = detecdiv_paths_register_one(userprefs, p)
    if ~isfield(userprefs,'paths'), return; end
    if isempty(p), return; end

    p = string(p);
    if ~isfolder(p), return; end

    % 1) stocker le chemin complet (Pos0)
    userprefs = localPushHistory(userprefs, p);

    % 2) stocker une racine "probable"
    r = detecdiv_paths_guess_root(p);
    if strlength(r)>0 && isfolder(r)
        userprefs = localPushHistory(userprefs, r);
    end
end

function userprefs = localPushHistory(userprefs, p)
    H = string(userprefs.paths.rawPathHistory);
    H = [string(p); H(:)];
    H = unique(H, 'stable');
    if numel(H) > 300
        H = H(1:300);
    end
    userprefs.paths.rawPathHistory = cellstr(H);
end

function root = detecdiv_paths_guess_root(p)
    s = strrep(string(p), '\','/');

    % SynologyDrive/Data
    ix = regexpi(s, '/synologydrive/data/');
    if ~isempty(ix)
        root = extractBefore(s, ix(1) + strlength("/synologydrive/data/")-1);
        root = strrep(root,'/','\');
        return;
    end

    % UNC //server/share
    if startsWith(s,"//")
        parts = split(s,"/");
        parts(parts=="") = [];
        if numel(parts)>=2
            root = "\\\\" + parts(1) + "\\" + parts(2);
            return;
        end
    end

    % Drive letter root like Z:\Florian\Microscopy (heuristique: garder 3 segments)
    parts = split(s,"/");
    parts(parts=="") = [];
    if numel(parts) >= 3 && contains(parts(1),":")
        root = join(parts(1:3), "\");
        root = string(root);
        return;
    end

    root = "";
end
