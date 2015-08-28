# fetch-out-bw

`fetch-out-bw` is a quick and dirty approach to access a set of internet 
gateways (for example) via snmp and calculate the outgoing bandwith within 
a given time.

### Run

```
usage: fetch-out-bw.rb [options]
    -v, --version
    -h, --help
    -q, --quiet
    -u, --debug
    -g, --gateways=val
    -c, --count=val
    -d, --delay=val

```

Where `--gateways` specifies a yaml file which descibes the gateways to fetch:

```
gateways:
- name: "fqdn.of.gw.one"
  snmp_community: "snmp.community"
  interface_id: "last.part.of.the.snmp.oid"
  interface_descr: "snmp.descr.of.interface"
- name: "fqdn.of.gw.two"
  snmp_community: "snmp.community"
  interface_id: "last.part.of.the.snmp.oid"
  interface_descr: "snmp.descr.of.interface"
```
