// This is a simple and stupid flat routing mechanism. 
// It broadcasts ARP requests if it wants to find a destination 
// address, and it responds to ARP requests made for it. 

elementclass DumbRouter {
  $myaddr, $myaddr_ethernet | 
class :: Classifier(12/0806 20/0001,12/0806 20/0002, -);
mypackets :: IPClassifier(dst host $myaddr, -); 
myarpquerier :: ARPQuerier($myaddr,$myaddr_ethernet); 
myarpresponder :: ARPResponder($myaddr $myaddr_ethernet); 
ethout :: Queue -> ToDump(Server_out_eth0) -> ToSimDevice(eth0); 

FromSimDevice(eth0,4096) 
//-> Print(eth0,64) 
-> ToDump(Server_in_eth0) 
-> HostEtherFilter($myaddr_ethernet) 
-> class;

// ARP queries from other nodes go to the ARP responder module 
class[0] -> myarpresponder; 

// ARP responses go to our query module 
class[1] -> [1]myarpquerier; 

// All other packets get checked to see if they're meant for us 
class[2] 
-> Strip(14)
-> CheckIPHeader 
-> MarkIPHeader 
-> GetIPAddress(16) 
-> mypackets; 

// Packets for us go to ``tap0'' which sends them to the kernel 
mypackets[0] 
//-> IPPrint(tokernel) 
-> ToDump(Server_tokernel,2000,IP) 
-> ToSimDevice(tap0,IP);

// Packets for other folks or broadcast packets get discarded 
mypackets[1] 
//-> Print(Server_discard,64) 
-> ToDump(Server_discard,2000,IP) 
-> Discard; 

// Packets sent out by the ``kernel'' get pushed into the ARP query module 
FromSimDevice(tap0,4096) 
-> CheckIPHeader
//-> IPPrint(fromkernel) 
-> ToDump(Server_fromkernel,2000,IP) 
-> GetIPAddress(16) 
-> myarpquerier; 

// Both the ARP query and response modules send data out to 
// the simulated network device, eth0. 
myarpquerier 
//-> Print(fromarpquery,64) 
-> ToDump(Server_out_arpquery)
-> ethout; 

myarpresponder 
//-> Print(Server_arpresponse,64) 
-> ToDump(Server_out_arprespond) 
-> ethout; 
}

// Note the use of the :simnet suffix. This means that 70 
// the simulator will be asked for the particular value 
// for the variable in this node. 
AddressInfo(me0 192.168.1.1 00:00:5E:00:00:01); 
u :: DumbRouter(me0,me0); 
