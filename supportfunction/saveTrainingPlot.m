
function saveTrainingPlot(path,name)
    currentfig = findall(groot,'Type','Figure');
    currentfig=currentfig(1);%take the last opened figure
    %             ValAccuracy=info.ValidationAccuracy(end);
    disp('Saving figure...');
    %             savefig(currentfig, [path '/TrainingValidation/LSTMTraining.fig'],'compact')
    %             saveas(currentfig, [path '/TrainingValidation/LSTMTraining.pdf'])

  if ishandle(currentfig)
      exportgraphics(currentfig,fullfile(path, 'TrainingValidation',[name '.pdf']));
    %print(currentfig,fullfile(path, 'TrainingValidation',name),'-dpdf','-fillpage')
  else
      if exist('exportapp')
     exportapp(currentfig,fullfile(path, 'TrainingValidation',[name '.pdf']));
      end
  end