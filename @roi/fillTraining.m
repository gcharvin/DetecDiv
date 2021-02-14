function fillTraining(obj)

%find the training id
trainids=fieldnames(obj.train);

str=[];
for i=1:numel(trainids)
    str=[str num2str(i) ' - ' trainids{i} ';'];
end

prompt=['Choose which training to fill among: ' str];
trainid=input(prompt);

if numel(trainid)==0
                trainid=numel(trainids);
end
            
%fill the holes
lastAnnotatedFrame=find(obj.train.(trainids{trainid}).id,1,'last');

for f=1:lastAnnotatedFrame 
    if obj.train.(trainids{trainid}).id(f)==0
     obj.train.(trainids{trainid}).id(f)=     obj.train.(trainids{trainid}).id(f-1);
    end
end
disp('Array filled');