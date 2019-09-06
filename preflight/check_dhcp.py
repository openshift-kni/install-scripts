#!/usr/bin/env python 
#####################################################################################################
#
# Python script to pass in a MAC Address and send out a DHCPDISCOVER packet and get reply
# Original Author: Hassane
# Original Reference Link: http://code.activestate.com/recipes/577649-dhcp-query/
# Original Licence: MIT License
#
#####################################################################################################

import socket, struct, re, argparse
from uuid import getnode as get_mac
from random import randint

parser=argparse.ArgumentParser(description="Python script to pass in a MAC Address and send out a DHCPDISCOVER packet and get reply")
parser.add_argument('-m', help='Enter in valid mac address', required=True)
args=vars(parser.parse_args())

macaddr=args["m"]
macaddr = re.sub('[:]', '', macaddr)

def getMacInBytes():
    mac = macaddr
    while len(mac) < 12 :
        mac = '0' + mac
    macb = b''
    for i in range(0, 12, 2) :
        m = int(mac[i:i + 2], 16)
        macb += struct.pack('!B', m)
    return macb

class DHCPDiscover:

    def __init__(self):
        self.transactionID = b''
        for i in range(4):
            t = randint(0, 255)
            self.transactionID += struct.pack('!B', t) 

    def buildPacket(self):
        macb = getMacInBytes()
        packet = b''
        packet += b'\x01'   #Message type: Boot Request (1)
        packet += b'\x01'   #Hardware type: Ethernet (1)
        packet += b'\x06'   #Hardware address length: (6)
        packet += b'\x00'   #Hops: (0) 
        packet += self.transactionID       #Transaction ID
        packet += b'\x00\x00'    #Seconds elapsed: (0)
        packet += b'\x80\x00'   #Bootp flags: 0x8000 (Broadcast) + reserved flags
        packet += b'\x00\x00\x00\x00'   #Client IP address: 0.0.0.0
        packet += b'\x00\x00\x00\x00'   #Your (client) IP address: 0.0.0.0
        packet += b'\x00\x00\x00\x00'   #Next server IP address: 0.0.0.0
        packet += b'\x00\x00\x00\x00'   #Relay agent IP address: 0.0.0.0
        #packet += b'\x00\x26\x9e\x04\x1e\x9b'   #Client MAC address: 00:26:9e:04:1e:9b
        packet += macb
        packet += b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'   #Client hardware address padding: 00000000000000000000
        packet += b'\x00' * 67  #Server host name not given
        packet += b'\x00' * 125 #Boot file name not given
        packet += b'\x63\x82\x53\x63'   #Magic cookie: DHCP
        packet += b'\x35\x01\x01'   #Option: (t=53,l=1) DHCP Message Type = DHCP Discover
        #packet += b'\x3d\x06\x00\x26\x9e\x04\x1e\x9b'   #Option: (t=61,l=6) Client identifier
        packet += b'\x3d\x06' + macb
        packet += b'\x37\x03\x03\x01\x06'   #Option: (t=55,l=3) Parameter Request List
        packet += b'\xff'   #End Option
        return packet

class DHCPOffer:

    def __init__(self, data, transID):
        self.data = data
        self.transID = transID
        self.offerIP = ''
        self.unpack()
    
    def unpack(self):
        if self.data[4:8] == self.transID :
            self.offerIP = '.'.join(map(lambda x:str(x), data[16:20]))
            self.nextServerIP = '.'.join(map(lambda x:str(x), data[20:24]))  #c'est une option
            self.DHCPServerIdentifier = '.'.join(map(lambda x:str(x), data[245:249]))
                
    def printOffer(self):
        key = ['DHCP Server', 'Offered IP address']
        val = [self.DHCPServerIdentifier, self.offerIP]
        for i in range(2):
            print('{0:20s} : {1:15s}'.format(key[i], val[i]))

if __name__ == '__main__':

    #Define the Python socket
    dhcps = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)    #internet, UDP
    dhcps.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # Added to share port we bind  
    dhcps.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1) #broadcast
    
    try:
        dhcps.bind(('', 68))
    except Exception as e:
        print('Cannot bind to port 68 for some reason')
        dhcps.close()
        exit()
 
    #Build and send DHCPDISCOVER packet
    discoverPacket = DHCPDiscover()
    dhcps.sendto(discoverPacket.buildPacket(), ('<broadcast>', 67))
    
    #Hopefully receive DHCPOFFER packet and print results  
    dhcps.settimeout(30)
    try:
        while True:
            data = dhcps.recv(1024)
            offer = DHCPOffer(data, discoverPacket.transactionID)
            if offer.offerIP:
                offer.printOffer()
                break
    except socket.timeout as e:
        print('Socket timed out with no response\n')
    dhcps.close()   
    exit()
