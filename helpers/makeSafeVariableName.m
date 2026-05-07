function out = makeSafeVariableName(nameIn)
% makeSafeVariableName  Convert arbitrary text into a valid MATLAB variable name.
%
% Invalid characters are replaced by underscores. MATLAB may prepend a
% letter when required (for example if the name starts with a digit).

out = char(string(nameIn));
out = regexprep(out, '[^A-Za-z0-9_]', '_');
out = matlab.lang.makeValidName(out, 'ReplacementStyle', 'underscore');
