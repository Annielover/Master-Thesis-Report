/*
 * dispatcher.{cc,hh}
 * Houdt de huidige en vorige RAU (MAC) bij en zendt
 * downlinkpakketten door naar de huidige RAU.  Vorige wordt
 * bijgehouden om geen jojo-effect te creëren.
 */

#include <click/config.h>
#include "dispatcher.hh"
#include <clicknet/ether.h>
#include <click/confparse.hh>
#include <click/error.hh>
#include <click/etheraddress.hh>
#include <click/glue.hh>
#include <click/bitvector.hh>
CLICK_DECLS

Dispatcher::Dispatcher()
  : Element(2, 3)
{
  MOD_INC_USE_COUNT;
  previous = EtherAddress();
  current = EtherAddress();
  centrale = EtherAddress();
  channel = 0;
  enabled = 0;
}

Dispatcher::~Dispatcher()
{
  MOD_DEC_USE_COUNT;
}

/* Parameter 1: kanaal
   Parameter 2: MAC centrale, kant RAU's */
int
Dispatcher::configure(Vector<String> &conf, ErrorHandler *errh)
{
	unsigned chan;
  if ( cp_unsigned(conf[0], &chan)<0 ) return errh->error("sdf");
  channel = chan;
  cp_ethernet_address (conf[1], &centrale);
  return 0;
}

void
Dispatcher::push(int source, Packet *p)
{
  
  if (source == UPLINK) {
    /* Indien current nog niet geldig -> discard */
    if (enabled == 0) {
    	  output(DISCARD).push(p);
    	  
    	} else {
      /* Pakket 1 byte uitbreiden met kanaal */
      WritablePacket* q = p->push(1);
      memcpy(q->data(), &channel, 1);
    
      /* Pakket uitbreiden met ethernetheader
         source MAC is MAC centrale
         DST MAC is current, payload = <kanaal|wireless pakket> */
      WritablePacket* r = q->push_mac_header(14);
      click_ether* e = (click_ether*) r->data();
      memcpy(e->ether_shost, centrale.data(),6);
      memcpy(e->ether_dhost, current.data(),6);
    
      /* Pakket versturen naar Q */
      output(DOWNLINK).push(r);
    }
    
  } else if (source == DOWNLINK) {
  	/* Haal MAC src uit pakket */
  	click_ether* e = (click_ether*) p->data();
  	EtherAddress src = EtherAddress(e->ether_shost);
  	
    /* Indien MAC src verschillend van current en timeout overschreden,
       stel previous = current en current = MAC src */
       /* Voorlopig zonder timeout, dit komt later */
    if (current != src) {
    		if (previous != src) {
    		 /*
	    timeval t;
	    click_gettimeofday(&t);
	    */
	    previous = current;
	    current = src;
	    }
	    /* Indien src gelijk aan previous, geen wijzigingen nodig, niet terugkaatsen. */
    }
    
    /* Verstuur naar stripper */
    output(UPLINK).push(p);
    
    /* Zet enabled aan */
    enabled = 1;
    
  } /* Close if(source) */
  
} /* Close push() */

EXPORT_ELEMENT(Dispatcher)

CLICK_ENDDECLS
