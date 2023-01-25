function computeVolume(project,channelMaskName)

for i=1:numel(project.fov) % loop on all FOVs
    for j=1:numel(project.fov(i).roi)  % loop on all ROIs
        fprintf('.');
        % load images if necessary
        im= project.fov(i).roi(j).image;
        if numel(im)==0
            project.fov(i).roi(j).load;
        end

       
        channel= project.fov(i).roi(j).findChannelID(channelMaskName); % retrieves channel number

        if numel(channel)==0
            fprintf('could not find channel in ROI')
            return;
        end
        frames= project.fov(i).roi(j).image(:,:,channel,:); % gets all frames
        frames= frames==2; % converts into a binary mask with cell of interest only ( pixel label=2 for that cell). 
        project.fov(i).roi(j).results.cytometry=[];
        [a0,b0,c0,d0,e0]=volumeApprox(frames);
        project.fov(i).roi(j).results.cytometry.volume=a0;
        project.fov(i).roi(j).results.cytometry.surface=b0;
        project.fov(i).roi(j).results.cytometry.surface_mask=c0;
        project.fov(i).roi(j).results.cytometry.length=d0;
        project.fov(i).roi(j).results.cytometry.width=e0;
    end
    fprintf('\n');
end

function [volume,surface,surface_mask,len,wid]=volumeApprox(frames)


volume=[];
surface=[];
surface_mask=[];
len=[];
wid=[];

for i=1:size(frames,4)
    bw=frames(:,:,1,i);
    stats=regionprops(bw,'Area','MajorAxisLength','MinorAxisLength');
    if numel(stats)
        def=1;

        if numel(stats)>1 % if several objects are found, take the biggest one
            [t,def]=max([stats(:).Area]);
        end

    r=stats(def).MinorAxisLength;
    h=stats(def).MajorAxisLength -r;

    volume(i)= 4*pi*r^3/3 + pi*r^2*h;
    surface(i)= 4*pi*r^2 + 2*pi*r*h; 
    surface_mask(i)=stats(def).Area;
    wid(i)=stats(def).MinorAxisLength;
    len(i)=stats(def).MajorAxisLength;
    else
    volume(i)=nan;
    surface(i)=nan; 
    surface_mask(i)=nan;
    wid(i)=nan;
    len(i)=nan; 
    end
end

