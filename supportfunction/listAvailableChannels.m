function list=listAvailableChannels()
% list all possible channels in the workspace variable

list=[];
listproj= gatherVariablesFromWorkspace;

for i=1:numel(listproj.Project)

    proj=evalin('base',listproj.Project{i});

    positions={proj.fov.id};
    classifiers={proj.processing.classification.strid};

    for j=1:numel(listproj.Projectpos)

        pix=find(matches(positions,listproj.Projectpos{j}));

        if numel(pix)==0
            continue
        end

        roiobj=proj.fov(pix).roi;
        listcha={};

        for k=1:numel(roiobj)
            listcha=[ listcha  roiobj(k).display.channel];
        end

        list=[list unique(listcha) ];
    end

    for j=1:numel(listproj.Projectclassi)

        pix=find(matches(classifiers,listproj.Projectclassi{j}));

        if numel(pix)==0
            continue
        end

        roiobj=proj.processing.classification(pix).roi;
        listcha={};

        for k=1:numel(roiobj)
            listcha=[ listcha  roiobj(k).display.channel];
        end

        list=[list unique(listcha) ];
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
