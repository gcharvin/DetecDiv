function params = setparam(ctx) %#ok<INUSD>
%movieExport.setparam  Defaults for non-interactive movie/PDF exports.

params = struct();
params.sourceType = 'score_roi';       % score_roi | raw_fov | viewer_snapshot
params.outputMode = 'Movie';           % Movie | Sequence | images (snapshot)
params.outputPath = '';
params.useRunArtifactFolder = false;
params.layoutOptions = struct();
params.snapshotPath = '';
params.snapshotChecksum = '';
params.overwrite = false;
params.raw = struct('fovIndex', 1, 'frames', [], 'channelCfg', struct([]), ...
    'framesPerSecond', 10, 'title', '');
end
