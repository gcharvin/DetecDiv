function tests=testComputeDriftAdaptive
tests=functiontests(localfunctions);
end

function testCanonicalDefaultsAndLegacyPolicies(t)
p=roiExtract.setparam();d=roiExtract.driftDefaults();
verifyEqual(t,p.driftMethod,d.method);verifyEqual(t,p.driftRefMode,'adaptive');
verifyEqual(t,p.driftMaxStep,20);verifyEqual(t,p.driftReferenceInterval,d.referenceInterval);
verifyEqual(t,roiExtract.driftReferenceMode('robust','previous'),'fixed');
verifyEqual(t,roiExtract.driftReferenceMode('robust','first'),'fixed');
verifyEqual(t,roiExtract.driftReferenceMode('subpixel'),'fixed');
end

function testDefaultAllowsMeasuredSeventeenPixelJump(t)
r=texture();ims=cat(4,r,imtranslate(r,[17 0],'FillValues',15000));
f=fov();[~,d]=f.computeDrift('images',ims);
verifyTrue(t,all(d.accepted));verifyLessThan(t,abs(d.y(2)+17),.25);
f=fov();[~,d]=f.computeDrift('images',ims,'refmode','fixed','maxstep',10);
verifyFalse(t,d.accepted(2));verifyEqual(t,d.y(2),0,'AbsTol',1e-8);
end

function testEvolvingContentMatchesSingletonAndUnevenBlocks(t)
[ims,rows,cols]=evolving();args={'referenceinterval',8,'refimage',ims(:,:,1,1)};
f=fov();[out,full]=f.computeDrift('images',ims,args{:});
verifyLessThan(t,max(hypot(full.x+rows,full.y+cols)),.75);
verifyTrue(t,any(startsWith(full.estimation,'temporalFallback:keyframe')));
for widths={[7 16 18],[ones(1,41)]}
    f=fov();outBlocks=zeros(size(ims),'like',ims);first=1;
    for width=widths{1}
        idx=first:first+width-1;
        [outBlocks(:,:,:,idx),d]=f.computeDrift('images',ims(:,:,:,idx),'framesid',idx,args{:});
        first=first+width;
    end
    verifyEqual(t,d.x,full.x,'AbsTol',1e-8);verifyEqual(t,d.y,full.y,'AbsTol',1e-8);
    verifyEqual(t,d.referenceFrames,full.referenceFrames);verifyEqual(t,outBlocks,out);
end
end

function testRejectedFrameNeverBecomesReference(t)
[ims,~,~]=evolving();ims(:,:,1,25)=0;
f=fov();[~,d]=f.computeDrift('images',ims,'referenceinterval',4);
verifyFalse(t,d.accepted(25));verifyFalse(t,any(d.referenceFrames==25));
verifyTrue(t,d.accepted(26));verifyLessThan(t,abs(d.x(26)+3.75),.8);
end

function testColdResumeRebuildsTrustedKeyframe(t)
[ims,~,~]=evolving();folder=tempname;mkdir(folder);
cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
for k=1:41,imwrite(ims(:,:,1,k),fullfile(folder,sprintf('frame_%03d.tif',k)));end
f=fov();f.srcpath={folder};f.srclist={dir(fullfile(folder,'frame_*.tif'))};
f.channel={'test'};f.frames=41;f.interval=1;
args={'refimage',ims(:,:,1,1),'referenceinterval',8};
f.computeDrift('images',ims(:,:,:,1:27),'framesid',1:27,args{:});
saved=f.drift;f.drift=jsondecode(jsonencode(saved));f.driftReferenceState=[];
[~,resumed]=f.computeDrift('images',ims(:,:,:,28:end),'framesid',28:41,args{:});
f=fov();[~,full]=f.computeDrift('images',ims,args{:});
verifyEqual(t,resumed.x,full.x,'AbsTol',1e-8);verifyEqual(t,resumed.y,full.y,'AbsTol',1e-8);
verifyFalse(t,any(isfield(saved.adaptiveReference,{'gray','proc','edges'})));
mc=metaclass(f);props=mc.PropertyList;idx=strcmp({props.Name},'driftReferenceState');
verifyTrue(t,props(idx).Transient);
end

function r=texture()
rng(171);r=uint16(15000+2500*imgaussfilt(randn(256),1.2));
end

function [ims,rows,cols]=evolving()
r=texture();other=uint16(15000+2500*imgaussfilt(randn(256),1.2));
rows=0:.15:6;cols=-rows/2;ims=zeros(256,256,1,41,'uint16');
for k=1:41
    a=(k-1)/40;im=uint16((1-a)*double(r)+a*double(other));
    ims(:,:,1,k)=imtranslate(im,[cols(k) rows(k)],'linear','FillValues',15000);
end
end
