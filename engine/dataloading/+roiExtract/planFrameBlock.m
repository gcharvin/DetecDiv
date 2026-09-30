function count = planFrameBlock(available, frameBytes, driftBytes, shareCount, remaining)
%PLANFRAMEBLOCK Bound the next block by this job's remaining shared RAM.
% Four copies cover raw, corrected images, crops and writer temporaries.
% Drift FFT workspaces are a fixed per-FOV cost, independent of block size.
% The 512 MiB cap limits ordinary blocks, but must not prohibit a single
% larger frame when the actual memory budget can hold it.
headroom = max(0, available/shareCount - driftBytes);
memoryFrames = floor(headroom/(4*frameBytes));
capFrames = max(1, floor((512*2^20)/frameBytes));
count = min([remaining, memoryFrames, capFrames]);
end
