
function saveTrainingPlot(path,name)
    currentfig = findall(groot,'Type','Figure');
    currentfig=currentfig(1);%take the last opened figure
    %             ValAccuracy=info.ValidationAccuracy(end);
    disp('Saving figure...');
    %             savefig(currentfig, [path '/TrainingValidation/LSTMTraining.fig'],'compact')
    %             saveas(currentfig, [path '/TrainingValidation/LSTMTraining.pdf'])
    
    if ishandle(currentfig)
        if exist('print')
            print(currentfig,[path '/TrainingValidation/' name],'-dpdf','-fillpage')
            
        elseif exist('exportgraphics')
            exportgraphics(currentfig,fullfile(path, 'TrainingValidation',[name '.pdf']));
        elseif 1==1
            try
                %   savefig(currentfig, [path '/TrainingValidation/LSTMTraining.fig'],'compact')
                saveas(currentfig, [path '/TrainingValidation/' name '.pdf'])
            catch
                
            end
            %print(currentfig,fullfile(path, 'TrainingValidation',name),'-dpdf','-fillpage')
        elseif exist('exportapp')
            exportapp(currentfig,fullfile(path, 'TrainingValidation',[name '.pdf']));
        end
    end