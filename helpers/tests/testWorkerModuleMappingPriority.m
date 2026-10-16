function tests = testWorkerModuleMappingPriority
tests = functiontests(localfunctions);
end

function testWorkerRootWinsOverMoreSpecificClientPath(tc)
ctx = fixture();
[path, mapped] = detecdiv_paths_map_module_path('/data/project/module', ctx, 'local');
verifyTrue(tc, mapped);
verifyEqual(tc, path, '\\worker\DATA\project\module');
end

function testAccessibleWorkerAliasDoesNotBecomeForeignDrive(tc)
ctx = fixture();
[path, mapped] = detecdiv_paths_map_module_path('\\worker\DATA\project\module', ctx, 'local');
verifyTrue(tc, mapped);
verifyEqual(tc, path, '\\worker\DATA\project\module');
end

function testForeignClientPathCanStillBecomeCanonical(tc)
ctx = fixture();
[path, mapped] = detecdiv_paths_map_module_path('Z:\foreign\module', ctx, 'server');
verifyTrue(tc, mapped);
verifyEqual(tc, path, '/data/project/module');
end

function testSpecificWorkerMappingStillWinsWithinHost(tc)
ctx = fixture();
ctx.execution.worker_path_mappings(2) = struct('source', '/data/project', 'target', 'C:\modelcache');
[path, mapped] = detecdiv_paths_map_module_path('/data/project/module', ctx, 'local');
verifyTrue(tc, mapped);
verifyEqual(tc, path, 'C:\modelcache\module');
end

function ctx = fixture()
ctx.execution.worker_path_mappings = struct('source', '/data', 'target', '\\worker\DATA');
ctx.run.paths.path_mappings = struct('localRoot', 'Z:\foreign', 'remoteRoot', '/data/project');
end
