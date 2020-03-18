function computefluo(obj)
% compute fluorescence values based on object trajectory

%fprintf('Compute fluo values\n');


if numel(obj.gfp)==0
    obj.load;
end

frames=1:size(obj.track,3);

fluo=zeros(length(frames),size(obj.gfp,4));
phc=zeros(length(frames),1);

for i=1:4
    bw(:,:,i)=poly2mask(obj.data.cavity.rect(:,1,i),obj.data.cavity.rect(:,2,i),size(obj.gfp,1),size(obj.gfp,2));
    % figure, imshow(bw(:,:,i),[]);
end

cavity=obj.data.cavity.inputpoly;
xc=mean(cavity(1:end-1,1));
yc=mean(cavity(1:end-1,2));

bwcavity=poly2mask(cavity(:,1),cavity(:,2),size(obj.gfp,1),size(obj.gfp,2));

%figure, imshow(bw,[]);

incavity=zeros(1,length(frames));


ce=1;
reverseStr='';
for i=frames
    % fprintf('.');
    tmp=(obj.track(:,:,i));
    
    for j=1:size(obj.gfp,4)
        
        fluotemp=obj.gfp(:,:,i,j);
        
        %figure, imshow(bwcavity & tmp,[]);
        %return;
        tmp2=bwcavity & tmp;
        
        if sum(tmp2(:))>0
            incavity(i)=1;
        end
        
        if max(tmp(:))>0
            
            fluo(i,j)=sum(fluotemp(tmp==1));
            
            
            % s = regionprops(tmp==1,'centroid');
            % teste(i)=sqrt((s.Centroid(1)-size(obj.gfp,2)/2)^2+(s.Centroid(2)-size(obj.gfp,1)/2-5)^2);
        end
        
        
        if j==obj.phasechannel
            for k=1:4
                phc(i,k)=mean(fluotemp(bw(:,:,k)));
            end
            
             I=obj.gfp(:,:,i,j);
             bwn=logical(tmp);
                
             [level em] = graythresh(I);
             BW = imbinarize(I,level);
                
              BW=BW | ~bwcavity;
                
                m=bwdist(BW);
                %figure, imshow(BW,[]);
                
                if sum(bwn(:))>0
                    dist(i)=mean(m(bwn));
                    
                else
                    dist(i)=0;
                end 
        end
        
    end
    
    if mod(ce-1,50)==0
        msg = sprintf('%d / %d Frames - Computing fluo values', ce , numel(frames) ); %Don't forget this semicolon
        msg=[msg ' for trap ' obj.id];
        
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    
    ce=ce+1;
end

fprintf('\n');


% fluorescence and phase values over time
windowsize=20;
%size(fluo)

meanfluo(1)=mean(fluo(:,1));
meanfluo(2)=mean(fluo(:,2));

fluo(:,1)=fluo(:,1)-smooth(fluo(:,1),windowsize);
fluo(:,2)=fluo(:,2)-smooth(fluo(:,2),windowsize);

%fluo(:,1)=fluo(:,1)./abs(max(fluo(:,1)));
%fluo(:,2)=fluo(:,2)./abs(max(fluo(:,2)));

for k=1:4
    phc(:,k)=(phc(:,k)-smooth(phc(:,k),windowsize));
end
% for k=1:4
%     phc(:,k)=phc(:,k)./max(abs(phc(:,k)));
% end


obj.data.fluo=fluo; % image intensity in tracked nucleus for al channels
obj.data.phc=phc; % phase image intensity in some fixed ROIs

% other properties

% calculate variables associated with  divisions
fluo=fluo(:,obj.gfpchannel);


 cv=[];
 win=20;
 for i=1:numel(fluo)-win
     cv(i)=std(fluo(i:i+win))/meanfluo(obj.gfpchannel);%./mean(fluo(i:i+win));
 end
 
 cv(numel(cv)+1:size(obj.gfp,3))=0;
 %cv
 obj.data.dist=dist; % distance of nucleus to center
 obj.data.cv=cv; % cv of gfp fluo signal over time



