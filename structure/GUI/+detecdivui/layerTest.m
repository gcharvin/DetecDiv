function layerTest()
%LAYERTEST Contrast, colors, label IDs, temporal state and source immutability.
phase = uint32([0 50;100 200]);
green = uint32([200 0;100 50]);
labels = uint32([0 1;65536 0]);
project = shallow(); project.fov.roi = roi('layers',[1 1 2 2]);
source = project.fov.roi;
source.image = cat(3,phase,green,labels);
source.image(:,:,:,2) = cat(3,phase+20,green+20,labels);
source.channelid = [1 2 3];
source.display.channel = {'Phase','GFP','Cells'};
source.display.indexed = [false false true];
source.display.selectedchannel = [true false false];
source.display.alpha = [1 1 0.5];
beforePixels = source.image; beforeDisplay = source.display;
session = detecdivui.Session(project); session.selectZone(1);
model = detecdivui.LayerModel(); model.configure(session,1);
assert(strcmp(model.Layers(3).kind,'Labels'));
first = model.compose(1,1);
assert(first.native && isequal(first.pixels,phase));
model.setLimits(1,[0 200]);
second = model.compose(2,1);
assert(second.native && isequal(second.limits,[0 200]));
assert(isequal(second.pixels,phase+20));
model.setColor(1,'1 0 0');
model.setVisible(2,true); model.setColor(2,'0 1 0'); model.setLimits(2,[0 200]);
view = model.compose(1,1);
assert(isequal(reshape(view.pixels(1,1,:),1,3),uint8([0 255 0])));
assert(isequal(reshape(view.pixels(2,1,:),1,3),uint8([128 128 0])));
model.setOpacity(2,0.5);
view = model.compose(1,1);
assert(isequal(reshape(view.pixels(1,1,:),1,3),uint8([0 128 0])));
base = view.pixels;
model.setVisible(3,true); model.setColor(3,'0 0 1'); model.setOpacity(3,0.5);
view = model.compose(1,1);
assert(isequal(view.pixels(1,1,:),base(1,1,:))); % label zero is transparent
assert(isequal(reshape(view.pixels(1,2,:),1,3),uint8([32 0 128]))); % ID 1 remains visible
assert(isequal(reshape(view.pixels(2,1,:),1,3),uint8([64 32 128])));
model.setColor(3,'Labels'); view = model.compose(1,1);
expected = uint8(double(reshape(base(2,1,:),1,3))*0.5 + 255*score_trackColor(65536)*0.5);
assert(isequal(reshape(view.pixels(2,1,:),1,3),expected)); % no uint16 label truncation
model.solo(1); model.autoContrast(1,2);
assert(isequal(model.Layers(1).limits,[20 220]));
try
    model.setLimits(1,[100 20]); error('Expected invalid contrast rejection.');
catch err
    assert(strcmp(err.identifier,'detecdivui:Contrast'));
end
try
    model.setColor(1,'not-a-colormap'); error('Expected invalid color rejection.');
catch err
    assert(contains(err.identifier,'Color') || contains(err.identifier,'Colormap'));
end
% Negative/fractional source values stay in physical units in the UI.
project.fov.roi(2) = roi('physical',[1 1 2 2]);
physical = project.fov.roi(2); physical.image = [-1 0;1 3];
physical.display.channel = {'Signal'};
session.selectZone(2); model.configure(session,1);
view = model.compose(1,1);
assert(view.native && isequal(view.limits,[-1 3]));
model.setColor(1,'turbo'); view = model.compose(1,1);
map = score_colormapFromName('turbo',256);
assert(isequal(reshape(view.pixels(2,2,:),1,3),uint8(255*map(end,:))));
assert(isequal(physical.image,[-1 0;1 3]));
session.selectZone(1); model.configure(session,1);
assert(isequal(model.Layers(1).limits,[20 220]) && strcmp(model.Layers(1).color,'1 0 0'));
assert(isequal(source.image,beforePixels) && isequal(source.display,beforeDisplay));
model.solo(1); model.read(1,1);
source.image(:,:,1,1) = phase+10;
assert(isequal(model.read(1,1),phase)); % bounded current-frame cache
model.invalidate(); assert(isequal(model.read(1,1),phase+10));
disp('Layer test passed: score rendering, labels, opacity, physical contrast, state and source immutability.');
end
