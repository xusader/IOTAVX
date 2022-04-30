#
# 71_IOTAVX.pm xusader
#

package main;

use strict;
use warnings;
use DevIo; 
use Time::HiRes qw(gettimeofday);

my %commands = (
	"mute:on" => "",
	"mute:off" => ""
);

my %modes = (
	"DIRECT" => "",
	"STEREO" => ""
);

my %inputs = (
	"TV(ARC)"   => "",
        "HDMI1"     => "",
        "HDMI2"     => "",
        "HDMI3"     => "",
        "HDMI4"     => "",
        "HDMI5"     => "",
        "HDMI6"     => "",
        "COAX"      => "",
        "OPTICAL"   => "",
        "ANALOG1"   => "",
        "ANALOG2"   => "",
        "BT"        => ""
);

# called upon loading the module IOTAVX
sub IOTAVX_Initialize($)
{
  my ($hash) = @_;

  Log 5, "IOTAVX_Initialize: Entering";
		
  require "$attr{global}{modpath}/FHEM/DevIo.pm";
  
  $hash->{DefFn}     = "IOTAVX_Define";
  $hash->{UndefFn}   = "IOTAVX_Undef";
  $hash->{SetFn}     = "IOTAVX_Set";
  $hash->{ReadFn}    = "IOTAVX_Read";
  $hash->{ReadyFn}   = "IOTAVX_Ready";
}

# called when a new definition is created (by hand or from configuration read on FHEM startup)
sub IOTAVX_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t]+", $def);

  my $name = $a[0];
  
  # $a[1] is always equals the module name "IOTAVX"
  
  # first argument is a serial device (e.g. "/dev/ttyUSB0@9600")
  my $dev = $a[2]; 

  return "no device given" unless($dev);
  
  # close connection if maybe open (on definition modify)
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  

  # add a default baud rate (9600), if not given by user
  $dev .= '@9600' if(not $dev =~ m/\@\d+$/);
  
  # set the device to open
  $hash->{DeviceName} = $dev;
  
  # open connection with custom init function
  my $ret = DevIo_OpenDev($hash, 0, "IOTAVX_Init"); 

  #unless ( exists( $attr{$name}{devStateIcon} ) ) {
  #                 $attr{$name}{devStateIcon} = 'on:10px-kreis-gruen:disconnected disconnected:10px-kreis-rot:on';
  #          }
  unless (exists($attr{$name}{webCmd})){
                  $attr{$name}{webCmd} = 'on:off:mute:volume:volumeUp:volumeDown:input:mode';
          }

  return undef;
}

# called when definition is undefined 
# (config reload, shutdown or delete of definition)
sub IOTAVX_Undef($$)
{
  my ($hash, $name) = @_;
 
  # close the connection 
  DevIo_CloseDev($hash);
  
  return undef;
}

# called repeatedly if device disappeared
sub IOTAVX_Ready($)
{
  my ($hash) = @_;
  
  # try to reopen the connection in case the connection is lost
  return DevIo_OpenDev($hash, 1, "IOTAVX_Init"); 
}

# called when data was received
sub IOTAVX_Read($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  
  my $data = DevIo_SimpleRead($hash);
  return if(!defined($data)); # connection lost 

  my $buffer = $hash->{PARTIAL};
   
  # concat received data to $buffer
  $buffer .= $data;
 
  # as long as the buffer contains newlines (complete datagramm)
  while($buffer =~ '\*')
  {
    my $msg;

    # extract the complete message ($msg), everything else is assigned to $buffer
    ($msg, $buffer) = split("\n", $buffer, 2);

    # remove trailing whitespaces
    chomp $msg; 
    
    if ($msg =~/14K(\d+)/) {
      
      my $vol = ($1 / 10);

      readingsSingleUpdate($hash, "volume", $vol, 1);
      readingsSingleUpdate($hash, "mute", "off", 1);
    }
    elsif ($msg =~/DIM1\*/) {
       
      readingsSingleUpdate($hash, "mute", "on", 1);
    }

    # parse the extracted message
    IOTAVX_Parse($hash, $msg);
    Log3 $name, 5, "$name - msg: $msg";
  }
  # update $hash->{PARTIAL} with the current buffer content
  $hash->{PARTIAL} = $buffer; 
}

