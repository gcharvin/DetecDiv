function trainClassifier(classif,setparam)
% trains the selected classifier
% setparam can be any argument and is used to setup default parameter value

trainingFun=classif.trainingFun;



if nargin==1
    disp(['Launching training procedure with ' trainingFun]);
feval(trainingFun,classif);
else
    disp(['Setting parameters for  ' trainingFun]);
 feval(trainingFun,classif,setparam);  
 
end

            
