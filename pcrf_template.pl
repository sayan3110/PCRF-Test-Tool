#!/bin/usr/perl
#Script_ID: 
#Script_Name: pcrf_simulator.pl
#Script_Author: Sayandeb Kar
#Script_Author_MailId: sayandeb.kar@citrix.com
#Script_Date: 01-08-2016

use IO::Socket::INET;
use threads;
use Switch;
use threads;
use threads::shared;

our ($local_hostname, $local_realm, $local_host_ip, $local_product_name) :shared;
our $dwr_flag = "YES";
our $dwr_interval = 10;
read_pcrf_properties();

our ($peer_origin_host,$peer_origin_realm,$peer_host_ip_address,$peer_vendor_id,$peer_product_name,$peer_vendor_specific_id);
our ($cc_req_type,$cc_req_num,$auth_application_id);
our @session_id_arr = {};
our $diam_header;
our ($hbyh_hex, $e2e_hex) :shared;
our $local_host_ip_hex = return_hex_ip($local_host_ip);
our $client_socket;
our $diam_mult_flag = 0;
our @data_arr = {}; 
our @diam_mult_msg = {};

main();

sub main()
	{
	#Create Socket
	create_socket();
	#### Start of Message Sequence 		####
	close_socket();
	}
	
sub create_watchdog_task
	{
    threads->create(sub { 
        my $thr_id = threads->self->tid;
        while(1)
			{
			sleep($dwr_interval);
			send_dwr();
			}
		threads->detach(); #End thread.
		});
	}
	
