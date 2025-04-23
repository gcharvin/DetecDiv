function output = formatPixelTrainingSetYOLO(foldername, classif, trainrois, valrois)
% Formats training set for YOLOv8/YOLOv11 instance segmentation.

output = 0;

% Create necessary directories for images and labels
mkdir([classif.path '/' foldername], 'images/train');
mkdir([classif.path '/' foldername], 'images/val');
mkdir([classif.path '/' foldername], 'labels/train');
mkdir([classif.path '/' foldername], 'labels/val');

defaultclass = 1; % Default class for unassigned pixels
cltmp = classif.roi;
warning off all

channel = classif.channelName;

debug =false; % false; % Flag for debugging polygon generation

% Combine train and validation ROIs for processing
all_rois = [trainrois, valrois];

for i = 1:numel(all_rois)
    roi_id = all_rois(i);
    disp(['Processing ROI ' num2str(roi_id) '...']);

    cltmp(roi_id).load;

    im = cltmp(roi_id).image;
    %  lab = cltmp(roi_id).image(:, :, cc, :);

    pix = cltmp(roi_id).findChannelID(channel);
    if iscell(pix)
        pix = cell2mat(pix);
    end

    for j = 1:size(im, 4) % Loop through time frames

        masklist=false(size(im,1),size(im,2),0);
        vlist=[];

        cm=1;
        for k = 1:numel(classif.classes)

            cc = cltmp(roi_id).findChannelID([classif.strid '_' classif.classes{k}]);

            if numel(cc) > 0
                lab = cltmp(roi_id).image(:, :, cc, j);
                mlab=max(lab(:));
                if  mlab>=1 % image is annotated

                    for kk=1:mlab % here change value 

                        pixz = lab == kk;

                        if any(pixz(:))
                            masklist(:,:,end+1)=pixz;
                            vlist(end+1)=k;
                            cm=cm+1;
                        end
                    end
                end
            end
        end

       if numel(vlist) % annotated data were found
        if ismember(roi_id, trainrois)
            img_subdir = 'train';
            label_subdir = 'train';
        else
            img_subdir = 'val';
            label_subdir = 'val';
        end

        %   for j = 1:size(im, 4) % Loop through time frames
        %  tmp = im(:, :, :, j);
        %  tmplab = lab(:, :, :, j);

        tr = sprintf('%04d', j);
        base = fullfile(classif.path, foldername);
        dirs = { fullfile(base,'images','train'), fullfile(base,'images','val'), fullfile(base,'labels','train'), fullfile(base,'labels','val') };
        for d = dirs, if ~exist(d{1},'dir'), mkdir(d{1}); end, end

        img_path   = fullfile(base, 'images', img_subdir, [cltmp(roi_id).id '_frame_' tr '.jpg']);
        label_path = fullfile(base, 'labels', label_subdir, [cltmp(roi_id).id '_frame_' tr '.txt']);

        tmp_uint8 = uint8(255 * mat2gray(im(:,:,pix,j))); % Scale and convert to uint8
        imwrite(tmp_uint8, img_path);

        %  label_path = [classif.path '/' foldername '/labels/' label_subdir '/' cltmp(roi_id).id '_frame_' tr '.txt'];
        fid = fopen(label_path, 'w');

        for kk=1:size(masklist,3)

            boundaries = bwboundaries(masklist(:,:,kk));

            for b = 1:length(boundaries)
                boundary = boundaries{b};

                % Simplify polygon to 64 points max
                if size(boundary, 1) > 64
                    boundary = boundary(round(linspace(1, size(boundary, 1), 64)), :);
                end

                % Normalize pixel coordinates
                normalized_coords = [boundary(:, 2) / size(im, 2), boundary(:, 1) / size(im, 1)];
                coords = reshape(normalized_coords', 1, []); % Flatten coordinates

                % Write class and coordinates to file
                fprintf(fid, '%d %s\n', vlist(kk)-1, sprintf('%.6f ', coords)); % python yolo cclasses start with 0 !

                % Debug: visualize the polygon
                if debug
                    figure;
                    imshow(tmp_uint8, []);
                    hold on;
                    plot(boundary(:, 2), boundary(:, 1), '-r', 'LineWidth', 2);
                    title(['Class ' num2str(k) ' Polygon for Frame ' num2str(j)]);
                    hold off;
                end
            end
        end

        fclose(fid);
        output = output + 1;
       end
    end
end

warning on all;
for i = all_rois
    cltmp(i).clear;
end

% Save dataset configuration file
yaml_path = [classif.path '/' foldername '/dataset.yaml'];
fid = fopen(yaml_path, 'w');
fprintf(fid, 'path: %s\n', [classif.path '/' foldername]);
fprintf(fid, 'train: images/train\n');
fprintf(fid, 'val: images/val\n');
fprintf(fid, 'names:\n');

for k = 1:numel(classif.classes)
    fprintf(fid, '  %d: %s\n', k-1 , classif.classes{k});
end
fclose(fid);
end
