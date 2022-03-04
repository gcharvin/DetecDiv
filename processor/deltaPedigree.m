function paramout=deltaPedigree(param,obj,frames)

% implements the pedigree method inspired  lugagne paper Delta 2.0 
% procedure 
% setup processor paramters : "add processor..." 
% training : 

% 1) requires a ground truth dataset with tracked cells + mother array that specifies parentage to serve as
% groundturth (labeled images + rwa brightfield image)

% 2) set up a new delta pedigree  classifier  and train it using the ground
% truth data

% 3) run the delta pedrigree tracking routine 


if nargin==0
    paramout=[];
    
    paramout.raw_channel_name='ch1--'; % raw images
    paramout.seg_channel_name='track_segcell_1'; % tracked data
    paramout.output_channel_name='pedigree_delta_4'; % output channel 
    
  %  paramout.frames='0';
    paramout.classifier_name='pedigree_delta_4';
    paramout.imagesize=151; 
    
    return;
else
paramout=param; 
end


% channelstr: segmented objects channel
% input image channel 

display=0;

imagesize=param.imagesize;

channelID=obj.findChannelID(param.seg_channel_name);

if numel(channelID)==0 % this channel contains the segmented objects
   disp([' This channel ' param.seg_channel_name ' does not exist ! Quitting ...']) ;
   return;
end

inputchannelID=obj.findChannelID(paramout.raw_channel_name);

if numel(inputchannelID)==0 % this channel contains the raw images used to segment objects or to characterize the object
   disp([' This channel ' paramout.raw_channel_name ' does not exist ! Quitting ...']) ;
   return;
end

if numel(obj.image)==0
    obj.load
end

if numel(obj.image)==0
  disp('Could not load images, check your network connection ... quitting !') ;
  return;
end

im=obj.image(:,:,channelID,:);
%im=im>0; % binarize cell contours

rawim=obj.image(:,:,inputchannelID,:);

totphc=rawim;
meanphc=0.5*double(mean(totphc(:)));
maxphc=double(meanphc+0.5*(max(totphc(:))-meanphc));


if frames==0
    frames=1:size(im,4);
else
    frames=frames;
end


    disp('Loading classifier....')
    
    varlist=evalin('base','who');

    ok=0;
   for i=1:numel(varlist)
                if strcmp(varlist{i},param.classifier_name)
                   ok=1;
                    break
                end
   end
    
   if ok==1
         classifier=evalin('base',param.classifier_name);
    else
        disp('This classifer is not in the workspace. Please load the classifier using the load method applied to the relevant @classi')
    end
    
%creates an output channel to update results
pixresults=findChannelID(obj,param.output_channel_name);

if numel(pixresults)>0
obj.image(:,:,pixresults,:)=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
   % add channel is necessary 
   matrix=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   rgb=[1 1 1];
   intensity=[0 0 0];
   pixresults=size(obj.image,3)+1;
   obj.addChannel(matrix,param.output_channel_name,rgb,intensity);
end

    memory=zeros(1,max(im(:))); % array stores the memory of budding times for all cells 
    obj.results.(paramout.classifier_name)=[];
    obj.results.(paramout.classifier_name).mother=zeros(1,max(im(:)));
    mothers=obj.results.(paramout.classifier_name).mother;
    
