function pipe = pipelineTemplatePhyloCellImport(path, name)
% pipelineTemplatePhyloCellImport  Legacy phyloCell -> DetecDiv pipeline.
%
%   Nodes:
%     phyloCellLoader       parse legacy project and create DetecDiv FOVs
%     roiGrid              create one full-frame ROI per FOV
%     roiExtract           extract raw channels into ROI H5 stores
%     phyloCellAnnotations convert phyloCell contours/lineage to channels/data

if nargin < 1 || isempty(path)
    path = pwd;
end
if nargin < 2 || isempty(name)
    name = 'pipeline_phylocell_import';
end

pipe = pipelineConstruct(path, name, 1);
pipe.description = 'Import legacy phyloCell projects into DetecDiv using full-frame ROIs and annotation conversion.';

n1 = blankNode();
n1.id = 'load_phylocell';
n1.type = 'dataLoader';
n1.func = 'phyloCellLoader.process';
n1.pkg = 'phyloCellLoader';
n1.params = phyloCellLoader.setparam(struct());
n1.paramRequired = {'path'};
n1.gui = '';
n1.guiMode = 'replace';
n1.inputs = {};
    n1.outputs = {'shallow','fovList','channels','annotations'};

n2 = blankNode();
n2.id = 'create_fullframe_rois';
n2.type = 'roiGrid';
n2.func = 'roiGrid.process';
n2.pkg = 'roiGrid';
n2.params = roiGrid.setparam(struct('mode', 'fullframe', 'gridCount', 1));
n2.paramRequired = {};
n2.gui = 'roiGrid.ui';
n2.guiMode = 'replace';
n2.inputs = {'fovList'};
n2.outputs = {'roiList','channels'};

n3 = blankNode();
n3.id = 'extract_raw_channels';
n3.type = 'roiExtract';
n3.func = 'roiExtract.process';
n3.pkg = 'roiExtract';
n3.params = roiExtract.setparam(struct());
n3.paramRequired = {};
n3.gui = 'roiExtract.ui';
n3.guiMode = 'replace';
n3.inputs = {'roiList','channels'};
n3.outputs = {'roiList','channels'};

n4 = blankNode();
n4.id = 'convert_phylocell_annotations';
n4.type = 'processor';
n4.func = 'phyloCellAnnotations.process';
n4.pkg = 'phyloCellAnnotations';
n4.params = phyloCellAnnotations.setparam(struct());
n4.paramRequired = {};
n4.gui = '';
n4.guiMode = '';
    n4.inputs = {'roiList','annotations'};
n4.outputs = {'roiList','channels','dataSeries'};

pipe.nodes = [n1 n2 n3 n4];
pipe.edges = struct( ...
    'from', {'load_phylocell','load_phylocell','create_fullframe_rois','extract_raw_channels'}, ...
    'to',   {'create_fullframe_rois','convert_phylocell_annotations','extract_raw_channels','convert_phylocell_annotations'}, ...
    'fromPort', {'images','annotations','roiList','roiList'}, ...
    'toPort', {'images','annotations','roiList','roiList'}, ...
    'condition', {'','','',''} ...
    );
end

function node = blankNode()
node = struct();
node.id = '';
node.type = '';
node.func = '';
node.pkg = '';
node.params = struct();
node.paramRequired = {};
node.gui = '';
node.guiMode = '';
node.inputs = {};
node.outputs = {};
end