sub receive_msg()
	{
	LISTEN:
	my $data = "";
	my $i;
	if($diam_mult_flag == 0)
		{
		$client_socket->recv($data, 512);
		#Put the data in an array
		@data_arr = split(//,$data);	
		}
	else
		{
		@data_arr = @diam_mult_msg;
		}
	# our $ver_hex = $data_arr[0];
	our $ver_hex = "\x01";
	our $length = hex(unpack('H*',join('',$data_arr[1],$data_arr[2],$data_arr[3])));
	our $length_hex = join('',$data_arr[1],$data_arr[2],$data_arr[3]);
	our $flags = unpack('H*',$data_arr[4]);
	our $cmd_code = hex(unpack('H*',join('',$data_arr[5],$data_arr[6],$data_arr[7])));
	our $application_id_hex = join('',$data_arr[8],$data_arr[9],$data_arr[10],$data_arr[11]);
	$hbyh_hex = join('',$data_arr[12],$data_arr[13],$data_arr[14],$data_arr[15]);
	$e2e_hex = join('',$data_arr[16],$data_arr[17],$data_arr[18],$data_arr[19]);
	my $diam_msg_length = scalar @data_arr;
	if($diam_msg_length > $length)
		{
		# More than one message in the TCP segment
		$diam_mult_flag = 1;
		for($i=$length+1 ; $i<$diam_msg_length; $i++)
			{
			push @diam_mult_msg, $data_arr[$i];
			}
		}
	else
		{
		@diam_mult_msg = {};
		$diam_mult_flag = 0;
		}

	switch($cmd_code)
		{
		case [257]
			{
			read_cer();
			}
		case [272]
			{
			read_ccr();
			}
		case [258]
			{
			read_raa();
			}
		case [282]
			{
			read_dpa();
			}	
		case [280]
			{
			read_dwa();
			# If Device-Watchdog-Answer, goto start of function and wait for another message
			goto LISTEN;
			}
		else
			{
			print "\nReceived Dummy\n";
			}
		}
	}	
		
sub read_cer()
	{
	my $starting_byte = 20;
	my ($avp_code,$avp_length,$final_avp_data);
	print "\n###Received CER###\n";
	while ($starting_byte < $length)
		{
		($starting_byte,$avp_code,$avp_length,$avp_data,$avp_hex) = return_avp($starting_byte);
		if($avp_code == 264)
			{
			$peer_origin_host = pack("H*",$avp_data);
			}
		if($avp_code == 296)
			{
			$peer_origin_realm = pack("H*",$avp_data);
			}
		if($avp_code == 257)
			{
			$peer_host_ip_address = $avp_hex;
			}
		if($avp_code == 266)
			{
			$peer_vendor_id = $avp_hex;
			}
		if($avp_code == 269)
			{
			$peer_product_name = pack("H*",$avp_data);
			}
		if($avp_code == 260)
			{
			$peer_vendor_specific_id = $avp_hex;
			}
		}
	}

sub read_ccr()
	{
	my $starting_byte = 20;
	my ($avp_code,$avp_length,$final_avp_data);
	print "\n###Received CCR###\n";
	while ($starting_byte < $length)
		{
		($starting_byte,$avp_code,$avp_length,$avp_data,$avp_hex) = return_avp($starting_byte);
		if($avp_code == 263)
			{
			push(@session_id_arr,$avp_hex);
			}
		if($avp_code == 416)
			{
			$cc_req_type = $avp_hex;
			}
		if($avp_code == 415)
			{
			$cc_req_num = $avp_hex;
			}
		if($avp_code == 258)
			{
			$auth_application_id = $avp_hex;
			}
		}
	}

sub read_raa()
	{
	print "\n###Received RAA###\n";
	}	

sub read_dwa()
	{
	print "\n###Received DWA###\n";
	}	

sub read_dpa()
	{
	print "\n###Received DPA###\n";
	}	
		
sub send_cea()
	{
	print "\n#################### Sending CEA#####################\n";
	my ($code) = @_;
	my $osi = read_osi();
	my $result_code_avp = create_avp(268,$code);
	my $origin_host_avp = create_avp(264,$local_hostname);
	my $origin_realm_avp = create_avp(296,$local_realm);
	my $host_ip_address_avp = create_avp(257,$local_host_ip_hex,"64");
	my $vendor_id_avp = create_avp(266,$peer_vendor_id);
	my $product_name_avp = create_avp(269,$local_product_name);
	my $origin_state_id_avp = create_avp(278,$osi);
	my $supported_vendor_id_avp = create_avp(260,$peer_vendor_specific_id);
	my $avps = pack("a*a*a*a*a*a*a*a*",$result_code_avp,$origin_host_avp,$origin_realm_avp,$host_ip_address_avp,$vendor_id_avp,$product_name_avp,$origin_state_id_avp,$supported_vendor_id_avp);
	my $length = length ($avps);
	$length = $length + 20;
	my $diam_header =  create_header("00","257",$length);
	my $msg = pack("a*a*",$diam_header,$avps);
	$client_socket->send($msg);
	print "#################### Sent CEA #####################\n";
	if($dwr_flag eq "YES")
		{
		create_watchdog_task();	
		}
	}
	
sub send_cca()
	{
	print "\n#################### Sending CCA #####################\n";
	my ($code,$new_rule,$index) = @_;
	my $osi = read_osi();
	my $session_id = $session_id_arr[$index];
	my $session_id_avp = create_avp(263,$session_id);
	my $auth_application_id_avp = create_avp(258,$auth_application_id);
	my $origin_host_avp = create_avp(264,$local_hostname);
	my $origin_realm_avp = create_avp(296,$local_realm);
	my $result_code_avp = create_avp(268,$code);
	my $cc_req_type_avp = create_avp(416,"");
	my $cc_req_num_avp = create_avp(415,"");
	my $origin_state_id_avp = create_avp(278,$osi);
	my $charging_rule_install = create_avp(1001,$new_rule,"192","10415");
	my $avps = pack("a*a*a*a*a*a*a*a*a*",$session_id_avp,$auth_application_id_avp,$origin_host_avp,$origin_realm_avp,$result_code_avp,$cc_req_type_avp,$cc_req_num_avp,$origin_state_id_avp,$charging_rule_install);
	my $length = length ($avps);
	$length = $length + 20;
	my $diam_header = create_header("64","272",$length);
	my $msg = pack("a*a*",$diam_header,$avps);
	$client_socket->send($msg);
	print "#################### Sent CCA #####################\n";
	}	

sub send_raru()
	{
	print "\n#################### Sending RAR-U #####################\n";
	my ($old_rule,$new_rule,$index) = @_;
	update_e2e_hbyh();
	my $osi = read_osi();
	my $session_id = $session_id_arr[$index];
	my $session_id_avp = create_avp(263,$session_id);
	my $auth_application_id_avp = create_avp(258,$auth_application_id);
	my $origin_host_avp = create_avp(264,$local_hostname);
	my $origin_realm_avp = create_avp(296,$local_realm);
	my $destination_realm_avp = create_avp(283,$peer_origin_realm);
	my $destination_host_avp = create_avp(293,$peer_origin_host);
	my $re_auth_req_type = create_avp(285,"0");
	my $origin_state_id_avp = create_avp(278,$osi);
	my $charging_rule_install = create_avp(1001,$new_rule,"192","10415");
	my $charging_rule_remove = create_avp(1002,$old_rule,"192","10415");
	my $avps = pack("a*a*a*a*a*a*a*a*a*a*",$session_id_avp,$auth_application_id_avp,$origin_host_avp,$origin_realm_avp,$destination_realm_avp,$destination_host_avp,$re_auth_req_type,$origin_state_id_avp,$charging_rule_remove,$charging_rule_install);
	my $length = length ($avps);
	$length = $length + 20;
	my $diam_header = create_header("192","258",$length);
	my $msg = pack("a*a*",$diam_header,$avps);
	$client_socket->send($msg);
	print "#################### Sent RAR-U #####################\n";
	}

sub send_dwr()
	{
	print "\n#################### Sending DWR #####################\n";
	my $osi = read_osi();
	update_e2e_hbyh();
	my $origin_host_avp = create_avp(264,$local_hostname);
	my $origin_realm_avp = create_avp(296,$local_realm);
	my $origin_state_id_avp = create_avp(278,$osi);
	my $avps = pack("a*a*a*",$origin_host_avp,$origin_realm_avp,$origin_state_id_avp);
	my $length = length ($avps);
	$length = $length + 20;
	my $diam_header = create_header("128","280",$length);
	my $msg = pack("a*a*",$diam_header,$avps);
	$client_socket->send($msg);
	print "#################### Sent DWR #####################\n";
	}

sub send_rart()
	{
	print "\n#################### Sending RAR-T #####################\n";
	my ($index) = @_;
	my $osi = read_osi();
	update_e2e_hbyh();
	my $session_id = $session_id_arr[$index];
	my $session_id_avp = create_avp(263,$session_id);
	my $auth_application_id_avp = create_avp(258,$auth_application_id);
	my $origin_host_avp = create_avp(264,$local_hostname);
	my $origin_realm_avp = create_avp(296,$local_realm);
	my $destination_realm_avp = create_avp(283,$peer_origin_realm);
	my $destination_host_avp = create_avp(293,$peer_origin_host);
	my $re_auth_req_type = create_avp(285,"0");
	my $origin_state_id_avp = create_avp(278,$osi);
	my $session_release_cause = create_avp(1045,1,"192","10415");
	my $avps = pack("a*a*a*a*a*a*a*a*a*",$session_id_avp,$auth_application_id_avp,$origin_host_avp,$origin_realm_avp,$destination_realm_avp,$destination_host_avp,$re_auth_req_type,$session_release_cause,$origin_state_id_avp);
	my $length = length ($avps);
	$length = $length + 20;
	my $diam_header = create_header("192","258",$length);
	my $msg = pack("a*a*",$diam_header,$avps);
	$client_socket->send($msg);
	print "#################### Sent RAR-T #####################\n";
	}
	
sub send_dpr()
	{
	print "\n#################### Sending DPR #####################\n";
	my $osi = read_osi();
	update_e2e_hbyh();
	my $origin_host_avp = create_avp(264,$local_hostname);
	my $origin_realm_avp = create_avp(296,$local_realm);
	my $disconnect_cause_avp = create_avp(273,2);
	my $avps = pack("a*a*a*",$origin_host_avp,$origin_realm_avp,$disconnect_cause_avp);
	my $length = length ($avps);
	$length = $length + 20;
	my $diam_header = create_header("128","282",$length);
	my $msg = pack("a*a*",$diam_header,$avps);
	$client_socket->send($msg);
	print "#################### Sent DPR #####################\n";
	}
	
##### Sub-Routines #####
sub create_socket()
	{
	# auto-flush on socket
	$| = 1;
	# creating a listening socket
	our $socket = new IO::Socket::INET (
		LocalHost => '0.0.0.0',
		LocalPort => '3868',
		Proto => 'tcp',
		Listen => 5,
		Reuse => 1
	);
	die "ERROR: Cannot Open Socket $!\n" unless $socket;
	# Wait for the connection
	print "PCRF Ready and listening on port 3868!!!\n";
	$client_socket = $socket->accept();
	}

sub close_socket()
	{
	print "\n### Closing Socket !!!\n";
	shutdown($client_socket, 1);
	$socket->close();
	}
	
sub return_avp()
	{
	my ($first_byte) = @_;
	my $avp_code = hex(unpack('H*',join('',$data_arr[$first_byte],$data_arr[$first_byte+1],$data_arr[$first_byte+2],$data_arr[$first_byte+3])));
	my $avp_code_hex = join('',$data_arr[$first_byte],$data_arr[$first_byte+1],$data_arr[$first_byte+2],$data_arr[$first_byte+3]);
	my $avp_flags = unpack('H*',$data_arr[$first_byte+4]);
	my $avp_flags_hex = $data_arr[$first_byte+4];
	my $avp_length = hex(unpack('H*',join('',$data_arr[$first_byte+5],$data_arr[$first_byte+6],$data_arr[$first_byte+7])));
	my $avp_length_hex = join('',$data_arr[$first_byte+5],$data_arr[$first_byte+6],$data_arr[$first_byte+7]);
	my $avp_data = "";
	my $padding_hex = "";
	my $last_byte = $first_byte + $avp_length;
	for(my $i = $first_byte + 8; $i < $last_byte; $i++)
			{
			my $temp = join('',$avp_data,$data_arr[$i]);
			$avp_data = $temp;
			}
    my $final_avp_data = unpack('H*', $avp_data);			
	if($avp_length%4 != 0)
		{
		my $padding = 4 - ($avp_length%4);
		$last_byte = $last_byte + $padding;
		for(my $i=0;$i<$padding;$i++)
			{
			$padding_hex = $padding_hex."\x00";
			}
		}
	#AVP in Hex
	my $avp_hex = join('',$avp_code_hex,$avp_flags_hex,$avp_length_hex,$avp_data,$padding_hex);
	#my $avp_hex = pack ("a*a*a*a*a*",$avp_code_hex,$avp_flags_hex,$avp_length_hex,$avp_data,$padding_hex);
	return($last_byte,$avp_code,$avp_length,$final_avp_data,$avp_hex);
	}

sub create_avp()
	{
	my ($code,$value,$flags,$vendor_id) = @_;
	my ($code_hex,$length_hex,$value_hex,$vendor_id_hex);
	my $avp_hex;
	if($flags eq undef)
		{
		$flags = "00";
		}
	my $flags_hex = sprintf("%02x", $flags);
	my $vendor_id_hex = sprintf("%08x", $vendor_id);
	### AVP Type String ###
	if(($code == 264)||($code == 296)||($code == 283)||($code == 293)||($code == 269))
		{
		$code_hex = sprintf("%08x", $code);
		my $length = length($value);
		my $padding_hex;
		if($length%4 != 0)
			{
			my $padding = 4 - ($length%4);
			for(my $i=0;$i<$padding;$i++)
				{
				$padding_hex = $padding_hex."\x00";
				}
			}
		$length = $length + 8;
		$length_hex = sprintf("%06x", $length);
		$value = $value.$padding_hex;
		$avp_hex = pack ("H8H2H6a*",$code_hex,$flags_hex,$length_hex,$value);
		}
	### AVP Type Enumerated and non-Vendor Specific Data ###
	if(($code == 268)||($code == 285)||($code == 278)||($code == 273))
		{
		$code_hex = sprintf("%08x", $code);
		$length_hex = sprintf("%06x", 12);
		$value_hex = sprintf("%08x", $value);
		$avp_hex = pack ("H8H2H6H*",$code_hex,"00",$length_hex,$value_hex);
		}
	### AVP Type Address and non-Vendor Specific Data ###
	if($code == 257)
		{
		$code_hex = sprintf("%08x", $code);
		$length_hex = sprintf("%06x", 14);
		my $padding_hex = "\x00\x00";
		$value = pack("a*a*",$value,$padding_hex);
		$avp_hex = pack ("H8H2H6a*",$code_hex,$flags_hex,$length_hex,$value);
		}	
	### Hardcoded AVPs ###
	if($code == 266)
		{
		$avp_hex = $peer_vendor_id;
		}
	if($code == 260)
		{
		$avp_hex = $peer_vendor_specific_id;
		}
	if($code == 263)
		{
		$avp_hex = $value;
		}
	if($code == 258)
		{
		$avp_hex = $auth_application_id;
		}	
	if($code == 416)
		{
		$avp_hex = $cc_req_type;
		}	
	if($code == 415)
		{
		$avp_hex = $cc_req_num;
		}	
	### Gx Specific AVPs ###
	if(($code == 1001)||($code == 1002))
		{
		$code_hex = sprintf("%08x", $code);
		$value = create_avp(1005,$value,"192",10415);
		my $length = length($value);
		my $padding_hex;
		if($length%4 != 0)
			{
			my $padding = 4 - ($length%4);
			for(my $i=0;$i<$padding;$i++)
				{
				$padding_hex = $padding_hex."\x00";
				}
			}
		$length = $length + 12;
		$length_hex = sprintf("%06x", $length);
		$vendor_id_hex = sprintf("%08x", $vendor_id);
		$value = $value.$padding_hex;
		$avp_hex = pack ("H8H2H6H8a*",$code_hex,$flags_hex,$length_hex,$vendor_id_hex,$value);
		}
	if($code == 1005)
		{
		$code_hex = sprintf("%08x", $code);
		my $length = length($value);
		my $padding_hex;
		if($length%4 != 0)
			{
			my $padding = 4 - ($length%4);
			for(my $i=0;$i<$padding;$i++)
				{
				$padding_hex = $padding_hex."\x00";
				}
			}
		$length = $length + 12;
		$length_hex = sprintf("%06x", $length);
		$vendor_id_hex = sprintf("%08x", $vendor_id);
		$value = $value.$padding_hex;
		$avp_hex = pack ("H8H2H6H8a*",$code_hex,$flags_hex,$length_hex,$vendor_id_hex,$value);
		}
	if($code == 1045)
		{
		$code_hex = sprintf("%08x", $code);
		$length_hex = sprintf("%06x", 16);
		$vendor_id_hex = sprintf("%08x", $vendor_id);
		$value_hex = sprintf("%08x", $value);
		$avp_hex = pack ("H8H2H6H8H*",$code_hex,$flags_hex,$length_hex,$vendor_id_hex,$value_hex);
		}
	return($avp_hex);
	}
	
sub create_header()
	{
	my ($flags,$code,$length) = @_;
	my $flags_hex = sprintf("%02x", $flags);
	my $code_hex = sprintf("%06x", $code);
	my $length_hex = sprintf("%06x", $length);
	my $header = pack ("a1H6H2H6a4a4a4",$ver_hex,$length_hex,$flags_hex,$code_hex,$application_id_hex,$hbyh_hex,$e2e_hex);
	return($header);
	}
		
sub return_hex_ip()
	{
	my $ip = shift;
	my $ip_family = sprintf("%04x", 1);
	if($ip =~ m/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/)
		{
		($a,$b,$c,$d) = ($1,$2,$3,$4);
		}
	my $hex_ip = pack("H4H2H2H2H2",$ip_family,sprintf("%02x",$a),sprintf("%02x",$b),sprintf("%02x",$c),sprintf("%02x",$d));
	return($hex_ip);	
	}

sub update_e2e_hbyh()
	{
	my ($temp1,$temp2) = (0,0);
	$temp1 = hex(unpack('H*', $hbyh_hex));
	$temp1++;
	$hbyh_hex = pack("H*",sprintf("%08x", $temp1));;
	$temp2 = hex(unpack('H*', $e2e_hex));
	$temp2++;
	$e2e_hex = pack("H*",sprintf("%08x", $temp2));;
	}
	
sub read_osi()
	{
	my $osi = 0;
	my $out = `cat osi_file.txt`;
	if($out =~ m/([0-9]+)/)
		{
		$osi = $1;
		}
	return($osi);
	}

sub read_pcrf_properties()
	{
	my $out = `cat pcrf_properties.txt`;
	my @lines = split('\n', $out);
	foreach $line (@lines)
		{
		if($line =~ m/Hostname=\s*([a-zA-Z0-9\._]+)/)
			{
			$local_hostname = $1;
			}
		if($line =~ m/Realm=\s*([a-zA-Z0-9\._]+)/)
			{
			$local_realm = $1;
			}
		if($line =~ m/Host-IP=\s*([0-9\.]+)/)
			{
			$local_host_ip = $1;
			}
		if($line =~ m/Product-Name=\s*([a-zA-Z0-9\._]+)/)
			{
			$local_product_name = $1;
			}	
		if($line =~ m/DWR_enabled=\s*([a-zA-Z]+)/)
			{
			$dwr_flag = $1;
			}	
		if($line =~ m/DWR_interval=\s*([0-9]+)/)
			{
			$dwr_interval = $1;
			}	
		}
	}
	