function nameOut = sanitizeDatasetName(nameIn)
s = char(string(nameIn));
s = regexprep(s,'\s+','_');
s = regexprep(s,'[^A-Za-z0-9_\-\.]','_');
if isempty(s), s = 'channel'; end
nameOut = s;
end