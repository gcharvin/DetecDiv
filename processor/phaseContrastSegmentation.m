function paramout=phaseContrastSegmentation(param,roiobj,frames)

 listChannels=unique(listAvailableChannels);

 % initialize parameter structure
if nargin==0
    paramout=[];
    
    tip={'Select the channel name to be used as input','Enter the name of the output channel'};

    paramout.input_channel=[listChannels listChannels{end}];
    paramout.output_channel_name='pc_segment';
    
    paramout.tip=tip;
  
    return;
else
paramout=param; 
end

obj=roiobj; 


if numel(obj.image)==0
obj.load; 
end

% manage input / output image channels
pixresults=findChannelID(obj, paramout.input_channel{end});
 
pixoutput=findChannelID(obj,  paramout.output_channel_name);

if numel(pixoutput)>0
obj.image(:,:,pixoutput,frames)=uint16(zeros(size(obj.image,1),size(obj.image,2),1,numel(frames)));
else
   % add channel is necessary 
   matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   rgb=[1 1 1];
   intensity=[0 0 0]; %indexed image
   pixoutput=size(obj.image,3)+1;
   obj.addChannel(matrix,paramout.output_channel_name,rgb,intensity);
end



for i=frames
img= obj.image(:,:,pixresults,i);

BW=uint16(segment(img)); % the '2' factor is just to assign to the second class in case of piel training 

obj.image(:,:,pixoutput,i)=BW;
end


function newlabels2=segment(img)

img2=img;
img = rangefilt(img); 
T = adaptthresh(uint16(img2),0.05);
BW2=imbinarize(uint16(img2),T);
     BW=edge(img,'canny');    
 
BW2 = bwareaopen(BW2, 10);

BW = bwareaopen(BW, 10);
imdist=bwdist(BW2);
imdist = imclose(imdist, strel('disk',2));
imdist = imhmax(imdist,2);

sous=BW2- imdist;

labels = double(watershed(sous,8)).* ~BW2;% .* BW % .* param.mask; % watershed
warning off all
tmp = imopen(labels > 0, strel('disk', 4));
warning on all
tmp = bwareaopen(tmp, 50);


newlabels = labels .* tmp; % remove small features
newlabels = bwlabel(newlabels>0);

l=regionprops(newlabels,"Area","Circularity");

newlabels2=zeros(size(newlabels));

cc=1;
for i=1:numel(l)
if l(i).Area<5000 && l(i).Circularity>0.6
 bw=newlabels==i;
 newlabels2(bw)=cc;

%  figure,imshow(bw,[]);
%  pause
%  close

 cc=cc+1;
else
%'discarded contour'
end

end


%newlabels2 = bwlabel(newlabels2>0);


