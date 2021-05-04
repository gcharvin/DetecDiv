function addROI(classif,obj,option)

% add ROI to object classif

% ROIs are imported from obj, which is either another classification, or a FOV from a shallow project

% Option : a vector that contains the list of ROIs to be added

if isa(obj,'fov')
    objtype='@fov';
    disp('You want to import ROIs from an existing @fov for training');
end
if isa(obj,'classi')
    objtype='@classi';
    disp('You want to import ROIs from an existing @classi for training');
    disp('Training datasets (ground truth) will be preserved when transferring ROIs');
    
end


if nargin==2
    disp(['This ' objtype ' has ' num2str(numel(obj.roi)) ' ROIs available']);
    disp('You did not specify which ROI you want to import.');
    prompt='Please enter the ROIs tu use as training sets: [ROI1id ROI2id ROI3id] (Default: [1 2 3])';
    rois= input(prompt);
    if numel(rois)==0
        rois=[1 2 3];
    end
    
end

if nargin==3 % use ROI numbers provdied as an extra argument
    rois=option;
end

disp('These ROIs will be imported:');
disp(rois);

%classif.addTrainingData(rois);

% copy dedicated ROIs to local classification folder and change path

cc=numel(classif.roi);

if cc==1
    if  numel(classif.roi(1).id)==0
        cc=0;
    end
end

preserv='';

arr={};

for i=1:length(rois)
    disp(['Processing ROI ' num2str(i) '/' num2str(length(rois))]);
    
    roitocopy=obj.roi(rois(i));

    % aa=roitocopy
    if cc==0
        classif.roi=roi('',[]);
    else
        classif.roi(cc+1)=roi('',[]);
    end
    
    if numel(roitocopy.image)==0
        roitocopy.load;
    end
    
    classif.roi(cc+1)=propValues(classif.roi(cc+1),roitocopy);
    classif.roi(cc+1).path = classif.path;
    
    classif.roi(cc+1).classes=classif.classes;
    
    %size(classif.roi(cc+1).image)
    
    if strcmp(classif.category{1},'Image') | strcmp(classif.category{1},'LSTM')
        classif.roi(cc+1).train.(classif.strid)=[];
        classif.roi(cc+1).train.(classif.strid).id= zeros(1,size(classif.roi(cc+1).image,4));
        classif.roi(cc+1).train.(classif.strid).classes=classif.classes;
         
        if isa(obj,'classi')
            if isfield(roitocopy.train,obj.strid) % test if previous ROI has training
                
                if  numel(preserv)==0 % new class has different number of classes
                    prompt='Preserve training set? (y/n); Default: y';
                    preserv= input(prompt,'s');
                    
                    if numel(preserv)==0
                        preserv='y';
                    end
                    
                    disp('This setting will apply to all ROIs');
                end
                
                if strcmp(preserv,'y')
                    
                    
                    nclasses1=length(classif.classes);
                    nclasses2=length(obj.classes);
                    
                    %if  nclasses1~=nclasses2
                    if numel(arr)==0
                        
                        
                        disp(['current @classi has ' num2str(nclasses1) 'classes:']);
                        disp(classif.classes);
                        
                        disp(['@classi to import from has ' num2str(nclasses2) 'classes:']);
                        disp(obj.classes);
                        
                        disp('You must map the first set of classes to the second');
                        
                        
                        for j=1:nclasses1
                            
                            str='';
                            for k=1:nclasses2
                                str=[str num2str(k) ' - ' obj.classes{k} ';'];
                            end
                            
                            disp(['Enter the id number(s) of the  class corresponding to ' classif.classes{j}  ]);
                            
                            prompt=['Among these classes: ' str '; Type 0 if this class has no match; Default :'  num2str(j)];
                            idclass= input(prompt);
                            
                            if numel(idclass)==0
                                idclass=j;
                            end
                            
                            arr{j}=idclass;
                        end
                    end
                    
                    %arr
                    
                    %classif.roi(cc+1).train.(classif.strid).id=roitocopy.train(obj.strid).id;
                    
                    for j=1:nclasses1
                        for k=1:numel(arr{j})
                            
                            if arr{j}(k)~=0
                                pix=roitocopy.train.(obj.strid).id==arr{j}(k);
                                %j
                                %aa=classif.roi(cc+1).train.(classif.strid).id
                                
                                classif.roi(cc+1).train.(classif.strid).id(pix)=j;
                                
                                %bb=classif.roi(cc+1).train.(classif.strid).id
                            end
                            
                        end
                    end
                    
               % else % classes are identical betwen old and new classes
               %     classif.roi(cc+1).train.(classif.strid).id=roitocopy.train.(obj.strid).id;
               % end
                
            end
        end
    end
    % classif.roi(cc+1).train= zeros(1,size(classif.roi(cc+1).image,4));
end

if strcmp(classif.category{1},'Pedigree')
    classif.roi(cc+1).train.(classif.strid)=[];
    classif.roi(cc+1).train.(classif.strid).id= zeros(1,size(classif.roi(cc+1).image,4));
    classif.roi(cc+1).train.(classif.strid).classes=classif.classes;
    classif.roi(cc+1).train.(classif.strid).mother= [];%zeros(1,size(classif.roi(cc+1).image,4));
    % classif.roi(cc+1).train= zeros(1,size(classif.roi(cc+1).image,4));
    
    im=classif.roi(cc+1).image;
    %size(im)
    matrix=im(:,:,classif.channel(2),:);
    
    classif.roi(cc+1).addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
