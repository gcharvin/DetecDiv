function tmpout=post(features,classes,varargin)
% postprocessing function for pixel segmentation.
%It may be used either as an output of the pixel  classification function,
%or as a standalone function
% features provides the probabilities for each pixel for each class

watersh=0;
thresh=0.9;

sizethreshold=[];

keeplargest=[];

thrmethod='threshold';

for i=1:numel(varargin)
    if strcmp(varargin{i},'watershed') % does watershed on each class > 1 to cut connected objects
        watersh=1;
    end
    
    if strcmp(varargin{i},'keeplargest') % removes all small objects except the largest one for indicated classes numbers; keeplargest=[2 3];
        keeplargest=varargin{i+1};
    end
    
    if strcmp(varargin{i},'sizethreshold') % removes small features smaller than size threshold for all classes
        sizethreshold=str2num(varargin{i+1});
    end
    
    if strcmp(varargin{i},'threshold') % threshold on probability to assign class to pixel
        thresh=varargin{i+1};
        thrmethod='threshold';
    end
    
    if strcmp(varargin{i},'adaptivethreshold') % pixel assignment threshod based on mean proba value within putative object
        
        thrmethod='adaptivethreshold';
    end
    
    if strcmp(varargin{i},'maxproba') % pixel assignment threshod based on max probability for each pixel
        
        thrmethod='maxproba';
    end
    
end

tmpout=uint16(zeros(size(features,1),size(features,2),1,size(features,4)));

for i=2:numel(classes)
    
    % feature thresholding
     
    switch thrmethod
        case 'threshold'
            
            BW=features(:,:,i,:)>str2num(thresh);
            
        case 'adaptivethreshold'
         %   ccbwsize=[];
         %   midx=[];
         %   CCBW=[];
         %   lst=[];
            
            T=graythresh(features(:,:,i,:)); %get otsu threshold
            tmpmask=imbinarize(features(:,:,i,:),T*1);
            
            featuresim=tmpmask.*features(:,:,i,:);
            
            BW=features(:,:,i,:)>1*mean(featuresim(featuresim>0));
            
        case 'maxproba'
            [~, BW]=max(features,[],3);
            BW=BW==i;
    end
    
    
    % remove small objects
    if numel(keeplargest) || numel(sizethreshold)
        
        BW=bwareaopen(BW,10);
        CC= bwconncomp(BW);
        numPixels = cellfun(@numel,CC.PixelIdxList);
        
        if numel(keeplargest)
            if numel(find(keeplargest==i)) & numel(numPixels)>1 % only for selected classes & only if several objects are presents
                [~,idx] = max(numPixels);
                BW([CC.PixelIdxList{setxor(1:numel(numPixels),idx)}]) = 0;
            end
        end
        
        if numel(sizethreshold)
            idx=find(numPixels<sizethreshold);
            % objects numbers smallers than threshold
            for k=1:numel(idx)
                BW(CC.PixelIdxList{idx(k)}) = 0;
            end
        end
    end
    
    % performs watershed segmentation
    if watersh==1
        BW=~BW;
        %       figure, imshow(BW,[]);
        imdist=bwdist(BW);
        %      figure, imshow(imdist,[]);
        imdist = imclose(imdist, strel('disk',2));
        imdist = imhmax(imdist,1);
        %   figure, imshow(BW,[]);
        BW= double(watershed(-imdist,8)).* ~BW;
        %  figure, imshow(BW,[]);
        BW = BW>0;% & imopen(BW > 0, strel('disk', 1));
        % figure, imshow(BW,[]);
        
    end
   % res=uint16(uint16(BW)*(i));
   % tmpout=tmpout+ res;
    tmpout(BW)=i;
    
end

tmpout(tmpout==0)=1; %fill background
