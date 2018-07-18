#!/usr/bin/env python

#--------------------------------------------------------------------
# Name: check_bond.py
# Description: Used to monitor bonded interfaces via influxdb.
# Created: January 19, 2018
# Author: mhersant
#--------------------------------------------------------------------

import sys
import json
import urllib2
import optparse

##############################################
if __name__=='__main__':
##############################################
    OptionParser = optparse.OptionParser
    parser = OptionParser()
    parser.add_option(
        '--influxhost',
        type   = 'string',
        dest   = 'influxhost',
        help   = 'InfluxDB hostname/IP address'
    )
    parser.add_option(
        '--influxport',
        type   = 'int',
        dest   = 'influxport',
        help   = 'InfluxDB port number'
    )
    parser.add_option(
        '--influxdbname',
        type = 'string',
        dest = 'influxdbname',
        help = 'InfluxDB db name'
    )
    parser.add_option(
        '--hostname',
        type   = 'string',
        dest   = 'hostname',
        help   = 'Hostname used to query InfluxDB'
    )
    
    (options, args) = parser.parse_args()

    exit_codes = {
        'OK':       0,
        'WARNING':  1,
        'CRITICAL': 2,
        'UNKNOWN':  3,
    }

    req_options = [
        'influxhost',
        'influxport',
        'influxdbname',
        'hostname',
    ]

    for req in req_options:
        if options.__dict__[req] is None:
            print "Missing required cmdlint arg: --%s" % req
            sys.exit(exit_codes['WARNING'])

    url = "http://%s:%s/query?db=%s&" % (options.influxhost, options.influxport, options.influxdbname)
    query = "select * from bond_slave where host='%s' and time > now() - 1m group by bond" % options.hostname

    response = urllib2.urlopen("%s&q=%s" % (url, urllib2.quote(query)))
    html = response.read()
    myds = json.loads(html)

    myref = {}
    columns = ''
    output = ''
    exit_how = 'OK'
    parsed_bonds = {}

    if myds['results'][0]:
        for series in myds['results'][0]['series']:
            myref[series['tags']['bond']] = series['values']
            if not columns:
                columns = series['columns']
    
        coldict = {}
        for idx, val in enumerate(columns):
            coldict[val] = idx
    
        cntr = 0
    
        for bond in myref:
            cntr = 0
            parsed_bonds[bond] = []
            for row in reversed(myref[bond]):
                if cntr < 2:
                    parsed_bonds[bond].append(row)
                    cntr += 1
    
        for bond in parsed_bonds:
            myb = parsed_bonds[bond][0]
            query = "select * from bond where time='%s' and bond='%s' and host='%s'" % (myb[coldict['time']], bond, myb[coldict['host']])
            response = urllib2.urlopen("%s&q=%s" % (url, urllib2.quote(query)))
            html = response.read()
            myds = json.loads(html)
    
            primary_int = myds['results'][0]['series'][0]['values'][0][1]
    
            if len(parsed_bonds[bond]) == 1:
                output += "%s degraded current primary %s\n" % (bond, primary_int)
                exit_how = 'CRITICAL'
            elif len(parsed_bonds[bond]) == 0:
                output += "%s failed to received data from influxdb\n" % bond
                exit_how = 'WARNING'
            else:
                for val in [0,1]:
                    if parsed_bonds[bond][val][coldict['status']] != 1:
                        output += "%s degraded, interface %s down current primary %s\n" % (bond, parsed_bonds[bond][val][coldict['interface']] ,primary_int)
                        exit_how = 'CRITICAL'
    else:
        output = 'No bonds found'
        exit_how = 'WARNING'

    if not output:
        print "Bonds %s OK" % ' '.join(parsed_bonds.keys())
        sys.exit(exit_codes['OK'])
    else:
        print output
        sys.exit(exit_codes[exit_how])
