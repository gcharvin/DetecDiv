function exportData(datagroup,rois,filename,varargin)
% export single cell dataseries from rois as xls file
% mainly used by the detector GUI

            [p ,f ,ext]=fileparts(filename);
   
            dat=datagroup.Source.nodename;

            disp('Please wait and do not access file until writing is complete....')
            disp('It may take a few minutes !')

            if isempty(dat)
                warning('exportData:NoDataSelected','No dataseries columns are selected for export.');
                return;
            end

            clearedGroups={};

            for i=1:numel(dat)
                if numel(dat)>0

                    d=dat{i};

                    strtot={};
                    for j=1:numel(rois)
                        if isempty(rois(j).data)
                            continue;
                        end
                        groups={rois(j).data.groupid};
                        pix=find(matches(groups,d{1}));

                        if numel(pix)
                            out=rois(j).data(pix(1)).getData(d{2});
                            values=toWriteCells(out);
                            strtot(end+1,1)={char(string(rois(j).id))}; %#ok<AGROW>
                            strtot(end,2:1+numel(values))=values(:)'; %#ok<AGROW>
                        end
                    end

                    if ~isempty(strtot)
                        safeGroup=regexprep(char(string(d{1})),'[^A-Za-z0-9_-]','_');
                        outfile=fullfile(p,[f '_' safeGroup '.xlsx']);
                        if ~ismember(safeGroup,clearedGroups) && exist(outfile,'file')==2
                            delete(outfile);
                        end
                        sheet=char(string(d{2}));
                        sheet=regexprep(sheet,'[\\/\?\*\[\]:]','_');
                        sheet=sheet(1:min(31,numel(sheet)));
                        writecell(strtot,outfile,'Sheet',sheet,'WriteMode','overwritesheet');
                        clearedGroups{end+1}=safeGroup; %#ok<AGROW>
                    end
                end
            end

            disp('Export is done !')
end

function values=toWriteCells(out)
if iscategorical(out)
    values=cellstr(string(out(:)));
elseif isstring(out)
    values=cellstr(out(:));
elseif ischar(out)
    values=cellstr(out);
elseif iscell(out)
    values=out(:);
elseif isnumeric(out) || islogical(out)
    values=num2cell(out(:));
else
    values=cellstr(string(out(:)));
end
end

