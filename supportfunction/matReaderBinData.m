function out = matReaderBinData(filename, datasetRoot)
%matReader Read annotations for simulated bin picking dataset

data = load(filename);

imagePath = fullfile(datasetRoot, 'synthetic_parts_dataset', 'image',data.imageFile); 

im = imread(imagePath);

numObjects = size(data.boxes,1);

out{1} = im;
out{2} = data.boxes;       % Nx4 double bounding boxes
% Convert the dataset into 1 class
out{3} = repmat(categorical("Object"), [numObjects 1]);       % Nx1 categorical object labels
out{4} = data.masks;        % HxWxN logical mask arrays

