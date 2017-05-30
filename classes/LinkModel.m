classdef LinkModel < handle
    %LINKMODEL class
    %   Represents a link model for a node

    properties   
        id
        mac
        proto
        busy
        until
        enabled
        src
        lastlen = 0;
        collisions = 0;
        carrier = 0;
        err
        pkt % here we store a packet being transmitted
    end
    
    events
        finishedSending
    end
    
    methods
        function obj = LinkModel( id, proto, ena )
                                      
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
            obj.enabled = ena;
            obj.lastlen = 0;
            obj.collisions = 0;
            obj.err = 0;
            obj.src = '';
            obj.proto = upper(char(proto));
            
        end
                
        function n = get.proto( obj )
            n = obj.proto;
        end
        
        function b = checkLinkBusy( obj, t )
            % each protocol has its own check link state 
            switch obj.proto
                case 'ALOHA'
                    b = 0;
                case 'CSMA' 
                    if obj.busy == 0 % send, if channel idle
                        obj.mac.flush();
                        b = 0;
                    else                        
                        if obj.mac.retry < obj.mac.maxretry
                            if obj.mac.timeout == 0 % timer not running
                                obj.mac.retry = 1;
                                obj.mac.backoff = obj.mac.RandomBackoff;
                                obj.mac.timeout = t + obj.mac.backoff;
                                b = 1; % start timer
                            elseif obj.mac.timeout >= t % timer expired
                                if obj.busy == 1 % channel is still busy, increase retry and backoff timer
                                    obj.mac.retry = obj.mac.retry + 1;
                                    obj.mac.timeout = t + (obj.mac.backoff * obj.mac.retry);
                                    b = 1;
                                else % channel is idle, send packet now
                                    obj.mac.flush();
                                    b = 0; 
                                end
                            else                                
                                b = 1; % timer not expired
                            end
                        else
                            obj.mac.flush();
                            b = 1; % drop
                        end
                    end
                case 'S-ALOHA' 
                    b = 0;
                case 'TDMA' 
                    b = 0;
                case 'CSMA-CA'
                    b = 0;
                otherwise
                    error('Unsupported MAC protocol');
            end 
        end
        
        function b = isBusy( obj )
            
            if obj.enabled == 0
                b = 0;
                return;
            end
            
            % each protocol has its own busy state 
            switch obj.proto
                case 'ALOHA'
                    [b, c] = obj.mac.isBusy(obj.err, obj.busy);
                    if c == 1
                        obj.collisions = obj.collisions + 1;
                        warning('Collision detected at Node %d', obj.id);
                    end
                case 'CSMA' 
                    b = 0;
                case 'S-ALOHA' 
                    b = 0;
                case 'TDMA' 
                    b = 0;
                case 'CSMA-CA'
                    b = 0;
                otherwise
                    error('Unsupported MAC protocol');
            end                                                                                               
        end
        
        function obj = linkLockTx(obj,src,time,pkt)
            if (isnumeric(time))
                if obj.enabled == 1
                    obj.busy = obj.busy + 1;
                end
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
            if obj.enabled == 1
                obj.busy = obj.busy + 1;
            end
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

