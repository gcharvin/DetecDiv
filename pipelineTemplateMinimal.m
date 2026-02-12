function pipe = pipelineTemplateMinimal(path, name)
% pipelineTemplateMinimal  Create a minimal dataloading pipeline template.
%
%   pipe = pipelineTemplateMinimal(path, name)

    if nargin < 1 || isempty(path)
        path = pwd;
    end
    if nargin < 2 || isempty(name)
        name = 'pipeline_minimal';
    end

    pipe = pipeline(path, name, 1);
    pipe.description = 'Load data -> Identify ROIs -> Extract ROI crops';

    n1 = struct();
    n1.id = 'load_data';
    n1.type = 'dataLoader';
    n1.params = dataLoader.setparam(struct());
    n1.paramRequired = {'path'};
    n1.gui = 'dataLoader.ui';
    n1.guiMode = 'replace';
    n1.inputs = {};
    n1.outputs = {'shallow','fovList','channels'};

    n2 = struct();
    n2.id = 'identify_rois';
    n2.type = 'roiIdentify';
    n2.params = roiIdentify.setparam(struct());
    n2.gui = 'roiIdentify.ui';
    n2.guiMode = 'replace';
    n2.inputs = {'fovList'};
    n2.outputs = {'roiList','channels'};

    n3 = struct();
    n3.id = 'extract_rois';
    n3.type = 'roiExtract';
    n3.params = roiExtract.setparam(struct());
    n3.inputs = {'roiList'};
    n3.outputs = {'roiList','dataSeries'};

    pipe.nodes = [n1 n2 n3];
    pipe.edges = struct( ...
        'from', {'load_data','identify_rois'}, ...
        'to',   {'identify_rois','extract_rois'}, ...
        'condition', {'',''} ...
    );
end
