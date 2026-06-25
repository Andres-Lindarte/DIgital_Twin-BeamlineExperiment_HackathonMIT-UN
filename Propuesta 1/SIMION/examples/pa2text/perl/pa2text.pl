#
# pa2text.cpp
# Reads the contents of a SIMION potential array file and writes the contents
# to standard output.
#
# This makes use of the SL Potential Array Tools library for
# the file I/O.
#
# David Manura, Scientific Instrument Services, Inc.
# $Revision$ $Date$ Created: 2003-11-14.
#

use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib/perl";
use warnings;
use Getopt::Long;

use SIMION::PA;

my $headers = 1;
my $points  = 1;
my $verbose = 1;
my $output;

#-- read command-line parameters

my $result = GetOptions(
    "headers!" => \$headers,
    "points!" => \$points,
    # may be '-' for STDOUT
    "output=s" => \$output,
    "verbose!" => \$verbose
);

if(!$result || @ARGV < 1) {
    &print_usage();
}

my $infile = $ARGV[0];

my $outfile = $output || "$infile.txt";

unless($outfile eq '-') {
    # write to file (not standard output)
    print "Writing $outfile...\n";
    open(STDOUT, ">$outfile") or die "$! $outfile";
}

# read file
my $pa = new SIMION::PA(file => $infile);

# print header parameters
if($headers) {
    print "begin_header\n";
    print "mode=",        $pa->mode(),        "\n";
    print "symmetry=",    $pa->symmetry(),    "\n";
    print "max_voltage=", $pa->max_voltage(), "\n";
    print "nx=",          $pa->nx(),          "\n";
    print "ny=",          $pa->ny(),          "\n";
    print "nz=",          $pa->nz(),          "\n";
    print "mirror_x=",    $pa->mirror_x(),    "\n";
    print "mirror_y=",    $pa->mirror_y(),    "\n";
    print "mirror_z=",    $pa->mirror_z(),    "\n";
    print "field=",       $pa->field(),       "\n";
    print "ng=",          $pa->ng(),          "\n";
    print "end_header\n";
}

# print data points
if($points) {
    print "begin_points\n";
    # note: output in row-major order: points[nz][ny][nz]
    for my $z (0 .. $pa->nz()-1) {
        for my $y (0 .. $pa->ny()-1) {
            for my $x (0 .. $pa->nx()-1) {
                my ($elec, $pot) = $pa->point($x, $y, $z);
                $elec = $elec ? 1 : 0;
                if($verbose) {
                    print "x=$x, y=$y, z=$z, ";
                    print "elec=$elec, pot=$pot\n";
                }
                else { # terse format
                    print "$elec, $pot\n";
                }
            }
        }
    }
    print "end_points\n";
}


sub print_usage
{
    print "pa2text\n";
    print "  usage: perl pa2text.pl [options] <file>\n";
    print "where options can contain\n";
    print "  --[no]headers - whether to display headers\n";
    print "  --[no]points  - whether to display data points\n";
    print "  --output=filename - write to file.  If unspecified,\n";
    print "                      appends '.txt' to input file name.\n";
    print "                      Use '-' to write to standard output.\n";
    print "  --[no]verbose - verbose data point format\n";
    exit(1);
}
