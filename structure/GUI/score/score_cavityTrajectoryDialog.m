function figures = score_cavityTrajectoryDialog(roiobj,selectedTrackId,varargin)
%SCORE_CAVITYTRAJECTORYDIALOG Inspect the selected object's cavity path.
% This bridge contains no trajectory inference. Score can call it after an
% object click or from a future "Inspect trajectory" context action.

p=inputParser;
p.addParameter('DataSeries','',@(x)ischar(x)||isstring(x));
p.addParameter('OpenLineageTree',true,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
if nargin<2||isempty(selectedTrackId), selectedTrackId=NaN; end

index=findTrajectorySeries(roiobj,char(string(p.Results.DataSeries)),selectedTrackId);
if isempty(index)
    error('score:CavityTrajectoryNotFound', ...
        'No cavity-trajectory dataseries contains TrackID %g.',double(selectedTrackId));
end
ds=roiobj.data(index);
figures=struct('trajectory',[],'lineage',[]);
figures.trajectory=cavityTrajectoryView.plotTrajectory(ds, ...
    'FocusTrackID',double(selectedTrackId), ...
    'Title',sprintf('%s — Track %g',char(string(roiobj.id)),double(selectedTrackId)));

if p.Results.OpenLineageTree
    familyId=[];
    try familyId=uint32(ds.userData.family_id); catch, end
    if ~isempty(familyId)
        [model,~]=roiobj.loadCellModel('MigrateLegacy',true);
        figures.lineage=score_lineageTreeDialog(model,familyId, ...
            'SelectedTrackId',double(selectedTrackId), ...
            'Title',sprintf('Lineage — %s',char(string(roiobj.id))));
    end
end
end

function index=findTrajectorySeries(roiobj,name,trackId)
index=[];
for i=1:numel(roiobj.data)
    ds=roiobj.data(i);
    try
        if ~isempty(name)&&~strcmp(char(string(ds.groupid)),name), continue; end
        if ~istable(ds.data)||~ismember('TargetTrackID',ds.data.Properties.VariableNames), continue; end
        if ~isfinite(trackId)||any(ds.data.TargetTrackID==uint64(trackId))|| ...
                (ismember('CompanionBudTrackID',ds.data.Properties.VariableNames)&& ...
                 any(ds.data.CompanionBudTrackID==uint64(trackId)))
            index=i; return;
        end
    catch
    end
end
end
