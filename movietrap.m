function movietrap(mov,movid,trapsid,varargin)

% plots all movies associated with traps
% mov : array that contains all movies to be plotted
% movid / trapid : pairs of integers that refers to the movie/traps to be
% plotted. EG: if one wants to plots traps 1 , 3 , 4 or movie 1 and 5 6 7
% of movie 3, then enters movid=[1 1 1 2 2 2], [1 3 4 5 6 7]

% option : size (pixels) of each movie 
st=[];
st.im=[];



frames= 1:size(mov(1).trap(1).gfp, 3);

siz=100;
for i=1:numel(varargin)
    
    if strcmp(varargin{i},'fluo')
        
    end

    if strcmp(varargin{i},'frames')
        frames=varargin{i+1};
    end
    
     if strcmp(varargin{i},'size')
         siz=varargin{i+1};
     end
    
%     if strcmp(varargin{i},'plot')
%         vartoplot=
%     end
end

cc=1;

for i=trapsid
    
    [rgb fr]=mov(movid(cc)).trap(i).export(mov.trap(i),'frames',frames,'size',siz);
    
    if cc==1
        w=size(fr(1).cdata,1);
        h=size(fr(1).cdata,2);
        nf=length(fr);
        ma=uint8(zeros(w,h,3,nf));
    end
    
   for j=1:length(fr)
       ma(:,:,:,j)=fr(j).cdata;
   end
   st(cc).im=ma;
   cc=cc+1;
end

nmov=length(trapsid);

nsize=[1 1; 1 2; 1 3; 2 2; 2 3; 2 3; 3 3; 3 3; 3 3];

if nmov>9
   nsize=floor(sqrt(nmov-1))+1; 
   nsize=[nsize nsize];
else
   nsize=nsize(nmov,:); 
end

rgb=uint8(zeros(nsize(1)*w,nsize(2)*h,3,nf));

cc=1;
for i=1:nsize(1)
    for j=1:nsize(2)
        
        if cc<= length(trapsid)
        rgb((i-1)*w+1:i*w,(j-1)*h+1:j*h,:,:)= st(cc).im;
        end
        
        cc=cc+1;
        

        
    end
end

v=VideoWriter([mov.filename '-' num2str(trapsid) '.mp4'],'MPEG-4');

v.FrameRate=30;
open(v);

writeVideo(v,rgb);

close(v);



