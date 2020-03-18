function classifyPixels(handle,event,im,hpaint)


%im,hpaint

h=figure('Tag','Classify');% imshow(im,[]);;

% matrix with predictors

Nucleus=hpaint.CData(:,:,2);

%imshow(Nucleus,[]);;


%imshow(pixNucleus,[])

pixNucleus=find(Nucleus~=0);

listNucleus=im(pixNucleus);

Bck=hpaint.CData(:,:,1);
pixBck=find(Bck~=0);
listBck=im(pixBck);

X=zeros(length(pixNucleus)+length(pixBck),1);

%size(X)

X=double([listNucleus ; listBck]); % predictors

%size(X)


Y=[ones(length(pixNucleus),1); zeros(length(pixBck),1)]; % ground truth

%size(Y)

tree = fitctree(X,Y); % decision tree
% new observations to predict

newPix= find(Nucleus==0 & Bck==0);

Xnew= double(im(newPix));

Ynew=predict(tree,Xnew);

imout=uint8(zeros(size(im)));

imout(newPix)=Ynew;


imoutrgb=uint8(zeros(size(imout,1),size(imout,2),3));

imoutrgb(:,:,2)=255*imout+0.5*Nucleus;
imoutrgb(:,:,1)=255*uint8(imout==0 & Nucleus==0 & Bck==0)+0.5*Bck;

 %imshow(imout,[])
imshow(imoutrgb);

% refine display

axis square equal 
colormap(gray)
h.Position(3)=700;
h.Position(4)=700;
a=gca;
a.Position=[0.05 0.05 0.9 0.9];


% X=[0 1 1; 1 0 1; 1 0 1; 1 1 0; 0 0 1; 0 1 0];
% X=[X; X ; X;X]
% 
% Y=[1 ; 0 ; 0 ; 0 ; 1 ; 1];
% 
% Y=[Y; Y;Y;Y]
% 
% 
% tree = fitctree(X,Y) %'MaxNumSplits',7,'CrossVal','on');
% 
% %figure;
% %view(tree.Trained{1},'Mode','graph')
% 
% Xnew=[1 1 1; 0.4 0 0];
% 
% Yfit=predict(tree,Xnew)
% 
% imp = predictorImportance(tree);
% 
% figure;
% bar(imp);
% title('Predictor Importance Estimates');
% ylabel('Estimates');
% xlabel('Predictors');
% h = gca;
% h.XTickLabel = tree.PredictorNames;
% h.XTickLabelRotation = 45;
% h.TickLabelInterpreter = 'none';

