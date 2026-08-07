classdef Session < handle
    %ANNOTATIONMANAGER.SESSION Backend state shared by classifierGUI and Score.

    properties (SetAccess = private)
        Classifier
        RoiIndex = 1
        Roi
        Spec
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
        end

        function refresh(obj)
            obj.Spec = annotationManager.specForClassifier(obj.Classifier);
            obj.Roi = obj.Classifier.roi(obj.RoiIndex);
        end

        function value = summary(obj, varargin)
            value = annotationManager.inspect(obj.Roi, obj.Spec, varargin{:});
        end

        function report = bootstrap(obj, varargin)
            report = annotationManager.bootstrap( ...
                obj.Classifier, obj.Roi, obj.Spec, varargin{:});
            obj.refresh();
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
        end

        function report = startBlank(obj, varargin)
            report = annotationManager.startBlank( ...
                obj.Classifier, obj.Roi, obj.Spec, varargin{:});
            obj.refresh();
        end

        function entry = markReviewed(obj, varargin)
            entry = annotationManager.markReviewed(obj.Roi, obj.Spec, varargin{:});
        end

        function entry = markChanged(obj, varargin)
            entry = annotationManager.markChanged(obj.Roi, obj.Spec, varargin{:});
        end

        function report = validate(obj, varargin)
            report = annotationManager.validate(obj.Roi, obj.Spec, varargin{:});
        end

        function report = quickValidate(obj, varargin)
            report = annotationManager.quickValidate(obj.Roi, obj.Spec, varargin{:});
        end

        function [entry, report] = approve(obj, varargin)
            [entry, report] = annotationManager.approve(obj.Roi, obj.Spec, varargin{:});
        end

        function context = uiContext(obj)
            summary = obj.summary();
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
                'displayPreset', annotationManager.displayPreset(obj.Roi, obj.Spec), ...
                'legacyScoreOption', legacyScoreOption(obj.Spec));
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
