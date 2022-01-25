function data = matReader(filename)

 d = load(filename);
 f = fields(d);
 
 data=d.(f{1}); 
 
 