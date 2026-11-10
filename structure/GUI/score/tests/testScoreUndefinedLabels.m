function tests = testScoreUndefinedLabels
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));
end

function testMissingCategoricalHasVisibleLevelWithoutChangingGT(testCase)
classes = {'unbud','small','large','dead','empty','clog'};
v = categorical({'clog';'';'large'}, classes);
tbl = table(v, 'VariableNames', {'labels_training'});
[y, names, ticks] = score_extractYData(tbl, 1);
verifyEqual(testCase, y, [6;0;3]);
verifyEqual(testCase, names, {'labels_training'});
verifyEqual(testCase, ticks.ticks, 0:6);
verifyEqual(testCase, ticks.labels, [{'undefined'};classes(:)]);
verifyTrue(testCase, isundefined(tbl.labels_training(2)));
verifyEqual(testCase, categories(tbl.labels_training), classes(:));
end

function testLegacyUndefinedCategoryReusesExistingLevel(testCase)
v = categorical({'small';'';'undefined'}, {'small','undefined','large'});
[y, ~, ticks] = score_extractYData(table(v), 1);
verifyEqual(testCase, y, [1;2;2]);
verifyEqual(testCase, ticks.ticks, 1:3);
verifyEqual(testCase, ticks.labels, {'small';'undefined';'large'});
end

function testMissingTextLabelsAreVisible(testCase)
v = ["small";missing;"large"];
[y, ~, ticks] = score_extractYData(table(v), 1);
verifyEqual(testCase, y(2), 0);
verifyEqual(testCase, ticks.labels{1}, 'undefined');
end

function testNumericMissingValuesRemainGaps(testCase)
v = [1;NaN;3];
[y, ~, ticks] = score_extractYData(table(v), 1);
verifyEqual(testCase, y, v);
verifyFalse(testCase, ticks.isLabel);
end
function testOverlaidPredictionsAndLegacyTrainingAlignByName(testCase)
classes={'budding','arrested','dead'};
pred=categorical({'budding';'arrested';'dead';''},classes);
training=categorical({'budding';'arrested';'dead';'undefined'},[{'undefined'} classes]);
tbl=table(pred,training,'VariableNames',{'labels','labels_training'});before=tbl;
[y,~,info]=score_extractYData(tbl,[1 2]);
verifyEqual(testCase,y,[1 1;2 2;3 3;0 0]);
verifyEqual(testCase,info.ticks,0:3);verifyEqual(testCase,info.labels,[{'undefined'} classes]');
verifyEqual(testCase,tbl,before);
% Selection order may choose another numeric axis, but class names coincide.
[y,~,info]=score_extractYData(tbl,[2 1]);
verifyEqual(testCase,y,[2 2;3 3;4 4;1 1]);
verifyEqual(testCase,info.ticks,1:4);verifyEqual(testCase,info.labels,[{'undefined'} classes]');
verifyEqual(testCase,tbl,before);
end
function testOverlaidReorderedCategoriesAndAdditionalClass(testCase)
a=categorical({'budding';'dead';'arrested'}, {'dead','budding','arrested'});
b=categorical({'budding';'dead';'empty'}, {'empty','arrested','budding','dead'});
[y,~,info]=score_extractYData(table(a,b),[1 2]);
verifyEqual(testCase,y,[2 2;1 1;3 4]);
verifyEqual(testCase,info.labels,{'dead';'budding';'arrested';'empty'});
end
function testOverlayAddsUndefinedLevelWithoutShiftingKnownClasses(testCase)
a=categorical({'budding';'dead'}, {'budding','arrested','dead'});
b=categorical({'budding';'undefined'}, {'undefined','budding','arrested','dead'});
[y,~,info]=score_extractYData(table(a,b),[1 2]);
verifyEqual(testCase,y,[1 1;3 0]);verifyEqual(testCase,info.ticks,0:3);
verifyEqual(testCase,info.labels,{'undefined';'budding';'arrested';'dead'});
end
