classdef Session < handle
    %ANNOTATIONMANAGER.SESSION Backend state shared by classifierGUI and Score.

    properties (SetAccess = private)
        Classifier
        RoiIndex = 1
        Roi
        Spec
        LastValidationStatus = 'not_run'
        LastValidationMessage = ''
    end

    events
        StateChanged
        BoundsChanged
    end

    methods
        function obj = Session(classif, roiIndex)
            if nargin < 2 || isempty(roiIndex), roiIndex = 1; end
            obj.Classifier = classif;
            obj.Spec = annotationManager.specForClassifier(classif);
            obj.selectRoi(roiIndex);
        end

        function selectRoi(obj, roiIndex)
            index = round(double(roiIndex));
            if ~isscalar(index) || ~isfinite(index) || index < 1 || ...
                    index > numel(obj.Classifier.roi)
                error('annotationManager:InvalidRoiIndex', ...
                    'ROI index must be between 1 and %d.', numel(obj.Classifier.roi));
            end
            obj.RoiIndex = index;
            obj.Roi = obj.Classifier.roi(index);
            obj.Roi.parent = obj.Classifier;
            obj.restoreValidationState();
        end

        function refresh(obj)
            obj.Spec = annotationManager.specForClassifier(obj.Classifier);
            obj.Roi = obj.Classifier.roi(obj.RoiIndex);
            obj.restoreValidationState();
        end

        function value = summary(obj, varargin)
            value = annotationManager.inspect(obj.Roi, obj.Spec, ...
                'ReviewFrames', obj.trainingFrames(), varargin{:});
        end

        function report = bootstrap(obj, varargin)
            report = annotationManager.bootstrap( ...
                obj.Classifier, obj.Roi, obj.Spec, varargin{:});
            obj.refresh();
            obj.changed();
        end

        function catalog = initializationCatalog(obj)
            catalog = annotationManager.initializationCatalog(obj.Roi, obj.Spec);
            catalog.defaultRecipe = annotationManager.defaultInitializationRecipe( ...
                obj.Classifier, catalog);
        end

        function report = initialize(obj, recipe, varargin)
            report = annotationManager.initialize( ...
                obj.Classifier, obj.Roi, obj.Spec, recipe, varargin{:});
            obj.refresh();
            obj.changed();
        end

        function report = importBundle(obj, bundle, varargin)
            % Import a provenance-bearing external GT bundle as editable
            % managed Draft data. Coverage is copied explicitly; absent
            % coverage is never inferred from the presence of assets.
            report = annotationManager.importBundle( ...
                obj.Classifier, obj.Roi, obj.Spec, bundle, varargin{:});
            obj.refresh();
            obj.changed();
        end

        function report = startBlank(obj, varargin)
            report = annotationManager.startBlank( ...
                obj.Classifier, obj.Roi, obj.Spec, varargin{:});
            obj.refresh();
            obj.changed();
        end

        function entry = markReviewed(obj, varargin)
            if ~hasOption(varargin, 'Frames')
                varargin = [varargin {'Frames', obj.trainingFrames()}];
            end
            entry = annotationManager.markReviewed(obj.Roi, obj.Spec, varargin{:});
            entry = obj.completeRoiReviewWhenFramesComplete(entry, ...
                optionValue(varargin, 'Save', true));
            obj.changed();
        end

        function entry = markChanged(obj, varargin)
            entry = annotationManager.markChanged(obj.Roi, obj.Spec, varargin{:});
            entry = obj.completeRoiReviewWhenFramesComplete(entry, ...
                optionValue(varargin, 'Save', true));
            obj.changed();
        end

        function report = validate(obj, varargin)
            % Upgrade legacy/in-progress sessions that reviewed every frame
            % in the training interval but still carry an unconfirmed
            % ROI-level unit such as parentage.
            obj.completeRoiReviewWhenFramesComplete([], true);
            [liveHash, migration] = ...
                obj.prepareCurrentGroundTruthForValidation();
            report = annotationManager.validate(obj.Roi, obj.Spec, ...
                'ReviewFrames', obj.trainingFrames(), varargin{:});
            report = obj.attachParentageMigration(report, migration);
            report = obj.attachReviewHints(report);
            annotationManager.recordValidation(obj.Roi, obj.Spec, report, ...
                'ContentHash', liveHash);
            if report.valid
                obj.LastValidationStatus = 'valid';
                obj.LastValidationMessage = '';
            else
                obj.LastValidationStatus = 'invalid';
                obj.LastValidationMessage = char(strjoin( ...
                    cellstr(report.errors), newline));
            end
            notify(obj, 'StateChanged');
        end

        function report = quickValidate(obj, varargin)
            report = annotationManager.quickValidate(obj.Roi, obj.Spec, varargin{:});
        end

        function report = findings(obj, varargin)
            % Read-only full audit for Score.  Unlike validate(), this does
            % not persist, approve, hash or otherwise change GT lifecycle.
            report = annotationManager.validate(obj.Roi, obj.Spec, ...
                'ReviewFrames', obj.trainingFrames(), varargin{:});
            report = obj.attachReviewHints(report);
        end

        function [entry, report] = approve(obj, varargin)
            [~, migration] = obj.prepareCurrentGroundTruthForValidation();
            [entry, report] = annotationManager.approve(obj.Roi, obj.Spec, ...
                'ReviewFrames', obj.trainingFrames(), varargin{:});
            report = obj.attachParentageMigration(report, migration);
            report = obj.attachReviewHints(report);
            obj.LastValidationStatus = 'valid';
            obj.LastValidationMessage = '';
            notify(obj, 'StateChanged');
        end

        function bounds = frameBounds(obj)
            bounds = trainingBounds.resolve(obj.Classifier, obj.RoiIndex, ...
                'FrameCount', annotationManager.frameCount(obj.Roi));
        end

        function frames = trainingFrames(obj)
            frames = trainingBounds.frames(obj.Classifier,obj.RoiIndex, ...
                annotationManager.frameCount(obj.Roi),[]);
        end

        function setFrameBounds(obj, value)
            trainingBounds.setRoi(obj.Classifier, obj.RoiIndex, value, ...
                'FrameCount', annotationManager.frameCount(obj.Roi));
            obj.clearPersistedValidation();
            obj.resetValidationState();
            notify(obj, 'BoundsChanged');
        end

        function clearFrameBounds(obj)
            trainingBounds.clearRoi(obj.Classifier, obj.RoiIndex);
            obj.clearPersistedValidation();
            obj.resetValidationState();
            notify(obj, 'BoundsChanged');
        end

        function context = uiContext(obj)
            summary = obj.summary();
            frameBounds = obj.frameBounds();
            context = struct( ...
                'session', obj, ...
                'classifierId', obj.Spec.classifierId, ...
                'annotationId', obj.Spec.id, ...
                'displayName', obj.Spec.displayName, ...
                'roiIndex', obj.RoiIndex, ...
                'roiId', char(string(obj.Roi.id)), ...
                'status', summary.status, ...
                'coverage', summary.coverage, ...
                'editor', obj.Spec.defaultEditor, ...
                'supportsBootstrap', obj.Spec.supportsBootstrap, ...
                'components', obj.Spec.components, ...
                'frameBounds', frameBounds, ...
                'frameBoundsText', trainingBounds.text(frameBounds), ...
                'trainingFrames', obj.trainingFrames(), ...
                'displayPreset', annotationManager.displayPreset( ...
                    obj.Roi, obj.Spec, obj.Classifier), ...
                'legacyScoreOption', legacyScoreOption(obj.Spec));
        end
    end

    methods (Access = private)
        function entry = completeRoiReviewWhenFramesComplete(obj, entry, saveValue)
            if nargin < 2 || isempty(entry)
                [entry, found] = annotationManager.entryForSpec( ...
                    obj.Roi, obj.Spec);
                if ~found, return; end
            end
            if nargin < 3, saveValue = true; end

            components = obj.Spec.components;
            required = [components.required];
            frameComponents = components(required & strcmp( ...
                {components.coverageUnit}, 'frame'));
            roiComponents = components(required & strcmp( ...
                {components.coverageUnit}, 'roi'));
            if isempty(frameComponents) || isempty(roiComponents), return; end

            frames = obj.trainingFrames();
            if isempty(frames), return; end
            for i = 1:numel(frameComponents)
                reviewIndex = find(strcmp({entry.review.component_id}, ...
                    frameComponents(i).id), 1, 'first');
                if isempty(reviewIndex) || ...
                        max(frames) > numel(entry.review(reviewIndex).frames) || ...
                        ~all(entry.review(reviewIndex).frames(frames))
                    return;
                end
            end

            incompleteIds = {};
            for i = 1:numel(roiComponents)
                reviewIndex = find(strcmp({entry.review.component_id}, ...
                    roiComponents(i).id), 1, 'first');
                if isempty(reviewIndex) || ~entry.review(reviewIndex).complete
                    incompleteIds{end+1} = roiComponents(i).id; %#ok<AGROW>
                end
            end
            if isempty(incompleteIds), return; end
            entry = annotationManager.markReviewed(obj.Roi, obj.Spec, ...
                'Frames', frames, 'Components', incompleteIds, ...
                'Save', logical(saveValue));
        end

        function changed(obj)
            obj.resetValidationState();
            notify(obj, 'StateChanged');
        end

        function restoreValidationState(obj)
            obj.resetValidationState();
            try
                [entry, found] = annotationManager.entryForSpec( ...
                    obj.Roi, obj.Spec);
                if ~found, return; end
                if strcmp(char(string(entry.status)), 'approved')
                    obj.LastValidationStatus = 'valid';
                    return;
                end
                if uint32(entry.validated_revision) ~= uint32(entry.revision)
                    return;
                end
                status = char(string(entry.validation_status));
                if any(strcmp(status, {'valid','invalid'}))
                    obj.LastValidationStatus = status;
                    obj.LastValidationMessage = char(string( ...
                        entry.validation_message));
                end
            catch
                obj.resetValidationState();
            end
        end

        function clearPersistedValidation(obj)
            try
                [entry, found] = annotationManager.entryForSpec( ...
                    obj.Roi, obj.Spec);
                if ~found, return; end
                entry = annotationManager.resetValidationState(entry);
                annotationManager.setEntry(obj.Roi, obj.Spec, entry);
            catch
            end
        end

        function persistCurrentGroundTruth(obj)
            channels = {};
            saveData = false;
            saveModel = false;
            completeFrameCount = annotationManager.frameCount(obj.Roi);
            for i = 1:numel(obj.Spec.components)
                component = obj.Spec.components(i);
                switch char(string(component.storage))
                    case 'channel'
                        [channel, exists] = annotationManager.resolveChannel( ...
                            obj.Roi, component.groundTruth);
                        if ~exists || isempty(obj.Roi.image), continue; end
                        [indices, cacheStatus] = ...
                            annotationManager.loadedChannelIndices( ...
                            obj.Roi, channel);
                        if cacheStatus == "invalid_cache"
                            error('annotationManager:InvalidChannelCache', ...
                                ['ROI "%s" has an inconsistent image/channel ' ...
                                 'mapping. Reload it before validating GT.'], ...
                                char(string(obj.Roi.id)));
                        elseif cacheStatus ~= "loaded" || isempty(indices)
                            continue;
                        end
                        if size(obj.Roi.image, 4) < completeFrameCount
                            error('annotationManager:IncompleteChannelCache', ...
                                ['ROI "%s" has only %d/%d frame(s) loaded. ' ...
                                 'Reload the complete ROI before validating ' ...
                                 'GT so a partial cache cannot replace the ' ...
                                 'materialized channel.'], ...
                                char(string(obj.Roi.id)), ...
                                size(obj.Roi.image, 4), completeFrameCount);
                        end
                        channels{end+1} = channel; %#ok<AGROW>
                    case 'dataseries'
                        saveData = true;
                    case 'cell_model_family'
                        saveModel = true;
                end
            end

            if ~isempty(channels)
                didSave = obj.Roi.save(unique(channels, 'stable'), false);
            elseif saveData
                didSave = obj.Roi.save('data', false);
            else
                didSave = true;
            end
            if ~didSave
                error('annotationManager:GroundTruthPersistenceFailed', ...
                    'The live GT for ROI "%s" could not be saved.', ...
                    char(string(obj.Roi.id)));
            end
            if saveModel && isstruct(obj.Roi.cellModel) && ...
                    isfield(obj.Roi.cellModel, 'schema_version')
                obj.Roi.saveCellModel(obj.Roi.cellModel);
            end
        end

        function report = canonicalizeCurrentParentageEvents(obj)
            % Legacy Score builds stored the UI click frame in event_frame.
            % Migrate it only when this cell-model GT is explicitly
            % validated: ordinary loading must not change approval hashes.
            [~, report] = cellModel.canonicalizeParentageEvents(struct());
            componentRows = find(strcmp({obj.Spec.components.storage}, ...
                'cell_model_family'));
            if isempty(componentRows)
                return;
            end
            [model, ~] = obj.Roi.loadCellModel('MigrateLegacy', true);
            model = cellModel.normalize(model, obj.Roi.id);
            familyIds = zeros(0, 1, 'uint32');
            for i = componentRows(:).'
                familyName = obj.Spec.components(i).groundTruth.family;
                [familyIndex, familyId] = cellModel.familyIndex( ...
                    model, familyName);
                if ~isempty(familyIndex)
                    familyIds(end+1,1) = familyId; %#ok<AGROW>
                end
            end
            familyIds = unique(familyIds);
            if isempty(familyIds)
                return;
            end
            [model, report] = cellModel.canonicalizeParentageEvents( ...
                model, 'FamilyIds', familyIds);
            if report.changed
                obj.Roi.cellModel = model;
            end
        end

        function [liveHash, migration] = ...
                prepareCurrentGroundTruthForValidation(obj)
            % A validation/approval must refer to the exact durable GT,
            % including any deterministic legacy parent-event migration.
            migration = obj.canonicalizeCurrentParentageEvents();
            liveHash = annotationManager.contentHash(obj.Roi, obj.Spec);
            obj.persistCurrentGroundTruth();
            diskHash = annotationManager.materializedContentHash( ...
                obj.Roi, obj.Spec);
            if isempty(liveHash) || ~strcmpi(liveHash, diskHash)
                error('annotationManager:GroundTruthPersistenceMismatch', ...
                    ['The live GT and its materialized files differ after ' ...
                     'saving. Validation was not recorded; reload the ROI ' ...
                     'and retry.']);
            end
        end

        function report = attachParentageMigration(~, report, migration)
            report.parentageEventMigration = migration;
            if migration.changed
                report.warnings(end+1,1) = string(sprintf([ ...
                    '%d legacy parentage event timestamp(s) were moved ' ...
                    'to child birth; parent/child track IDs were unchanged.'], ...
                    migration.count));
            end
        end

        function report = attachReviewHints(obj, report)
            hints = annotationManager.reviewHints( ...
                obj.Classifier, obj.Roi, ...
                'ReviewFrames', obj.trainingFrames());
            if ~isfield(report, 'issues') || isempty(report.issues)
                report.issues = hints.issues;
            elseif ~isempty(hints.issues)
                report.issues = [report.issues(:); hints.issues(:)];
            end
            report.reviewHints = hints;
        end

        function resetValidationState(obj)
            obj.LastValidationStatus = 'not_run';
            obj.LastValidationMessage = '';
        end
    end
end

function tf = hasOption(args,name)
tf = false;
for i = 1:2:numel(args)
    if (ischar(args{i}) || isstring(args{i})) && strcmpi(args{i},name)
        tf = true;
        return;
    end
end
end

function value = optionValue(args, name, fallback)
value = fallback;
for i = 1:2:numel(args)
    if i + 1 <= numel(args) && ...
            (ischar(args{i}) || isstring(args{i})) && strcmpi(args{i}, name)
        value = args{i+1};
        return;
    end
end
end

function option = legacyScoreOption(spec)
switch char(string(spec.defaultEditor))
    case 'class_palette'
        option = 'dataAnnotation';
    case {'semantic_mask','instance_mask','tracking','lineage','mask'}
        option = 'pixelAnnotation';
    otherwise
        option = '';
end
end
