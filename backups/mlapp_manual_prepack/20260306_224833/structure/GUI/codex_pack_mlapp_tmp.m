cd('C:/Users/charvin/Documents/MATLAB/DetecDiv');
report = sync_mlapp_code('pack', ["pipelineGUI","pipelineRunGUI","detecdiv"]);
disp(report);
sync_workflow_layout;
