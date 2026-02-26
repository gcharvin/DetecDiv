src = fullfile('structure','GUI','detecdiv.mlapp');
out = fullfile('structure','GUI','detecdiv_extracted.m');
fr = appdesigner.internal.serialization.FileReader(src);
code = readMATLABCodeText(fr);
fid = fopen(out,'w'); fwrite(fid, code, 'char'); fclose(fid);
