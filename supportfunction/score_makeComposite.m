function [displayImage, vContours indexedOverlay alphaOverlay]=score_makeComposite(roitmp,fr,param)

channel=param.channel;
% imageSize=param.imageSize;
overlay=param.overlay;

% frames=param.frames;
% snapRate=param.snapRate;
levels=param.levels;
rgb=param.RGB;
weights=param.weights;
paintChannel=param.paintChannel;
defaultClass=param.defaultClass;

%figure, imshow(roitmp.image(:,:,13,1),[]);
imtmp=preProcessROI(roitmp,param);

%figure, imshow(imtmp(:,:,13,1),[]);

% here make a distinction : if image has 3 D , then don't display it as
% overlay , otherwise  do it !

if overlay==false
    displayImage= zeros([size(imtmp,1), size(imtmp,2) 3 numel(channel)], 'uint8');
else
    displayImage= zeros([size(imtmp,1), size(imtmp,2) 3 ], 'uint8');
    comp=displayImage;
end

indexedOverlay = zeros(size(imtmp,1), size(imtmp,2), 3);
alphaOverlay = zeros(size(imtmp,1), size(imtmp,2));
alphamask = zeros(size(alphaOverlay));

vContours = [];

for ch=1:numel(channel)
%fr
    if iscell(channel)
        currentCha = roitmp.findChannelID(channel{ch});
    else
        pix = find(roitmp.channelid == channel(ch));
        currentCha = pix;
    end

  %  currentCha

    totim =roitmp.image(:,:, currentCha, :); % to get the whole range of map values

    imtmp2 = imtmp(:,:, currentCha, fr);
   % class(imtmp2),max(imtmp2(:))
   % figure, imshow(imtmp2,[]);

    if numel(currentCha)==1 && ~iscell(levels{ch})
        if ~isequal(levels{ch}, [-1 -1])
            if levels{ch}(1)>=levels{ch}(2)
                levels{ch}(1)=levels{ch}(2)-1;
            end
            imtmp2 = imadjust(imtmp2, [levels{ch}(1)/65535, levels{ch}(2)/65535]);
        end

        imtmp2 = cat(3, imtmp2*rgb{ch}(1), imtmp2*rgb{ch}(2), imtmp2*rgb{ch}(3));


        if size(imtmp2,3) ~= 3
            imtmp2 = repmat(imtmp2, [1,1,3]);
        end

        if overlay
            if isempty(weights)
                comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
            else
                comp = imlincomb(1, comp, weights(ch), uint8(double(imtmp2)/256));
            end
        else
            displayImage(:,:,:,ch) = uint8(double(imtmp2)/256);
        end

    elseif numel(currentCha)==1 && iscell(levels{ch})
        imtmp2 = imadjust(imtmp2, [0 1]);

     %   max(imtmp2(:))
        indices = str2num(levels{ch}{1});
        % Traitement des canaux indexés
        listofindexedcha = find(roitmp.display.indexed);
        tmpcha = roitmp.channelid(currentCha);
        currentIndx = find(listofindexedcha == tmpcha);

        if  (paintChannel ~= currentIndx) && paintChannel~=0 % in paint mode, discard other channels
            continue
        end


        if isempty(indices) || (numel(indices)==1 && indices==-1)
            if defaultClass && (paintChannel ~= currentIndx)
                indices = 2:max(imtmp2(:));
            else
                indices = 1:max(imtmp2(:));
            end
        end

%tmp=levels{ch}{2} 

        if paintChannel == currentIndx
            uni = unique(totim(:));
            uni(uni==0) = [];
            nuni = max(numel(uni),numel(indices));
            levmap = eval([levels{ch}{2} '(' num2str(nuni) ')']);
        else
            levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices), 1]);
        end





        wid = levels{ch}{5};
        weiVal = double(levels{ch}{3});
        fillAlpha = min(1, weiVal);

        switch param.mode
            case {"Sequence","Movie"}
                % build vectors
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

            case "Display"

                %  annotationColorImage = zeros(size(indexedOverlay));
                % alphamask = zeros(size(alphaOverlay));

                for iVal = 1:numel(indices)
                    mask = imtmp2 == indices(iVal);
                    %   figure, imshow(mask,[])
                    alphamask = alphamask | mask;

              
                    for c = 1:3
                        channelOverlay = indexedOverlay(:, :, c);
                        channelOverlay(mask) =levmap(iVal, c);
                        indexedOverlay(:, :, c) = channelOverlay;
                    end

                    if numel(find(mask))
                        alphaOverlay(mask) = fillAlpha;
                    end

                end
        end
    else

         if ~isequal(levels{ch}, [-1 -1])
            imtmp2 = imadjust(imtmp2, [levels{ch}(1)/65535, levels{ch}(2)/65535]);
         end
         
        if overlay
        if isempty(weights)
            comp = imlincomb(1, comp, 1, uint8(double(imtmp2)/256));
        else
            comp = imlincomb(1, comp, weights(ch), uint8(double(imtmp2)/256));
        end
        else
 
            displayImage(:,:,:,ch) = uint8(double(imtmp2)/256);
        end
    end


    if overlay
        displayImage =comp;
    end

end



end



function imtmp=preProcessROI(roitmp,param)

channel=param.channel;
frames=param.frames;
crop=param.crop;
scalingFactor=param.scalingFactor;
imageSize=param.imageSize;
flip=param.flip;

if isempty(roitmp.image), roitmp.load; end

%disp(['ROI ' roitmp.id ' is loaded']);

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
end

