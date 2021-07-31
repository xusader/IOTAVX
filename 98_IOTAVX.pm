#
# 98_IOTAVX.pm
#

package main;

use strict;
use warnings;
use DevIo; # load DevIo.pm if not already loaded
use Time::HiRes qw(gettimeofday);

# called upon loading the module IOTAVX
sub IOTAVX_Initialize($)
{
  my ($hash) = @_;

  Log 5, "IOTAVX_Initialize: Entering";
		
  require "$attr{global}{modpath}/FHEM/DevIo.pm";
  
  $hash->{DefFn}    = "IOTAVX_Define";
  $hash->{UndefFn}  = "IOTAVX_Undef";
  $hash->{SetFn}    = "IOTAVX_Set";
  $hash->{ReadFn}   = "IOTAVX_Read";
  $hash->{ReadyFn}  = "IOTAVX_Ready";
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
  
  # read the available data
  my $buf = DevIo_SimpleRead($hash);
  
  # stop processing if no data is available (device disconnected)
  return if(!defined($buf));
  
  Log3 $name, 5, "IOTAVX ($name) - received: $buf"; 
  
  #
  # do something with $buf, e.g. generate readings, send answers via DevIo_SimpleWrite(), ...
  #
   
}

# called if set command is executed
sub IOTAVX_Set($$@)
{
    my ($hash, $name, $cmd) = @_;

    my $usage = "unknown argument $cmd, choose one of statusRequest:noArg off:noArg on:noArg muteOff:noArg muteOn:noArg volumeUp:noArg volumeDown:noArg volume_pct:slider,-80,1,0";

    if($cmd eq "statusRequest")
    {
         DevIo_SimpleWrite($hash, "get_status\r\n", 2);
    }
    elsif($cmd eq "on")
    {
         my $id = q('@112');
         DevIo_SimpleWrite($hash, qq($id), 2);
    }
    elsif($cmd eq "off")
    {
         my $id = q('@113');
         DevIo_SimpleWrite($hash, qq($id), 2);
    }
    elsif($cmd eq "muteOn")
    {
         my $id = q('@11Q');
         DevIo_SimpleWrite($hash, qq($id), 2);
    }
    elsif($cmd eq "muteOff")
    {
         my $id = q('@11R');
         DevIo_SimpleWrite($hash, qq($id), 2);
    }
    elsif($cmd eq "volumeUp")
    {
         my $id = q('@11S');
	 DevIo_SimpleWrite($hash, qq($id), 2);
    }
    elsif($cmd eq "volumeDown")
    {
         my $id = q('@11T');
         DevIo_SimpleWrite($hash, qq($id), 2);
    }
    elsif($cmd eq "volume_pct")
    {
         my $id = q('@11P');
         DevIo_SimpleWrite($hash, qq($id), 2);
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
    DevIo_SimpleWrite($hash, "get_status\r\n", 2);
    
    return undef; 
}

1;
