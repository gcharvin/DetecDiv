function tests=testScoreEmptyImageNotice
tests=functiontests(localfunctions);
end
function setupOnce(~)
detecdiv_setup_path;
end
function testMissingTailIsExplicitAndNavigationRestoresImage(testCase)
r=roi('tail',[]);r.image=uint16(ones(3,4,2,70));r.image(:,:,:,65:70)=0;
r.display.channel={'BF','GFP'};r.display.indexed=[false false];r.channelid=[1 2];
before=r.image;fig=figure('Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
opts=struct('channel',{{'BF','GFP'}});
score_updateEmptyImageNotice(fig,r,opts,64);
verifyEmpty(testCase,findall(fig,'Tag','ScoreEmptyImageNotice'));
score_updateEmptyImageNotice(fig,r,opts,65);
notice=findall(fig,'Tag','ScoreEmptyImageNotice');verifyNumElements(testCase,notice,1);
verifyTrue(testCase,any(contains(string(notice.String),'frame 65')));
score_updateEmptyImageNotice(fig,r,opts,70);
verifyNumElements(testCase,findall(fig,'Tag','ScoreEmptyImageNotice'),1);
verifyTrue(testCase,any(contains(string(notice.String),'frame 70')));
score_updateEmptyImageNotice(fig,r,opts,63);
verifyEmpty(testCase,findall(fig,'Tag','ScoreEmptyImageNotice'));
verifyEqual(testCase,r.image,before);
end
function testEmptyMasksAreNotMissingImages(testCase)
r=roi('masks',[]);r.image=zeros(3,4,2,2,'uint16');
r.display.channel={'mask','BF'};r.display.indexed=[true false];r.channelid=[1 2];
r.image(:,:,2,:)=5;
fig=figure('Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
score_updateEmptyImageNotice(fig,r,struct('channel',{{'mask'}}),1);
verifyEmpty(testCase,findall(fig,'Tag','ScoreEmptyImageNotice'));
score_updateEmptyImageNotice(fig,r,struct('channel',{{'mask','BF'}}),1);
verifyEmpty(testCase,findall(fig,'Tag','ScoreEmptyImageNotice'));
end
function testSelectedLogicalChannelUsesCompactImagePlane(testCase)
r=roi('compact',[]);r.image=zeros(3,4,1,2,'uint16');r.channelid=2;
r.display.channel={'mask','BF'};r.display.indexed=[true false];
fig=figure('Visible','off');finish=onCleanup(@()delete(fig)); %#ok<NASGU>
score_updateEmptyImageNotice(fig,r,struct('channel',2),1);
verifyNumElements(testCase,findall(fig,'Tag','ScoreEmptyImageNotice'),1);
r.image(:,:,1,2)=10;
score_updateEmptyImageNotice(fig,r,struct('channel',{{'BF'}}),2);
verifyEmpty(testCase,findall(fig,'Tag','ScoreEmptyImageNotice'));
end
