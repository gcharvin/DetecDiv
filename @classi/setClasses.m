function setClasses(classif,classnames)

classnames=classnames';

n=numel(classnames);


cc=numel(classif.roi);
if cc==1
    if  numel(classif.roi(1).id)==0
        cc=0;
    end
end

if cc==0
    disp('Error: there is no ROI available for training, first define ROIs');
    return;
end


nclasses1=length(classif.classes);
nclasses2=length(classnames);

if  nclasses1~=nclasses2
    disp(['Warning: current @classi has ' num2str(nclasses1) 'classes:']);
    disp(classif.classes);
    disp(['But you propose to change it to ' num2str(nclasses2) 'classes:']);
    disp(classnames);
    
    prompt='Continue? (y/n); Default: n';
    preserv= input(prompt,'s');
    
    if numel(preserv)==0
        preserv='n';
    end
    
    if strcmp(preserv,'n')
        return;
    end
end

classif.classes=classnames;
classif.colormap=shallowColormap(numel(classif.classes));

    
    

        disp('Please indicate to which previous classes the new ones correspond to:');
        
        arr={};
        for j=1:nclasses2
            
            str='';
            for k=1:nclasses1
                str=[str num2str(k) ' - ' classif.classes{k} ';'];
            end
            
            disp(['Enter the id number(s) of the  class corresponding to ' classnames{j}  ]);
            
            prompt=['Among these classes: ' str '; Type 0 if this class has no match; Default :'  num2str(j)];
            idclass= input(prompt);
            
            if numel(idclass)==0
                idclass=j;
            end
            
            arr{j}=idclass;
        end
        
        
for i=1:cc
        %arr
        if numel(findobj('Tag',['ROI' classif.roi(i).id])) % handle exists already
            h=findobj('Tag',['ROI' classif.roi(i).id]);
            delete(h);
            classif.roi(i).view(classif.roi(i).display.frame,classif.category);
        end
        
        %classif.roi(cc+1).train.(classif.strid).id=roitocopy.train(obj.strid).id;
        id=zeros(size(classif.roi(i).train.(classif.strid).id));
        for j=1:nclasses2
            for k=1:numel(arr{j})
                
                if arr{j}(k)~=0
                    pix=classif.roi(i).train.(classif.strid).id==arr{j}(k);
                    %j
                    %aa=classif.roi(cc+1).train.(classif.strid).id
                    
                    id(pix)=j;
                    
                    %bb=classif.roi(cc+1).train.(classif.strid).id
                end
                
            end
        end
        
        classif.roi(i).train.(classif.strid).id=id;
        
        classif.roi(i).classes=classnames; 
end
    