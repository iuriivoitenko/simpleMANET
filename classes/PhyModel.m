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
        enable = 0
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
        function obj = PhyModel( range, ini )
            obj.radio = range;
            obj.sending = 0;
            obj.load(ini);
        end
            
        % communication range 
        function r = range( obj )
            if obj.enable == 0
                r = obj.radio;
            else                
                r = friis(obj.freq, obj.Pr, obj.Pt, obj.Gt, obj.Gr, obj.L, obj.Fade);
            end            
        end
        
        function obj = load(obj, ini)
            obj.enable = ini.enable;            % enable real RF range calculation based on PHY params and friis formula
            obj.freq = ini.freq;                % carrier frequency, Hz
            obj.modulation = ini.modulation;    % modulation scheme
            obj.bitrate = ini.bitrate;          % bitrate, b/s
            obj.coding = ini.coding;            % coding rate
            obj.Pt = ini.Pt;                    % Tx power, dBm
            obj.Pr = ini.Pr;                    % Rx sensitivity, dBm
            obj.Gt = ini.Gt;                    % Tx antenna gain, dBi
            obj.Gr = ini.Gr;                    % Rx antenna gain, dBi
            obj.L = ini.L;                      % other losses, dB
            obj.Fade = ini.Fade;                % fade margin, dB
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

