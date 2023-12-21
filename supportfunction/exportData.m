function exportData(datagroup,rois,filename,varargin)
% export single cell dataseries from rois as xls file
% mainly used by the detector GUI

            [p ,f ,ext]=fileparts(filename);
   
            dat=datagroup.Source.nodename;

            disp('Please wait and do not access file until writing is complete....')
            disp('It may take a few minutes !')

            for i=1:numel(dat)
        
                if numel(dat)>0

                    d=dat{i};

                    outfile=fullfile(p,[f '_' d{1} '.xlsx']); %write as xlsx is important , otherwise throw an error with large files 

                    if exist(outfile)
                        delete(outfile);
                    end
                end
            end

            for i=1:numel(dat)
                if numel(dat)>0

                    d=dat{i};

                    strtot={};
                    cc=1;
                    for j=1:numel(rois)
                        
                        groups={rois(j).data.groupid};
                        pix=find(matches(groups,d{1}));

                        if numel(pix)
                            out= rois(j).data(pix).getData(d{2});

                            str={};
                            str{1}=rois(j).id;

                             if iscell(out)
                                    str=[str out'];
                            else
                                    str2=num2cell(out');
                                     ny=size(str2,1);
                                     if ny>1
                                         str(2:ny,1)={[]};
                                     end
 
                                     str=[str str2];
                             end


                            strtot((cc-1)*size(str,1)+1:cc*size(str,1),1:size(str,2))=str;
                            cc=cc+1;
         
                        end
                    end

                    if cc>1
                        tt=fullfile(p,[f '_' d{1} '.xlsx']);
                  
                        writecell(strtot,fullfile(p,[f '_' d{1} '.xlsx']),'sheet',d{2},'WriteMode','overwritesheet');
                    end
                end
            end

            disp('Export is done !')

