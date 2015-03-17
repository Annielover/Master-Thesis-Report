# 
# Set some general simulation parameters
# 
# 
# Unity gain, omnidirectional antennas, centered 1.5m above each node. 
# These values are lifted from the ns-2 sample files. 
# 
Antenna/OmniAntenna set X_ 0 
Antenna/OmniAntenna set Y_ 0 
Antenna/OmniAntenna set Z_ 1.5 
Antenna/OmniAntenna set Gt_ 1.0
Antenna/OmniAntenna set Gr_ 1.0 
# 
# Initialize the SharedMedia interface with parameters to make 
# it work like the 914MHz Lucent WaveLAN DSSS radio interface 
# These are taken directly from the ns-2 sample files. 
# 
Phy/WirelessPhy set CPThresh_ 10.0 
Phy/WirelessPhy set CSThresh_ 1.559e-11 
Phy/WirelessPhy set RXThresh_ 3.652e-10
Phy/WirelessPhy set Rb_ 2.0*1e6 
Phy/WirelessPhy set Pt_ 0.2818 
#Phy/WirelessPhy set freq_ 914e+6 
Phy/WirelessPhy set freq_ 2.485e+9 
Phy/WirelessPhy set L_ 1.0 

#
#Set the size of the playing field and the topography. 
# 
set xsize 100
set ysize 100 
set wtopo [new Topography] 
$wtopo load_flatgrid $xsize $ysize 
#
#The network channel, physical layer, MAC, propagation model, 
# and antenna model are all standard ns-2. 
# 
set netchan Channel/WirelessChannel 
set netphy Phy/WirelessPhy 
set netmac Mac/802_11 
set netprop Propagation/TwoRayGround 
set antenna Antenna/OmniAntenna 


$netmac set basicRate_ 54Mb
$netmac set dataRate_ 54Mb
#$netmac set delay_ 0.0
#$netmac set bandwidth_ 54Mb
#$netphy set delay_ 0.0
#$netphy set bandwidth_ 54Mb

#
#
#We have to use a special queue and link layer. This is so that 
# Click can have control over the network interface packet queue, 
# which is vital if we want to play with, e.g. QoS algorithms. 
# 
set netifq Queue/ClickQueue 
set netll LL/Ext 
LL set delay_ 1ms 
#
#These are pretty self-explanatory, just the number of nodes 
# and when we'll stop. 
# 
set nodecount 2
set stoptime 5.0 


# set multirate PHY parameters
Phy/WirelessPhy set RateCount_ 4 ;# Number of rates
Phy/WirelessPhy set Rate0 54e6
Phy/WirelessPhy set Rate1 48e6
Phy/WirelessPhy set Rate2 36e6
Phy/WirelessPhy set Rate3 1e6
Phy/WirelessPhy set RXThresh0 1.427e-08 ;# 100m
Phy/WirelessPhy set RXThresh1 2.818e-09 ;# 150m
Phy/WirelessPhy set RXThresh2 8.916e-10 ;# 200m
Phy/WirelessPhy set RXThresh3 3.652e-10 ;# 250m

#
# With nsclick, we have to worry about details like which network 
# port to use for communication. This sets the default ports to 5000. 
#
Agent/Null set sport_ 5000 
Agent/Null set dport_ 5000 
Agent/CBR set sport_ 5000 
Agent/CBR set dport_ 5000 
#
# Standard ns-2 stuff here -create the simulator object. 
#
Simulator set MacTrace_ ON 
set ns_ [new Simulator] 
#
#Create and activate trace files. 
# 
set tracefd [open "log_nsclick-simple-wlan.tr" w] 
set namtrace [open "log_nsclick-simple-wlan.nam" w] 
$ns_ trace-all $tracefd 
$ns_ namtrace-all-wireless $namtrace $xsize $ysize 
$ns_ use-newtrace 

#
#Create the 'god' object. This is another artifact of using 
# the mobile node type. We have to have this even though 
# we never use it. 
#
set god_ [create-god [expr $nodecount + 0]] 
#
#Tell the simulator to create Click nodes. 
# 
Simulator set node_factory_ Node/MobileNode/ClickNode 

#
#Create a network Channel for the nodes to use. One channel 
# per LAN. Also set the propagation model to be used. 
# 
set prop_ [new $netprop] 


#setting network channels [1..13]
set netchan Channel/WirelessChannel
for {set i 1} { $i < 14} {incr i} {
set chan_($i) [new $netchan]
}

#switch channel function
proc SwitchChannel { i whichif whichnewchannel } {
global ns_ chan_
[$ns_ set Node_($i)] changechannel $whichif $chan_($whichnewchannel)
puts "node $i has changed its channel to $whichnewchannel on its interface $whichif"
}

#
#We set the routing protocol to 'Empty' so that ns-2 doesn't do 
# any packet routing. All of the routing will be done by the 
# Click script. 
# 
$ns_ rtproto Empty 

