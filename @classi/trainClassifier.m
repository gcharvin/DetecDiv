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
 
%    
  if  ~isfield(classif.trainingParam,'transfer_learning')
                 [t,lastIndex]=classif.version;
                 str=t(:,1);
                 str=['ImageNet', str', 'ImageNet'];
                 classif.trainingParam.transfer_learning=str;
                 classif.trainingParam.tip{end+1}='Select version of the classifier to be used';
end
end
            
