
function saveTrainingPlot(path,name)
    currentfig = findall(groot,'Type','Figure');
    currentfig=currentfig(1);%take the last opened figure
    %             ValAccuracy=info.ValidationAccuracy(end);
    disp('Saving figure...');
    %             savefig(currentfig, [path '/TrainingValidation/LSTMTraining.fig'],'compact')
    %             saveas(currentfig, [path '/TrainingValidation/LSTMTraining.pdf'])

  if ishandle(currentfig)
      if exist('exportgraphics')
      exportgraphics(currentfig,fullfile(path, 'TrainingValidation',[name '.pdf']));
      else
          try
    %   savefig(currentfig, [path '/TrainingValidation/LSTMTraining.fig'],'compact')
       saveas(currentfig, [path '/TrainingValidation/LSTMTraining.pdf']) 
          catch
              
          end
      end
    %print(currentfig,fullfile(path, 'TrainingValidation',name),'-dpdf','-fillpage')
  else
      if exist('exportapp')
     exportapp(currentfig,fullfile(path, 'TrainingValidation',[name '.pdf']));
      else
      
      end
  end