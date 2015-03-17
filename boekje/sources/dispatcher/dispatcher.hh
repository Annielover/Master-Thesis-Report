#ifndef CLICK_DISPATCHER_HH
#define CLICK_DISPATCHER_HH

#define UPLINK 0
#define DOWNLINK 1
#define DISCARD 2

#include <click/element.hh>
#include <click/etheraddress.hh>
CLICK_DECLS

class Dispatcher : public Element {
  
 public:
  
  Dispatcher();
  ~Dispatcher();
  
  const char *class_name() const		{ return "Dispatcher"; }
  const char *processing() const		{ return PUSH; }

  int configure(Vector<String> &, ErrorHandler *);
  
  void push(int port, Packet* p);

private:

  EtherAddress current, previous, centrale;
  uint8_t channel, enabled;
  /* Later: timeout */
};

CLICK_ENDDECLS
#endif
