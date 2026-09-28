function count = planFovWorkers(fovs, params, requested)
%PLANFOVWORKERS Estimate process + raw/crop/drift peak before creating a pool.
% Raw blocks are capped at 512 MiB in extractAllROICrops. Reserve four block
% copies plus double/complex drift workspaces and a measured MATLAB baseline.
[available, note] = roiExtract.availableMemoryBytes();
baseline = 2^30;
try
    if ispc
        m = memory; baseline = max(baseline, double(m.MemUsedMATLAB));
    else
        token = regexp(fileread('/proc/self/status'), ...
            '(?m)^VmRSS:\s+(\d+)\s+kB', 'tokens', 'once');
        if ~isempty(token), baseline = max(baseline, str2double(token{1})*1024); end
    end
catch
end
peak = baseline + 4*512*2^20;
for i = 1:numel(fovs)
    try
        im = fovs(i).readImage(1,1);
        if isempty(im), error('roiExtract:NoProbeImage','No source image'); end
        pixels = double(size(im,1))*double(size(im,2));
        spec = whos('im');
        channels = max(1,numel(fovs(i).channel));
        frameBytes = double(spec.bytes)*channels;
        driftBytes = 0;
        if ~isfield(params,'correctDrift') || params.correctDrift
            driftBytes = pixels*128; % real/complex FFT and filtering workspaces
        end
        peak = max(peak,baseline + 4*max(512*2^20,frameBytes) + driftBytes);
    catch
        count = 1;
        fprintf('[roiExtract] Cannot estimate FOV footprint: using one extraction task.\n');
        return;
    end
end
count = max(1,min(requested,floor(available/peak)));
fprintf('[roiExtract] RAM plan: %.2f GiB estimated peak/FOV, requested %d, admitted %d. %s\n', ...
    peak/2^30, requested, count, note);
end
