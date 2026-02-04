function [oldToNew, cancelled] = classMappingDialog(parentFig, oldClasses, newClasses)
%CLASSMAPPINGDIALOG  Map OLD classes to NEW classes (supports merges).
%
% Table rows = OLD classes (so merges are natural: multiple old -> same new).
%   Col1 (text)  : Old class
%   Col2 (popup) : New class (or (void) to delete)
%
% Extra rows:
%   For each NEW class not selected by any old row, add:
%       Old = (void), New = that NEW class
%   (represents "new-only" class created from scratch)
%
% Output:
%   oldToNew : containers.Map oldName -> newName ("" for delete)
%   cancelled: true if user cancelled

    %#ok<NASGU> parentFig

    cancelled = true;
    oldToNew  = containers.Map('KeyType','char','ValueType','char');

    % -------- Normalize inputs to cellstr(char) --------
    oldClasses = localCellstr_(oldClasses);
    newClasses = localCellstr_(newClasses);

    if isempty(newClasses)
        uialert(uifigure('Visible','off'), 'New class list is empty.', 'Map classes');
        return;
    end

    voidTok = '(void)'; % means: delete old / or "no match" placeholder

    % Popup items for NEW column must be 1xN cell of char
    ddNew = [{voidTok}; newClasses(:)];
    ddNew = ddNew(:)'; % row
    ddNew = cellfun(@localCharRow_, ddNew, 'UniformOutput', false);

    nOld = numel(oldClasses);

    % -------- Build base table (one row per OLD class) --------
    % Col1 Old class (text)
    % Col2 New class (popup)
    selNew = repmat({voidTok}, nOld, 1);

    % default mapping: if old name exists in new list -> match it
   sameCount = (numel(oldClasses) == numel(newClasses));

for i = 1:nOld
    o = oldClasses{i};

    % 1) exact match
    j = find(strcmp(newClasses, o), 1);

    % 2) case-insensitive match
    if isempty(j)
        j = find(strcmpi(newClasses, o), 1);
    end

    % 3) if same number of classes: default by index
    if isempty(j) && sameCount && i <= numel(newClasses)
        j = i;
    end

    if ~isempty(j)
        selNew{i} = newClasses{j};
    else
        selNew{i} = voidTok;
    end
end


    tbl = [oldClasses(:), selNew(:)];
    tbl = localForceCharCell_(tbl);

    % Add extra rows for NEW classes not currently targeted
    tbl = addNewOnlyRows_(tbl, newClasses, voidTok);

    nRows = size(tbl,1);

    % -------- Dialog sizing --------
    rowH = 30;
    btnH = 36;
    pad  = 12;

    maxVisible = 18;
    nVis = min(nRows, maxVisible);

    dlgH = pad*2 + (nVis+1)*rowH + 12 + btnH; % + header
    dlgW = 820;

    dlg = uifigure('Name','Map classes', 'WindowStyle','modal', 'Resize','on');
    dlg.Position(3:4) = [dlgW dlgH];

    main = uigridlayout(dlg, [2 1]);
    main.RowHeight = {'2x', btnH};
    main.ColumnWidth = {'1x'};
    main.Padding = [pad pad pad pad];
    main.RowSpacing = 10;

    % -------- Table --------
    t = uitable(main);
    t.ColumnName = {'Old class', 'New class (or void)'};
    t.ColumnEditable = [false true];
    t.RowName = [];
    t.ColumnWidth = {340, 'auto'};
    t.Data = tbl;

    % Popup for column 2 (with legacy fallbacks)
    try
        t.ColumnFormat = {'char', {'popup', ddNew}};
    catch
        try
            t.ColumnFormat = {'char', ddNew};
        catch
            t.ColumnFormat = {'char','char'}; % last resort
        end
    end

    % -------- Buttons --------
    btnGrid = uigridlayout(main, [1 4]);
    btnGrid.RowHeight = {btnH};
    btnGrid.ColumnWidth = {'1x','1x','1x','1x'};
    btnGrid.Padding = [0 0 0 0];
    btnGrid.ColumnSpacing = 10;

    uibutton(btnGrid, 'Text','Cancel',    'ButtonPushedFcn', @(~,~)doCancel());
    uibutton(btnGrid, 'Text','Auto match','ButtonPushedFcn', @(~,~)doAuto());
    uibutton(btnGrid, 'Text','Clear',     'ButtonPushedFcn', @(~,~)doClear());
    uibutton(btnGrid, 'Text','OK',        'ButtonPushedFcn', @(~,~)doOK());

    uiwait(dlg);

    % ================= Callbacks =================

    function doCancel()
        cancelled = true;
        uiresume(dlg);
        delete(dlg);
    end

    function doAuto()
        d = localForceCharCell_(t.Data);

        % Only apply auto mapping to real OLD rows (Old ~= void)
        for k=1:size(d,1)
            oldk = d{k,1};
            if strcmp(oldk, voidTok)
                continue; % keep new-only row as-is
            end

            j = find(strcmp(newClasses, oldk), 1);
            if isempty(j), j = find(strcmpi(newClasses, oldk), 1); end
            if ~isempty(j)
                d{k,2} = newClasses{j};
            else
                d{k,2} = voidTok;
            end
        end

        % Recompute new-only rows based on current selections
        d = addNewOnlyRows_(d, newClasses, voidTok);
        t.Data = localForceCharCell_(d);
    end

    function doClear()
        d = localForceCharCell_(t.Data);

        for k=1:size(d,1)
            if strcmp(d{k,1}, voidTok)
                continue; % keep new-only rows
            end
            d{k,2} = voidTok;
        end

        d = addNewOnlyRows_(d, newClasses, voidTok);
        t.Data = localForceCharCell_(d);
    end

    function doOK()
        d = localForceCharCell_(t.Data);

        % Build mapping old -> new
        tmp = containers.Map('KeyType','char','ValueType','char');

        for k=1:size(d,1)
            oldk = d{k,1};
            newk = d{k,2};

            if strcmp(oldk, voidTok)
                % new-only row: no old->new mapping to record
                continue;
            end

            if strcmp(newk, voidTok)
                tmp(oldk) = "";     % delete old
            else
                tmp(oldk) = newk;   % map old to new
            end
        end

        oldToNew = tmp;
        cancelled = false;
        uiresume(dlg);
        delete(dlg);
    end
