classdef IntentProfile
    % Curated user vocabulary; discovery and algorithms stay in their packages.
    methods (Static)
        function profiles = all()
            profiles = struct('id',{'define_rois','segment_cells','track_cells','measure_signals','cavity_trajectory'}, ...
                'label',{'Define ROIs','Segment Cells','Track Cells','Measure Signals','Analyze Cavity Trajectory'}, ...
                'roles',{{'rois'},{'segment'},{'segment','track'},{'segment','measure'},{'segment','identity','cavity'}});
        end
        function profile = get(id)
            profiles = detecdivui.IntentProfile.all(); index = find(strcmp({profiles.id},id));
            assert(isscalar(index),'detecdivui:Intent','Unknown workflow intent.'); profile = profiles(index);
        end
        function packages = packages(role)
            switch role
                case 'rois', packages = {'roiManual','roiPattern','roiGrid','roiTracked'};
                case 'extract', packages = {'roiExtract'};
                case 'segment', packages = {'cellposesam','deeplab_pixel_classification'};
                case 'track', packages = {'trackastra','cellLatentTracker','cellLatentModel'};
                case 'identity', packages = {'cellLatentModel'};
                case 'measure', packages = {'computeMetrics','objectMetrics'};
                case 'cavity', packages = {'selectCavityTrajectory'};
                otherwise, packages = {};
            end
        end
        function label = label(role)
            switch role
                case 'rois', label = 'Define ROIs';
                case 'extract', label = 'Extract ROI Images';
                case 'segment', label = 'Segment Cells';
                case 'track', label = 'Track Cells';
                case 'identity', label = 'Infer Identities and Parentage';
                case 'measure', label = 'Measure Signals';
                case 'cavity', label = 'Select Cavity Trajectory';
                otherwise, label = role;
            end
        end
        function yes = matches(node,role)
            yes = isfield(node,'pkg') && any(strcmpi(node.pkg,detecdivui.IntentProfile.packages(role)));
            if isfield(node,'enabled') && ~isempty(node.enabled), yes = yes && logical(node.enabled); end
            % A probability-only prediction cannot supply instance masks.
            if yes && strcmp(role,'segment') && isfield(node,'params') && isfield(node.params,'outputType')
                mode = node.params.outputType;
                if iscell(mode), mode = mode{end}; end
                yes = ~any(strcmpi(string(mode),{'probability','proba','classification'}));
            end
        end
    end
end
