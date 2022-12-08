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
        [project.fov(i).roi(j).results.cytometry.volume, project.fov(i).roi(j).results.cytometry.surface]=volumeApprox(frames);
    end
    fprintf('\n');
end

function [volume surface]=volumeApprox(frames)


volume=[];
surface=[];

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
    else
    volume(i)=nan;
    surface(i)=nan; 
    end
end

