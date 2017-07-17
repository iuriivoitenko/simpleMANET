classdef ICMPv6 < IPv6
    %ICMPV6 Summary of this class goes here
    %   Class represents ICMPv6 protocol
    
    properties
        type
        code
        size
        num
        % runtime vars
        sent = 0;  
        timer
        timestamp
    end
    
    properties (Constant)
        show = 1;             % show protocol packets in the debug window
        PING_PERIOD = 1000;
    end 
    
    methods
        function [obj, pkt] = timeout( obj, d, t )
            pkt = [];
            obj.timestamp = t;
            obj.timer = obj.timer + d;
            if (obj.timer >= obj.PING_PERIOD && obj.type == 128)
                obj.timer = mod(obj.PING_PERIOD, d);
            
            end
            
        end
        
        function ping( obj, dst, len, num )
            obj.type = 128;
            obj.code = 0;
            obj.dst = dst;
            obj.size = len;
            obj.num = num;
        end        
        
        function msg = process_datagram( obj, type, code )
            switch type            
                % ICMPv6 error messages
                case 1 % destination unreachable                        
                    switch code
                        case 0 % no route to destination
                        case 1 % communication with destination administratively prohibited
                        case 2 % beyond scope of source address
                        case 3 % address unreachable
                        case 4 % port unreachable
                        case 5 % source address failed ingress/egress policy
                        case 6 % reject route to destination
                        case 7 % error in source routing header
                        otherwise     
                            msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, seq=%d, prev=%d, hops=%d, ttl=%d \n', p, t, pkt.src, pkt.dst, pkt.next, type, pkt.appdata.jreq.seq, pkt.appdata.jreq.prev, pkt.appdata.jreq.hops, pkt.ttl);
                    end
                                        
                case 2 % packet too big 
                    switch code
                        case 0
                        otherwise
                            obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, count=%d, nonce=%d, group=%s \n', p, t, pkt.src, pkt.dst, pkt.next, type, pkt.appdata.jtable.count, pkt.appdata.jtable.reserved, pkt.appdata.jtable.mgroup);                                 
                    end                    
                    
                case 3 % time exceeded
                    switch code
                        case 0 % hop limit exceeded in transit
                        case 1 % fragment reassembly time exceeded
                        otherwise
                            obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %s, PROTO: %s, type=%s, seq=%d, len=%d, last=%d \n', p, t, pkt.src, pkt.dst, pkt.next, type, pkt.appdata.dataseq, pkt.len, pkt.appdata.prev);
                    end                    
                   
                case 4 % parameter problem
                    switch code
                        case 0 % erroneous header field encountered
                        case 1 % unrecognized Next Header type encountered
                        case 2 % unrecognized IPv6 option encountered
                        otherwise
                            obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %s, PROTO: %s, type=%s, seq=%d, len=%d, last=%d \n', p, t, pkt.src, pkt.dst, pkt.next, type, pkt.appdata.dataseq, pkt.len, pkt.appdata.prev);
                    end  
                    
                % ICMPv6 informational messages
                case 128 % echo request
                    
                case 129 % echo reply
                    
                otherwise                    
                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, ODMRP packet unknown\n', p, t, pkt.src, pkt.dst);
                    
            end
        end
    end
    
end

