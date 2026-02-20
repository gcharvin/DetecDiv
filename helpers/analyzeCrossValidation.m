function analyzeCrossValidation

path='S:\Theo\Projects\RAMM\ShallowProject\segmentationGilles\seg\classification\segcellpaper_5\TrainingValidation';

acc=[];
rec=[]
f1=[];

weights=[0.33 0.33 0.33];

for i=1:30
    val=num2str(i);
    
    while numel(val)<3
        val=['0' val];
    end
    
    str=['Step' val '.mat_score_1_classes.fig'];
    fil=fullfile(path,str);
    uiopen(fil,1);
    
    h=gca;
    
    acc(i)=weights(1)*h.Children(2).YData(1)+weights(2)*h.Children(2).YData(2)+weights(3)*h.Children(2).YData(3);
    rec(i)=weights(1)*h.Children(3).YData(1)+weights(2)*h.Children(3).YData(2)+weights(3)*h.Children(3).YData(3);
    f1(i)= weights(1)*h.Children(1).YData(1)+weights(2)*h.Children(1).YData(2)+weights(3)*h.Children(1).YData(3);
    
    close
    
end


figure('Color','w'), plot(rec,'Color',[0 0.6 0],'LineWidth',2); hold on; 
plot(acc,'Color',[0.8 0.2 0],'LineWidth',2);
plot(f1,'Color',[1 0.8 0],'LineWidth',2);


ylim([0 100]);

legend({'Accuracy', 'Recall', 'F1-score'});

xlabel('Draw');

ylabel('Benchmark (%)');

set(gca,'FontSize',14)


