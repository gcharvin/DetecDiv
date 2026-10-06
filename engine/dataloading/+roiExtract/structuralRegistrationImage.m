function out=structuralRegistrationImage(image,hipassSigma,denoiseSigma,mask)
% Polarity-independent image structure for registration across contrast changes.
image=double(image);
if denoiseSigma>0, image=imgaussfilt(image,denoiseSigma); end
[gx,gy]=gradient(image); out=hypot(gx,gy);
if hipassSigma>0, out=out-imgaussfilt(out,hipassSigma); end
if ~isempty(mask), out=out.*double(mask); end
out=out-mean(out(:)); scale=std(out(:));
if scale>0, out=out/scale; end
end
