function zfocus=computeFocus(zarray,imagestack,classif)


classifier=classif.loadClassifier; 

inputSize = classifier.Layers(1).InputSize;
gfp=imagestack;

im=uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,4)));
   
    for j=1:size(gfp,4)        
        tmp=preProcessROIData(gfp(:,:,1,j));
        im(:,:,:,j)=uint8(256*tmp);        
    end


im = imresize(im,inputSize(1:2));

tic
zfocus= predict(classifier, im); % this is used to get the probabilities rather than the classification itself
toc


offset=mean(zarray-zfocus')

figure, plot(zarray,zfocus); hold on;
xlabel('Z Axis (microns)');
ylabel('Deep focus predcition (microns)');

plot( zarray, zarray-offset,'Color','k');
line([offset offset],[min(zfocus), max(zfocus)],'LineStyle','--','Color','r');




function imout=preProcessROIData(im)

% preprocess frame / channel image of ROI and returns corresponding image

strchlm=stretchlim(im,[0.001 0.999]); 

imout = double(imadjust(im,strchlm))/65535;

 imout=repmat(imout,[1 1 3]);

            





