function [row,col,score,count,spread,correlation,reason,points,diagnostics] = featureAnchorShift(ref,mov,prediction,limit,maxStep,points,subpixel,mask)
% FEATUREANCHORSHIFT Distributed persistent-corner consensus against an anchor.
% Small salient patches supplement the regular grid when changing foreground
% obscures most large tiles. No ROI, trap template or biological model is used.
if nargin<6,points=[];end
if nargin<7,subpixel=true;end
if nargin<8,mask=[];end
row=NaN;col=NaN;score=NaN;count=0;spread=NaN;correlation=NaN;
reason='insufficientFeatureConsensus';
diagnostics=struct('points',[],'proposals',[],'matches',[],'locations',[],'modes',[]);
if isempty(limit)||~isfinite(limit)||limit<=0,return;end
if ~isempty(maxStep)&&maxStep>0,limit=min(limit,maxStep);end
if isempty(points),points=anchorPoints(ref,mask);end
diagnostics.points=points;
half=24;patchSize=48;n=0;
proposals=zeros(size(points,1),2);matches=zeros(size(points,1),1);scores=matches;
locations=zeros(size(points));
for k=1:size(points,1)
    r0=points(k,1)-half;c0=points(k,2)-half;
    [pr,pc,ps,match,unique]=roiExtract.anchorPatchProposal( ...
        ref,mov,r0,c0,patchSize,patchSize,prediction,limit,6);
    if ~isfinite(pr)||~unique||match<.5,continue;end
    [pr,pc,match]=roiExtract.refineAnchorShift(ref,mov,r0,c0,patchSize,patchSize,pr,pc,subpixel);
    if ~isfinite(pr)||~isfinite(pc)||match<.5|| ...
            abs(pr-prediction(1))>limit||abs(pc-prediction(2))>limit,continue;end
    if ~isempty(maxStep)&&maxStep>0&&hypot(pr-prediction(1),pc-prediction(2))>maxStep,continue;end
    n=n+1;proposals(n,:)=[pr pc];matches(n)=match;scores(n)=ps;locations(n,:)=points(k,:);
end
proposals=proposals(1:n,:);matches=matches(1:n);scores=scores(1:n);locations=locations(1:n,:);
diagnostics.proposals=proposals;diagnostics.matches=matches;diagnostics.locations=locations;
if n<3,return;end
modes=struct('row',{},'col',{},'weight',{},'members',{});radius=3;
for k=1:n
    members=find(hypot(proposals(:,1)-proposals(k,1),proposals(:,2)-proposals(k,2))<=radius);
    if numel(members)<3,continue;end
    % Refit the local consensus before ranking. Salience order must not let
    % an early, weaker seed suppress a nearby, better-supported estimate.
    center=proposals(k,:);
    for iteration=1:4
        members=find(hypot(proposals(:,1)-center(1),proposals(:,2)-center(2))<=radius);
        if numel(members)<3,break;end
        weights=matches(members).^4;
        center=[weightedMedian(proposals(members,1),weights) weightedMedian(proposals(members,2),weights)];
    end
    if numel(members)<3,continue;end
    weights=matches(members).^4;
    if sum(weights)^2/sum(weights.^2)<2.5,continue;end
    span=(max(locations(members,:),[],1)-min(locations(members,:),[],1))./size(ref);
    if max(span)<.5||min(span)<.2,continue;end
    rr=weightedMedian(proposals(members,1),weights);cc=weightedMedian(proposals(members,2),weights);
    modes(end+1)=struct('row',rr,'col',cc,'weight',sum(weights),'members',members); %#ok<AGROW>
end
diagnostics.modes=modes;
if isempty(modes),return;end
[~,best]=max([modes.weight]);chosen=modes(best);
for k=1:numel(modes)
    if k~=best&&hypot(modes(k).row-chosen.row,modes(k).col-chosen.col)>radius&& ...
            modes(k).weight>=.75*chosen.weight
        reason='ambiguousFeatureConsensus';return;
    end
end
members=chosen.members;weights=matches(members).^4;
row=chosen.row;col=chosen.col;count=numel(members);
spread=weightedMedian(hypot(proposals(members,1)-row,proposals(members,2)-col),weights);
correlation=weightedMedian(matches(members),weights);score=median(scores(members),'omitnan');
reason='featureConsensus';
end

function points=anchorPoints(ref,mask)
points=zeros(0,2);
if min(size(ref))<64||std(ref(:))<=eps,return;end
[gx,gy]=imgradientxy(double(ref),'sobel');
a=imgaussfilt(gx.^2,1.5);b=imgaussfilt(gy.^2,1.5);c=imgaussfilt(gx.*gy,1.5);
response=max(0,2*(a.*b-c.^2)./max(eps,a+b));
valid=response==imdilate(response,ones(3))&response>max(response(:))*.01;
valid(1:32,:)=false;valid(end-31:end,:)=false;
valid(:,1:32)=false;valid(:,end-31:end)=false;
if ~isempty(mask)
    % A fixed inclusion mask must not manufacture stationary corner votes.
    valid=valid&imerode(mask~=0,ones(49));
end
indices=find(valid);[~,order]=sort(response(indices),'descend');
% Cap salient points per spatial cell, so a crowded foreground region cannot
% consume the feature budget before persistent structures elsewhere are seen.
bins=zeros(8);imageSize=size(ref);
for idx=reshape(indices(order),1,[])
    [r,col]=ind2sub(size(ref),idx);
    br=min(8,ceil(r/imageSize(1)*8));bc=min(8,ceil(col/imageSize(2)*8));
    if bins(br,bc)>=3,continue;end
    if ~isempty(points)&&any(max(abs(points-[r col]),[],2)<24),continue;end
    points(end+1,:)=[r col]; %#ok<AGROW>
    bins(br,bc)=bins(br,bc)+1;
    if size(points,1)>=192,break;end
end
end

function v=weightedMedian(values,weights)
[values,idx]=sort(values);weights=weights(idx);
v=values(find(cumsum(weights)>=sum(weights)/2,1));
end
