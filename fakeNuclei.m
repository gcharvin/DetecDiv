function fakeNuclei(mov)

mov(1).fakeNuclei(1); % 1 is the trap number;

if numel(mov)>1
inputpoly=mov(1).inputpoly; 

for i=2:numel(mov)
    mov(i).fakeNuclei(1,inputpoly);
end
end