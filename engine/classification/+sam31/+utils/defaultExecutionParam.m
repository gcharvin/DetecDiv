function p = defaultExecutionParam()
% sam31.utils.defaultExecutionParam
% User-facing defaults for SAM3.1 inference in Pipeline2.

p = struct();
p.resolution = '280';
p.detectorCheckpointPath = '';
p.trackerCheckpointPath = '';
p.backend = 'local';
p.pythonExecutable = '';
p.maxNumObjects = 40;
p.prompt = 'cell';
p.minScore = 0;
p.chunkSize = 32;
p.chunkOverlap = 4;
p.videoScoreThreshold = 0.40;
p.videoNewDetThreshold = 0.40;
p.videoDetNmsThreshold = 0.10;
p.videoAssocIouThreshold = 0.50;
p.sam31Runner = 'session';
p.inferInstanceSegmentation = true;
p.inferCellTracking = true;
p.inferBudPairing = true;
p.budPairingSourceKey = '';
p.budPairingShowSource = true;
p.budPairingActivateSource = true;
p.budPairingWriteCanonical = true;
p.budPairingOverwriteMotherOf = false;
p.budPairingTypicalCellSize = 0;
p.budPairingMaxBirthAreaFraction = 1.25;
p.budPairingMinParentAreaReferenceFraction = 0.7;
p.budPairingMaxParentDistanceFraction = 0.5;
p.budPairingMaxParentCentroidDistanceFraction = 1.0;
p.budPairingFutureWindow = 6;
p.budPairingMinParentAgeFrames = 6;
p.budPairingMaxFutureDistanceReferenceFraction = 1.0;
p.budPairingMaxFutureCentroidDistanceReferenceFraction = 1.0;
p.budPairingAngleWeight = 1;
p.budPairingCentroidWeight = 1;
p.budPairingFutureWeight = 0.6;
p.budPairingFutureCentroidWeight = 0.4;
end