fluodiff=-diff(fluo);
fluodiff=fluodiff';
x=    1:numel(fluo);
xdiff=1+(1:numel(fluodiff));

xx=size(obj.gfp,1)/2;
yy=size(obj.gfp,2)/2;

for i=frames
    [l , n(i)] = bwlabel(obj.classi(:,:,2,i)>0);
    
    %figure, imshow(obj.track(:,:,i),[])
    
    p2=regionprops(obj.track(:,:,i),'Area','Centroid','Eccentricity');
    
    if numel(p2)>0
        a(i)=p2.Area;
        d(i)=sqrt((p2.Centroid(1)-size(obj.gfp,2)/2)^2+(p2.Centroid(2)-size(obj.gfp,1)/2)^2);
        e(i)=p2.Eccentricity;
        
        xx(i)=p2.Centroid(1);
        yy(i)=p2.Centroid(2);
        
    else
        a(i)=0;
        d(i)=0;
        e(i)=0;
        
        if i>1
            xx(i)=xx(i-1);
            yy(i)=yy(i-1);
        end
        
    end
    
    p=regionprops(l,'Centroid');
    
    isfirst(i)=1;
    
    if length(p)
    dd=[];
    for j=1:length(p)
        dd(j)=sqrt((p(j).Centroid(1)-xc)^2+(p(j).Centroid(2)-yc)^2);
    end
    [ddsort ix]=sort(dd);
    idtrack=mean(l(logical(obj.track(:,:,i))));
    
    if ix(1)~=idtrack % tracked ncleus is not the closest to cavifty center
       isfirst(i)=0;
    end
    
   % if i==327
     %  i,p,dd,ix,idtrack 
   % end
    end
    
end

motion=sqrt( (xx(2:end)-xx(1:end-1)).^2+(yy(2:end)-yy(1:end-1)).^2);
motion=2*motion./size(obj.gfp,1);

dn=diff(n);
dn(dn<0)=0;

da=-diff(a);
de=-diff(e);

 
obj.data.isfirst=isfirst; % isfirst=1 if tracked nucleus is closest nucleus to center
obj.data.motion=motion; % motion of nucleus from frame to frame
obj.data.area=a; % area of nucleus
obj.data.areadiff=da; 
obj.data.ecc=e; % excentricity of nucleus
obj.data.eccdiff=de;
obj.data.nucl=n; % number of nuclei in image
obj.data.nucldiff=dn;
obj.data.fluodiff=fluodiff; %


obj.data.incavity=incavity;
%%%


%
% % prepare division classifications
%
% for i=frames % number of objects on frame
% [aaa , n(i)] = bwlabel(obj.classi(:,:,2,i)>0);
% end
%
% n=n';
% ndiff=diff(n);
%
% fluodiff=-diff(fluo);
%
% %size(fluodiff), size(ndiff)
% %figure, plot((1+ndiff).*fluodiff)
%
% %figure, plot(fluodiff)
%
% blend= (1+1*ndiff).*fluodiff;
%
% x=    1:numel(fluo);
% xdiff=1:numel(fluodiff);

divisionTime=obj.div.divisionTime;

%figure, plot(blend)

%size(dn), size(fluodiff)

blend= (1+1*dn').*fluodiff';

%size(dn'),size(fluodiff)

TF = islocalmax(blend,'MinSeparation',divisionTime);%,'MinProminence',15000);

%sum(TF)

%size(blend)
%size(TF)
%obj.fluodiff=fluodiff;

obj.div.raw=logical(zeros(1,numel(TF)));
obj.div.raw(:)=TF(:);
obj.div.reject=zeros(1,numel(TF));
obj.div.classi=logical(zeros(1,numel(TF)));
obj.div.dead=logical(zeros(1,numel(TF)));
obj.div.stop=size(obj.gfp,3);
%obj.div.daughter=logical(zeros(1,numel(TF)));
