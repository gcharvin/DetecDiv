function [h5File, exists] = getH5Filename(obj)
%GETH5FILENAME Return absolute path to this ROI's HDF5 image file.
%   [h5File, exists] = obj.getH5Filename()

    % Basic guards
    if ~isprop(obj,'path') || isempty(obj.path) || ~isfolder(obj.path)
        error('roi:getH5Filename','ROI.path is missing or not a folder.');
    end
    if ~isprop(obj,'id') || isempty(obj.id)
        error('roi:getH5Filename','ROI.id is missing.');
    end

    h5File = fullfile(obj.path, ['im_' obj.id '.h5']);
    exists = isfile(h5File);
end
