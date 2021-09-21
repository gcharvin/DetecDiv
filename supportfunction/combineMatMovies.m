function combineMatMovies(matcell,cate,outputname)
% support function to combines exported movies as an array of rows or columns
% cate is either 'row' or 'col' 
% outputname is a full path + name

if strcmp(cate,'col')
    dim=2;
end
if strcmp(cate,'row')
    dim=1;
end


for i=1:numel(matcell)
    
    load(matcell{i})
    
    if ~isvarname('imgout') % imgout var does not exist
        disp('THe mat file does not feature an imgout movie matrix; quitting....');
    end

    if i==1
        C=imgout;
        continue;   
    end
    
    C=cat(dim,C,imgout);
    
end

   v=VideoWriter(outputname,'MPEG-4');
        v.FrameRate=25;
        v.Quality=100;
        open(v);
        
        %return
        writeVideo(v,C);
        close(v);
        disp(['Movie successfully exported to : ' outputname '.mp4'])


        