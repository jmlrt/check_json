#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Std;
use LWP::UserAgent;
use JSON 'decode_json';

my $plugin_name = "Nagios check_http_json";
my $VERSION = "1.01";

# getopt module config
$Getopt::Std::STANDARD_HELP_VERSION = 1;

# nagios exit codes
use constant EXIT_OK            => 0;
use constant EXIT_WARNING       => 1;
use constant EXIT_CRITICAL      => 2;
use constant EXIT_UNKNOWN       => 3;
my $status = EXIT_UNKNOWN;

#parse cmd opts
my %opts;
getopts('vU:t:d:', \%opts);
$opts{t} = 5 unless (defined $opts{t});
my $timeout = $opts{t};
my $url = $opts{U};
my $file = $opts{d};
if (not (defined $url) )
{
  print "ERROR: INVALID USAGE\n";
  HELP_MESSAGE();
  exit $status;
}

#initialize useragent
my $ua = LWP::UserAgent->new;

$ua->agent('Redirect Bot ' . $VERSION);
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($timeout);

#get http
my $response = $ua->get($url);

#exit if result is not json
if ( index($response->header("content-type"), 'application/json') == -1 )
{
  print "Expected content-type to be application/json, got ", $response->header("content-type");
  exit EXIT_CRITICAL;
}

eval
{

  my $json_response = decode_json($response->content);
  my %json_hash = %{$json_response};

  $status = EXIT_OK;
  if ($file)
  {

    if ( -e $file)
    {

      open( my $fh, '<', $file );
      my $json_text = <$fh>;
      my $hash_import = decode_json( $json_text );
      my %attr_check = %{$hash_import};

      my @errors;

      for my $key (sort keys %attr_check)
      {
        my $attr = $attr_check{$key};
        my $have = $json_hash{$key};
        push @errors, "$key: $have"
          unless $have eq $attr;
      }

      if (@errors)
      {
        print map { "$_, " } @errors;
        $status = EXIT_CRITICAL;
      }
      else
      {
        print "Found expected content.";
        $status = EXIT_OK;
      }
    }
    else
    {
      print "Unable to find data file $opts{d}";
      $status = EXIT_UNKNOWN;
    }
  }

  exit $status;

}
or do
{
        print "Unable to decode JSON, invalid response?";
        exit EXIT_CRITICAL;
};

sub HELP_MESSAGE
{
  print <<EOHELP
Retrieve an http/s url and checks its application type is application/json and the response content decodes properly into JSON.
Optionally verify content is found using data file.

  --help      shows this message
  --version   shows version information

USAGE: $0 -U http://my.url.com [-d sample.data]

  -U          URL to retrieve (http or https)
  -d          absolute path to data file containing hash to find with JSON response (optional)
  -t          Timeout in seconds to wait for the URL to load (default 60)

EOHELP
;
}

sub VERSION_MESSAGE
{
  print <<EOVM
$plugin_name v. $VERSION
Copyright 2012, Brian Buchalter, http://www.endpoint.com - Licensed under GPLv2
EOVM
;
}
