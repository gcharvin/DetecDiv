function formatSequenceSEP(obj,varargin)

rois=1:numel(obj.roi);

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Train')
        formatTrain=1;
    end
    
    if strcmp(varargin{i},'Input')
        formatInput=1;
    end
    
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
end

trainingpath=strsplit(obj.trainingset,'.');
classistridinput=trainingpath{2};

for r=rois
       
    if isfield(obj.roi(r).train.(classistridinput),'RLS')
        frameBirth=obj.roi(r).train.(classistridinput).RLS.frameBirth;
        frameEnd=obj.roi(r).train.(classistridinput).RLS.frameEnd;
        sep=obj.roi(r).train.(classistridinput).RLS.sep;
        divDuration=obj.roi(r).train.(classistridinput).RLS.divDuration;
    else
        error(['You must compute RLS of this roi the classi of' obj.trainingset])
    end
    
    
    targetobj=obj.roi(r);
    for ii=1:numel(trainingpath)-1
        targetobj=targetobj.(trainingpath{ii});
    end
    targetobj2=targetobj.id;
    targetobj3=targetobj.(trainingpath{end});

    %formatTraining
    if formatTrain==1
        
        obj.roi(r).train.(obj.strid).id=NaN(1,numel(targetobj2));
        if ~isempty(frameBirth) && ~isempty(frameEnd) && sep>0
            obj.roi(r).train.(obj.strid).id(frameBirth:frameBirth+sum([divDuration(1:sep)]))=0;
            obj.roi(r).train.(obj.strid).id(frameBirth+sum([divDuration(1:sep)])+1:frameEnd)=1;
        end %else, stay full of NaN;
        obj.roi(r).train.(obj.strid).id=...
            obj.roi(r).train.(obj.strid).id(~isnan(obj.roi(r).train.(obj.strid).id));
    end
    
    %format input timeseries
    if formatInput==1
        targetobj3=NaN(1,numel(targetobj2));
        if ~isempty(frameBirth) && ~isempty(frameEnd) && sep>0
            targetobj3(frameBirth:frameEnd)=...
                targetobj2(frameBirth:frameEnd);
        end %else, stay full of NaN;
        
        obj.roi(r).(trainingpath{1}).(trainingpath{2}).(trainingpath{3})=targetobj3;
        obj.roi(r).(trainingpath{1}).(trainingpath{2}).(trainingpath{3})=...
            obj.roi(r).(trainingpath{1}).(trainingpath{2}).(trainingpath{3})(~isnan(obj.roi(r).(trainingpath{1}).(trainingpath{2}).(trainingpath{3})));
    end
    
end

