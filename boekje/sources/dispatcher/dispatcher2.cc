/* Parameter 1: kanaal
   Parameter 2: MAC centrale, kant RAU's
   Parameter 3: MAC current RAU */
int
Dispatcher2::configure(Vector<String> &conf, ErrorHandler *errh)
{
	unsigned chan;
  if ( cp_unsigned(conf[0], &chan)<0 ) return errh->error("sdf");
  channel = chan;

  cp_ethernet_address (conf[1], &centrale);
  cp_ethernet_address (conf[2], &current);
  
  return 0;
}
