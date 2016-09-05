classdef ProtocolIP 
    % ProtocolIP Summary of this class goes here
    % simplified representation of IPv6 protocol
    
    properties
        src
        dst
        ttl = 0;
        len = 0;
        next
        % common transport layer params
        srcport
        dstport
    end
    
    methods       
       
       function obj = setTtl(obj,ttl)          
          if (isnumeric(ttl))
             obj.ttl = ttl;
          else
             error('Invalid ttl');
          end
       end 
       
       function obj = setLen(obj,len)          
          if (isnumeric(len))
             obj.len = len;
          else
             error('Invalid length');
          end
       end 
       
       function obj = setNext(obj,next)          
             obj.next = next;
       end 
       
       function obj = setSrcport(obj,srcport)          
          if (isnumeric(srcport))
             obj.srcport = srcport;
          else
             error('Invalid source port');
          end
       end 
       
       function obj = setDstport(obj,dstport)          
          if (isnumeric(dstport))
             obj.dstport = dstport;
          else
             error('Invalid destination port');
          end
       end       
       
       function out = check_ip(id,pkt)
           if pkt.src == id % loopback own packet               
               out = -1;
           elseif ((strcmpi(num2str(pkt.dst),'0') == 0) && (strcmpi(num2str(pkt.dst),num2str(id)) == 0)) % dest is neither me nor broadcast 
               out = -2;
           elseif pkt.ttl == 0 % TTL reached zero
               out = -3;
           else
               out = 0;
           end
       end

    end
    
end

