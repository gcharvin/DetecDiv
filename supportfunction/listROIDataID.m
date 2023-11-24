function [listout]=listROIDataID(datatype)
% list all possible channels in the workspace variable

if nargin==0
    datatype=[];
end

list=[];
listproj= gatherVariablesFromWorkspace;

for i=1:numel(listproj.Project)

    proj=evalin('base',listproj.Project{i});

    positions={proj.fov.id};
    if numel(proj.processing.classification)
        classifiers={proj.processing.classification.strid};
    else
        classifiers={};
    end

    for j=1:numel(listproj.Projectpos{i})
        tmp=listproj.Projectpos{i}{j};

        pix=find(matches(positions,tmp));

        if numel(pix)==0
            continue
        end

        roiobj=proj.fov(pix).roi;
        listcha={};



        for k=1:numel(roiobj)
            roiobj(k).load('data');

            if numel(roiobj(k).data)==0
                continue
            end
            
            if numel(roiobj(k).data(1).data)==0
                continue;
            end

            
            if numel(datatype)==0
                listcha=[ listcha  {roiobj(k).data.groupid}];
            else
              cla=[roiobj(k).data.class];
              if numel(find(matches(cla,datatype)))
               
                  pix=find(matches(cla,datatype));
                  listcha=[ listcha  {roiobj(k).data(pix).groupid}];
              end
            end

            

            if numel(listcha)>20 && k>100 % stop sampling roi if enough is gathered
                %    break;
            end
        end

        list=[list unique(listcha) ];
    end

    for j=1:numel(listproj.Projectclassi)

        pix=find(matches(classifiers,listproj.Projectclassi{j}));

        if numel(pix)==0
            continue
        end

        for jj=1:numel(pix)
            roiobj=proj.processing.classification(pix(jj)).roi;
            listcha={};

            for k=1:numel(roiobj)

                if numel(roiobj(k).data(1).data)==0
                    continue;
                end

               if numel(datatype)==0
                listcha=[ listcha  {roiobj(k).data.groupid}];
            else
              cla=[roiobj(k).data.class];
              if numel(find(matches(cla,datatype)))
               
                  pixe=find(matches(cla,datatype));
                  listcha=[ listcha  {roiobj(k).data(pixe).groupid}];
              end
            end

                if numel(listcha)>20 && k>100 % stop sampling roi if enough is gathered
                    %    break;
                end

            end
            %  listcha
            list=[list unique(listcha) ];
        end


    end
end



for i=1:numel(listproj.Classifier)
    classifiers=evalin('base',listproj.Classifier{i});
    % pix=find(matches(classifiers,listproj.Projectclassi{j}));
    roiobj=classifiers.roi;
    listcha={};

    for k=1:numel(roiobj)
        if numel(roiobj(k).data(1).data)==0
            continue;
        end

         if numel(datatype)==0
                listcha=[ listcha  {roiobj(k).data.groupid}];
            else
              cla=[roiobj(k).data.class];
              if numel(find(matches(cla,datatype)))
               
                  pix=find(matches(cla,datatype));
                  listcha=[ listcha  {roiobj(k).data(pix).groupid}];
              end
         end
   

        if numel(listcha)>20 && k>100 % stop sampling roi if enough is gathered
            %      break;
        end
    end

    list=[list unique(listcha) ];
end

list=unique(list);

listout={};

cc=1;
for i=1:numel(list)
    if sum(contains(list{i},' '))>0

        continue;
    end
    if sum(contains(list{i},'-'))>0

        continue;
    end

    listout{cc}=list{i};
    cc=cc+1;
end
