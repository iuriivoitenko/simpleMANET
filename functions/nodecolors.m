function [ a, c ] = nodecolors( nodes )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

s = size(nodes);
a = zeros(s(2),1);
c = zeros(s(2),3);

for i=1:s(2)
    a(i) = nodes(i).radius;
    c(i,:) = (nodes(i).color);
end

end