# called if set command is executed
sub IOTAVX_Set($@)
{
    my ($hash, @a) = @_;

    my $what = $a[1];
    
    my $usage = "Unknown argument $what, choose one of on off mute:on,off volumeDown volumeUp volume:slider,0,5,80 " . 
    		"input:" . join(",", sort keys %inputs) . " " .
    		"mode:" . join(",", sort keys %modes) . " " .
    		"statusRequest"; 

    if($what eq "statusRequest")
    {
       my $cmd = q('@12S');
       DevIo_SimpleWrite($hash, $cmd, 2);	  	
    }
    elsif ($what eq "on")
    {
       my $cmd = q('@112');
       DevIo_SimpleWrite($hash, $cmd, 2);
    }
    elsif ($what eq "off")
    {
       my $cmd = q('@113');
       DevIo_SimpleWrite($hash, $cmd, 2);
    }
    elsif ($what eq "volumeDown")
    {
       my $cmd = q('@11T');
       DevIo_SimpleWrite($hash, $cmd, 2);
    }
    elsif ($what eq "volumeUp")
    {
       my $cmd = q('@11S');
       DevIo_SimpleWrite($hash, $cmd, 2);
    }
    elsif ($what eq "volume")
    {
       my $volume = $a[2];
       my $vol = $volume * 10;
       my $strg1 = q('@11P);
       my $strg2 = q(');
       DevIo_SimpleWrite($hash, $strg1.$vol.$strg2, 2);
       readingsSingleUpdate($hash, "volume", $volume, 1);
    }    
    elsif ($what eq "mute")
    {
       my $mute =$a[2];
       
       if ($mute eq "on") {		
	    my $cmd = q('@11Q');
            DevIo_SimpleWrite($hash, $cmd, 2);
	    #readingsSingleUpdate($hash, "mute", "on", 1);
       } else {
            my $cmd = q('@11R');
	    DevIo_SimpleWrite($hash, $cmd, 2);
	    #readingsSingleUpdate($hash, "mute", "off", 1);
       }	       
    }
    elsif ($what eq "input")
    {
       my $input =$a[2];
	    
       if ($input eq "TV(ARC)") { 
	    my $cmd = q('@11B');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "TV(ARC)", 1);	    
       } elsif ($input eq "HDMI1") { 
	    my $cmd = q('@116');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "HDMI1", 1);	    
       } elsif ($input eq "HDMI2") {
	    my $cmd = q('@115');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "HDMI2", 1);
       } elsif ($input eq "HDMI3") {
	    my $cmd = q('@15A');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "HDMI3", 1);
       } elsif ($input eq "HDMI4") {
	    my $cmd = q('@15B');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "HDMI4", 1);
       } elsif ($input eq "HDMI5") {
	    my $cmd = q('@15C');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "HDMI5", 1);
       } elsif ($input eq "HDMI6") {
	    my $cmd = q('@15D');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "HDMI6", 1);
       } elsif ($input eq "COAX") {
	    my $cmd = q('@117');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "COAX", 1);
       } elsif ($input eq "OPTICAL") {
	    my $cmd = q('@15E');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "OPTICAL", 1);
       } elsif ($input eq "ANALOG1") {
	    my $cmd = q('@15F');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "ANALOG1", 1);
       } elsif ($input eq "ANALOG2") {
	    my $cmd = q('@15G');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "ANALOG2", 1);
       } else {
       if ($input eq "BT") {
	    my $cmd = q('@15H');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "input", "BT", 1);
       }
      }
    }
    elsif ($what eq "mode")
    {
       my $mode =$a[2];	    
       
       if ($mode eq "DIRECT") { 
            my $cmd = q('@13J');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "mode", "DIRECT", 1);
       } else {
       if ($mode eq "STEREO") { 
            my $cmd = q('@11E');
            DevIo_SimpleWrite($hash, $cmd, 2);
            readingsSingleUpdate($hash, "mode", "STEREO", 1);
       }
      }
    }
    else
    {
      return $usage;
    }
}

# will be executed upon successful connection establishment (see DevIo_OpenDev())
sub IOTAVX_Init($)
{
    my ($hash) = @_;

    # send a status request to the device
    #DevIo_SimpleWrite($hash, "get_status\r\n", 2);

    my $cmd = q('@12S');
    DevIo_SimpleWrite($hash, $cmd, 2);

    return undef; 
}

sub IOTAVX_Parse (@)
{

  my ($hash, $msg) = @_;
  my $name = $hash->{NAME};
 
  if ($msg =~/DIM/) {
    readingsSingleUpdate($hash, "state", "on", 1);
  } 
 
}

1;
