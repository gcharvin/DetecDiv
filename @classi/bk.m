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
            
%             src=    fullfile(pth,'netCNN.mat');
%             load(src)
%             if exist(src)
%                  target=fullfile(pth,['netCNN_' str '.mat'])
%                  copyfile(src,target);  
%             end
           
            src=    fullfile(pth,['netCNN_' classif.strid '.mat']);
            if exist(src)
                 target=fullfile(pth,['netCNN_' classif.strid '_' str '.mat']);
                 copyfile(src,target);  
            end
            
%             src=    fullfile(pth,'netLSTM.mat');
%              if exist(src)
%                  target=fullfile(pth,['netLSTM_' str '.mat']);
%                  copyfile(src,target);  
%              end
            
               src=    fullfile(pth,['netLSTM_' classif.strid '.mat']);
             if exist(src)
                      target=fullfile(pth,['netLSTM_' classif.strid '_' str '.mat']);
                 copyfile(src,target);  
            end
            