% loop on frames
for j=frames(1)+1:frames(end)-1 % loop on all frames
    
    disp([ 'Processing frame ' num2str(j) '; Last frame ' num2str(frames(end))]); 
   
      % fprintf('.')
        tmp1=rawim(:,:,1,j-1);
        tmp2=rawim(:,:,1,j);
        tmp3=rawim(:,:,1,j+1);
        
        label1=im(:,:,1,j-1);
        label2=im(:,:,1,j);
        
        % get new born cells 
        n1=unique(label1(:)); n1=n1(n1>0);
        n2=unique(label2(:)); n2=n2(n2>0);
        newcells=setdiff(n2,n1);
        memory(newcells)=0; % assign zero history for new cells
     
        
        if sum(label2(:))==0
            disp(['No annotation for frame: ' num2str(j+1)]);
            continue
        end
        
        %figure, imshow(tmp1,[]);
        %figure, imshow(tmp2,[]);
        %return;
        % if numel(pix)==1
            
            tmp1 = double(imadjust(tmp1,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp1=uint8(256*tmp1);
            tmp2 = double(imadjust(tmp2,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp2=uint8(256*tmp2);
            tmp3 = double(imadjust(tmp3,[meanphc/65535 maxphc/65535],[0 1]))/65535;
            tmp3=uint8(256*tmp3);
            %tmp=repmat(tmp,[1 1 3]);
        % end

        if max(label1(:))==0 % image is not annotated
             disp(['No annotation for frame: ' num2str(j+1)]);
            continue
        end

        for k=newcells' % loop on all new buds
            
            
         %   figure, imshow(label2,[]),k
            bw1=label2==k;
            
            if numel(bw1)==0 % this cell number is not present
                disp('This cell is not present');
                continue
            end
            
            if k>length(mothers)
                disp('This new bud is not present');
               continue 
            end
            
          %  if mothers(k)==0 % not assigned
          %      continue
          %  end
            
            stat1=regionprops(bw1,'Centroid');
            
            if numel(stat1)==0
                    disp('found object with no centroid; skipping....');
                continue
            end
            
            % reference of the image
          %  imagesize
            minex=uint16(max(1,round(stat1.Centroid(1))-imagesize/2));
            miney=uint16(max(1,round(stat1.Centroid(2))-imagesize/2));
            
            maxex=uint16(min(size(tmp1,2),round(stat1.Centroid(1))+imagesize/2-1));
            maxey=uint16(min(size(tmp1,1),round(stat1.Centroid(2))+imagesize/2-1));
            
           % maxey-miney+1,maxex-minex+1
            
            tmpcrop=uint8(zeros(maxey-miney+1,maxex-minex+1,5));
            
            tmpcrop(:,:,1)=tmp1(miney:maxey,minex:maxex);
            tmpcrop(:,:,2)=tmp2(miney:maxey,minex:maxex);
            tmpcrop(:,:,3)=tmp3(miney:maxey,minex:maxex);
            
            tmpcrop(:,:,4)=255*uint8(bw1(miney:maxey,minex:maxex));
           
            l= label2;
            l(bw1)=0;  % removes bud from list; 
            l=l(miney:maxey,minex:maxex);
            lmemory=double(l);
      
            for cc=1:max(l(:))
                b=l==cc;
                
                  if cc>numel(memory)
                    memory(cc)=0;
                  end
                
                lmemory(b)=(memory(cc)+1)./(memory(cc)+1+6); % memory saturates within 6 frames
            end
                
            tmpcrop(:,:,5)=uint8(255*lmemory);
            
             tmpcrop=imresize(tmpcrop,classifier.Layers(1).InputSize(1:2));
             [C,score,features]= semanticseg(tmpcrop, classifier);
             
             BW=features(:,:,2)>0.9;
             
             if sum(BW(:))>0
             si=  [maxey-miney+1,maxex-minex+1];
             BW=double(imresize(BW,si));
             
             ce=unique(l(:)); ce=ce(ce>0); ce=ce';
             
             freq=zeros(1,numel(ce));
             
             cc=1;
             for kk=ce
                 tmp=l==kk;
                 
                 freq(cc)=mean(BW(tmp));
                 cc=cc+1;
             end
             
            if k==124
                ce,freq
            end
            
             [m ix]=max(freq);
             
             val=ce(ix);
             
%              if k==110
%                  val
%              end
          %   size(l),size(BW)
          %  figure, imshow(BW,[])
         %   figure, imshow(l,[])
         
           % return;
          %   val=round(mean(l(BW)));
             
             if val>0
              
              mothers(k)=val;
           %   aa=mothers(k
              
              memory(val)=0;
             end
             end
         
        end
        
        %  if numel(newmothers)
           memory=memory+1;
         % end
end
        
%aa=mothers(107)
obj.results.(paramout.classifier_name).mother=mothers;
        
       % msg = sprintf('Processing frame: %d / %d for ROI %s', j, size(im,4),cltmp(i).id); %Don't forget this semicolon
      %  fprintf([reverseStr, msg]);
     %   reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
fprintf('\n');

disp('Pedigree done !');


