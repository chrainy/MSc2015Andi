function [grid, user] = downlinkUserSpesific(enb,user,grid)
% [grid user] = downlinkUserSpesific(enb,user,grid) Summary of this function goes here
% insert cell user spesific signals and channels
% only support SISO system (to be expanded to support MIMO)
% TS 36.230


% Channel insertion for each user
for  i = 1:size(user,2)
    %% DL-SCH Channel Coding
    
    % convert MCS to modulation scheme and transfer block size
    [modulation, itbs] = hMCSConfiguration(user(i).MCS);
    tbs = lteTBS(user(i).RBlength,itbs);
    
    % Transmission mode configuration for PDSCH
    pdschConfig.NLayers = 1;                                            % No of layers
    pdschConfig.TxScheme = 'Port0';                                     % Transmission scheme SISO
    pdschConfig.Modulation = modulation;                                % Modulation scheme
    pdschConfig.RNTI = user(i).RNTI;                                    % 16-bit UE-specific mask
    pdschConfig.RV = 0;                                                 % Redundancy Version
    pdschConfig.PRBSet = (user(i).RBstart : user(i).RBlength - 1).';    % Subframe resource allocation
    
    [pdschIndices, pdschInfo] = ltePDSCHIndices(enb, pdschConfig, pdschConfig.PRBSet, {'1based'});
    
    
    % Generate data if not supplied
    if isempty(user(i).data)
        user(i).data = randi([0 1], tbs, 1);
    else
        user(i).data = user(i).data(1:tbs);
    end
        
    
    % Perform Channel Coding and rate matching
    codedTrBlock = lteDLSCH(enb, pdschConfig, pdschInfo.G, user(i).data); 
    
    pdschSymbols = ltePDSCH(enb, pdschConfig, codedTrBlock);
    grid(pdschIndices) = pdschSymbols;
    
    
    %% DCI message configuration
    
    dciConfig.DCIFormat = 'Format1A';                               % DCI message format
    dciConfig.Allocation.RIV = allocation2RIV(enb,user(i));         % Resource indication value
    dciConfig.ModCoding = user(i).MCS;                              % MCS data
    [dciMessage, dciMessageBits] = lteDCI(enb, dciConfig);          % DCI message
    
    %% DCI Channel Coding
    
    pdcchConfig.NDLRB = enb.NDLRB;                                  % Number of DL-RB in total BW
    pdcchConfig.RNTI = pdschConfig.RNTI;                            % 16-bit value number
    pdcchConfig.PDCCHFormat = 0;                                    % 1-CCE of aggregation level 1
    
    % Performing DCI message bits coding to form coded DCI bits
    codedDciBits = lteDCIEncode(pdcchConfig, dciMessageBits);
    
    %% PDCCH Bits Generation
    
    pdcchInfo = ltePDCCHInfo(enb);                                  % Get the total resources for PDCCH
    pdcchBits = -1*ones(pdcchInfo.MTot, 1);                         % Initialized with -1
    
    % Performing search space for UE-specific control channel candidates
    candidates = ltePDCCHSpace(enb, pdcchConfig, {'bits','1based'});
    
    % Mapping PDCCH payload on available UE-specific candidate. In this example
    % the first available candidate is used to map the coded DCI bits.
    pdcchBits( candidates(1, 1) : candidates(1, 2) ) = codedDciBits;
    
   
end


 %% PDCCH Complex Symbol Generation
    
    pdcchSymbols = ltePDCCH(enb, pdcchBits);
    
 %% PDCCH Mapping Indices Generation and Resource Grid Mapping
    
    pdcchIndices = ltePDCCHIndices(enb, {'1based'});
    
    % The complex PDCCH symbols are easily mapped to each of the resource grids
    % for each antenna port
    grid(pdcchIndices) = pdcchSymbols;



function RIV = allocation2RIV(enb,userspesific)
% RIV calculation Resource allocation type 2 for 'Format-1A' C-RNTI DCI 
% TS 36.213 - 7.1.6.3

if (userspesific.RBlength - 1) < floor(enb.NDLRB/2)
    RIV = enb.NDLRB*(userspesific.RBlength - 1) + userspesific.RBstart;
else
    RIV = enb.NDLRB*(enb.NDLRB - userspesific.RBlength + 1) + (enb.NDLRB - 1 - userspesific.RBstart);
end

    





