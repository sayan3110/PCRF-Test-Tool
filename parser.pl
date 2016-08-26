use strict; 
use warnings;
use Switch;

my $file1 = "message_flow.txt";
my $file2 = "pcrf_template.pl";
my $file3 = "perl_pcrf.pl";
my $flag=0;


open(FILE1, '<', $file1) or die "couldn't open the file!";
open(FILE2, '<', $file2) or die "couldn't open the file!";
open(FILE3, '>', $file3) or die "couldn't open perl file";

while (<FILE2>) 
	{
	my $line1 = $_;
	print FILE3 $line1;
	if($line1 =~ m/Start of Message Sequence/)
		{
		last;
		}
	}
	
while (<FILE1>) 
	{
	my $line1 = $_;
	if($flag==1)
		{
		translator($line1);
		}
	if($line1 =~ m/Define Message Flow below this line/)
		{
		$flag=1;
		}
	if($line1 =~ m/End of Message Sequence/)
		{
		$flag=0;
		last;
		}
	}
	
while (<FILE2>) 
	{
	my $line1 = $_;
	print FILE3 $line1;
	}

close (FILE1); 
close (FILE2);
close (FILE3);

sub translator()
	{
	my ($line) = @_;
	my $msg = "";
	if(($line =~ m/([A-Z]+)/) && ($line !~ m/#/))
		{
		$msg = $1;
		}
	switch($msg)
		{
		case["CER","CCR","RAAU","RAAT","RAA"]
			{
			print FILE3 "        receive_msg();\n";
			}
		case["CEA"]
			{
			if($line =~ m/([A-Z]+)\|response_code=([0-9]+)/)
				{
				print FILE3 "        send_cea(\"$2\");\n";
				}
			}
		case["CCA"]
			{
			if($line =~ m/([A-Z]+)\|response_code=([0-9]+)\|charging_rule_install=([a-zA-Z0-9 _]+)\|index=([0-9]+)/)
				{
				print FILE3 "        send_cca(\"$2\",\"$3\",\"$4\");\n";
				}
			}
		case["RARU"]
			{
			if($line =~ m/([A-Z]+)\|charging_rule_remove=([a-zA-Z0-9 _]+)\|charging_rule_install=([a-zA-Z0-9 _]+)\|index=([0-9]+)/)
				{
				print FILE3 "        send_raru(\"$2\",\"$3\",\"$4\");\n";
				}
			}
		case["RART"]
			{
			if($line =~ m/([A-Z]+)\|index=([0-9]+)/)
				{
				print FILE3 "        send_rart(\"$2\");\n";
				}
			}
		case["SLEEP"]
			{
			if($line =~ m/([A-Z]+)\|time=([0-9]+)/)
				{
				print FILE3 "        sleep(\"$2\");\n";
				}
			}	
		case["CREATE_SOCKET"]
			{
			print FILE3 "        create_socket();\n";
			}
		case["CLOSE_SOCKET"]
			{
			print FILE3 "        close_socket();\n";
			}
		}
	}
	
