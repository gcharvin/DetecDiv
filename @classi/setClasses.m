function report = setClasses(classif, newClasses, varargin)
%SETCLASSES Change class list and update ROI training dataseries (LSTM only).
%
% newClasses : cellstr (NEW class names)
%
% Name-Value:
%   'mapping'       : containers.Map oldName -> newName (or ""/"--" to delete old)
%   'deleteToken'   : token meaning delete, default "--"
%   'updateROIData' : true/false, default true
%
% RULES (as requested):
% - Only LSTM classifiers (classif.description{3}{1} contains "lstm") are processed
% - For each ROI:
%     roi.load('data')
%     find dataseries with ds.groupid == classif.strid
%     remap labels_training + id_training according to mapping
%     if inference columns exist (prob_*, labels/id variants), remove ALL except:
%         labels_training, id_training

    % ---------------- Options ----------------
    ip = inputParser;
    ip.addParameter('mapping', [], @(x) isa(x,'containers.Map') || isempty(x));
    ip.addParameter('deleteToken', "--", @(x)ischar(x)||isstring(x));
    ip.addParameter('updateROIData', true, @(x)islogical(x)&&isscalar(x));
    ip.addParameter('storeMapping', false, @(x)islogical(x)&&isscalar(x));
    ip.parse(varargin{:});
    opt = ip.Results;

    if opt.storeMapping
    if ~isprop(classif,'userData') || isempty(classif.userData) || ~isstruct(classif.userData)
        classif.userData = struct();
    end
    classif.userData.lastClassMapping = opt.mapping;  % containers.Map
    classif.userData.lastClassMappingDate = datestr(now);
