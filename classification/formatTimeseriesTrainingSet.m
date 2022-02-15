function output= formatTimeseriesTrainingSet(foldername,classif,rois)

output=0;
% if ~isfolder([classif.path '/' foldername '/data'])
%     mkdir([classif.path '/' foldername], 'data');
% end

% get the training data for each ROI and put in a relevant file

XTrain={};
YTrain={};
classes=classif.classes;

strfield=classif.channelName{1};

pix=strfind(strfield,'.');

if numel(pix)==0
    str={strfield};
else
    str={strfield(1:pix(1)-1)};

    cc=1;
    for i=1:numel(pix)-1
        str{cc+1}=strfield(pix(i)+1:pix(i+1)-1);
        cc=cc+1;
    end
end
str{cc+1}=strfield(pix(cc)+1:end);

% parse fields

cc=1;


for i=rois

    tmp=classif.roi(i);

  %  str
    for j=1:numel(str)
        if isprop(tmp,str{j}) || isfield(tmp,str{j})
            
        tmp=tmp.(str{j});
        else
        tmp=[];
        break;
        end
    end

    
 %   tmp

    if numel(tmp)

       % tmp
      pix=find(~isnan(classif.roi(i).train.(classif.strid).id));
      %pix=pix(1:numel(tmp));
      
      xtmp=tmp(pix);
      ytmp=classif.roi(i).train.(classif.strid).id(pix);

        %& ~isnan(classif.roi(i).train.(classif.strid).id)
    XTrain{cc,1}=xtmp;

   % if classif.roi(i).train.(classif.strid).id~=0 % uncomment if willing
   % to resassign =0 values to =numel(tmp) values , and updates the
   % training setp

    YTrain{cc,1}=ytmp;
     output=output+1;
  %  else
  %  YTrain{cc,1}=numel(tmp);
   % classif.roi(i).train.(classif.strid).id=numel(tmp);

     cc=cc+1;
    end

end

save(fullfile(classif.path,foldername,'TrainingData.mat'),'XTrain','YTrain','classes');


end