#
#Here is where we actually create all of the nodes. 
# 
for {set i 0} {$i < $nodecount} {incr i} {
	set node_($i) [$ns_ node]

	#
	#After creating the node, we add one wireless network interface to 
	# it. By default, this interface will be named 'eth0'. If we 
	# added a second interface it would be named 'eth1', a third 
	# 'eth2' and so on. 
	#
	$node_($i) add-interface $chan_(1) $prop_ $netll $netmac $netifq 1 $netphy $antenna 

	#
	#Set some node properties 
	#
	$node_($i)	random-motion 0
	$node_($i)	topography $wtopo 
	$node_($i)	nodetrace $tracefd 

	#
	#The node name is used by Click to distinguish information 
	# coming from different nodes. For example, a 'Print' element 
	# prepends this to the printed string so it's clear exactly 
	# which node is doing the printing. 
	# 
	[$node_($i) set classifier_] setnodename "log_node$i-bss" 
	

	#
	# Load the appropriate Click router script for the node.
	# All nodes in this simulation are using the same script,
	# but there's no reason why each node couldn't use a different
	# script.	
	#
	if {$i==0} {
    	$node_($i) setmac "eth0" "00:05:4E:46:97:28"
    	$node_($i) setip "eth0" "192.168.1.1"
		[$node_($i) entry] loadclick "ap.click" 
		$node_($i) start
		$ns_ at 0 "[$node_($i) entry] runclick"
		
	} else {
    	$node_($i) setmac "eth0" "00:05:4E:46:97:29"
    	$node_($i) setip "eth0" "192.168.1.2"
		[$node_($i) entry] loadclick "sta.click" 
		$node_($i) start
		$ns_ at 0 "[$node_($i) entry] runclick"
	}
}


# 
# Define node network traffic. 

#
# We use the "raw" packet type, which sends real packet data
# down the pipe. 
# 
set raw_(0) [new Agent/Raw] 
$ns_ attach-agent $node_(0) $raw_(0)
set null_(0) [new Agent/Null] 
$ns_ attach-agent $node_(1) $null_(0)

#
# The CBR object is just the default ns-2 CBR object, so 
# no change in the meaning of the parameters. 
# 
set cbr_(0) [new Application/Traffic/CBR] 
$cbr_(0) set packetSize_ 1000
$cbr_(0) set interval_ [expr 1.0/600.0]
$cbr_(0) set random_ 0 
$cbr_(0) set maxpkts_ 600
$cbr_(0) attach-agent $raw_(0)

# 
# The Raw agent creates real UDP packets, so it has to know 
# the source and destination IP addresses and port numberes. 
# 
$raw_(0) set-srcip 192.168.1.1
$raw_(0) set-srcport 5000
$raw_(0) set-destport 5000
$raw_(0) set-destip 192.168.1.2
# 
# Set node positions. For wired networks, these are only used 
# when looking at nam traces. 
#
$node_(0) set X_ 10 
$node_(0) set Y_ 50 
$node_(0) set Z_ 0 
$node_(1) set X_ 50 
$node_(1) set Y_ 50 
$node_(1) set Z_ 0 

#
# This sizes the nodes for use in nam. Currently, the trace files 
# produced by nsclick don't really work in nam. 
# 

for {set i 0} {$i < $nodecount} {incr i} {
	$ns_ initial_node_pos $node_($i) [expr 10 + 40*$i] 
}

proc Station_Auth  {} {
	global node_
	[$node_(1) set classifier_] writehandler "winfo" "bssid" [$node_(0) getmac eth0]
#	[$node_(1) set classifier_] writehandler "winfo" "bssid" "00:05:4E:46:97:28"
	[$node_(1) set classifier_] writehandler "winfo" "channel" "1"
	[$node_(1) set classifier_] writehandler "winfo" "ssid" "MadWifi"
	[$node_(1) set classifier_] writehandler "station_auth" "send_auth_req" "1"
}

proc Station_Assoc {} {
	global node_
	[$node_(1) set classifier_] writehandler "station_assoc" "send_assoc_req" "1"
}

proc Station_Auth_Check  {} {
	global node_
	set assoc [[$node_(1) set classifier_] readhandler "station_assoc" "associated"]
	set bssid [[$node_(1) set classifier_] readhandler "winfo" "bssid"]
	set channel [[$node_(1) set classifier_] readhandler "winfo" "channel"]
	set ssid [[$node_(1) set classifier_] readhandler "winfo" "ssid"]
	puts "station associated : $assoc to $ssid with bssid:$bssid on channel $channel"
}

$ns_ at 1.5 "Station_Auth"
$ns_ at 1.6 "Station_Assoc"
$ns_ at 1.7 "Station_Auth_Check"
$ns_ at 3.0 "$cbr_(0) start"

#
# Stop the simulation 
#
$ns_ at $stoptime.000000001 "puts \"NS EXITING...\" ; $ns_ halt" 
#
#Let nam know that the simulation is done. 
# 
$ns_ at $stoptime "$ns_ nam-end-wireless $stoptime" 

puts "Starting Simulation..." 
$ns_ run
