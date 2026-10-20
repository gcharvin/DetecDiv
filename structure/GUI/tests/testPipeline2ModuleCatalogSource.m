function tests = testPipeline2ModuleCatalogSource
% Keep catalogue browsing separate from adapter activation and saved nodes.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.source = fileread(fullfile( ...
    fileparts(fileparts(mfilename('fullpath'))), 'pipeline2_extracted.m'));
end

function testLibraryUsesCommonMetadataWithoutActivatingPackages(testCase)
block = methodSource(testCase, 'defaultModuleLibrary');
verifyTrue(testCase, contains(block, "detecdiv_modules_ui('Root', repoRoot(app)"));
verifyTrue(testCase, contains(block, 'app.ModuleCatalogueItems'));
verifyTrue(testCase, contains(block, 'app.ModuleCatalogueDiagnostics'));
for call = {'dir(', 'addpath(', 'feval(', 'executionSpec', 'pipelineNodeContract', ...
        'detecdiv_plugins_list', 'detecdiv_plugins_addpath'}
    verifyFalse(testCase, contains(block, call{1}));
end
end

function testMenusGroupByFunctionAndExposeOneCatalogue(testCase)
groups = methodSource(testCase, 'moduleTypeMenuGroup');
verifyTrue(testCase, contains(groups, "label = 'Classifier'"));
verifyTrue(testCase, contains(groups, "label = 'Processor'"));
verifyFalse(testCase, contains(groups, 'Builtin'));
verifyFalse(testCase, contains(groups, 'Plugin'));
menu = methodSource(testCase, 'rebuildModulesMenu');
verifyTrue(testCase, contains(menu, "'Add module...'"));
verifyTrue(testCase, contains(menu, "'Module catalogue...'"));
verifyFalse(testCase, contains(menu, 'built-in'));
verifyFalse(testCase, contains(menu, 'plugin module'));
end

function testEveryNewModuleMutationChecksCatalogueBeforeChangingData(testCase)
methods = {'addModuleOfType', 'addModuleAfterSelected', ...
    'insertModuleBeforeSelected', 'changeSelectedModuleType', ...
    'applyTypeControlsToSelectedNode'};
firstMutations = {'app.NodeCounter =', 'shiftLayoutRowFromColumn', ...
    'shiftLayoutRowFromColumn', 'clearModuleDerivedFields', 'clearModuleDerivedFields'};
for i = 1:numel(methods)
    block = methodSource(testCase, methods{i});
    gate = strfind(block, 'moduleCatalogueAllowsMutation(');
    mutation = strfind(block, firstMutations{i});
    verifyNotEmpty(testCase, gate, methods{i});
    verifyNotEmpty(testCase, mutation, methods{i});
    verifyLessThan(testCase, gate(1), mutation(1), methods{i});
end
end

function testUnsafeCatalogueRowsCannotBeAddedThroughMenusOrTypeLists(testCase)
menu = methodSource(testCase, 'addModuleLibraryMenu');
verifyTrue(testCase, contains(menu, "'catalogueRow', idx"));
verifyTrue(testCase, contains(menu, 'moduleCatalogueRowCanAdd(app, idx)'));
verifyTrue(testCase, contains(menu, "item.Enable = 'off'"));
callback = methodSource(testCase, 'ModuleLibraryMenuSelected');
verifyTrue(testCase, contains(callback, 'moduleCatalogueRowCanAdd(app, catalogueRow)'));
choices = methodSource(testCase, 'moduleLibraryPackagesForType');
verifyTrue(testCase, contains(choices, 'moduleCatalogueRowCanAdd(app, i)'));
picker = methodSource(testCase, 'chooseModuleFromLibrary');
verifyTrue(testCase, contains(picker, 'moduleCatalogueRowCanAdd(app, idx)'));
end

function testCatalogueSelectionReportsMetadataWithoutExecutingModule(testCase)
details = methodSource(testCase, 'showModuleCatalogueDetails');
verifyTrue(testCase, contains(details, 'item.details'));
verifyTrue(testCase, contains(details, 'item.reason'));
verifyTrue(testCase, contains(details, 'UIWorkspacePipelineTable.Tooltip'));
verifyFalse(testCase, contains(details, 'feval'));
guard = methodSource(testCase, 'moduleCatalogueRowCanAdd');
verifyTrue(testCase, contains(guard, 'item.canAdd'));
verifyTrue(testCase, contains(guard, 'which(item.module.entrypoint)'));
verifyTrue(testCase, contains(guard, 'sameModuleCataloguePath'));
end

function testClickRechecksEveryDeclaredEntrypoint(testCase)
guard = methodSource(testCase, 'moduleCatalogueRowCanAdd');
verifyTrue(testCase, contains(guard, 'struct2cell(item.module.entrypoints)'));
verifyTrue(testCase, contains(guard, 'for i = 1:numel(entrypoints)'));
verifyTrue(testCase, contains(guard, 'isempty(entrypoints{i})'));
verifyTrue(testCase, contains(guard, 'which(entrypoints{i})'));
verifyTrue(testCase, contains(guard, ...
    'sameModuleCataloguePath(app, fileparts(resolved), item.module.path)'));
verifyFalse(testCase, contains(guard, 'addpath('));
end

