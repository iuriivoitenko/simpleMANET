classdef PhyModel < handle
% PHYMODEL class defines PHY layer parameters
% modulation - will be used to calculate BER
% bitrate - will be used to compute duration in TX state
% coding - channel coding rate
% Pt - transmit power, dBm
% Pr - receiver sensitivity, dBm
% Gt - transmit antenna gain, dBi
% Gr - receive antenna gain, dBi
% L - other losses, dB
% Fade - fade margin, dB

    properties (Access = private)
        radio
        bypass = 0
        sending
    end

    properties
        freq
        modulation
        bitrate
        coding
        Pt
        Pr
        Gt
        Gr
        L
        Fade

    end
    
    methods
        function obj = PhyModel( bypassrange, range )
            obj.radio = range;
            obj.bypass = bypassrange;
            obj.sending = 0;
        end
            
        % communication range 
        function r = range( obj )
            if obj.bypass == 1
                r = obj.radio;
            else                
                r = friis(obj.freq, obj.Pr, obj.Pt, obj.Gt, obj.Gr, obj.L, obj.Fade);
            end            
        end
        
        % how long a given packet is being transmitted, ms
        function d = duration( obj, packetlen )
            d = (packetlen * 8 * 1000 / obj.bitrate) / obj.coding; 
        end
                
        function s = get.modulation( obj )
            s = obj.modulation;
        end  
        
        function b = get.freq( obj )
            b = obj.freq;
        end
        
        function set.freq(obj,b)
          if (isnumeric(b))
            obj.freq = b;
          else
            error('Invalid frequency, f.ex. 400*10^6');
          end
        end
        
        function b = get.bitrate( obj )
            b = obj.bitrate;
        end
        
        function set.bitrate(obj,b)
          if (isnumeric(b))
            obj.bitrate = b;
          else
            error('Invalid bitrate, f.ex. 100000');
          end
        end
        
        function b = get.coding( obj )
            b = obj.coding;
        end
        
        function set.coding(obj,c)
          if (isnumeric(c))
            obj.coding = c;
          else
            error('Invalid coding rate, f.ex. 1/2, 3/4, 1');
          end
        end
        
        function pt = get.Pt( obj )
            pt = obj.Pt;
        end
        
        function set.Pt(obj,pt)
          if (isnumeric(pt))
            obj.Pt = pt;
          else
            error('Invalid transmit power, dBm');
          end
        end
        
        function pr = get.Pr( obj )
            pr = obj.Pr;
        end
        
        function set.Pr(obj,pr)
          if (isnumeric(pr))
            obj.Pr = pr;
          else
            error('Invalid receiver sensitivity, dBm');
          end
        end
        
        function gt = get.Gt( obj )
            gt = obj.Gt;
        end
        
        function set.Gt(obj,pt)
          if (isnumeric(pt))
            obj.Gt = pt;
          else
            error('Invalid transmit antenna gain, dBi');
          end
        end        
        
        function gr = get.Gr( obj )
            gr = obj.Gr;
        end
        
        function set.Gr(obj,pt)
          if (isnumeric(pt))
            obj.Gr = pt;
          else
            error('Invalid receive antenna gain, dBi');
          end
        end 
        
        function gr = get.Fade( obj )
            gr = obj.Fade;
        end
        
        function set.Fade(obj,pt)
          if (isnumeric(pt))
            obj.Fade = pt;
          else
            error('Invalid fade margin, dB');
          end
        end 
        
        function gr = get.L( obj )
            gr = obj.L;
        end
        
        function set.L(obj,pt)
          if (isnumeric(pt))
            obj.L = pt;
          else
            error('Invalid other losses, dB');
          end
        end
        
        function gr = isSending( obj )
            gr = obj.sending;
        end
        
        function set.sending(obj,s)
          if (s == 1 || s == 0)
            obj.sending = s;
          else
            error('Invalid transmitting parameter');
          end
        end        
        
    end
    
end

