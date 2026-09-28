function tests = testRoiExtractMemoryBudget
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(genpath(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
end

function testServiceAndParentHeadroom(testCase)
[proc, cg] = fixture(testCase, '0::/workers/worker1');
put(fullfile(cg,'workers','worker1','memory.max'), sprintf('%d',32*2^30));
put(fullfile(cg,'workers','worker1','memory.high'), 'max');
put(fullfile(cg,'workers','worker1','memory.current'), sprintf('%d',8*2^30));
put(fullfile(cg,'workers','memory.max'), sprintf('%d',96*2^30));
put(fullfile(cg,'workers','memory.current'), sprintf('%d',90*2^30));
[bytes, note] = roiExtract.availableMemoryBytes(proc,cg);
verifyEqual(testCase,bytes,0.8*6*2^30);
verifyTrue(testCase,contains(note,'workers'));
end

function testExhaustedWorkerDoesNotUseHostMemory(testCase)
[proc,cg] = fixture(testCase,'0::/workers/worker1');
put(fullfile(cg,'workers','worker1','memory.max'),'1024');
put(fullfile(cg,'workers','worker1','memory.current'),'1024');
verifyEqual(testCase,roiExtract.availableMemoryBytes(proc,cg),0);
end

function testHighWatermarkAndSwapExcluded(testCase)
[proc,cg] = fixture(testCase,'0::/workers/worker1');
leaf=fullfile(cg,'workers','worker1');
put(fullfile(leaf,'memory.max'),sprintf('%d',32*2^30));
put(fullfile(leaf,'memory.high'),sprintf('%d',28*2^30));
put(fullfile(leaf,'memory.current'),sprintf('%d',8*2^30));
put(fullfile(leaf,'memory.swap.max'),sprintf('%d',100*2^30));
verifyEqual(testCase,roiExtract.availableMemoryBytes(proc,cg),0.8*20*2^30);
end

function testLegacyCgroup(testCase)
[proc,cg] = fixture(testCase,'5:memory:/workers/worker1');
leaf=fullfile(cg,'memory','workers','worker1');
put(fullfile(leaf,'memory.limit_in_bytes'),sprintf('%d',16*2^30));
put(fullfile(leaf,'memory.usage_in_bytes'),sprintf('%d',4*2^30));
verifyEqual(testCase,roiExtract.availableMemoryBytes(proc,cg),0.8*12*2^30);
end

function [proc,cg] = fixture(testCase,membership)
root=tempname; mkdir(root);
addTeardown(testCase,@() rmdir(root,'s'));
proc=fullfile(root,'proc'); cg=fullfile(root,'cgroup');
put(fullfile(proc,'meminfo'),sprintf('MemTotal: 134217728 kB\nMemAvailable: 104857600 kB\n'));
put(fullfile(proc,'self','cgroup'),sprintf('%s\n',membership));
end

function put(path,content)
parent=fileparts(path); if ~isfolder(parent), mkdir(parent); end
fid=fopen(path,'w'); clean=onCleanup(@() fclose(fid));
fprintf(fid,'%s',content);
end
