function value = utcIso8601()
%CELLLATENTMODEL.UTILS.UTCISO8601 Strict UTC timestamp for JSON records.
%
% MATLAB renders the XXX offset token as "***" when a datetime has no
% TimeZone.  Packaging manifests must be portable ISO-8601, so always bind
% the clock to UTC before formatting it.

value = char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
