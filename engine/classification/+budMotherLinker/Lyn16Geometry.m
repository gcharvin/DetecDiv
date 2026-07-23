classdef Lyn16Geometry < handle
    %LYN16GEOMETRY MATLAB implementation of the 16 published LYN descriptors.

    properties (SetAccess = private)
        Tracks
        NumFrames = 8
        ScaleLength
    end

    properties (Access = private)
        ContourCache
        CentreCache
        MajorAxisCache
    end

    methods
        function obj = Lyn16Geometry(tracks, numFrames)
            obj.Tracks = uint32(tracks);
            if nargin >= 2, obj.NumFrames = double(numFrames); end
            obj.ContourCache = containers.Map('KeyType','char','ValueType','any');
            obj.CentreCache = containers.Map('KeyType','char','ValueType','any');
            obj.MajorAxisCache = containers.Map('KeyType','char','ValueType','any');

            areas = [];
            for frame = 1:size(obj.Tracks,3)
                plane = obj.Tracks(:,:,frame);
                labels = unique(plane(:));
                labels = labels(labels > 0);
                for i = 1:numel(labels)
                    areas(end+1,1) = nnz(plane == labels(i)); %#ok<AGROW>
                end
            end
            if isempty(areas)
                error('budMotherLinker:EmptyTracks', ...
                    'Track stack contains no labelled cells.');
            end
            averageDiameter = 2 * sqrt(mean(areas) / pi);
            obj.ScaleLength = 45.32 / averageDiameter;
        end

        function tf = hasCell(obj, cellId, frame)
            tf = any(obj.Tracks(:,:,frame) == uint32(cellId), 'all');
        end

        function points = contour(obj, cellId, frame)
            key = obj.key(cellId, frame);
            if isKey(obj.ContourCache, key)
                points = obj.ContourCache(key);
                return;
            end
            mask = obj.Tracks(:,:,frame) == uint32(cellId);
            if ~any(mask, 'all')
                error('budMotherLinker:FeatureCellMissing', ...
                    'Cell %u is missing at frame %u.', cellId, frame);
            end
            boundaries = bwboundaries(mask, 8, 'noholes');
            if isempty(boundaries)
                error('budMotherLinker:InvalidContour', ...
                    'No contour for cell %u at frame %u.', cellId, frame);
            end
            areas = cellfun(@(b) abs(polyarea(b(:,2), b(:,1))), boundaries);
            [~, index] = max(areas);
            boundary = boundaries{index};
            if size(boundary,1) > 1 && isequal(boundary(1,:), boundary(end,:))
                boundary(end,:) = [];
            end
            if size(boundary,1) < 5
                error('budMotherLinker:InvalidContour', ...
                    'Contour for cell %u at frame %u has fewer than 5 points.', ...
                    cellId, frame);
            end
            points = double([boundary(:,2), boundary(:,1)]);
            obj.ContourCache(key) = points;
        end

        function centre = centre(obj, cellId, frame)
            key = obj.key(cellId, frame);
            if isKey(obj.CentreCache, key)
                centre = obj.CentreCache(key);
                return;
            end
            [rows, columns] = find(obj.Tracks(:,:,frame) == uint32(cellId));
            if isempty(rows)
                error('budMotherLinker:FeatureCellMissing', ...
                    'Cell %u is missing at frame %u.', cellId, frame);
            end
            centre = [mean(columns), mean(rows)];
            obj.CentreCache(key) = centre;
        end

        function axis = majorAxis(obj, cellId, frame)
            key = obj.key(cellId, frame);
            if isKey(obj.MajorAxisCache, key)
                axis = obj.MajorAxisCache(key);
                return;
            end
            axis = obj.fitEllipseMajorAxis(obj.contour(cellId, frame));
            obj.MajorAxisCache(key) = axis;
        end

        function [values, names] = featureVector(obj, budId, candidateId, frames)
            n = obj.NumFrames;
            budToPoint = zeros(n,1);
            expansion = zeros(n,1);
            position = zeros(n,1);
            orientation = zeros(n,1);
            distances = zeros(n,1);

            for i = 1:numel(frames)
                frame = frames(i);
                candidateMajor = obj.majorAxis(candidateId, frame);
                budMajor = obj.majorAxis(budId, frame);
                budPoint = obj.pairBudCmToBudPoint(budId, candidateId, frame);
                budCandidate = obj.pairCmToCm(budId, candidateId, frame);
                candidateToPoint = budPoint - budCandidate;
                budToPoint(i) = norm(budPoint);
                expansion(i) = norm(obj.expansionVector(budId, candidateId, frame));
                distances(i) = obj.pairDistance(budId, candidateId, frame);
                positionCos = abs(dot(candidateMajor, candidateToPoint)) / ...
                    max(norm(candidateMajor) * norm(candidateToPoint), eps);
                orientationCos = abs(dot(budMajor, candidateToPoint)) / ...
                    max(norm(budMajor) * norm(candidateToPoint), eps);
                position(i) = acos(min(1,max(0,positionCos)));
                orientation(i) = acos(min(1,max(0,orientationCos)));
            end

            count = numel(frames);
            slopeBudPoint = polyfit(double(frames(:)), budToPoint(1:count), 1);
            slopeExpansion = polyfit(double(frames(:)), expansion(1:count), 1);
            slopeOrientation = polyfit(double(frames(:)), orientation(1:count), 1);
            values = [ ...
                distances(1), std(distances,1), ...
                slopeBudPoint(1), slopeExpansion(1), ...
                std(position,1), max(position), min(position), ...
                position(count), position(1), ...
                std(orientation,1), max(orientation), min(orientation), ...
                orientation(count), orientation(1), ...
                abs(orientation(count) - orientation(1)), ...
                slopeOrientation(1)];
            names = { ...
                'dist_0','dist_std','poly_fit_budcm_budpt', ...
                'poly_fit_expansion_vector','position_bud_std', ...
                'position_bud_max','position_bud_min','position_bud_last', ...
                'position_bud_first','orientation_bud_std', ...
                'orientation_bud_max','orientation_bud_min', ...
                'orientation_bud_last','orientation_bud_first', ...
                'orientation_bud_last_minus_first','plyfit_orientation_bud'};
        end
    end

    methods (Access = private)
        function vector = pairCmToCm(obj, cellId1, cellId2, frame)
            vector = (obj.centre(cellId1, frame) - ...
                obj.centre(cellId2, frame)) * obj.ScaleLength;
        end

        function point = buddingPoint(obj, budId, parentId, frame)
            parent = obj.contour(parentId, frame);
            bud = obj.contour(budId, frame);
            distances = pdist2(parent, bud);
            if any(distances < 12, 'all')
                [parentRows, ~] = find(distances <= 12);
                point = mean(parent(parentRows,:), 1);
            else
                [~, index] = min(distances, [], 'all', 'linear');
                [parentIndex, ~] = ind2sub(size(distances), index);
                point = parent(parentIndex,:);
            end
        end

        function vector = pairBudPoint(obj, budId, candidateId, frame)
            vector = (obj.buddingPoint(budId, candidateId, frame) - ...
                obj.centre(candidateId, frame)) * obj.ScaleLength;
        end

        function vector = pairBudCmToBudPoint(obj, budId, candidateId, frame)
            % Preserve the argument order used by LYN-trace _get_features.
            vector = obj.pairCmToCm(candidateId, budId, frame) + ...
                obj.pairBudPoint(candidateId, budId, frame);
        end

        function distance = pairDistance(obj, cellId1, cellId2, frame)
            distances = pdist2(obj.contour(cellId1, frame), ...
                obj.contour(cellId2, frame));
            distance = min(distances, [], 'all') * obj.ScaleLength;
        end

        function vector = expansionVector(obj, budId, parentId, frame)
            bud = obj.contour(budId, frame);
            point = obj.buddingPoint(budId, parentId, frame);
            [~, index] = max(pdist2(point, bud));
            vector = bud(index,:) - point;
        end

        function axis = fitEllipseMajorAxis(~, points)
            % Port of OpenCV fitEllipseNoDirect (Daniel Weiss algorithm).
            points = double(points);
            if size(points,1) == 5
                axis = directEllipseAxis(points);
                return;
            end
            centre = mean(points,1);
            centred = points - centre;
            scale = 100 / max(sum(abs(centred),'all'), single(eps('single')));
            px = centred(:,1) * scale;
            py = centred(:,2) * scale;
            design = [-px.^2, -py.^2, -px.*py, px, py];
            coefficients = pinv(design) * repmat(10000,size(points,1),1);
            centreSystem = [ ...
                2*coefficients(1), coefficients(3); ...
                coefficients(3), 2*coefficients(2)];
            ellipseCentre = pinv(centreSystem) * coefficients(4:5);
            shiftedX = px - ellipseCentre(1);
            shiftedY = py - ellipseCentre(2);
            quadratic = [shiftedX.^2, shiftedY.^2, shiftedX.*shiftedY];
            coefficients = pinv(quadratic) * ones(size(points,1),1);
            angle = -0.5 * atan2(coefficients(3), ...
                coefficients(2) - coefficients(1));
            if abs(coefficients(3)) > 1e-8
                radiusTerm = coefficients(3) / sin(-2 * angle);
            else
                radiusTerm = coefficients(2) - coefficients(1);
            end
            widthRadius = sqrt(2 / abs( ...
                coefficients(1) + coefficients(2) - radiusTerm));
            heightRadius = sqrt(2 / abs( ...
                coefficients(1) + coefficients(2) + radiusTerm));
            if ~all(isfinite([angle,widthRadius,heightRadius]))
                error('budMotherLinker:InvalidEllipse', ...
                    'Unable to fit an ellipse to the cell contour.');
            end
            if widthRadius > heightRadius
                majorAngle = angle;
            else
                % OpenCV leaves box.angle at zero in this branch; LYN then
                % adds pi/2 when converting the returned minor-axis angle.
                majorAngle = pi / 2;
            end
            axis = [cos(majorAngle), sin(majorAngle)];
        end

        function value = key(~, cellId, frame)
            value = sprintf('%u_%u', uint32(cellId), uint32(frame));
        end
    end
end

function axis = directEllipseAxis(points)
points = points - mean(points,1);
x = points(:,1);
y = points(:,2);
quadratic = [x.^2, x.*y, y.^2];
linear = [x, y, ones(size(x))];
transform = -((linear' * linear) \ (quadratic' * linear)');
reduced = quadratic' * quadratic + quadratic' * linear * transform;
reduced = [reduced(3,:)/2; -reduced(2,:); reduced(1,:)/2];
[vectors, ~] = eig(reduced);
condition = 4 * vectors(1,:) .* vectors(3,:) - vectors(2,:).^2;
index = find(isfinite(condition) & condition > 0, 1);
if isempty(index)
    error('budMotherLinker:InvalidEllipse', ...
        'Unable to fit an ellipse to the cell contour.');
end
conic = vectors(:,index);
quadraticForm = [conic(1), conic(2)/2; conic(2)/2, conic(3)];
[directions, weights] = eig(quadraticForm, 'vector');
[~, major] = min(abs(weights));
axis = directions(:,major)';
end
