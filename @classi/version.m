function [t,lastIndex]=version(classif)
% list all stored version of the current classifier


[pth,file]=classif.getPath;
l=dir(pth);
l=l([l.isdir]==0);

%  tmp_network=regexp({l.name}, [file '_\d+.mat'],'match')
tmp_network=regexp({l.name}, [file '_(?<val>\d+).mat'],'names');
tmp_classi=regexp({l.name}, [file '_classification_(?<val>\d+).mat'],'names');

val_network=[];
fileindex_network=[];

for i=1:numel(tmp_network)
    if numel(tmp_network{i})~=0
        val_network=[val_network str2num(tmp_network{i}.val)];
        fileindex_network=[fileindex_network i];
    end
end

val_classi=[];
fileindex_classi=[];

for i=1:numel(tmp_classi)
    if numel(tmp_classi{i})~=0
        val_classi=[val_classi str2num(tmp_classi{i}.val)];
        fileindex_classi=[fileindex_classi i];
    end
end

[inte ia ib]=intersect(val_network,val_classi);
fileindex_classi=fileindex_classi(ib);
fileindex_network=fileindex_network(ia);

t={''};
lastIndex=0;


cc=1;
if numel(inte)
   lastIndex=max(inte); 
for i=inte
    
    %                    str=num2str(i);
    %                     while numel(str)<3
    %                         str=['0' str];
    %                     end
    %
    %
    %                  classiName=[file '_classification_' str '.mat']
    %                  classifierName=[file '_' str '.mat']

    cla=l(fileindex_classi(cc));
    net=l(fileindex_network(cc));
    
    classiObj=[];
    
    ff=(fullfile(cla.folder,cla.name));
    
    if exist(ff)
        load(ff);
    else
        disp('could not load classification file');
    end
    
    ca=1;
    
    if numel(classiObj.roi)==1 & numel(classiObj.roi.id)==0
        nrois=0;
    else
        nrois=numel(classiObj.roi);
    end
    
    t{cc,ca}=cla.name; ca=ca+1;
    t{cc,ca}=cla.date; ca=ca+1;
    t{cc,ca}=nrois; ca=ca+1;
    t{cc,ca}=net.name; ca=ca+1;
    t{cc,ca}=net.date; ca=ca+1;
    
      
    cc=cc+1;
end
end