end



    report = struct('changedClasses', false, ...
                    'roisScanned', 0, ...
                    'roisWithTrainingDS', 0, ...
                    'roisTrainingRemapped', 0, ...
                    'roisInferencePurged', 0);

    % ---------------- Normalize newClasses ----------------
    if isstring(newClasses), newClasses = cellstr(newClasses); end
    newClasses = newClasses(:);
    newClasses = cellfun(@(s) char(string(s)), newClasses, 'UniformOutput', false);
    newClasses = newClasses(~cellfun(@(s) isempty(strtrim(s)), newClasses));

    % Validate
    if isempty(newClasses)
        error('setClasses:Empty', 'New class list is empty.');
    end
    if any(contains(string(newClasses), " "))
        error('setClasses:InvalidName', ...
            'Class names must not contain spaces (space-separated list).');
    end
    if numel(unique(newClasses)) ~= numel(newClasses)
        error('setClasses:Duplicates', 'Duplicate class names detected.');
    end

    % Old classes
    oldClasses = classif.classes;
    if isstring(oldClasses), oldClasses = cellstr(oldClasses); end
    oldClasses = oldClasses(:);
    oldClasses = cellfun(@(s) char(string(s)), oldClasses, 'UniformOutput', false);

    if isequal(oldClasses, newClasses)
        return;
    end

    % ---------------- Apply to classif + ROIs ----------------
    classif.classes  = newClasses;
    classif.colormap = shallowColormap(numel(newClasses));

    if isprop(classif,'roi') && ~isempty(classif.roi)
        for i=1:numel(classif.roi)
            classif.roi(i).classes = newClasses;
        end
    end

    report.changedClasses = true;

    % ---------------- Stop here if not LSTM or no ROI update requested ----------------
    if ~opt.updateROIData
        return;
    end
    if ~isLSTMClassifier_(classif)
        % You asked: only CNN/LSTM here, image classifiers later
        return;
    end

    if isempty(opt.mapping)
        error('setClasses:MappingRequired', ...
            'For LSTM classifiers, mapping (containers.Map oldName->newName) is required.');
    end

    % Build index remap oldIdx -> newIdx (0 delete)
    remapIdx = buildIndexRemap_(oldClasses, newClasses, opt.mapping, opt.deleteToken);

    % ---------------- Loop ROIs ----------------
    for i=1:numel(classif.roi)
        report.roisScanned = report.roisScanned + 1;

        r = classif.roi(i);

        % Load ROI data (required)
        try
            r.load('data');
        catch
            continue;
        end

        % Find dataseries with groupid == classif.strid
        ds = findTrainingDataseries_(r, classif.strid);
        if isempty(ds)
            continue;
        end
        report.roisWithTrainingDS = report.roisWithTrainingDS + 1;

        changed = false;

        % Remap training columns
        changed = remapTrainingColumns_(ds, oldClasses, newClasses, remapIdx) || changed;
        if changed
            report.roisTrainingRemapped = report.roisTrainingRemapped + 1;
        end

        % Purge inference columns if present (keep ONLY training)
        purged = purgeInferenceKeepTrainingOnly_(ds);
        if purged
            report.roisInferencePurged = report.roisInferencePurged + 1;
            changed = true;
        end

        % Keep stable reference of classes for label variables
        if isempty(ds.userData) || ~isstruct(ds.userData)
            ds.userData = struct();
        end
        ds.userData.classes = cellstr(string(newClasses(:)')); % row

        % Sync plot props/groups if table changed
        if changed
            ds.ensurePlotProperties();
            r.save('data');
        end
    end
end

% ======================================================================
% Helpers
% ======================================================================

function tf = isLSTMClassifier_(classif)
% Exact project rule: classification "type" comes from classif.description{3}{1}
% Example: {'LSTM + CNN workflow'} or similar.
    tf = false;
    try
        d = classif.description;
        if numel(d) >= 3 && ~isempty(d{3}) && ~isempty(d{3}{1})
            tf = contains(lower(string(d{3}{1})), "lstm");
        end
    catch
        tf = false;
    end
end

function remapIdx = buildIndexRemap_(oldClasses, newClasses, oldToNew, deleteToken)
% remapIdx(iOld) = iNew or 0 if deleted/unmapped

    nOld = numel(oldClasses);
    remapIdx = zeros(nOld,1);
    delTok = string(deleteToken);

    for i=1:nOld
        o = oldClasses{i};
        if isKey(oldToNew, o)
            v = string(oldToNew(o));
            if v=="" || v==delTok || v=="-- (supprimer)"
                remapIdx(i) = 0;
            else
                j = find(strcmp(newClasses, char(v)), 1);
                if isempty(j), remapIdx(i) = 0;
                else,          remapIdx(i) = j;
                end
            end
        else
            remapIdx(i) = 0;
        end
    end
end

function ds = findTrainingDataseries_(roiObj, gid)
% Finds dataseries in ROI where ds.groupid == gid.
% Tries roiObj.data first, then roiObj.dataseries (if exists).

    ds = [];

    container = [];
    if isprop(roiObj,'data') && ~isempty(roiObj.data)
        container = roiObj.data;
    elseif isprop(roiObj,'dataseries') && ~isempty(roiObj.dataseries)
        container = roiObj.dataseries;
    end
    if isempty(container), return; end

    for k=1:numel(container)
        try
            if strcmp(container(k).groupid, gid)
                ds = container(k);
                return;
            end
        catch
        end
    end
end

function changed = remapTrainingColumns_(ds, oldClasses, newClasses, remapIdx)
% Remap:
%   - id_training : numeric oldIdx -> newIdx (0 if deleted)
%   - labels_training : map old label names to new ones, cast to categorical(newClasses)

    changed = false;

    T = ds.data;
    if ~istable(T) || isempty(T), return; end
    vars = T.Properties.VariableNames;

    % ---- id_training (numeric)
    if ismember('id_training', vars)
        v = T.id_training;
        if isnumeric(v)
            v2 = zeros(size(v));
            mask = v>=1 & v<=numel(remapIdx);
            v2(mask) = remapIdx(v(mask));
            if ~isequaln(v, v2)
                T.id_training = v2;
                changed = true;
            end
        end
    end

    % ---- labels_training (categorical/string/cell)
    if ismember('labels_training', vars)
        lab = T.labels_training;

        % convert to strings
        if iscategorical(lab)
            s = string(lab);
        elseif isstring(lab)
            s = lab;
        elseif iscell(lab)
            s = string(lab);
        else
            s = string(lab);
        end

        out = strings(size(s));
        out(:) = "";

        % map by old class name
        for i=1:numel(oldClasses)
            o = string(oldClasses{i});
            j = remapIdx(i);
            if j>0
                out(s==o) = string(newClasses{j});
            else
                out(s==o) = ""; % deleted
            end
        end
        out(ismissing(s)) = "";

        lab2 = categorical(out, string(newClasses));
        if ~isequaln(lab, lab2)
            T.labels_training = lab2;
            changed = true;
        end
    end

    if changed
        ds.data = T;
    end
end

function purged = purgeInferenceKeepTrainingOnly_(ds)
% If inference-like variables exist, remove ALL columns except:
%   id_training, labels_training

    purged = false;

    T = ds.data;
    if ~istable(T) || isempty(T), return; end
    vars = string(T.Properties.VariableNames);

    keep = ["id_training","labels_training"];

    % Detect inference presence:
    % - any prob_*
    % - any "labels*" except labels_training
    % - any "id*" except id_training
    hasProb = any(startsWith(vars, "prob_"));
    hasLabelsOther = any(startsWith(vars, "labels")) && any(vars ~= "labels_training");
    hasIdOther = any(startsWith(vars, "id")) && any(vars ~= "id_training");

    if ~(hasProb || hasLabelsOther || hasIdOther)
        return;
    end

    toRemove = vars(~ismember(vars, keep));
    if ~isempty(toRemove)
        T = removevars(T, cellstr(toRemove));
        ds.data = T;
        purged = true;
    end
end
