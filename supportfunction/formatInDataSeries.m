function formatInDataSeries(roiobj)

for i=1:numel(roiobj)
    
   % tmp=dataseries; 

    roiobj(i).data=dataseries();

    formatData(roiobj(i),"classification","temporal");
    roiobj(i).save('data');
end

function formatData(roiobj,class,type)

    train=roiobj.train;

    if numel(train)~=0

    p=fieldnames(train);

    if numel(roiobj.data)==1 & numel(roiobj.data.data)==0
    cc=1;
    else
    cc=numel(roiobj.data)+1;
    end
    
    for i=1:numel(p)
    
        roiobj.data(cc)=dataseries();
        roiobj.data(cc).class=class;
        roiobj.data(cc).groupid=p{i};
        roiobj.data(cc).parentid=roiobj.id;
   
        if isfield(train.(p{i}),'classes')
        roiobj.data(cc).userData.classes=train.(p{i}).classes;
        end

        if isfield(train.(p{i}),'bounds')
        roiobj.data(cc).userData.bounds=train.(p{i}).bounds;
        end

        q=fieldnames(train.(p{i}));

        for k=1:numel(q)

        if strcmp(q{k},'bounds') || strcmp(q{k},'classes') 
            continue
        end

        tmp=train.(p{i}).(q{k}); tmp=tmp';


        switch q{k}
            case 'id'
              %  for j=1:size(tmp,2)
    
                  roiobj.data(cc).addData(tmp,'id_training','groups','id');

                  categoryArray = categorical(tmp, 1:numel(roiobj.data(cc).userData.classes), roiobj.data(cc).userData.classes);
                 
                  roiobj.data(cc).addData(categoryArray,'labels_training','groups','label');
              %  end

            otherwise
                  sz=size(roiobj.data(cc).data,1);
                  if numel(tmp)==sz
                  roiobj.data(cc).addData(tmp,q{k});
                  else
                %  roiobj.data(cc).userData.(q{k})=tmp;
                  end
        end
        end

        cc=cc+1;
    end

    end

    if numel(train)~=0
    train=roiobj.results;
    p=fieldnames(train);

%     if numel(roiobj.data)==1 & numel(roiobj.data.data)==0
%     cc=1;
%     else
%     cc=numel(roiobj.data)+1;
%     end

    for i=1:numel(p)

        % identify if data exist already

        pixdata=find(arrayfun(@(x) strcmp(x.groupid,p{i}),roiobj.data));

%          if numel(pixdata)
%             cc=pixdata(1); % data to be overwritten
%         else
%             n=numel(dataout);
%             if n==1 & numel(dataout.data)==0
%                 cc=1; % replace empty dataset
%             else
%                 cc=numel(dataout)+1;
%             end
%          end

        if numel(pixdata)
            cc=pixdata(1);
        else
            cc=numel(roiobj.data)+1;
            roiobj.data(cc)=dataseries();
        %bb=roiobj.data(cc).class
        roiobj.data(cc).class=class;
        roiobj.data(cc).groupid=p{i};
        roiobj.data(cc).parentid=roiobj.id;
        end
 
        if isfield(train.(p{i}),'classes')
        roiobj.data(cc).userData.classes=train.(p{i}).classes;
        end
        
 
        q=fieldnames(train.(p{i}));

        for k=1:numel(q)

        if strcmp(q{k},'bounds') || strcmp(q{k},'classes') 
            continue
        end

        tmp=train.(p{i}).(q{k}); tmp=tmp';

        switch q{k}
            case 'prob'
                for j=1:size(tmp,2)
                 classes=roiobj.data(cc).userData.classes;
                 roiobj.data(cc).addData(tmp(:,j),['prob_' classes{j}],'groups','prob');
                end

            case 'probCNN'
                for j=1:size(tmp,2)

                  classes=roiobj.data(cc).userData.classes;
                  roiobj.data(cc).addData(tmp(:,j),['probCNN_' classes{j}],'groups','prob');
                end

            otherwise
                  sz=size(roiobj.data(cc).data,1);
                  if numel(tmp)==sz
                  roiobj.data(cc).addData(tmp,q{k});
                  else
                  %roiobj.data(cc).userData.(q{k})=tmp;
                  end
        end  
     
        end

        cc=cc+1;
    end
    end




