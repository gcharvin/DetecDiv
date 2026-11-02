function tests=testFeatureAnchorShift
tests=functiontests(localfunctions);
end

function testKnownFractionalTranslationWithGainOffset(t)
r=texture();mov=imtranslate(r,[-3.4 4.3],'linear','FillValues',15000);
mov=.7*mov+300;
[row,col,~,count,spread,correlation,reason]=roiExtract.featureAnchorShift(r,mov,[3 -3],20,20);
verifyLessThan(t,abs(row-4.3),.25);verifyLessThan(t,abs(col+3.4),.25);
verifyGreaterThan(t,count,10);verifyLessThan(t,spread,.3);
verifyGreaterThan(t,correlation,.9);verifyEqual(t,reason,'featureConsensus');
end

function testComparableOpposingMotionsAreAmbiguous(t)
r=texture();mov=r;
mov(:,1:256)=circshift(r(:,1:256),[0 8]);
mov(:,257:end)=circshift(r(:,257:end),[0 -8]);
[row,col,~,~,~,~,reason]=roiExtract.featureAnchorShift(r,mov,[0 0],20,20);
verifyTrue(t,isnan(row));verifyTrue(t,isnan(col));
verifyEqual(t,reason,'ambiguousFeatureConsensus');
end

function testLocalizedTextureCannotCertifyWholeField(t)
r=15000*ones(512);rng(383);
r(40:120,40:120)=15000+2500*imgaussfilt(randn(81),1.2);
mov=imtranslate(r,[3 2],'FillValues',15000);
[row,col]=roiExtract.featureAnchorShift(r,mov,[0 0],20,20);
verifyTrue(t,isnan(row));verifyTrue(t,isnan(col));
end

function testOutOfBoundMotionIsRejected(t)
r=texture();mov=imtranslate(r,[21 0],'FillValues',15000);
[row,col]=roiExtract.featureAnchorShift(r,mov,[0 0],20,20);
verifyTrue(t,isnan(row));verifyTrue(t,isnan(col));
end

function testFixedMaskEdgesDoNotManufactureStationaryFeatures(t)
mask=false(512);mask(50:460,50:460)=true;r=15000*double(mask);
[row,col]=roiExtract.featureAnchorShift(r,r,[0 0],20,20,[],true,mask);
verifyTrue(t,isnan(row));verifyTrue(t,isnan(col));
end

function r=texture()
rng(381);r=15000+2500*imgaussfilt(randn(512),1.2);
end
