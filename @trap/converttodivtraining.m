function converttodivtraining(obj)

%pix=obj.div.raw;

%obj.div.reject(:)=1;

if numel(find(obj.div.classi))

r= ~obj.div.classi & obj.div.raw;

obj.div.reject(r)=1;
end

if numel(find(obj.div.dead))
obj.div.reject(obj.div.dead)=2; 
end

obj.div.classi(:)=0;
obj.div.dead(:)=0;
