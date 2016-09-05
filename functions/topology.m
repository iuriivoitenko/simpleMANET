function [ A ] = topology( coords, limit, nodes )
%UNTITLED Summary of this function goes here
%   function converts coordinates to topology matrix

s = size(coords(:,1));
A = zeros(s(1));

for i=1:s(1)
    for j=1:s(1)
        if i~=j
            x1 = coords(i,1);
            y1 = coords(i,2);
            x2 = coords(j,1);
            y2 = coords(j,2);

            range=sqrt((x2-x1)^2+(y2-y1)^2);
            if (range)<limit % remove edge and update graph
                A(i,j)=1;
            else        
                A(i,j)=0;
            end
        else
            A(i,i)=0;
        end
    end
end
end

