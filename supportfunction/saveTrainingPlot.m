
function saveTrainingPlot(path)
    currentfig = findall(groot,'Type','Figure');
    currentfig=currentfig(1);%take the last opened figure
    %             ValAccuracy=info.ValidationAccuracy(end);
    disp(['Saving figure...' '\n']);
    %             savefig(currentfig, [path '/TrainingValidation/LSTMTraining.fig'],'compact')
    %             saveas(currentfig, [path '/TrainingValidation/LSTMTraining.pdf'])

  if strcmp(class(currentfig),'figure')
    print(currentfig,[path '/TrainingValidation/CNNTraining'],'-dpdf','-fillpage')
  else
      if exist('exportapp')
     exportapp(currentfig,[path '/TrainingValidation/CNNTraining.pdf']);
      end
  end