// -- Definitions of ElementClasses ---------------------------------

elementclass SimInterface {
  $device  |
  FromSimDevice($device,4096) -> output;
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
AddressInfo(station_address 192.168.1.2 00:00:00:00:00:01);
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
winfo :: WirelessInfo(SSID "Treintjes", BSSID 00:00:00:CE:A0:00, CHANNEL 1);
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
	-> SetTXRate(108)
	-> SetTXPower(63) -> ToDump(SetPower, 4096, ENCAP 802_11, PER_NODE true)
	-> ToDump(NaQueue, 4096, ENCAP 802_11, PER_NODE true)
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
	-> ToDump(Auth, 4096, ENCAP 802_11, PER_NODE true)
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
//	-> PrintWifi(STA_data)
	-> wifi_decap :: WifiDecap()
	-> HostEtherFilter(station_address, DROP_OTHER true, DROP_OWN true) 
	//Zelf bijgegooid
	-> class :: Classifier(12/0806 20/0001, // ARP queries from other
							12/0806 20/0002, // ARP responses
							-); // other
							
myarpquerier :: ARPQuerier(station_address); 
myarpresponder :: ARPResponder(station_address); 
class[0]
	-> myarpresponder;
class[1]
	-> [1]myarpquerier;

class[2]
	-> Strip(14)
	-> tun_interface;

tun_interface
	-> GetIPAddress(16) 
	-> [0]myarpquerier;
	
myarpquerier
//	-> EtherEncap(0x0800, station_address, 00:00:5E:00:00:01)
	-> station_encap :: WifiEncap(0x01, WIRELESS_INFO winfo)
	-> wlanQ;

myarpresponder 
	-> station_encap;

// -- end Connections------------------------------------------------	
