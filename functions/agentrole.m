function [ A ] = agentrole( NODES, S, R )
%   This function creates a NODES by 1 vector A
%   with S senders and R receivers
%   where 0 - no data traffic, 1 - multicast receiver, 2 - multicast sender

if S+R > NODES
    error( 'wrong number of senders and receivers' );
end

A = zeros(1,NODES);

for i=1:S
    A(i) = 2;
end

for i=1:R
    A(i+S) = 1;
end

p=randperm(prod(size(A)));
A(:)=A(p);

end

