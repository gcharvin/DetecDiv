function cmap=shallowColormap(n)

% n is the number of colors

switch n
    case 1
        cmap=[1 0 0];
        
    case 2
        cmap=[1 0 0 ; 0 1 0];
        
    case 3
        cmap=[1 0 0 ; 0 1 0; 0 0 1];
        
    otherwise
      
  %    if n<8
  %       cmap=jet(10);
 %     else
      %    n
          cmap=prism(n)/2;
 %     end

        
       % tmp=cmap;
      %  tmp(2:2:end,:)=cmap(1:size(cmap,1)/2,:);
     %   tmp(1:2:end-1,:)=cmap(size(cmap,1)/2+1:end,:);
        %cmap=tmp(end:-1:1,:);

    %    cmap=tmp;
        
%         if n<8
%            cmap=cmap(1:n,:);
%         end
%         
%         if n==9
%             cmap(9,:)=[1 0.5 0.5];
%         end
end

cmap=[0 0 0; cmap];

%colormap(cmap);
%colorbar



