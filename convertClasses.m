function convertClasses(classif,roiid)
% convert small, unbudded , large classes into no div, div, dead classes
% for training set to test the possiblity to automatically detect divisions


deathid=4;
clogid=6;%findclassid(classes,'clog');
lbid=3;
smid=2;
unbuddedid=1;
%emptyid=findclassid(classes,'empty');

% new class id
classes={'nodiv','div','dead','clog'};


if nargin==1
    list=1:numel(classif.roi);
end
if nargin==2
    list=roiid;
end

for i=list
    
    id=classif.roi(i).train.(classif.strid).id; 
    
    idout=ones(size(id));
    
    idout(id==deathid)=3;
    idout(id==clogid)=4;
%    idout(id==emptyid)=1;

pixbirth=1;
pixend=length(idout);

for j=pixbirth:pixend-1
    % j
    if (id(j)==lbid && id(j+1)==smid) | (id(j)==lbid && id(j+1)==unbuddedid) % cell has divided
        %  j
        idout(j+1)=2;
    end
end

classif.roi(i).train.(classif.strid).id=idout;
end



