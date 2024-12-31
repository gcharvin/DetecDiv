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

    debug = false; % Flag for debugging polygon generation

    % Combine train and validation ROIs for processing
    all_rois = [trainrois, valrois];

    for i = 1:numel(all_rois)
        roi_id = all_rois(i);
        disp(['Processing ROI ' num2str(roi_id) '...']);

        cc = cltmp(roi_id).findChannelID(classif.strid);

        if numel(cc) > 0
            cltmp(roi_id).load;

            pix = cltmp(roi_id).findChannelID(channel);
            if iscell(pix)
                pix = cell2mat(pix);
            end

            im = cltmp(roi_id).image(:, :, pix, :);
            lab = cltmp(roi_id).image(:, :, cc, :);

            % Determine subdirectory based on ROI type (train or val)
            if ismember(roi_id, trainrois)
                img_subdir = 'train';
                label_subdir = 'train';
            else
                img_subdir = 'val';
                label_subdir = 'val';
            end

            for j = 1:size(im, 4) % Loop through time frames
                tmp = im(:, :, :, j);
                tmplab = lab(:, :, :, j);

                % Check if the annotation exists
                if max(tmplab(:)) <= 1
                    disp(['Skipping frame ' num2str(j) ' for ROI ' cltmp(roi_id).id ' - no annotations found.']);
                    continue;
                end

                % Save image as uint8 to ensure compatibility with imwrite
                tr = sprintf('%04d', j);
                img_path = [classif.path '/' foldername '/images/' img_subdir '/' cltmp(roi_id).id '_frame_' tr '.jpg'];
                tmp_uint8 = uint8(255 * mat2gray(tmp)); % Scale and convert to uint8
                imwrite(tmp_uint8, img_path);

                % Generate YOLO annotations with instance segmentation masks
                label_path = [classif.path '/' foldername '/labels/' label_subdir '/' cltmp(roi_id).id '_frame_' tr '.txt'];
                fid = fopen(label_path, 'w');

                for k = 1:numel(classif.classes)
                    % Skip the background class (defaultclass)
                    if k == defaultclass
                        continue;
                    end

                    pixz = tmplab == k;

                    if ~any(pixz(:))
                        % Ensure every class is represented, even if empty
                        continue;
                    end

                    % Extract boundary points of the mask
                    boundaries = bwboundaries(pixz);

                    for b = 1:length(boundaries)
                        boundary = boundaries{b};

                        % Simplify polygon to 64 points max
                        if size(boundary, 1) > 64
                            boundary = boundary(round(linspace(1, size(boundary, 1), 64)), :);
                        end

                        % Normalize pixel coordinates
                        normalized_coords = [boundary(:, 2) / size(tmp, 2), boundary(:, 1) / size(tmp, 1)];
                        coords = reshape(normalized_coords', 1, []); % Flatten coordinates

                        % Write class and coordinates to file
                        fprintf(fid, '%d %s\n', k - 1, sprintf('%.6f ', coords));

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
        fprintf(fid, '  %d: %s\n', k - 1, classif.classes{k});
    end
    fclose(fid);
end
