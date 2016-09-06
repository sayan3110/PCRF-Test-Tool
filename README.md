# PCRF-Test-Tool
PCRF Test Tool created in Perl
# Usage Guide

Running the PCRF Test Tool
1.	Untar the package
2.	Edit the message_flow.txt file as per the test scenario
3.	Edit the pcrf_properties.txt file to configure the PCRF properties
4.	Run "run_pcrf_simulator.sh"
5.	To change the Origin-State-Id at any time, edit the file ‘osi_file.txt’ (By default Origin-State-Id = 1000001)
Messages Supported

CER
Listens for CER
No arguments supported
Syntax:
CER

CCR
Listens for CCR
No arguments supported
Syntax:
CCR

RAA
Listens for RAA
No arguments supported
Syntax:
RAA

CEA
Sends CEA message
Arguments: Result-Code AVP value
Syntax:
CEA|response_code=2001

CCA
Sends CCA message
Arguments: Result-Code AVP value, Charging-Rule-Install name & array index
Syntax:
CCA|response_code=2001|charging_rule_install=policy gold|index=1

RARU
Sends RAR message
Arguments: Charging-Rule-Remove value, Charging-Rule-Install value & array index
Syntax:
RARU|charging_rule_remove=policy gold|charging_rule_install=policy silver|index=1

RART
Sends RAR message
Arguments: Array Index
Syntax:
RART|index=2

DWR
DWR messages can be enabled by setting the flag ‘DWR_enabled’ in pcrf_properties.txt. The interval can be set by ‘DWR_interval’ in the same file.

SLEEP
Sleep for specified time
Arguments: Time in seconds
Syntax:
SLEEP|time=20

CREATE_SOCKET
Opens the socket in listening mode (not recommended)
No arguments
Syntax:
CREATE_SOCKET

CLOSE_SOCKET 
Closes the socket (not recommended) 
No arguments
Syntax:
CLOSE_SOCKET
Array Index is used to identify the subscriber, e.g- The subscriber session learnt first has index ‘1’, subscriber session learnt second has index ‘2’ and so on.
Important:
1.	Array Index is used to identify the subscriber, e.g- The subscriber session learnt first has index ‘1’, subscriber session learnt second has index ‘2’ and so on.
2.	This tool is a send-expect type of a tool so the sequence of messages is vital
Sample Message Flow File:
####Define Message Flow below this line####
CER
CEA|response_code=2001
CCR
CCA|response_code=2001|charging_rule_install=policy gold|index=1
SLEEP|time=10
RARU|charging_rule_remove=policy gold|charging_rule_install=policy silver|index=1
RAA
SLEEP|time=10
RART|index=1
SLEEP|time=20
####End of Message Sequence####
Sample PCRF Properties File:
Hostname=pcrf1.sayan1.net
Realm=sayan1.net
Host-IP=10.102.163.134
Product-Name=PerlPCRF
DWR_enabled=YES
DWR_interval=10
Sample Logs:
[root@localhost ~]# ls -ltr PCRF_Test_Tool.tgz 
-rw-r--r-- 1 root root 4777 2016-08-23 12:56 PCRF_Test_Tool.tgz
[root@localhost ~]# tar -xzvf PCRF_Test_Tool.tgz 
PCRF_Test_Tool/
PCRF_Test_Tool/run_pcrf_simulator.sh
PCRF_Test_Tool/pcrf_template.pl
PCRF_Test_Tool/pcrf_properties.txt
PCRF_Test_Tool/perl_pcrf.pl
PCRF_Test_Tool/osi_file.txt
PCRF_Test_Tool/message_flow.txt
PCRF_Test_Tool/parser.pl
[root@localhost ~]# cd PCRF_Test_Tool
[root@localhost PCRF_Test_Tool]# ./run_pcrf_simulator.sh 
PCRF Ready and listening on port 3868!!!

###Received CER###

#################### Sending CEA#####################
#################### Sent CEA #####################

###Received CCR###

#################### Sending CCA #####################
#################### Sent CCA #####################

###Received CCR###

#################### Sending CCA #####################
#################### Sent CCA #####################

#################### Sending DWR #####################
#################### Sent DWR #####################

###Received DWA###

#################### Sending RAR-U #####################
#################### Sent RAR-U #####################

###Received RAA###

#################### Sending DWR #####################
#################### Sent DWR #####################

###Received DWA###

#################### Sending DWR #####################
#################### Sent DWR #####################

###Received DWA###

### Closing Socket !!!
A thread exited while 2 threads were running.
[root@localhost PCRF_Test_Tool]#
