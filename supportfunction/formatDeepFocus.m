function formatDeepFocus(classif)

offset=0.5;

for i=1:numel(classif.roi)

    id=classif.roi(i).train.(classif.strid).id;
    tmp=zeros(size(id));
    pix=find(id==0);
    
    if numel(pix)
        rr=1:numel(id)-pix;
    tmp(pix+1:numel(id))=offset*rr;
        rr=pix-1:-1:1;
    tmp(1:pix-1)=-offset*rr;
    classif.roi(i).train.(classif.strid).id=tmp;
    end
    
end


