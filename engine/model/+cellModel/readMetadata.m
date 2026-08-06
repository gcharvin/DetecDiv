function metadata = readMetadata(filename)
%CELLMODEL.READMETADATA Read and validate the lightweight HDF5 header.

filename = char(string(filename));
if ~isfile(filename)
    error('cellModel:FileNotFound', ...
        'Cell model file not found: %s', filename);
end

raw = h5read(filename, '/metadata_json');
jsonText = native2unicode(uint8(raw(:)).', 'UTF-8');
metadata = jsondecode(jsonText);
if ~isfield(metadata, 'format') || ...
        ~strcmp(char(string(metadata.format)), 'detecdiv_cell_model')
    error('cellModel:InvalidFormat', ...
        'Not a DetecDiv cell model: %s', filename);
end
if ~isfield(metadata, 'schema_version') || ...
        double(metadata.schema_version) ~= 1
    error('cellModel:UnsupportedVersion', ...
        'Unsupported cell model schema in %s.', filename);
end
end
