function viewtraps(obj,frame)

if nargin==1
    frame=1;
end

img1=readImage(obj,1,obj.PhaseChannel);

if numel(img1)==0
    fprintf('Cannot load images.... quit !\n');
    return
end

%img1=imresize(img1,0.5);

figure, imshow(img1,[]); hold on

for i=1:numel(obj.trap)
    roi=obj.trap(i).roi;
    
  % line( [roi(3) roi(3) roi(4) roi(4) roi(3)],[roi(1) roi(2) roi(2) roi(1) roi(1)],'Color','r','lineWidth',2);
   
   h(i)=patch([roi(3) roi(3) roi(4) roi(4) roi(3)],[roi(1) roi(2) roi(2) roi(1) roi(1)],[1 0 0],'FaceAlpha',0.3);
   
   h(i).ButtonDownFcn={@vie,obj,i};
   
   text( roi(3)+10, roi(1)+10, num2str(i),'Color','r');
end

title(['frame: ' num2str(frame)]);

function vie(handle, event, obj,arg)

obj.trap(arg).view




