//station.click

// -- Definitions of ElementClasses ---------------------------------

elementclass SimInterface {
  $device  |
  FromSimDevice($device,4096)-> output;
  input -> ToSimDevice($device);
}

elementclass TunInterface {
	$device  |
	pcapTun :: ToDump(Tun, 4096, IP, PER_NODE true);
	pcapTunTee :: Tee(2);
	pcapTunPullTee :: PullTee(2);
	pcapTunTee[1]
		-> pcapTun
		-> Discard;
	pcapTunPullTee[1]
		-> pcapTun;
	FromSimDevice($device,4096)
		-> pcapTunTee
		-> output;
	input
		-> tunQ :: Queue(100)
		-> pcapTunPullTee	
		-> ToSimDevice($device,IP);
}

// -- end Definitions of ElementClasses -----------------------------
// -- Configuration -------------------------------------------------

// -- Interfaces ----------------------------------------------------
AddressInfo(station_address eth0:simnet);
wlan_interface :: SimInterface (eth0);
pcapWlan :: ToDump(Wlan, 4096, ENCAP 802_11, PER_NODE true);
pcapWlanTee :: Tee(2);
pcapWlanPullTee :: PullTee(2);
pcapWlanTee[1]
	-> pcapWlan
	-> Discard;
pcapWlanPullTee[1]
	-> pcapWlan;
wlanQ :: Queue(100);

tun_interface  :: TunInterface (tap0);

// -- Wireless stuff ------------------------------------------------
winfo :: WirelessInfo(SSID "", BSSID 00:00:00:00:00:00, CHANNEL 1);
rates :: AvailableRates(DEFAULT 2 54 96 108);

wifi_cl :: Classifier(
		0/00%0c, //mgt
		0/08%0c, //data
		);

management_cl :: Classifier(
		0/10%f0, //assoc resp
		0/50%f0, //probe resp
		0/80%f0, //beacon
		0/a0%f0, //disassoc
		0/b0%f0, //auth
		);

station_probe :: ProbeRequester(
		ETH station_address,
		WIRELESS_INFO winfo,
		RT rates);

station_auth :: OpenAuthRequester(
		ETH station_address, 
		WIRELESS_INFO winfo);

station_assoc ::  AssociationRequester(
		ETH station_address,
		WIRELESS_INFO winfo,
		RT rates) ;

bs :: BeaconScanner(
		RT rates, 
		WIRELESS_INFO winfo);

// -- end Configuration ---------------------------------------------

// -- Connections----------------------------------------------------

wlanQ
	//-> SetTXRate(108)
	-> SetTXPower(63)
	-> pcapWlanPullTee
	-> ExtraEncap()
	-> wlan_interface;

wlan_interface
	-> extra_decap :: ExtraDecap()
	-> FilterPhyErr()
	-> FilterTX()
	-> dupe :: WifiDupeFilter(WINDOW 20)
	-> pcapWlanTee
	-> wifi_cl;
	
wifi_cl [0] 
	-> management_cl;
		     
station_probe
	-> PrintWifi("sta ->: probe-req") 
	-> wlanQ;

station_auth
	-> PrintWifi("sta ->: auth-req") 
	-> wlanQ;

station_assoc
	-> PrintWifi("sta: -> assoc_req") 
	-> wlanQ;

management_cl [0]
	-> PrintWifi("sta: <- assoc_resp")
	-> station_assoc;

management_cl [1]
	-> PrintWifi ("sta: <- probe-resp")
	-> bs
	-> Discard;

management_cl [2]
	-> beacon_t :: Tee(2) 
	-> bs;

beacon_t [1]
	-> tracker :: BeaconTracker(WIRELESS_INFO winfo, TRACK 10)
	-> Discard;

management_cl [3] 
	-> PrintWifi("sta: <- disassoc")
	-> station_assoc;
	
management_cl [4]
	-> PrintWifi ("sta: <- auth-resp")
	-> station_auth;

//-------------------------------------------------------------------
//Data
//-------------------------------------------------------------------

wifi_cl [1] 
	-> WifiDupeFilter(WINDOW 20)
	-> PrintWifi(STA_data)
	-> wifi_decap :: WifiDecap()
	-> HostEtherFilter(station_address, DROP_OTHER true, DROP_OWN true) 
	-> Strip(14)
	-> tun_interface;

tun_interface
	-> EtherEncap(0x0800, station_address, 00:05:4E:46:97:28)
	-> station_encap :: WifiEncap(0x01, WIRELESS_INFO winfo)
	-> wlanQ;
	
// -- end Connections------------------------------------------------	