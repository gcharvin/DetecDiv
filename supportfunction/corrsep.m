function [gt pred]=corrsep(sep)
% plots the correlation coefficient between gt and predicted value 

gt=[];
pred=[];

divclassi=sep.processing.classification(1);

for i=201:250 %1:numel(sep.processing.classification(2).roi)
    
    roiobj=sep.processing.classification(2).roi(i);
    
    div=divclassi.roi(i).results.myclassi_2.RLS.framediv; 
    
    if isfield(roiobj.results,'SEPdetection_2')
         if isfield(roiobj.results.SEPdetection_2,'id') 
             if numel(roiobj.results.SEPdetection_2.id)
                 
    pix1=find(roiobj.train.SEPdetection_2.id==2,1,'first');
     pix2=find(roiobj.results.SEPdetection_2.id==2,1,'first');
     
     div1=find(div>=pix1,1,'first');
     div2=find(div>=pix2,1,'first');
     
       gt=[gt div1];
     pred=[pred div2];
     
    % gt=[gt pix1];
   %  pred=[pred pix2];
             end
         end
    end
end

figure, plot(gt,pred,'LineStyle','none','Marker','.','MarkerSize',20); hold on 

xlabel('Groundtruth (divisions)');
ylabel('Predictions (divisions)');

data=[];
data.pred=pred;
data.gt=gt;

 plot([0 max(max(data.gt),max(data.pred))],[0 max(max(data.gt),max(data.pred))],'LineStyle','--','LineWidth',2,'Color','k');
            c=corrcoef(data.gt,data.pred);
            xlim([0 max(max(data.gt),max(data.pred))]);
            ylim([0 max(max(data.gt),max(data.pred))]);
            
            text(0,35,[ 'R^2 = ' num2str(c(1,2))]) 
            
