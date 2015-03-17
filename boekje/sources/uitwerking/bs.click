//bs.click

// Wired: eth3 (kant centrale)
// Wireless: eth0 tem eth2

// Run it at user level with
// 'click bs.click'

// Run it in the Linux kernel with
// 'click-install bs.click'
// Messages are printed to the system log (run 'dmesg' to see them, or look
// in /var/log/messages), and to the file '/click/messages'.


// interfaces
AddressInfo(wired 00:00:00:B5:00:E1);

// Centrale
AddressInfo(centrale 00:00:00:CE:E1:00);

classifier :: Classifier(	0/01,
							0/06,
							0/0B,
							-);


// Downstream
FromSimDevice(eth3, 4096)
-> ToDump(WiredIn, 4096, ENCAP ETHER, PER_NODE true)
-> Strip(14) // Weg met de ethernetheader
-> classifier;

classifier [0]
-> Strip(1)
-> splitter :: Tee(2);
splitter[0] -> Strip(24) -> ToDump(WiredInChannel1Stripped, 4096, ENCAP 802_11, PER_NODE true) -> Discard(); // Bloot binnengekomen pakket
splitter[1]
-> Queue(10)
-> ToSimDevice(eth0);

classifier [1]
-> Strip(1)
-> Queue(10)
-> ToSimDevice(eth1);

classifier [2]
-> Strip(1)
-> Queue(10)
-> ToSimDevice(eth2);

classifier [3]
-> Discard;


// Upstream
upqueue :: Queue(10)
-> ToDump(WiredUit, 4096, ENCAP ETHER, PER_NODE true)
-> uptee :: PullTee(2);
uptee[1] -> Strip(38) -> ToDump(WiredUitStripped, 4096, ENCAP 802_11, PER_NODE true);
uptee[0]
-> ToSimDevice(eth3);

FromSimDevice(eth0, 4096)
-> FilterTX()
-> wirelessInSplitter :: Tee(2);
wirelessInSplitter[0]
-> Strip(24) -> ToDump(WirelessIn, 4096, ENCAP 802_11, PER_NODE true);
wirelessInSplitter[1]
-> EtherEncap(0x0800, wired, centrale)
-> upqueue;

FromSimDevice(eth2)
-> EtherEncap(0x0800, wired, centrale)
-> upqueue;

FromSimDevice(eth3)
-> EtherEncap(0x0800, wired, centrale)
-> upqueue;
