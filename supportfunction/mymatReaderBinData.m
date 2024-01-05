function out = mymatReaderBinData(filename)
%matReader Read annotations for simulated bin picking dataset


data = load(filename);

%imagePath = fullfile(imagepath,data.imageFile)

imagePath = data.imageFile;

im = imread(imagePath);

numObjects = size(data.boxes,1);

out{1} = im;
out{2} = data.boxes;       % Nx4 double bounding boxes
% Convert the dataset into 1 class
out{3} = data.labels; %repmat(categorical("Object"), [numObjects 1]);       % Nx1 categorical object labels
out{4} = data.masks;        % HxWxN logical mask arrays

