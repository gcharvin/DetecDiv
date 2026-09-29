function count = planFrameBlock(available, frameBytes, driftBytes, shareCount, remaining)
%PLANFRAMEBLOCK Bound the next block by this job's remaining shared RAM.
% Four copies cover raw, corrected images, crops and writer temporaries.
% Drift FFT workspaces are a fixed per-FOV cost, independent of block size.
budget = min(512*2^20, max(0, available/shareCount - driftBytes)/4);
count = min(remaining, floor(budget/frameBytes));
end
