function plotData_generic(datagroups,filename,varargin)
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
leg={};
clineage=0;
listxlin=[];
listylin=[];
listxlintemp=[];
listylintemp=[];

for i=1:numel(datagroups)
    dat=datagroups(i).Source.nodename;
    for j=1:numel(dat) % loop on plotted data types
        leg{j}{2*i-1}=datagroups(i).Name;
        leg{j}{2*i}='';

        strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
        outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files

        if exist(outfile)
            delete(outfile);
        end

    end
end

plottable_data=false;

for i=1:numel(datagroups)

    if ~isfield(datagroups(i).Source,'nodename') % user did not check any node, so skip plotting
        continue
    end

    dat=datagroups(i).Source.nodename;
    rois=datagroups(i).Data.roiobj;

    % gather lineage information , if existing

    xlin={};
    ylin={};

      for j=1:numel(dat) % loop on plotted data types
      % test if lineage data type is present 
             if strcmp(dat{j}{2},'lineage') % get M/D lineage data
            d=dat{j};

              for k=1:numel(rois)
            % collect the selected data

            groups={rois(k).data.groupid};
            pix=find(matches(groups,d{1}));

                  if numel(pix)
               ylin{end+1}= rois(k).data(pix).getData(d{2});
                tmp=1:numel(ylin{end});
                xlin{end+1}=tmp';
                 end
              end

             end
      end
      if numel(ylin)
       [listxlin, listylin]=concatArrays(xlin,ylin, datagroups(i));
      end

      % gather temporal information , if existing

    xlintemp={};
    ylintemp={};

      for j=1:numel(dat) % loop on plotted data types
      % test if lineage data type is present 
             if strcmp(dat{j}{2},'totaltime') % get M/D lineage data
            d=dat{j};

              for k=1:numel(rois)
            % collect the selected data

            groups={rois(k).data.groupid};
            pix=find(matches(groups,d{1}));

                  if numel(pix)
               ylintemp{end+1}= rois(k).data(pix).getData(d{2});
                tmp=1:numel(ylintemp{end});
                xlintemp{end+1}=tmp';
                 end
              end

             end
      end

      if numel(ylintemp)
       [listxlintemp, listylintemp]=concatArrays(xlintemp,ylintemp, datagroups(i));
      end


    for j=1:numel(dat) % loop on plotted data types
        str=[datagroups(i).Name ' // ' dat{j}{1} ' // ' dat{j}{2}];

        d=dat{j};

        xout={};
        yout={};

        cc=1;

        groups={rois(1).data.groupid};
        
        pix=find(matches(groups,d{1}));

        if numel(pix)==0
            disp('Could not find corresponding data! quitting .... ')
            return
        end

        tt= rois(1).data(pix).getData(d{2});
        if ~isnumeric(tt)
            disp(['Those data  ' num2str(d{1}) ' are not numeric; skipping ....' ]);
            plottable_data(i,j)=false;
            continue
        end

        plottable_data(i,j)=true;

        roinames={};

        for k=1:numel(rois)
            % collect the selected data
            groups={rois(k).data.groupid};
            pix=find(matches(groups,d{1}));


            if numel(pix)

                tt= rois(k).data(pix).getData(d{2});
                yout{end+1}= rois(k).data(pix).getData(d{2});

                roinames{k}=rois(k).id;

                tmp=1:numel(yout{end});

                xout{end+1}=tmp';

                if strcmp(datagroups(i).Type,'generation')
                    switch datagroups(i).Param.Traj_synchronization{end}
                        case 'sep'
                            xout{end}= rois(k).data(pix).getData('sep');
                            
                            if numel(xout{end})==0 % there is no sep in this data set
                             xout{end}= rois(k).data(pix).getData('birth');
                            end

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

        cmap=lines(numel(xout));
        cmapcell = mat2cell(cmap, ones(numel(xout),1), 3);

      [listx, listy]=concatArrays(xout,yout, datagroups(i));

        if datagroups(i).Param.Display_single_cell_plot % plot single cell data....

            if strcmp(datagroups(i).Param.Single_cell_display_type{end},'plot')  % ....as plot

                h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
                hold on;

                cellfun(@(x, y, c) plot(x, y, 'Color',c), xout, yout, cmapcell', 'UniformOutput', false);

                title(datagroups(i).Name,'Interpreter','none');

                if strcmp(datagroups(i).Type,'temporal')
                    xlabel('Time (frames)');
                end
                if strcmp(datagroups(i).Type,'generation')
                    xlabel('Generation');
                end
                ylabel(dat{j}{2},'Interpreter','None');
            end

            if strcmp(datagroups(i).Param.Single_cell_display_type{end},'traj') % ....as traj
                h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
                hold on;

               % aligne=datagroups(i).Param.Traj_synchronization{end};

                htemp=h(i,j);


                plotTraj(htemp,listx,listy,dat{j}{2},datagroups(i).Param,roinames,listylin,listylintemp,rois);

                title(datagroups(i).Name,'Interpreter','none');

                if strcmp(datagroups(i).Type,'temporal')
                    xlabel('Time (frames)');
                end
                if strcmp(datagroups(i).Type,'generation')
                    xlabel('Generation');
                end

               % ylabel(dat{j}{2},'Interpreter','None');
            end
        end


        if datagroups(i).Param.Display_average  % plot average curve or traj 

            htmp=findobj('Tag',['plot_average_' dat{j}{2}]);

            if numel(htmp)==0
                havg(j)=figure('Color','w','Tag',['plot_average_' dat{j}{2}],'Name',dat{j}{2});
            else
                havg(j)=htmp;
            end

            meanx=min(listx(:)):max(listx(:)); 
            meany=mean(listy,2,"omitnan"); meany=meany'; meany=meany(~isnan(meany));
            stdy = std(listy,0,2,"omitnan")./sqrt(sum(~isnan(listy),2)); stdy=stdy'; stdy=stdy(~isnan(stdy));

            mi=uint16(min(size(meanx,2),size(meany,2)));
            meanx=meanx(1:mi);
            meany=meany(1:mi);
            stdy=stdy(1:mi);

            tmp=[];
            tmp(1,:)=meanx;
            tmp(2,:)=meany;
            tmp(3,:)=stdy;

            tmp=num2cell(tmp);
            tmp=[ {datagroups(i).Name; ' '; ' '} , {'abscissa'; 'mean'; 'sem'},  tmp];
            % tmp=[ {'abscissa'; 'mean'; 'sem'} tmp];

           figure(havg(j)); hold on;

          if strcmp(datagroups(i).Param.Single_cell_display_type{end},'plot') 
            plot(meanx, meany,'Color',col(i,:),'LineWidth',2);
            closedxt = [meanx fliplr(meanx)];
            inBetween = [meany+stdy fliplr(meany-stdy)];
            ptch=patch(closedxt, inBetween',col(i,:));

            if numel(ptch)
                ptch.EdgeColor=col(i,:);
                ptch.FaceAlpha=0.15;
                ptch.EdgeAlpha=0.3;
                ptch.LineWidth=1;
            end

            warning off all
            legend(leg{j});
            warning on all

            if strcmp(datagroups(i).Type,'temporal')
                xlabel('Time (frames)');
            end
            if strcmp(datagroups(i).Type,'generation')
                xlabel('Generation');
            end
            ylabel(dat{j}{2},'Interpreter','None');
            end

             if strcmp(datagroups(i).Param.Single_cell_display_type{end},'traj') % ....as traj
               
                plotTraj(havg(j),[meanx' ; max(meanx)+1],[NaN ; meany'],dat{j}{2},datagroups(i).Param,{},[],[],[]);

                title(datagroups(i).Name,'Interpreter','none');

                if strcmp(datagroups(i).Type,'temporal')
                    xlabel('Time (frames)');
                end
                if strcmp(datagroups(i).Type,'generation')
                    xlabel('Generation');
                end


             end

         strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
        outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files
        writecell(tmp,outfile,'WriteMode','append');
        end

     
    end
end


for i=1:numel(datagroups)
    dat=datagroups(i).Source.nodename;
    for j=1:numel(dat) % loop on plotted data types
        if plottable_data(i,j)

             if datagroups(i).Param.Display_single_cell_plot % plot single cell data....

            strname=fullfile(filename,[datagroups(i).Name '_' dat{j}{1} '_' dat{j}{2}]);
            exportgraphics(h(i,j),[strname '.pdf'],'BackgroundColor','None');
            savefig(h(i,j),[strname '.fig']);
             end
        end
    end
end

disp('Export is done !')

function [listx listy]=concatArrays(xout,yout, datagroups)

listx=[];
listy=[];

   if strcmp(datagroups.Type,'generation')  % don t do it if if  RLS survival curve

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

                switch datagroups.Param.Traj_synchronization{end}
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
            end

            if strcmp(datagroups.Type,'temporal')

                isScalarNonEmpty = @(x,y) ~isempty(x) && isnumeric(x) && ~isempty(y) && isnumeric(y);

                scalarNonEmptyIndex = cellfun(isScalarNonEmpty, xout,yout);
                xout = xout(scalarNonEmptyIndex);
                yout=yout(scalarNonEmptyIndex);


                if numel(yout)==0
                    disp('One of the variable you are trying to plot is empty or not numeric!')
                    return;
                end

                valMax = cellfun(@(x) max(x), xout);

                totMax=max(valMax)+1;

                totMax= num2cell(totMax*ones(1,numel(valMax)));
                % totMin=  num2cell(-totMin*ones(1,numel(valMin)));

                len=cellfun(@(x) length(x), xout,'UniformOutput',false);

                valMax = cellfun(@(x,y) x-y,  totMax,len,'UniformOutput',false);
                %   valMin = cellfun(@(x,y) x-y,  totMin,len,'UniformOutput',false);

                switch datagroups.Param.Traj_synchronization{end}
                    case 'sep'
                        disp('SEP synchro is not compatible with temporal display mode !');

                    case 'death'
                        paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),xout,valMax,'UniformOutput',false);
                        paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),yout,valMax,'UniformOutput',false);
                    otherwise % birth
                        %   paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),xout,valMax,'UniformOutput',false);
                        paddedx = cellfun(@(x, padSize) padarray(x, [padSize, 0], nan, 'post'), ...
                            xout, valMax, 'UniformOutput', false);

                        paddedy = cellfun(@(x, padSize) padarray(x, [padSize, 0], nan, 'post'), ...
                            yout, valMax, 'UniformOutput', false);

                        %  paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),yout,valMax,'UniformOutput',false);
                end

                listx=cell2mat(paddedx);
                listy=cell2mat(paddedy);
            end


