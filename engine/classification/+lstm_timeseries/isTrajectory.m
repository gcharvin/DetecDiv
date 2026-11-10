function value=isTrajectory(p)
value=isfield(p,'sequenceScope')&&strcmp(p.sequenceScope,'trajectory');
end
