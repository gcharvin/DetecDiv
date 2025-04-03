function roiOverlay=score_computePanels(obj, param,layout)

%% --- CONSTRUCTION DE roiOverlay POUR CHAQUE ROI ---
numROI = numel(obj);
roiOverlay = repmat(struct('baseImage', [], 'vectorText', [], 'vectorContours', []), 1, numROI);
channel=param.channel;
crop=param.crop;
scalingFactor=param.scalingFactor;
imageSize=param.imageSize;
overlayMode=param.overlayMode;
flip=param.flip;
frames=param.frames;
snapRate=param.snapRate;
levels=param.levels;
rgb=param.rgb;
weights=param.weights;
paintChannel=param.paintChannel;
defaultClass=param.defaultClass;

for cc = 1:numROI
    roitmp = obj(cc);
    if isempty(roitmp.image), roitmp.load; end
    disp(['ROI ' roitmp.id ' is loaded']);

    % Recalculer les indices de canaux pour cette ROI
    currentCha = cell(1, numel(channel));
    for j = 1:numel(channel)
        if iscell(channel)
            currentCha{j} = roitmp.findChannelID(channel{j});
        else
            pix = find(roitmp.channelid == channel(j));
            currentCha{j} = pix;
        end
    end

    % preprocess images 
    imtmp = roitmp.image(:,:,:,frames);
    if ~isempty(crop)
        for c = 1:size(imtmp,3)
            for f = 1:size(imtmp,4)
                imtmptp(:,:,c,f) = imcrop(imtmp(:,:,c,f), crop);
            end
        end
        imtmp = imtmptp;
    end

    if scalingFactor~=1
    imtmp = imresize(imtmp, scalingFactor, 'nearest');
    end

    if ~isempty(imageSize)
        imtmp = imresize(imtmp, imageSize);
    end

     if flip==1
         imtmp = flip(imtmp,1); 
     end

    numFrames = numel(layout.frames);
    compositeFrames = zeros(layout.imagesize, 'uint8');
    
    vectorTextCell = cell(1, numFrames);
    vectorContourCell = cell(1, numFrames);

    for i = 1:numFrames
        if overlayMode
            comp = uint8(zeros(size(imtmp,1), size(imtmp,2), 3));
        else
            comp = []; % concaténation verticale
        end

        vText = [];
        vContours = [];
         channelImages = {};
         vContoursTotal = {};  % Pour accumuler les contours de chaque canal

            for ii = 1:numel(channel)
                  totim = imtmp(:,:, currentCha{ii}, :);

                if numel(totim)==0, continue; end

                if mod(i-1, snapRate(ii))==0
                    if frames(i) < 9999
                        imtmp2 = imtmp(:,:, currentCha{ii}, i);
                    else
                        imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                    end
                else
                    imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                end

                 if numel(currentCha{ii})==1 && ~iscell(levels{ii})
                    if mod(i-1, snapRate(ii))==0
                        if frames(i) < 9999
                            imtmp2 = imtmp(:,:, currentCha{ii}, i);
                        else
                            imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                        end
                    else
                        imtmp2 = zeros(size(imtmp,1), size(imtmp,2), 'uint16');
                    end
                   
                    if isequal(levels{ii}, [-1 -1])
                        if i==1
                            tmptimelapse = imtmp(:,:, currentCha{ii}, :);
                            med = median(tmptimelapse(:));
                            stddev = std(double(tmptimelapse(:)));
                            stretchlim(:,ii) = [max(0, double(med)-4*stddev); min(65535, double(med)+4*stddev)]/65535;
                        end
                        imtmp2 = imadjust(imtmp2, stretchlim(:,ii));
                    else
                        imtmp2 = imadjust(imtmp2, [levels{ii}(1)/65535, levels{ii}(2)/65535]);
                    end

                    imtmp2 = cat(3, imtmp2*rgb{ii}(1), imtmp2*rgb{ii}(2), imtmp2*rgb{ii}(3));
                    if size(imtmp2,3) ~= 3
                        imtmp2 = repmat(imtmp2, [1,1,3]);
                    end
                    
                    channelImages{end+1} = uint8(double(imtmp2)/256);  %#ok<AGROW>

                    if overlayMode
                      if isempty(weights)
                        comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
                    else
                        comp = imlincomb(1, comp, weights(ii), uint8(double(imtmp2)/256));
                      end
                    end
                  elseif numel(currentCha{ii})==1 && iscell(levels{ii})
                    imtmp2 = imadjust(imtmp2, [0 1]);
                    indices = str2num(levels{ii}{1});
                    % Traitement des canaux indexés
                    listofindexedcha = find(roitmp.display.indexed);
                    tmpcha = roitmp.channelid(currentCha{ii});
                    currentIndx = find(listofindexedcha == tmpcha);
                    if isempty(indices) || (numel(indices)==1 && indices==-1)
                        if defaultClass && (paintChannel ~= currentIndx)
                            indices = 2:max(imtmp2(:));
                        else
                            indices = 1:max(imtmp2(:));
                        end
                    end
                    if paintChannel == currentIndx
                        uni = unique(totim(:));
                        uni(uni==0) = [];
                        nuni = numel(uni);
                        levmap = eval([levels{ii}{2} '(' num2str(nuni) ')']);
                    else
                        levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices), 1]);
                    end
                    wid = levels{ii}{5};
                    weiVal = double(levels{ii}{3});
                    fillAlpha = min(1, weiVal);
                    for iii = 1:numel(indices)
                        bw = imtmp2 == indices(iii);
                        B = bwboundaries(bw);
                        for kB = 1:length(B)
                            b = B{kB};
                            patchStruct = struct();
                            patchStruct.x = b(:,2);
                            patchStruct.y = b(:,1);
                            patchStruct.FaceColor = levmap(iii,:);
                            patchStruct.FaceAlpha = fillAlpha;
                            if roitmp.display.contour(tmpcha) == 1
                                patchStruct.EdgeColor = levmap(iii,:);
                                patchStruct.LineWidth = wid;
                            else
                                patchStruct.EdgeColor = 'none';
                                patchStruct.LineWidth = [];
                            end
                            vContours = [vContours, patchStruct];
                        end
                    end
                else
                    if isempty(weights)
                        comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
                    else
                        comp = imlincomb(1, comp, weights(ii), uint8(double(imtmp2)/256));
                    end
                 end

            end

            if ~overlayMode
             if ~isempty(channelImages)
                 if param.output=="Sequence"
                    comp = vertcat(channelImages{:});
                 else % Movie or Dislay mode;
                    comp = horzcat(channelImages{:});
                 end
                else
                    comp = zeros(size(imtmp,1), size(imtmp,2), 3, 'uint8');
             end
            end

        %  vectorTextCell{i} = vText;
        vectorContourCell{i} = vContours;
        compositeFrames(:,:,:,i) = comp;
    end

    roiOverlay(cc).baseImage = compositeFrames;
    roiOverlay(cc).vectorText = vectorTextCell;
    roiOverlay(cc).vectorContours = vectorContourCell;
end