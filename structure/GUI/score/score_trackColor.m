function color = score_trackColor(trackId)
%SCORE_TRACKCOLOR Stable TrackID color shared by Score and lineage views.

palette = [ ...
    0.121 0.466 0.705; ... % blue
    1.000 0.498 0.054; ... % orange
    0.172 0.627 0.172; ... % green
    0.839 0.152 0.156; ... % red
    0.580 0.404 0.741; ... % purple
    0.549 0.337 0.294; ... % brown
    0.890 0.466 0.760; ... % pink
    1.000 0.835 0.000; ... % gold
    0.737 0.741 0.133; ... % olive
    0.090 0.745 0.811; ... % cyan
    0.650 0.810 0.890; ... % light blue
    1.000 0.733 0.470; ... % light orange
    0.596 0.874 0.541; ... % light green
    1.000 0.596 0.588; ... % light red
    0.770 0.690 0.835; ... % light purple
    0.900 0.770 0.580];    % tan

id = max(1, round(double(trackId)));
color = palette(1 + mod(id - 1, size(palette, 1)), :);
end
