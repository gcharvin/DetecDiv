function [row,col,score,match,unique]=anchorPatchProposal(ref,mov,r0,c0,h,w,prediction,limit,psrRadius)
% Bounded normalized pixel correlation, independent of Fourier whitening.
row=NaN; col=NaN; score=NaN; match=NaN;
unique=false;
% Unbounded displacement uses the Fourier/global proposal instead of an
% expensive full-field pixel search for every patch.
if isempty(limit)||~isfinite(limit)||limit<=0, return; end
limit=ceil(limit); [H,W]=size(mov);
rr=max(1,r0+round(prediction(1))-limit):min(H,r0+h-1+round(prediction(1))+limit);
cc=max(1,c0+round(prediction(2))-limit):min(W,c0+w-1+round(prediction(2))+limit);
if numel(rr)<h || numel(cc)<w, return; end
patch=ref(r0:r0+h-1,c0:c0+w-1);
if std(patch(:))<=eps, return; end
corr=normxcorr2(patch,mov(rr,cc));
ys=(1:size(corr,1))-h+rr(1)-r0;
xs=(1:size(corr,2))-w+cc(1)-c0;
valid=false(size(corr)); valid(h:numel(rr),w:numel(cc))=true;
valid=valid & abs(ys(:)-prediction(1))<=limit & abs(xs-prediction(2))<=limit;
search=corr;search(~valid)=-inf;[match,ix]=max(search(:));
if ~isfinite(match), return; end
ties=find(valid & corr>=match-max(eps,abs(match)*1e-8));
if numel(ties)>1
    [ty,tx]=ind2sub(size(corr),ties);
    [~,nearest]=min(hypot(ys(ty)-prediction(1),xs(tx)-prediction(2))); ix=ties(nearest);
end
[py,px]=ind2sub(size(corr),ix); row=ys(py); col=xs(px);
side=valid;
side(max(1,py-psrRadius):min(size(side,1),py+psrRadius), ...
    max(1,px-psrRadius):min(size(side,2),px+psrRadius))=false;
values=corr(side);
if isempty(values)
    unique=true;
else
    score=(match-mean(values))/max(eps,std(values));
    % A ridge from a straight edge has a high correlation but cannot locate
    % motion along the edge. Compare the best nonlocal alternative directly.
    alternative=max(values);
    unique=max(eps,1-match)/max(eps,1-alternative)<.95;
end
end
