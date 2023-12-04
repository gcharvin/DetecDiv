function listout=listAvailableChannels()
% list all possible channels in the workspace variable

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
            if strcmp(roiobj(k).display.channel,' ')
                continue;
            end
            
         
            if sum(contains(roiobj(k).display.channel,'-'))>0
                continue;
            end
            listcha=[ listcha  roiobj(k).display.channel];
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

            if strcmp(roiobj(k).display.channel,' ')
                continue;
            end
   
            if sum(contains(roiobj(k).display.channel,'-'))>0
                continue;
            end

                listcha=[ listcha  roiobj(k).display.channel];
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
        listcha=[ listcha  roiobj(k).display.channel];
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
