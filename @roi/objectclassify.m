function objectclassify(obj)

% identifies nucleus of interest in the field over time using
% classification

%if nargin==2
% single frame to be classifed using exisiting training set
%    frames=obj.frame;
%else
% all frames to be classifed

if numel(obj.gfp)==0
              obj.load;
end

frames=1:size(obj.traintrack,4);
%end

if numel(obj.objtree)~=0
 tree=obj.objtree;  
  
else
 [M,Y]=collectObjectTrapData(obj);
 %M(1:10,:)
 tree = fitctree(M,Y);
 
 %aaa=tree.X
 imp = 1000*predictorImportance(tree)
end

% now make predictions for other frames : loop on all frames.
% must do a frame by frame analysis because input will change depending on
% the output of the previous frame

M=[]; % observations
nucleus=0;
ce=1;

reverseStr='';
for i=frames %122:123 %frames %263:264
    
    % first check that there is a nucleus on corresponding frame
    n2=obj.traintrack(:,:,2,i)>0;
    ma=max(n2(:));
    
  %  ma,nucleus
    
    if ma==0
      
        nucleus=0; % no nucleus found
        obj.track(:,:,i)=uint8(zeros(size(obj.track,1),size(obj.track,2)));
        
        continue
    else
        if nucleus==0 % first frame
            %i
            nucleus=1;
            % cc=1; % frame counter
            M=zeros(1,49); % input 4 + 9 x 5 columns
            % check if first frame is part of training set

            nref=obj.traintrack(:,:,3,i)>0; % trained object on first frame
            ma=max(nref(:));
            
            if ma==0 % no training on that frame, therefore choose cell in the center as a reference
                n=bwlabel(obj.traintrack(:,:,2,i)>0,4);
                p=regionprops(n,'Centroid');
                d=[];
                for j=1:numel(p)
                    d(j)=sqrt((p(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p(j).Centroid(2)-size(obj.gfp,1)/2)^2);
                end
                
                [dmin ix]=min(d);
                nc=n==ix;
                
              %  figure, imshow(nc,[]);
                
                obj.track(:,:,i)=nc;
            else
                obj.track(:,:,i)=obj.traintrack(:,:,3,i)>0; % choose the cell identified by training as a reference
            end
            
            p=regionprops(obj.track(:,:,i),obj.gfp(:,:,i,obj.gfpchannel),'Area','Centroid','Eccentricity','MeanIntensity');
            
            M(1)=1/sqrt((p.Centroid(1)-size(obj.gfp,2)/2)^2+(p.Centroid(2)-size(obj.gfp,1)/2)^2); % distance of tracked nucleus from center
            M(2)= p.Area; % area of nucleus
            M(3)= p.Eccentricity; % area of nucleus
            M(4)= p.MeanIntensity;
            
           % M
            %M(2)= 0; % area of nucleus
            %M(3)= 0; % area of nucleus
            %M(4)= 0;
            %M
            % find first nucleus
           % 'ok'
           % pause
        else  % continue track
          %  i
          
        %  M
        %  pause
          
            nref=obj.traintrack(:,:,3,i)>0; % trained object on first frame
            ma=max(nref(:));
            
            if ma==0 % no training on that frame, so go ahead and list existing nuclei
                
                n2=obj.traintrack(:,:,2,i)>0;
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
                         bw=lab2==ix(kk); % no sorting
                         tmp(bw)=kk;
                      end
            
                     %n2=tmp;
                     lab2=tmp;
                     
                     %figure, imshow(lab2,[]);
                     
                     p2=regionprops(lab2,obj.gfp(:,:,i,obj.gfpchannel),'Area','Centroid','Eccentricity','MeanIntensity');
                
                dd=0;
               % M
                
                for j=1:numel(p2)
                    % i,j,p2(j)
                    %dds=sqrt((p2(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p2(j).Centroid(2)-size(obj.gfp,1)/2)^2)
                    %pause
                    % close
                     M(5+dd)=  1/sqrt((p2(j).Centroid(1)-size(obj.gfp,2)/2)^2+(p2(j).Centroid(2)-size(obj.gfp,1)/2)^2); % distance of tracked nucleus from center
                     M(6+dd)=0;% p2(j).Area; % area of nucleus
                     M(7+dd)=0;% p2(j).Eccentricity; % area of nucleus
                     M(8+dd)=0;% p2(j).MeanIntensity;
                     
                     M(9+dd)= 1/sqrt((p2(j).Centroid(1)-p.Centroid(1))^2+(p2(j).Centroid(2)-p.Centroid(2))^2); % distance between nucleus and ref nucleus
                     M(10+dd)= 0;%( p2(j).Area - p.Area );
                     M(11+dd)= 0;%( p2(j).Eccentricity - p.Eccentricity );
                     M(12+dd)= 0;%( p2(j).MeanIntensity - p.MeanIntensity );
                     M(13+dd)= 0;%( p2(j).MeanIntensity*p2(j).Area - p.MeanIntensity*p.Area );
                     
                  %   M(6+dd)= 0; % area of nucleus
                  %  M(7+dd)= 0; % area of nucleus
                  %  M(8+dd)= 0;
                    dd=dd+9;
                    
                    %M
                end

               % M
               % i
               % M
               
                Y=round(predict(tree,M)); % round should ot be necessary, but was added because Y sometimes takes non integer values ! 
                
                %max(lab2(:))
                nc=lab2==Y;
                obj.track(:,:,i)=nc;
                
               % figure, imshow(lab2,[]);
                
                % now init M matrix for next frame
                
                
            else % use training data as reference nucleus
                obj.track(:,:,i)=obj.traintrack(:,:,3,i)>0;
            end
            
           
            p=regionprops(obj.track(:,:,i),obj.gfp(:,:,i,obj.gfpchannel),'Area','Centroid','Eccentricity','MeanIntensity');
            %size(p)
            
            if numel(p)==0
               
             % M, Y, i,p
              % classifer made a wrong prediction % track is lost
              nucleus=0;
               % figure, imshow(obj.track(:,:,i),[]);
                %return;
                
                continue
            end
            
            M=zeros(1,49); % input 4 + 5 x 5 columns
            M(1)= 1/sqrt((p.Centroid(1)-size(obj.gfp,2)/2)^2+(p.Centroid(2)-size(obj.gfp,1)/2)^2); % distance of tracked nucleus from center
            M(2)= 0;%p.Area; % area of nucleus
            M(3)= 0;%p.Eccentricity; % area of nucleus
            M(4)= 0;%p.MeanIntensity;
           % end
            
           %  M(2)= 0; % area of nucleus
           % M(3)= 0; % area of nucleus
           % M(4)= 0;
            
            
           
                 
        end  
    end
    
   % i
%     if i==191
%         'ok'
%        figure, imshow( obj.traintrack(:,:,1,i),[]);
%     end
    obj.traintrack(:,:,1,i)=255*obj.track(:,:,i);
    
    if mod(ce-1,50)==0
     msg = sprintf('%d / %d Frames classified', ce , numel(frames) ); %Don't forget this semicolon
     msg=[msg ' for trap ' obj.id];
     
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
     
    ce=ce+1;
end

fprintf('\n');

obj.computefluo; % compute fluorescence value within nucleus




