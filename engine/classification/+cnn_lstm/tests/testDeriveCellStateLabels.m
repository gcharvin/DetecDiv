function tests=testDeriveCellStateLabels
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);startup;
end
function testSingleDeadOverridesArrest(testCase)
labels=repmat("large",150,1);labels(37)="dead";
r=cnn_lstm.deriveCellStateLabels(labels,'FrameRange',[1 120]);
verifyEqual(testCase,{r.windows.state},{'dead','arrested'});
verifyEqual(testCase,r.windows(1).deadFrameCount,1);
end
function testRepeatedAlternationBudding(testCase)
labels=repmat([repmat("small",10,1);repmat("large",10,1)],6,1);
r=cnn_lstm.deriveCellStateLabels(labels);
verifyEqual(testCase,{r.windows.state},{'budding','budding'});
end
function testDeadWinsEvenWithMissingTeacherFrames(testCase)
labels=strings(60,1);labels(20)="dead";
r=cnn_lstm.deriveCellStateLabels(labels);
verifyEqual(testCase,r.windows.state,'dead');
verifyEqual(testCase,r.ids,repmat(3,60,1));
end
function testStrictlyLongerThanWindow(testCase)
r=cnn_lstm.deriveCellStateLabels(repmat("small",60,1));
verifyEqual(testCase,r.windows.state,'budding');
r=cnn_lstm.deriveCellStateLabels(repmat("small",61,1),'FrameRange',[1 60]);
verifyEqual(testCase,r.windows.state,'arrested');
end
function testWholeWindowMustBeContained(testCase)
labels=[repmat("small",30,1);repmat("large",70,1);repmat("small",50,1)];
r=cnn_lstm.deriveCellStateLabels(labels,'FrameRange',[1 120]);
verifyEqual(testCase,r.longNoAlternationPeriods,[31 100]);
verifyEqual(testCase,{r.windows.state},{'budding','budding'});
end
function testMissingTeacherRemainsUnlabelled(testCase)
labels=[repmat("large",150,1);repmat("",70,1)];
r=cnn_lstm.deriveCellStateLabels(labels,'FrameRange',[1 180]);
verifyEqual(testCase,{r.windows.state},{'arrested','arrested','undefined'});
verifyEqual(testCase,r.ids(121:180),zeros(60,1));
end
function testUnknownDoesNotBridgeEvidence(testCase)
labels=[repmat("small",60,1);"";repmat("small",59,1)];
r=cnn_lstm.deriveCellStateLabels(labels);
verifyEmpty(testCase,r.longNoAlternationPeriods);
verifyEqual(testCase,{r.windows.state},{'budding','undefined'});
end
function testUnbudBetweenSmallAndLargeStillAlternates(testCase)
labels=[repmat("small",20,1);repmat("unbud",5,1);repmat("large",35,1)];
r=cnn_lstm.deriveCellStateLabels(labels);
verifyEqual(testCase,r.alternationFrames,26);
verifyEqual(testCase,r.windows.state,'budding');
end
function testTrailingPartialWindowIsNotAFullInterval(testCase)
r=cnn_lstm.deriveCellStateLabels(repmat("dead",100,1));
verifyEqual(testCase,{r.windows.state},{'dead','undefined'});
verifyEqual(testCase,r.windows(2).reason,'partial_window');
end
