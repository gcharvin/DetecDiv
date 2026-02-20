function displayValidation(classif)
% display groundtruth and validaton to compare data for a given ROI that
% belongs to a @classi object

    
disp(['Number of ROIs available in the @classi object: ' num2str(numel(classif.roi))]);
    for j=1:numel(classif.roi)
       disp([num2str(j) '- '  classif.roi(j).id]);
    end
    
prompt='Please enter the ROI number in which to view the comparison between ground truth and validation; Default:1';
classitype= input(prompt);

if numel(classitype)==0
    classitype=1;
end

classif.roi(classitype).traj(classif.strid);
