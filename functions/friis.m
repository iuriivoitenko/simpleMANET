function [ d ] = friis( freq, Pr, Pt, Gt, Gr, L, F )
%FRIIS formula calculation for distance
% freq - frequency, Hz
% Pr - receiver sensitivity, dBm
% Pt - transmitter power, dBm
% Gt - tx antenna gain, dBi
% Gr - rx antenna gain, dBi
% L - other losses (cables, connectors etc), dB
% F - Fade margin, dB
% d - distance, m

c = physconst('lightspeed');
lambda = c / freq;
Lp = Pr - Pt - Gt - Gr + L;
a = Lp + F;
d = lambda / (4*pi*(10^(a/20)));

end

