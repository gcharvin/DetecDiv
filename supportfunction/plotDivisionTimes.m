function plotDivisionTimes(datagroups,filename,varargin)
% plot dataseries from rois as a collection of single cell traj and/or
% averages

% for single cells , one plot per datagroup and per datatype (mean, max 20
% pixels)

% for averages, put all datagroups on one plot to compare the datagroups,
% provide averag, standard deviation and bootstrap for standard error on
% mean

% special plot for RLS data : event / div duration : ecf function : plot
% reletaed to the number of events in array

[p ,f ,ext]=fileparts(filename);

col=lines(numel(datagroups));

% here do implement divtimes analysis 

leg={};
leg2=leg;

cd=1;
for i=1:numel(datagroups)
    cd(i)=0;
    dat=datagroups(i).Source.nodename;

    if ~isfield(datagroups(i).Source,'nodename') % user did not check any node, so skip plotting
        continue
    end

    for j=1:numel(dat) % loop on plotted data types

        if strcmp(dat{j}{2},'divduration') % plotting division times data
            cd(i)=j;

               strname=fullfile(filename,['average_' dat{cd(i)}{1} '_' dat{cd(i)}{2}]);
            outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files

            if exist(outfile)
                delete(outfile);
            end

           % break
        end

            if strcmp(dat{j}{2},'lineage') % get M/D lineage data
            cd(i)=j;

            % HERE

         %   strname=fullfile(filename,['average_' dat{cd(i)}{1} '_' dat{cd(i)}{2}]);
        %    outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files

        %    if exist(outfile)
        %        delete(outfile);
          %  end

           % break
        end

    end

if cd(i)==0
    disp(['Could not find the data required to plot division times in group ' num2str(i) ' ; Quitting ....'])
    return;
end

 leg{i}=datagroups(i).Name;
% leg{2*i}='';

  leg2{2*i-1}=datagroups(i).Name;
  leg2{2*i}='';


end

%leg2=leg;

