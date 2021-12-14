function setChannel(mov,varargin)


for i=1:numel(varargin)
    
    if strcmp(varargin{i},'GFP')
        ind=varargin{i+1};
        
        
        
        for j=1:numel(mov)
            mov(j).GFPChannel=ind; 
            for k=1:numel(mov(j).trap)
               mov(j).trap(k).gfpchannel=ind; 
            end
        end

    end
     if strcmp(varargin{i},'Phase')
        ind=varargin{i+1};
        
         for j=1:numel(mov)
            mov(j).PhaseChannel=ind; 
            for k=1:numel(mov(j).trap)
               mov(j).trap(k).phasechannel=ind; 
            end
        end
    end
end