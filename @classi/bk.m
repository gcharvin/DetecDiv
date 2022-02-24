function bk(classif)
% back up current classification object and related classifier 

            
            [pth,file]=classif.getPath;
           
            [t,lastIndex]=classif.version;
            
              str=num2str(lastIndex+1);
              
                    while numel(str)<3
                        str=['0' str];
                    end
            
            classifier=loadClassifier(classif);
            classiObj=classif;
            
            save(fullfile(pth,[file '_' str '.mat']),'classifier');
            save(fullfile(pth,[file '_classification_' str '.mat']),'classiObj');