for i=1:numel(datagroups)

    if ~isfield(datagroups(i).Source,'nodename') % user did not check any node, so skip plotting
        continue
    end

    dat=datagroups(i).Source.nodename;
    rois=datagroups(i).Data.roiobj;

    %   for j=1:numel(dat) % loop on plotted data types

    j=cd(i);

    str=[datagroups(i).Name ' // ' dat{j}{1} ' // ' dat{j}{2}];

    d=dat{j};
    xout={};
    yout={};

    cc=1;

    groups={rois(1).data.groupid};
    pix=find(matches(groups,d{1}));
    tt= rois(1).data(pix).getData(d{2});

    if ~isnumeric(tt)
        disp(['Those data:  ' num2str(d{1}) ' are not numeric, yet I expected numeric data; quitting ....' ]);
        return
    end

    for k=1:numel(rois)
        % collect the selected data

        groups={rois(k).data.groupid};
        pix=find(matches(groups,d{1}));

        if numel(pix)
            tt= rois(k).data(pix).getData(d{2});
            yout{end+1}= rois(k).data(pix).getData(d{2});
            tmp=1:numel(yout{end});
            xout{end+1}=tmp';

            if strcmp(datagroups(i).Type,'generation')
                switch datagroups(i).Param.Traj_synchronization{end}
                    case 'sep'
                        xout{end}= rois(k).data(pix).getData('sep');
                    case 'death'
                        xout{end}= rois(k).data(pix).getData('death');
                    otherwise % birth
                        xout{end}= rois(k).data(pix).getData('birth');
                end
            end
            cc=cc+1;
        else
            disp(['Could not find ' num2str(d{1}) 'in the avaiable data']);
        end
    end

    % cmap=lines(numel(xout));
    % cmapcell = mat2cell(cmap, ones(numel(xout),1), 3);
    % 
    % if datagroups(i).Param.Display_single_cell_plot
    %     h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
    %     hold on;
    % 
    %     cellfun(@(x, y, c) plot(x, y, 'Color',c), xout, yout, cmapcell', 'UniformOutput', false);
    % 
    %     title(datagroups(i).Name,'Interpreter','none');
    % 
    %     if strcmp(datagroups(i).Type,'temporal')
    %         xlabel('Time (frames)');
    %     end
    %     if strcmp(datagroups(i).Type,'generation')
    %         xlabel('Generation');
    %     end
    % 
    %     ylabel(dat{j}{2},'Interpreter','None');
    % end

    %   if datagroups(i).Param.Display_single_cell_plot
    % h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
    % hold on;
    %
    % cellfun(@(x, y, c) plot(x, y, 'Color',c), xout, yout, cmapcell', 'UniformOutput', false);
    %
    % title(datagroups(i).Name,'Interpreter','none');
    %
    % if strcmp(datagroups(i).Param.Plot_type{end},'temporal')
    %     xlabel('Time (frames)');
    % end
    % if strcmp(datagroups(i).Param.Plot_type{end},'generation')
    %     xlabel('Generation');
    % end
    %
    % ylabel(dat{j}{2},'Interpreter','None');
    %   end


    %    if datagroups(i).Param.Display_average  % plot average curve

    htmp=findobj('Tag',['plot_average_' dat{j}{2}]);

    if numel(htmp)==0
        havg=figure('Color','w','Tag',['plot_average_' dat{j}{2}],'Name',dat{j}{2});
    else
        havg=htmp;
    end

    htmp=findobj('Tag',['plot_average2_' dat{j}{2}]);

    if numel(htmp)==0
        havg2=figure('Color','w','Tag',['plot_average2_' dat{j}{2}],'Name',dat{j}{2});
    else
        havg2=htmp;
    end


    %   if strcmp(datagroups(i).Type,'generation')  % don t do it if if  RLS survival curve

    yout=cellfun(@(x,y) y(~isnan(x)), xout,yout,'UniformOutput',false);
    xout=cellfun(@(x) x(~isnan(x)), xout,'UniformOutput',false);

    valMin = cellfun(@(x) min(x), xout);
    totMin=min(valMin)-1;
    valMax = cellfun(@(x) max(x), xout);
    totMax=max(valMax)+1;

    totMax= num2cell(totMax*ones(1,numel(valMax)));
    totMin=  num2cell(-totMin*ones(1,numel(valMin)));

    len=cellfun(@(x) length(x), xout,'UniformOutput',false);

    valMax = cellfun(@(x,y) x-y,  totMax,len,'UniformOutput',false);
    valMin = cellfun(@(x,y) x-y,  totMin,len,'UniformOutput',false);

    switch datagroups(i).Param.Traj_synchronization{end}
        case 'sep'

            lenMin=cellfun(@(x) length(find(x<=0)), xout,'UniformOutput',false);
            lenMax=cellfun(@(x) length(find(x>=0)), xout,'UniformOutput',false);

            valMax = cellfun(@(x,y) x-y,  totMax,lenMax,'UniformOutput',false);
            valMin = cellfun(@(x,y) x-y,  totMin,lenMin,'UniformOutput',false);

            paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),xout,valMin,'UniformOutput',false);
            paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),yout,valMin,'UniformOutput',false);

            paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),paddedx,valMax,'UniformOutput',false);
            paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),paddedy,valMax,'UniformOutput',false);

        case 'death'
            paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),xout,valMin,'UniformOutput',false);
            paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),yout,valMin,'UniformOutput',false);
        otherwise % birth
            paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),xout,valMax,'UniformOutput',false);
            paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),yout,valMax,'UniformOutput',false);
    end

    listx=cell2mat(paddedx);
    listy=cell2mat(paddedy);

    %  end

    % plot the average data points after synchronization 
    
    meanx=min(listx(:)):max(listx(:));
    meany=mean(listy,2,"omitnan"); meany=meany'; meany=meany(~isnan(meany));
    stdy = std(listy,0,2,"omitnan")./sqrt(sum(~isnan(listy),2)); stdy=stdy'; stdy=stdy(~isnan(stdy));

    mi=uint16(min(size(meanx,2),size(meany,2)));
    meanx=meanx(1:mi);
    meany=meany(1:mi);
    stdy=stdy(1:mi);

    %[rlsb] = bootstrp(Nboot,@(x)x,rlst);
    % rlsb=[rlst; rlsb ]; %add the real one in addition to the bootstrap

    figure(havg2); hold on;
    plot(meanx, meany,'Color',col(i,:),'LineWidth',2);
    closedxt = [meanx fliplr(meanx)];
    inBetween = [meany+stdy fliplr(meany-stdy)];

    tmp=[];
    tmp(1,:)=meanx;
    tmp(2,:)=meany;
    tmp(3,:)=stdy;

    tmp=num2cell(tmp);
    tmp=[ {datagroups(i).Name; ' '; ' '} , {'abscissa'; 'mean'; 'sem'},  tmp];
    % tmp=[ {'abscissa'; 'mean'; 'sem'} tmp];

    ptch=patch(closedxt, inBetween',col(i,:));

    if numel(ptch)
        ptch.EdgeColor=col(i,:);
        ptch.FaceAlpha=0.15;
        ptch.EdgeAlpha=0.3;
        ptch.LineWidth=1;
    end

    warning off all
    legend(leg2);
    warning on all

    xlabel('Generation');
    ylabel(dat{j}{2},'Interpreter','None');

    % save average as xlsx file 
    strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
    outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files
    writecell(tmp,outfile,'WriteMode','append');

    % plot the histogram of division times

    val=listy(:); val=val(~isnan(val));

    figure(havg); hold on;
    hs(i)=histogram(val);
    hs(i).Normalization='probability';
    hs(i).BinWidth=1;


  %  plot(xt,1-yt,'LineWidth',2,'color',col(i,:));

    % tmp=[];
    % tmp(1,:)=xt;
    % tmp(2,:)=1-yt;
    % tmp(3,:)=(fup-flo)/2;
    % 
    % tmp=num2cell(tmp);
    % tmp=[ {datagroups(i).Name; ' '; ' '},  {'abscissa'; 'mean'; 'sem'} tmp];

    leg{i}=[leg{i}  ' - Median= ' num2str(median(val)) '+/-' num2str(std(val)) ' (N=' num2str(length(val)) ')'];

   % leg{2*i-1}=[ leg{2*i-1} ' - Median=' num2str(median(ngen)) ' (N=' num2str(length(ngen)) ')'];

    % fup(1)=0;
    % fup(end)=1;
    % flo(1)=0;
    % flo(end)=1;
    % closedxt = [xt', fliplr(xt')];
    % inBetween = [1-fup', fliplr(1-flo')];
    % ptch=patch(closedxt, inBetween,col(i,:));
    % ptch.EdgeColor=col(i,:);
    % ptch.FaceAlpha=0.15;
    % ptch.EdgeAlpha=0.3;
    % ptch.LineWidth=1;

    warning off all
   legend(leg);
    warning on all

    ylabel('Probability')
    xlabel('Time (frames)')

 %   strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
 %   outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files
 %   writecell(tmp,outfile,'WriteMode','append');
end

% for i=1:numel(datagroups)
%     dat=datagroups(i).Source.nodename;
%     %    for j=1:numel(dat) % loop on plotted data types
%     j=cd;
%   %  if plottable_data(i)
strname=fullfile(filename,['histogram_' dat{j}{1} '_' dat{j}{2}]);
exportgraphics(havg(j),[strname '.pdf'],'BackgroundColor','None');
exportgraphics(havg(j),[strname '.pdf'],'BackgroundColor','None');
savefig(havg(j),[strname '.fig']);

% %    en
% end

disp('Export is done !')

