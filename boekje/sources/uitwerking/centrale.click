//centrale.click

// Uplink: eth0
// Downlink: eth1 (kant BS's)

// Run it at user level with
// 'click centrale.click'

// Run it in the Linux kernel with
// 'click-install centrale.click'
// Messages are printed to the system log (run 'dmesg' to see them, or look
// in /var/log/messages), and to the file '/click/messages'.

elementclass AP {
	// input/ouput 0 is wireless
	// input/ouput 1 is wired

    $ap_bssid, $winfo, $rates  |

    wifi_cl :: Classifier(
            0/00%0c, //mgt
            0/08%0c, //data
            );
  
    mgt_cl :: Classifier(
            0/00%f0, //assoc req
            0/40%f0, //probe req
            0/a0%f0, //disassoc
            0/b0%f0, //auth
            );
                    
    assoc_resp :: AssociationResponder(
            WIRELESS_INFO $winfo,
            RT $rates);
  
    beacon_source :: BeaconSource(
            WIRELESS_INFO $winfo,
            RT $rates);
                    
    open_auth_resp :: OpenAuthResponder(
        WIRELESS_INFO $winfo);
  
    input[0]
        -> wifi_cl;
  
    wifi_cl [0]
        -> mgt_cl;
  
    wifi_cl [1]
        -> decap :: WifiDecap()
        -> HostEtherFilter($ap_bssid, DROP_OTHER false, DROP_OWN true)
        -> [1]output;
  
    mgt_cl [0]
        -> PrintWifi ("ap: <- assoc_req")
        -> assoc_resp
        -> [0]output;

  
    mgt_cl [1]
        //-> PrintWifi ("ap: <- probe_req")
        -> beacon_source
//		-> Print("BeaconSource: ")
        -> [0]output;
  
    mgt_cl [2]
        //-> PrintWifi ("ap: <- disassoc")
        -> Discard;
      
    mgt_cl [3]
        -> PrintWifi ("ap: <- auth")
        -> open_auth_resp
        -> [0]output;

    input[1]
        -> wifi_encap :: WifiEncap(0x02, WIRELESS_INFO $winfo)
        -> [0]output;
}


// Wired interfaces
AddressInfo(ap_up 00:00:00:CE:E0:00); // Upstream
AddressInfo(ap_down 00:00:00:CE:E1:00); // Downstream

// Centrale: AP0
AddressInfo(ap_bssid0 00:00:00:CE:A0:00);

winfo0 :: WirelessInfo(SSID "Treintjes", BSSID ap_bssid0, CHANNEL 1);

rates :: AvailableRates(DEFAULT 2 4 11 22);

ap0 :: AP (ap_bssid0, winfo0, rates); 

// MAC van centrale, eth1
//dispatcher0 :: Dispatcher (1,00:00:00:CE:E1:00);

// Test: dispatcher initialiseren op BS0 eth1
dispatcher0 :: Dispatcher2 (1,00:00:00:CE:E1:00,00:00:00:B5:00:E1);


// De centrale bestaat uit drie grote delen:
// 1. De logische elementen die elk de functies van een logisch AP voor één trein voor hun rekening nemen
// 2. Het uplinkdeel, met de switch die het verkeer verdeelt over de verschillende logische elementen
// 3. Het downlinkdeel dat de informatie van de logische elementen naar de BS's stuurt en omgekeerd


// 1. Logisch element

// Downstream
ap0 [0]
-> SetTXRate (108)
-> SetTXPower(63)
-> ExtraEncap()
-> [0] dispatcher0;

// Upstream
dispatcher0 [0]
-> Strip(14)
-> ExtraDecap()
-> FilterPhyErr()
-> FilterTX()
-> WifiDupeFilter(WINDOW 20) 
-> ToDump(UpVanDispatcherNaarAP0, 4096, ENCAP 802_11, PER_NODE true)
-> [0] ap0;

dispatcher0 [2]
-> Discard;


// 2. Uplinkdeel centrale

FromSimDevice(eth0, 4096)
-> ToDump(InVanServer, 4096, ENCAP ETHER, PER_NODE true)
-> [0] ether_switch :: EtherSwitch();

ether_switch [0]
-> ToDump(UitNaarServer, 4096, ENCAP ETHER, PER_NODE true)
-> ToSimDevice (eth0);

ap0 [1]
-> [1] ether_switch;

ether_switch [1]
-> [1] ap0;


// 3. Downlinkdeel centrale
// Uitgaand pakket: eth-header (14 bytes) + channel (1 byte) + extra_encap (24 bytes) + wifi_hdr + data
// Inhoud appart wegschrijven voor ethereal
q :: Queue(100)
-> uitsplitter :: PullTee(2);
uitsplitter[0]
-> ToDump(UitNaarBs, 4096, ENCAP ETHER, PER_NODE true)
-> ToSimDevice (eth1);
uitsplitter[1]
-> Strip(39)
-> ToDump(UitNaarBsStripped, 4096, ENCAP 802_11, PER_NODE true)
-> Discard();

// MAC van treintje:
// 00:00:00:00:00:01

// classifier: splitst stroom op volgens MAC trein
// Houdt geen rekening met RTS/CTS
classifier :: Classifier(48/000000000001, // source address = address 2; offset = eth-hdr (van BS naar Centrale, 14 bytes) + extra_encap (24 bytes) + wifi_hdr voorafgaand aan address 2 (10 bytes)
							-);

FromSimDevice(eth1, 4096)
-> ToDump(InVanBs, 4096, ENCAP ETHER, PER_NODE true)
-> classifier;

classifier [0]
-> ToDump(C0NaarDispatcher, 4096, ENCAP ETHER, PER_NODE true)
-> [1] dispatcher0;

classifier [1]
-> ToDump(C1NaarDiscard, 4096, ENCAP ETHER, PER_NODE true)
-> Discard;

dispatcher0 [1]
-> q;



