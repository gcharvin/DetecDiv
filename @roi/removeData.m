function removeData(obj,type,option)
% removes training / results fields from ROIs 
% type : 'train' , 'results', 
% option = strid to be removed  ; if no option provided, than all fields
% are removed

removeall=0;

if nargin==2
   removeall=1;
   option='';
end

if numel(obj.(type))==0
    disp(['No '  type  ' data to be erased in this ROI!']);
    return;
end

res=fieldnames(obj.(type));

for i=1:numel(res)
    
    if strcmp(res{i},option) | removeall==1
    obj.(type)=rmfield(obj.(type),res{i});
 disp([ type  ' data '  res{i} '  erased in this ROI!']);
    end 
   
end

res=fieldnames(obj.(type));
if numel(res)==0
    obj.(type)=[];
end
    
