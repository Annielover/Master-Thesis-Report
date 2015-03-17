// Sniffer
//
FromSimDevice(eth0,4096) ->
	ToDump(Sniffer)->
	Discard;
	
Idle->
	ToSimDevice(eth0);	
