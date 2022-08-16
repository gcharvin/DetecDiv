function removeData(obj,train,results)
% removes training / results fields from ROIs 

% train and results are cell arrays of string with field names t be erased
% in each respective category . 
% write "all" if you want to remove all the fields 

removeall=0;

%obj.load % necessary to make sure that saving will then be effective. 

for i=1:numel(train)
    
type=train{i};

if strcmp(type,'all')
    obj.train=[];
    break;
end

if isfield(obj.train,train{i})
    obj.train=rmfield(obj.train,train{i});
else
    disp(['No '  type  ' data in training to be erased in this ROI!']);
end
end

for i=1:numel(results)
    
type=results{i};

if strcmp(type,'all')
    obj.results=[];
    break;
end

if isfield(obj.results,results{i})
    obj.results=rmfield(obj.results,results{i});
else
    disp(['No '  type  ' data in results to be erased in this ROI!']);
end
end

%obj.save;
    
 obj.log(['Removed training data or classi results from ROI'],'Processing');
