function addChannel(obj,matrix)

% a channel is a matrick that has either 1 or 3 sub channels , other
% dimensions being like the obj.image.

if size(obj.image,1)~= size(matrix,1)
    disp('Error: the new matrix does not have the right size');
end
if size(obj.image,2)~= size(matrix,2)
    disp('Error: the new matrix does not have the right size');
end
if size(obj.image,4)~= size(matrix,4)
    disp('Error: the new matrix does not have the right size');
end

% add matrix to existing list of channel


% then creat function to generate overlays....