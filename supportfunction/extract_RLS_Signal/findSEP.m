function [t1 t2 mid x y tdiv fdiv]=findSEP(tab,l,display)

%tab=matrix, each line corresponds to a cell with successive values of cell
%cycle duration in min
%l=cell line for which we want to find SEP
timefactor=5;
tab=tab*timefactor;
tab(tab<60)=65;
t1=[];
t2=[];
x=[];
y=[];
tdiv=[];
fdiv=[];

%     if numel(dau)==0
%         return;
%     end

tdiv=tab(l,:);


tdiv=tdiv(tdiv>0);

if numel(tdiv)==0
    return;
end

fdiv=1./tdiv;

test=fdiv;
%test(end+1)=0.001;

[t1 t2 level1 level2 curve]=fitSenescenceModel(test,0,0);

% [sp v] = spaps(1:length(fdiv),fdiv,0.002);


%

% t1,t2,level1,level2
%
if level2<=0.06/timefactor %0.09
    % senesence case
    %mid=(t1+t2)/2
    
    mid=find(curve<level1-0.0,1,'first'); % 0.03
    mid=t1;
    
    
    if numel(mid)==0
        mid=round((t1+t2)/2);
    end
    
    mid=min(length(fdiv),mid);
    
    %mid=t1;
    
    %mid=t1;
    x=1:1:length(fdiv);
    x=x-mid;
    % x=x-length(x);
    
    y=1./fdiv(1:end);
    % mid
    % plot(x,y,'Color',col(i,:)); hold on;
else
    %continue
    x=1:1:length(fdiv);
    
    
    
    x=x-length(x);
    y=1./fdiv(1:end);
    
    mid=length(x)+1;
    t2=mid; t1=mid-1;
    t1=0;
    t2=0;
    mid=0;
    %if length(fdiv
    %figure(h3); plot(x,1./y,'Color',col(i,:));
    %hold on;
    
    % plotFit(fdiv,t1,t2)
end

%plot(x,1./y,'Color',col(i,:));

%%% plotFit(x,fdiv,t1,t2)

%  return;
if nargin==3
    h= plotFit(x,fdiv,t1,t2); %plot(x,v,'Color','g');
end


function [t1 t2 level1 level2 curve]=fitSenescenceModel(fdiv,thr1,thr2)

chi2=zeros(size(fdiv));

% fdiv(fdiv>1/60)=1/65;

for i=1:length(fdiv)-1
    for j=i+1:length(fdiv)
        %chi2=0;
        
        level1=mean(fdiv(1:i));
        level2=mean(fdiv(j:end));
        
        chi2(i,j)= sum((fdiv(1:i)-level1).^2)+sum((fdiv(j:end)-level2).^2);
        
        if j>i+1
            arrx=i:1:j;
            arry=(level1-level2)/(i-j)*arrx+(level2*i-level1*j)/(i-j);
            
            chi2(i,j)= chi2(i,j) + sum( (fdiv(i+1:j-1)- arry(2:end-1)).^2 );
    
        end
        
        %          if i>8
        %          plotFit(1:1:length(fdiv),fdiv,i,j);
        %         a=chi2(i,j),i,j
        %          pause
        %          close
        %          end
        
    end
end


pix=find(chi2==0);
chi2(pix)=max(max(chi2));

[m pix]=min(chi2(:));
%figure, plot(chi2(:));
[i j]=ind2sub(size(chi2),pix);

t1=i;
t2=j;

%plotFit(1:1:length(fdiv),fdiv,i,j);

level1=mean(fdiv(1:i));
level2=mean(fdiv(j:end));

curve(1:i)=level1*ones(1,i);


%length(fdiv)-j

curve(j:length(fdiv))=level2*ones(1,length(fdiv)-j+1);

arrx=i:1:j;
arry=(level1-level2)/(i-j)*arrx+(level2*i-level1*j)/(i-j);
curve(i+1:j-1)=arry(2:end-1);




function h=plotFit(x,fdiv,i,j)


h=figure;

level1=mean(fdiv(1:i));
level2=mean(fdiv(j:end));

line1x=1:i; line1y=level1*ones(1,length(line1x));
line2x=j:length(fdiv); line2y=level2*ones(1,length(line2x));

if j>=i+1
    arrx=i:1:j;
    arry=(level1-level2)/(i-j)*arrx+(level2*i-level1*j)/(i-j);
end

plot(x,fdiv,'Marker','.','LineStyle','none','MarkerSize',20); hold on;

plot(line1x+x(1)-1,line1y,'Color','r','LineStyle','--'); hold on;
plot(line2x+x(1)-1,line2y,'Color','r','LineStyle','--');  hold on;

if j>=i+1
    plot(arrx+x(1)-1,arry,'Color','r','LineStyle','--'); hold on;
end