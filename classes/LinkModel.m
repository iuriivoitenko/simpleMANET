classdef LinkModel < handle
    %LINKMODEL class
    %   Represents a link model for a node

    properties   
        id
        mac
        proto
        busy
        until
        lastlen
        src
        collisions = 0;
        carrier = 0;
        err
        pkt % here we store a packet being transmitted
    end
    
    events
        finishedSending
    end
    
    methods
        function obj = LinkModel( id, proto )
                                      
            switch upper(char(proto))
                case 'ALOHA'
                    obj.mac = ALOHA;
                case 'S-ALOHA'
                    obj.mac = SALOHA;
                case 'TDMA'
                    obj.mac = TDMA;
                case 'CSMA'
                    obj.mac = CSMA;
                case 'CSMA-CA'
                    obj.mac = CSMACA;
                otherwise
                    error('Unsupported MAC protocol');
            end
            
            obj.id = id;            
            obj.busy = 0;
            obj.until = 0;
            obj.lastlen = 0;
            obj.collisions = 0;
            obj.err = 0;
            obj.src = '';
            obj.proto = proto;
            
        end
                
        function n = get.proto( obj )
            n = obj.proto;
        end
        
        function b = isBusy( obj )
            if (obj.err == 1)
                b = 1;
            elseif obj.busy > 0 && obj.err == 0 
                b = 1;
                obj.collisions = obj.collisions + 1;
                warning('Collision detected at Node %d', obj.id);
            elseif obj.busy > 0
                b = 1;
            else
                b = 0;
            end
        end
        
        function obj = linkLockTx(obj,src,time,pkt)
            if (isnumeric(time))
                obj.busy = obj.busy + 1;
                obj.src = src;               
                obj.until = time;
                obj.pkt = pkt;
                %fprintf('%d locking link for %d ms as sender\r\n',obj.id,time);
            else
                error('Invalid parameter');
            end
        end 
        
        function obj = linkLockRx(obj,src)
            obj.carrier = obj.carrier + 1;
            obj.busy = obj.busy + 1;
            obj.src = src;    
            if obj.busy > 1
                %fprintf('%d senses carrier on link from %d with collision\r\n',obj.id, src); 
                warning('Link collision at Node %d, src: %d', obj.id, src);
                obj.collisions = obj.collisions + 1;
                obj.err = 1;
            else                
                %fprintf('%d senses carrier on link from %d\r\n',obj.id, src); 
                obj.err = 0;
            end
        end 
        
        function obj = linkReleaseRx(obj)
            if obj.busy > 0
                obj.busy = obj.busy - 1;
            end
        end
        
        function obj = linkReleaseTx(obj)
            if obj.busy > 0
                obj.busy = obj.busy - 1;
            end
        end        
        
        function obj = timeout(obj,t) % downcounter for the link busy time, processed at Node's sampling rate
            if obj.until > 0
                obj.until = obj.until - t;
                if obj.until <= 0
                    %fprintf('link timeout at %d\r\n',obj.id);
                    notify(obj,'finishedSending');   % link is available again
                end
            end
        end
        
    end
    
end

