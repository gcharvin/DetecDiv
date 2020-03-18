  function [M,Y]=collectObjectTrapData(obj)
   % collect training events in a given trap 
   
   if numel(obj.gfp)==0
              obj.load;
   end

      frames=1:size(obj.traintrack,4);
%end


% use training set for building classification tree

train= obj.traintrack(:,:,3,frames);
trainst=sum(train,2);
trainst=sum(trainst,1);
trainst=permute(trainst,[4 1 2 3]);

l=bwlabel(trainst); % frames that are used for training

M=zeros(1,49); % input 4 + 9 x 5 columns
Y=[]; % ground truth

cc=1;

fra=[];



for k=1:max(l(:)) % detect series of tracked nuclei
    fr=find(l==k);
    
    for i=fr'
        
        if i==fr(1) % init algo for first detected object
            
            nref=obj.traintrack(:,:,3,i)>0; % selected object on first frame
            
            p=regionprops(nref,obj.gfp(:,:,i,obj.gfpchannel),'Area','Centroid','Eccentricity','MeanIntensity');
            
            M(cc,1)= 1/sqrt((p.Centroid(1)-size(obj.gfp,2)/2)^2+(p.Centroid(2)-size(obj.gfp,1)/2)^2); % distance of tracked nucleus from center
            M(cc,2)= p.Area; % area of nucleus
            M(cc,3)= p.Eccentricity; % area of nucleus
            M(cc,4)= p.MeanIntensity;
            
            %M(cc,2)= 0; % area of nucleus
            %M(cc,3)= 0; % area of nucleus
            %M(cc,4)= 0;
            
        else
            n2=obj.traintrack(:,:,2,i)>0; % all objects on  frame n
            %n1=obj.traintrack(:,:,1,i)>0; % all objects on  frame n-1
            lab2=bwlabel(n2,4);
            p2=regionprops(lab2,obj.gfp(:,:,i,obj.gfpchannel),'Area','Centroid','Eccentricity','MeanIntensity');
            
            
                      % subselect and sort 5 objects close to center
                    dist=[];
                      for j=1:numel(p2)
                          dist(j)=sqrt((p2(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p2(j).Centroid(2)-size(obj.gfp,1)/2)^2);
                      end
            
                      [distmin ix]=sort(dist,'ascend');
            
                      tmp=zeros(size(n2));
            
                      for kk=1:min(5,numel(p2))
                         bw=lab2== ix(kk); % no sorting
                         tmp(bw)=kk;
                      end
            
                     %n2=tmp;
                     lab2=tmp;
                     p2=regionprops(lab2,obj.gfp(:,:,i,obj.gfpchannel),'Area','Centroid','Eccentricity','MeanIntensity');
%             
%             
            
            
            %           % first sort by distance from center
            %           dist=[];
            %           for j=1:numel(p2)
            %               dist(j)=sqrt((p2(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p2(j).Centroid(2)-size(obj.gfp,1)/2)^2);
            %           end
            %
            %           [distmin ix]=sort(dist,'ascend');
            %
            %           tmp=zeros(size(n2));
            %
            %           for kk=1:numel(p2)
            %              bw=lab2==kk;
            %              tmp(bw)=ix(kk);
            %           end
            
            %          n2=tmp;
            %         p2=regionprops(tmp,obj.gfp(:,:,i),'Area','Centroid','Eccentricity','MeanIntensity');
            
            %n2=tmp;
            %p2=regionprops(tmp,obj.gfp(:,:,i),'Area','Centroid','Eccentricity','MeanIntensity');
            %figure, imshow(tmp,[])
            
            
            dd=0;
            for j=1:numel(p2)
                
                % i,j,p2(j)
                
                %dds=sqrt((p2(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p2(j).Centroid(2)-size(obj.gfp,1)/2)^2)
                %pause
                % close
                
                     M(cc,5+dd)=  1/sqrt((p2(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p2(j).Centroid(2)-size(obj.gfp,1)/2)^2); % distance of tracked nucleus from center
                     M(cc,6+dd)=0;% p2(j).Area; % area of nucleus
                     M(cc,7+dd)=0;% p2(j).Eccentricity; % area of nucleus
                     M(cc,8+dd)=0;% p2(j).MeanIntensity;
                     
                     M(cc,9+dd)= 1/sqrt((p2(j).Centroid(1)-p.Centroid(1))^2+(p2(j).Centroid(2)-p.Centroid(2))^2); % distance between nucleus and ref nucleus
                     M(cc,10+dd)= 0; % p2(j).Area - p.Area ;
                     M(cc,11+dd)= 0; % p2(j).Eccentricity - p.Eccentricity ;
                     M(cc,12+dd)= 0; % p2(j).MeanIntensity - p.MeanIntensity ;
                     M(cc,13+dd)= 0; % p2(j).MeanIntensity*p2(j).Area - p.MeanIntensity*p.Area ;
                 
                
               % M(cc,4+dd)=0;% 1/sqrt((p2(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p2(j).Centroid(2)-size(obj.gfp,1)/2)^2); % distance of tracked nucleus from center
               % M(cc,5+dd)= 1/sqrt((p2(j).Centroid(1)-p.Centroid(1))^2+(p2(j).Centroid(2)-p.Centroid(2))^2); % distance between nucleus and ref nucleus
               % M(cc,6+dd)= 0; % area of nucleus
               % M(cc,7+dd)= 0; % area of nucleus
               % M(cc,8+dd)= 0;
                
                dd=dd+9;
            end
            
            
            n3=obj.traintrack(:,:,3,i)>0; % selected object on frame n
            
            
            
            Y(cc)=round(mean(lab2(n3))); %output nucleus number of the nucleus evnetually selected by user
            %lab2(n3)
            fra(cc)=i;
            
            if i<fr(end)
                p=regionprops(n3,obj.gfp(:,:,i,obj.gfpchannel),'Area','Centroid','Eccentricity','MeanIntensity');
                cc=cc+1;
                
                
                M(cc,1)= 1/sqrt((p.Centroid(1)-size(obj.gfp,2)/2)^2+(p.Centroid(2)-size(obj.gfp,1)/2-5)^2); % distance of tracked nucleus from center
                M(cc,2)=0;% p.Area; % area of nucleus
                M(cc,3)=0;% p.Eccentricity; % area of nucleus
                M(cc,4)=0;% p.MeanIntensity;
                %M(cc,2)= 0; % area of nucleus
                %M(cc,3)= 0; % area of nucleus
                %M(cc,4)= 0;
            end
            
        end
        
    end
end

%pi=find(Y==3);
%test=M(pi,:);
%fra(pi)

Y=Y';

if sum(M(:))==0 % in case there was training in this trap
    M=[]; 
end
%tree = fitctree(M,Y'); % build classification tree;