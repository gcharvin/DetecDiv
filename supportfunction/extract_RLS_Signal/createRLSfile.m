function rls=createRLSfile(classif,roiobj,varargin)

GT=0;
for i=1:numel(varargin)
    if strcmp(varargin{i},'GT')
        GT=1;
    end
end

%ClassiType is the classif type of obj :
% ClassiType='bud' : unbudded, small, large, dead etc.
% ClassiType='div' : nodiv, div, dead etc.

% rls combines results and groundtruth is applicable
% rlsResults only results
%rlsGroundtruth only groundtruth
environment='local';


classifstrid=classif.strid;
for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Envi')
        environment=varargin{i+1};
    end

end
%%
cc=1;
for i=1:numel(roiobj)
    if strcmp(environment,'local')
        roiobj(i).path=strrep(roiobj(i).path,'/shared/space2/','\\space2.igbmc.u-strasbg.fr\');
    end
    roiobj(i).load('results');
    roiobj(i).path=strrep(roiobj(i).path,'/shared/space2/','\\space2.igbmc.u-strasbg.fr\');
    rls(cc)=roiobj(i).results.RLS.(['from_' classifstrid]);
    
    if GT==1
        rls(cc+1)=roiobj(i).train.RLS.(['from_' classifstrid]);
        cc=cc+2;
    else
        cc=cc+1;
    end
%     if isprop(roiobj(i),'train') && numel(roiobj(i).train.(classifstrid).id)>0
%         roiobj(i).train.(classifstrid).RLS=RLS(roiobj(i),'train',classif,param);
%     end
    roiobj(i).clear;        
    
end
