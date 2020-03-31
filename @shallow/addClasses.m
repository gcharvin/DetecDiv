function addClasses(obj,classiid,classnames)

n=numel(classnames);


cc=numel(obj.processing.classification(classiid).roi);
if cc==1
   if  numel(obj.processing.classification(classiid).roi(1).id)==0
       cc=0;
   end
end

if cc==0
   disp('Error: there is no ROI available for training, first define ROIs'); 
   return;
end

obj.processing.classification(classiid).classes(end+1:end+n)=classnames;


for i=1:cc
    
    obj.processing.classification(classiid).roi(i).classes(end+1:end+n)=classnames;
    
    if numel(findobj('Tag',['ROI' obj.processing.classification(classiid).roi(i).id])) % handle exists already
    h=findobj('Tag',['ROI' obj.processing.classification(classiid).roi(i).id]);
    delete(h);
    obj.processing.classification(classiid).roi(i).view(obj.processing.classification(classiid).roi(i).display.frame,obj.processing.classification(classiid).category);
    end
end