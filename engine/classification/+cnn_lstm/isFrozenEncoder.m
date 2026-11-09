function yes = isFrozenEncoder(c)
%ISFROZENENCODER Opt-in fixed CNN features with a separately fitted LSTM.
yes=false;
try,yes=isfield(c.trainingParam,'frozen_encoder_head')&&isequal(c.trainingParam.frozen_encoder_head,true);catch,end
end