end

% ======================================================================
% Helpers
% ======================================================================

function d = addNewOnlyRows_(d, newClasses, voidTok)
% Ensure NEW classes that are not selected by any old-row appear as:
%   Old=(void), New=<that class>
%
% Removes existing "new-only" rows first, then rebuilds them.

    d = localForceCharCell_(d);

    % remove existing new-only rows (Old == voidTok)
    isNewOnly = false(size(d,1),1);
    for i=1:size(d,1)
        isNewOnly(i) = strcmp(d{i,1}, voidTok);
    end
    d = d(~isNewOnly,:);

    % collect targeted NEW classes from real old rows
    targeted = d(:,2);
    targeted = targeted(~strcmp(targeted, voidTok));

    % add rows for new classes not targeted
    missing = setdiff(newClasses(:), targeted(:), 'stable');

    if ~isempty(missing)
        extra = cell(numel(missing),2);
        for k=1:numel(missing)
            extra{k,1} = voidTok;
            extra{k,2} = missing{k};
        end
        d = [d; extra];
    end

    d = localForceCharCell_(d);
end

function c = localCellstr_(x)
% Convert input to cellstr of char rows.
    if isempty(x)
        c = {};
        return;
    end
    if ischar(x)
        c = cellstr(string(x));
    elseif isstring(x)
        c = cellstr(x);
    elseif iscell(x)
        if numel(x)==1 && iscell(x{1})
            x = x{1};
        end
        c = cell(size(x));
        for i=1:numel(x)
            c{i} = localCharRow_(x{i});
        end
        c = c(:);
        c = c(~cellfun(@(s) isempty(strtrim(s)), c));
    else
        c = cellstr(string(x));
        c = c(:);
    end
    c = cellfun(@localCharRow_, c, 'UniformOutput', false);
end

function s = localCharRow_(x)
% Force scalar char row vector
    if isempty(x)
        s = '';
        return;
    end
    if ischar(x)
        s = x;
    elseif isstring(x)
        s = char(x);
    elseif iscell(x)
        if isempty(x), s=''; else, s = localCharRow_(x{1}); end
        return;
    else
        s = char(string(x));
    end
    s = char(s);
    if size(s,1) > 1
        s = s(1,:);
    end
end

function C = localForceCharCell_(C)
% Ensure every cell is a char row vector (older uitable requirement)
    if ~iscell(C)
        try
            C = table2cell(C);
        catch
            C = num2cell(C);
        end
    end
    for i=1:numel(C)
        C{i} = localCharRow_(C{i});
    end
end
