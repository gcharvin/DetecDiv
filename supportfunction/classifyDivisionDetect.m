function classifyDivisionDetect(roiobj,lstmmodel,classeid,classistr)

% uses lstm model to classify probability of a given class 

className=roiobj(1).classes{classeid};
cate=categorical({className, 'other'});
classes=categories(cate);


for i=1:numel(roiobj)
    roitmp=roiobj(i); 
    
    % get the data
    X=roitmp.results.(classistr).prob(classeid,:);
    
    Y=classify(lstmmodel,X);
    Y=double(Y==classes(2));

    roitmp.results.(classistr).probcorr(classeid,:)=Y;
end
