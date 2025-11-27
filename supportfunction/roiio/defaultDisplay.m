function d = defaultDisplay(N, C)
d = struct();
d.intensity       = repmat([1 1 1], N, 1);
d.frame           = 1;
d.selectedchannel = ones(1,N);
d.binning         = 1;
d.rgb             = repmat([1 1 1], N, 1);   % <<< N x 3 (par canal logique)
d.channel         = arrayfun(@(k)sprintf('channel_%d',k), 1:N, 'UniformOutput', false);
d.stretchlim      = [];
d.displaylim      = repmat([0;1], 1, C);
d.indexed         = zeros(1,N);
d.alpha           = ones(1,N);
d.contour         = zeros(1,N);
d.width           = ones(1,N);
d.log             = zeros(1,N);
end
