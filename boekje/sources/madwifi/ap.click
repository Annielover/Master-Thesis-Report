//access_point.click


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
AddressInfo(ap_bssid eth0:simnet);
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

tun_interface :: TunInterface (tap0);

// -- Wireless stuff ------------------------------------------------

winfo :: WirelessInfo(SSID "MadWifi", BSSID ap_bssid, CHANNEL 1);

rates :: AvailableRates(DEFAULT 2 54 96 108);

wifi_cl :: Classifier(
		0/08%0c 1/01%03, //data
		 0/00%0c); //mgt
		

mgt_cl :: Classifier(
		0/00%f0, //assoc req
		0/40%f0, //probe req
		0/a0%f0, //disassoc
		0/b0%f0, //auth
		);
			     
assoc_resp :: AssociationResponder(
		WIRELESS_INFO winfo,
		RT rates);

beacon_source :: BeaconSource(
		WIRELESS_INFO winfo,
		RT rates);
				 
open_auth_resp :: OpenAuthResponder(
	WIRELESS_INFO winfo);
	
// -- end Configuration ---------------------------------------------

// -- Connections----------------------------------------------------

// -- Wireless stuff ------------------------------------------------
wlanQ
	-> SetTXRate(108)
	-> SetTXPower(63)
	-> pcapWlanPullTee
	-> ExtraEncap()
	-> wlan_interface;

wlan_interface
	-> extra_decap :: ExtraDecap()
	-> phyerr_filter :: FilterPhyErr()
	-> tx_filter :: FilterTX()
	-> dupe :: WifiDupeFilter(WINDOW 20) 
	-> pcapWlanTee
	-> wifi_cl;
	
	
wifi_cl [1] 
	-> mgt_cl;

mgt_cl [0] 
	-> PrintWifi ("ap: <- assoc_req")
	-> assoc_resp
	-> wlanQ;

mgt_cl [1]
	-> PrintWifi ("ap: <- probe_req")
	-> beacon_source
	-> wlanQ;

mgt_cl [2]
	-> PrintWifi ("ap: <- disassoc")
	-> Discard;
	
mgt_cl [3]
	-> PrintWifi ("ap: <- auth")
	-> open_auth_resp
	-> wlanQ;

//-------------------------------------------------------------------
//Data
//-------------------------------------------------------------------

wifi_cl [0] 
	-> decap :: WifiDecap()
	-> HostEtherFilter(ap_bssid, DROP_OTHER false, DROP_OWN true) 
	-> Strip(14)
	-> tun_interface;

tun_interface
	-> EtherEncap(0x0800, ap_bssid, 00:05:4E:46:97:29)
	-> wifi_encap :: WifiEncap(0x02, WIRELESS_INFO winfo)
	-> wlanQ;

// -- end Connections------------------------------------------------



