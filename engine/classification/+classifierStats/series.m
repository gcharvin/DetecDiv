function data=series(r)
%SERIES Read available saved groups without replacing unsaved ROI metadata.
data=r.data;
file=fullfile(char(string(r.path)),['data_' char(string(r.id)) '.mat']);
if ~isfile(file),return;end
stored=load(file,'data');if ~isfield(stored,'data'),return;end
for k=1:numel(stored.data)
    ds=stored.data(k);
    if ~any(strcmp({data.groupid},ds.groupid)),data(end+1)=ds;end %#ok<AGROW>
end
end
