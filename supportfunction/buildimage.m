function im=buildimage(obj)

% outputs a structure containing all displayed images
im=[];
im.data=[];

frame=obj.display.frame;

if numel(obj.image)==0
    disp('Warning : image is no longer present. Try reloading ...');
    obj.load
end

if frame>size(obj.image,4)
    frame=size(obj.image,4);
    obj.display.frame=frame;
end
if frame<1
    frame=1;
    obj.display.frame=1;
end


cc=1;
for i=1:numel(obj.display.channel)

    pix=find(obj.channelid==i); % find matrix index associated with channel
    %   pix=pix(1); % there may be several items in case of a   multi-array channel

    if obj.display.selectedchannel(i)==1
        %    if obj.display.selectedchannel(pix)==1
        % get the righ data: there may be several matrices for one single
        % channel in case of RGB images

        pix=find(obj.channelid==i);

        imtemp=obj.image(:,:,pix,frame);

        % WARNING PIX MAY BE A 1 or  3 element vector
       
        % added display lim to take care of displaying images ; stretchlim
        % applies to preprocessing only
                 if (~isfield(obj.display,'displaylim') && ~isprop(obj.display,'displaylim')) || numel(obj.display.displaylim)~=2*numel(obj.channelid)
            disp(['No display limits found for ROI ' num2str(obj.id) ', computing them...']);
            
            obj.computeDisplaylim;
         end

    %     if (~isfield(obj.display,'displaylim') && ~isprop(obj.display,'displaylim')) || size(obj.display.displaylim,2)~=numel(obj.channelid) || size(obj.display.displaylim,1)~=2
      %      disp(['No display limits found for ROI ' num2str(obj.id) ', computing them...']);
     %       obj.computeDisplaylim;
     %    end

%         if (~isfield(obj.display,'stretchlim') && ~isprop(obj.display,'stretchlim')) || size(obj.display.stretchlim,2)~=numel(obj.channelid)
%             disp(['No stretch limits found for ROI ' num2str(obj.id) ', computing them...']);
%             obj.computeStretchlim;
%         end


        strchlm=obj.display.displaylim(:,(pix(end)-pix(1))/2 + pix(1));
        
        %middle stack
        
        %strchlm=stretchlim(imtemp(:,:,(end-1)/2 + 1),[0.005 0.995]);
        %strchlm=stretchlim(imtemp(:,:,ceil((end+1)/2))); % computes the strecthlim for the middle stack. To be changed once we add multichannels as inputs.

        it=mean(obj.display.intensity(i,:)); % indexed images has intensity levels to 0

        if it~=0 || numel(pix)==3

            if strchlm(1)==0 && strchlm(2)==0
                strchlm(2)=1;
            end

            imtemp=imadjust(imtemp,strchlm);

        end
        imout=imtemp;

           if numel(pix)==1 & obj.display.intensity(i,1)==1 % grayscale image but with rgb output request
             imtemp =repmat(imtemp,[1 1 3]);
              for j=1:size(imtemp,3)
                

                imout(:,:,j)=imtemp(:,:,j).*obj.display.rgb(i,j);
            end
          end

%         if numel(pix)==3
%             for j=1:size(imtemp,3)
%                 %   i,j,pix(j)
%                 %  tmp=src(:,:,pix(j),:);
%                 %  meangfp=0.5*double(mean(tmp(:)));
%                 % it=obj.display.intensity(i,j);
%                 %                         maxgfp=double(meangfp+it*(max(tmp(:))-meangfp));
%                 %                         if maxgfp==0
%                 %                             maxgfp=1;
%                 %                         end
% 
%                 %size(imtemp)
% 
%                 % if meangfp>0 && maxgfp>0
%                 %    imtemp = imadjust(imtemp,[meangfp/65535 maxgfp/65535],[0 1]);
%                 %end
% 
%                 imout(:,:,j)=imtemp(:,:,j).*obj.display.rgb(i,j);
%             end
%         end

        %         end
        im(cc).data=imout;
        cc=cc+1;
    end
end
%   cc=cc+1;
end