end


if strcmp(classif.category{1},'Pixel')
    im=classif.roi(cc+1).image;
    matrix=uint16(zeros(size(im,1),size(im,2),1,size(im,4)));
    classif.roi(cc+1).addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
    classif.roi(cc+1).display.selectedchannel(end)=1;
    
%     if isa(obj,'classi')
%         if  strcmp(obj.category{1},'Pixel')
%             pixid=classif.roi(i).findChannelID(obj.strid);
%             classif.roi(i).display.channel{pixid}=classif.strid;
%         end
%     end
    %pixelchannel=size(obj.image,3);
end



if strcmp(classif.category{1},'Object')
    im=classif.roi(cc+1).image;
    %size(im)
    matrix=uint16(im(:,:,classif.channel(2),:)>0);
    
    classif.roi(cc+1).addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
    
%     if isa(obj,'classi')
%         pixid=classif.roi(i).findChannelID(obj.strid);
%         classif.roi(i).display.channel{pixid}=classif.strid;
%     end
    %pixelchannel=size(obj.image,3);
end


classif.roi(cc+1).save;
classif.roi(cc+1).clear;

cc=cc+1;
end


% if isa(obj,'classi') % rois are imported from previous classiciation
%
%     disp('You want to import ROIs from an existing @classi for training');
%     disp('This @classi has ' num2str(numel(obj.roi)) ' ROIs available');
%
%     if nargin<3 % specificy classif to import from
%         prompt='Enter the id number of the classification to import from (Default: 1): ';
%         prevclas= input(prompt);
%         if numel(prevclas)==0
%             prevclas=1;
%         end
%     else
%         prevclas=option;
%     end
%
%     disp(' ');
%
%     disp(['Number of ROIs available in the classification training set: ' num2str(numel(obj.processing.classification(prevclas).roi))]);
%     for j=1:numel(obj.processing.classification(prevclas).roi)
%         disp([num2str(j) '- '  obj.processing.classification(prevclas).roi(j).id]);
%     end
%     disp(' ');
%     prompt='Enter the id numbers of the ROIs to import in a comma-separated way (Default: 1): ';
%     ids= input(prompt,'s');
%     if numel(ids)==0
%         ids=1;
%     else
%         ids=str2num(ids);
%     end
%
%     classif.trainingset=obj.processing.classification(prevclas).trainingset;
%
%     % copy dedicated ROIs to local classification folder and change path
%
%     cc=numel(classif.roi);
%
%     if cc==1
%         if  numel(classif.roi(1).id)==0
%             cc=0;
%         end
%     end
%
%
%
%     for i=ids
%         % rois(1,i),rois(1,i)
%         %rois(1,i),rois(2,i)
%         disp(['Processing ROI ' num2str(cc+1) '/' num2str(numel(ids))]);
%
%         roitocopy=obj.processing.classification(prevclas).roi(i); %obj.fov(rois(1,i)).roi(rois(2,i));
%
%         % aa=roitocopy
%
%         if cc==0
%             classif.roi=roi('',[]);
%         end
%         classif.roi(cc+1)=roi('',[]);
%
%         if numel(roitocopy.image)==0
%             roitocopy.load;
%         end
%
%         classif.roi(cc+1)=propValues(classif.roi(cc+1),roitocopy);
%         classif.roi(cc+1).path = classif.path;
%
%         classif.roi(cc+1).classes=classif.classes;
%
%         %size(classif.roi(cc+1).image)
%
%         %     if strcmp(classif.category{1},'Image') | strcmp(classif.category{1},'LSTM')
%         %     classif.roi(cc+1).train.(classif.strid)=[];
%         %     classif.roi(cc+1).train.(classif.strid).id= zeros(1,size(classif.roi(cc+1).image,4));
%         %    % classif.roi(cc+1).train= zeros(1,size(classif.roi(cc+1).image,4));
%         %     end
%
%         if strcmp(classif.category{1},'Pixel') && strcmp(obj.processing.classification(prevclas).category{1},'Pixel')
%
%             pixid=classif.roi(i).findChannelID(obj.processing.classification(prevclas).strid);
%             classif.roi(i).display.channel{pixid}=classif.strid;
%
%             %im=classif.roi(cc+1).image;
%             % matrix=uint16(zeros(size(im,1),size(im,2),1,size(im,4)));
%             %classif.roi(cc+1).addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
%             %classif.roi(cc+1).display.selectedchannel(end)=1;
%             %pixelchannel=size(obj.image,3);
%         end
%
%         if strcmp(classif.category{1},'Object')
%
%             pixid=classif.roi(i).findChannelID(obj.processing.classification(prevclas).strid);
%             classif.roi(i).display.channel{pixid}=classif.strid;
%
%             % im=classif.roi(cc+1).image;
%             %size(im)
%             % matrix=uint16(im(:,:,classif.channel(2),:)>0);
%
%             % classif.roi(cc+1).addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
%             %pixelchannel=size(obj.image,3);
%         end
%
%
%
%         classif.roi(cc+1).save;
%         classif.roi(cc+1).clear;
%
%         cc=cc+1;
%     end
%
% end


function newObj=propValues(newObj,orgObj)
pl = properties(orgObj);
for k = 1:length(pl)
    if isprop(newObj,pl{k})
        newObj.(pl{k}) = orgObj.(pl{k});
    end
end