function testImplicitLegacyPackagesAreNormalizedOnlyForCatalogueComparison(testCase)
guard = methodSource(testCase, 'moduleCatalogueAllowsMutation');
verifyTrue(testCase, contains(guard, 'comparisonType = char(string(nodeType))'));
verifyTrue(testCase, contains(guard, 'comparisonPkg = char(string(pkg))'));
verifyTrue(testCase, contains(guard, 'isempty(comparisonPkg)'));
verifyTrue(testCase, contains(guard, 'comparisonPkg = comparisonType'));
for type = {'dataLoader','roiPattern','roiManual','roiGrid','roiTracked','roiExtract'}
    verifyTrue(testCase, contains(guard, ['''' type{1} '''']));
end
verifyTrue(testCase, contains(guard, "strcmpi(comparisonType, 'roiIdentify')"));
verifyTrue(testCase, contains(guard, 'app.AvailableModules{row,3}, comparisonPkg'));
controls = methodSource(testCase, 'selectedModuleTypeAndPackage');
verifyTrue(testCase, contains(controls, "pkg = ''"));
node = methodSource(testCase, 'makePipelineNode');
verifyTrue(testCase, contains(node, 'node.pkg = pkg'));
verifyFalse(testCase, contains(node, 'comparisonPkg'));
end

function testExistingNodeLoadingPreservesUnavailableSubtype(testCase)
loading = methodSource(testCase, 'selectTypeControlsForNode');
verifyTrue(testCase, contains(loading, 'selectExistingNodeSubtype(app, pkg)'));
verifyFalse(testCase, contains(loading, 'moduleCatalogueAllowsMutation'));
preserve = methodSource(testCase, 'selectExistingNodeSubtype');
verifyTrue(testCase, contains(preserve, 'app.SubtypeDropDown.Items'));
verifyTrue(testCase, contains(preserve, 'app.SubtypeDropDown.Value = subtype'));
node = methodSource(testCase, 'makePipelineNode');
verifyFalse(testCase, contains(node, 'ModuleCatalogue'));
verifyTrue(testCase, contains(node, 'node.pkg = pkg'));
verifyTrue(testCase, contains(node, 'node.params = applyRuntimeDefaultsToParams'));
end

function testPackageReferenceReadsOnlyCurrentlySelectedAdapter(testCase)
lookup = methodSource(testCase, 'registeredPluginPackageDir');
verifyTrue(testCase, contains(lookup, 'which(entrypoint)'));
verifyTrue(testCase, contains(lookup, 'sameModuleCataloguePath'));
verifyTrue(testCase, contains(lookup, "strcmp(module.distribution, 'external')"));
for name = {'registeredPluginPackageDir', 'pluginPackageExists', ...
        'openPluginBrowser', 'openBuiltinModuleBrowser'}
    block = methodSource(testCase, name{1});
    verifyFalse(testCase, contains(block, 'detecdiv_plugins_addpath'));
    verifyFalse(testCase, contains(block, 'detecdiv_plugins_list'));
    verifyFalse(testCase, contains(block, 'addpath('));
end
end

function testUiValidationUsesTheReadOnlyCatalogue(testCase)
source = testCase.TestData.source;
calls = regexp(source, ...
    '(?s)\[ok, report\] = validatePipeline\(pipeResolved, ctx, .*?\);', ...
    'match');
verifyNumElements(testCase, calls, 2);
for i = 1:numel(calls)
    verifyTrue(testCase, contains(calls{i}, "'readOnlyModuleDiscovery', true"));
    verifyTrue(testCase, contains(calls{i}, ...
        "'moduleCatalogue', [app.ModuleCatalogueItems.module]"));
end
end

function testExplicitCustomPackageChoiceStillActivatesSelectedPackage(testCase)
choice = methodSource(testCase, 'resolveCustomPackageChoice');
verifyTrue(testCase, contains(choice, 'addpath(info.root)'));
verifyTrue(testCase, contains(choice, "'customPackageDir', info.packageDir"));
guard = methodSource(testCase, 'moduleCatalogueAllowsMutation');
verifyTrue(testCase, contains(guard, "isfield(paramsPatch, 'customPackageDir')"));
verifyTrue(testCase, contains(guard, "isfield(paramsPatch, 'customPackageRoot')"));
browser = methodSource(testCase, 'openBuiltinModuleBrowser');
verifyTrue(testCase, contains(browser, "'PackagePaths', app.ModuleCataloguePackagePaths"));
end

function testBindingResolutionAlsoPreservesSelectedRelease(testCase)
calls=regexp(testCase.TestData.source, ...
    '(?s)\[pipe(?:Resolved|Obj), bindingResolution\] = pipelineResolveBindings\(.*?\);', ...
    'match');
verifyNumElements(testCase,calls,3);
for i=1:numel(calls)
    verifyTrue(testCase,contains(calls{i},"'readOnlyModuleDiscovery', true"));
    verifyTrue(testCase,contains(calls{i}, ...
        "'moduleCatalogue', [app.ModuleCatalogueItems.module]"));
end
end

function block = methodSource(testCase, name)
pattern = ['(?ms)^        function [^\n]*\<' name ...
    '\([^\n]*\n.*?(?=^        function |^    end\s*$)'];
block = regexp(testCase.TestData.source, pattern, 'match', 'once');
assertNotEmpty(testCase, block, ['Missing method: ' name]);
end
