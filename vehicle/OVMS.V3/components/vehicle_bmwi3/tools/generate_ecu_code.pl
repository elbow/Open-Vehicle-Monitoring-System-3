#! /usr/bin/perl -w

no warnings 'experimental::smartmatch';

use File::Slurp;
use Data::Dumper;
use JSON::PP;

our $DEBUG = 0;

# Optionally you can pass a PID to match in which case you get that one only
our @MATCH_PIDS = ();
if (scalar(@ARGV) > 3) {
    @MATCH_PIDS = @ARGV[3..scalar(@ARGV)-1];
    @MATCH_PIDS = map { uc($_) } @MATCH_PIDS;
}

our $types = {
    'signed char' => 'SCHAR',
    'unsigned char' => 'UCHAR',
    'char' => 'UCHAR',
    'signed int' => 'SINT',
    'unsigned int' => 'UINT',
    'int' => 'UINT',
    'long' => 'SINT32',
    'signed long' => 'SINT32',
    'unsigned long' => 'UINT32'
};

our $sizes = {
    'signed char' => 1,
    'unsigned char' => 1,
    'char' => 1,
    'signed int' => 2,
    'unsigned int' => 2,
    'int' => 2,
    'long' => 4,
    'signed long' => 4,
    'unsigned long' => 4
};

our $ctypes = {
    'signed char' => 'char',
    'unsigned char' => 'unsigned char',
    'char' => 'char',
    'signed int' => 'short',
    'unsigned int' => 'unsigned short',
    'int' => 'unsigned short',
    'signed long' => 'long',
    'long' => 'long',
    'unsigned long' => 'unsigned long',
    'BITFIELD' => 'HANDLED SEPARATELY'
};

# These map from the C++ types!
our $formats = {
    'char' => '%x',
    'unsigned char' => '%x',
    'short' => '%d',
    'unsigned short' => '%u',
    'long' => '%ld',
    'unsigned long' => '%lu',
    'float' => "%.4f",
    'string?' => "%s"
};

our $blacklist = {
#    'KUEHLDAUER_HVB' => 1                      # Obsolete and dupe
};

# We sometimes get duplicate result names - in that case we dedupe them by added the ID that they are returned from
our $usedfunctionnames = {};
our $usedresultnames = {};


binmode(STDOUT, ":utf8");
open (CODE, ">&=3") || die "Can't fdopen 3";
open (POLLLIST, ">&=4") || die "Can't fdopen 4";

# Read ECU definition json as created by parseecu.pl
my $tables;
{
    my $jsonpp = JSON::PP->new->utf8;
    my $json = read_file($ARGV[0]);
    $tables = $jsonpp->decode($json);
}

our $ECU = $ARGV[1] || $tables->{'ovmscode'} || "???";
our $ECUID = $ARGV[2] || $tables->{'ovmsextaddr'} || "??";
our $ECUDESC = $tables->{'ovmsdesc'} || "ECU: $ECU";

print STDERR "Generating OVMS config for ECU $ECU on id $ECUID: $ECUDESC\n";

# Dump header
foreach my $FD (*STDOUT, *CODE, *POLLLIST) {
    print $FD "
//
// Warning: don't edit - generated by generate_ecu_code.pl processing $ARGV[0]: $ECU $ECUID: $ECUDESC
// This generated code  makes it easier to process CANBUS messages from the $ECU ecu in a BMW i3
//";
}

print "

#define I3_ECU_${ECU}_TX                                                0x06F1${ECUID}
#define I3_ECU_${ECU}_RX                                                0x06${ECUID}F1";


$tables = $tables->{'tables'};
my $functions = $tables->{'SG_FUNKTIONEN'};

my $need_nl = 0;

# Read through the functions
foreach my $function (@$functions) {

    my $functionname = $function->{ARG};

    # Filter
    if (scalar(@MATCH_PIDS)) {
	print STDERR "checking " . 
       	next unless (uc($function->{ID}) ~~ @MATCH_PIDS);
    }
    
    # For now skip those that take arguments (which are actually some of the most interesting)
    $need_nl = 1;
    if ($function->{ARG_TABELLE} && $function->{ARG_TABELLE} ne '-') {
        if ($need_nl) { print "\n"; $need_nl = 0; }
	    print "\n// Skipping " . $functionname . " on " . $function->{ID} . " which takes arguments";
	    next;
    }

    # And skip those marked as obsolete
    if ($function->{INFO} =~ /^Dieser Job ist nicht mehr angefordert und wird nicht mehr/) {
        if ($need_nl) { print "\n"; $need_nl = 0; }
	    print "\n// Skipping " . $functionname . " on " . $function->{ID} . " INFO says it's obsolete";
    	next;
    }

    # And skip those blacklisted
    if ($blacklist->{$functionname}) {
        if ($need_nl) { print "\n"; $need_nl = 0; }
    	print "\n// Skipping " . $functionname . " on " . $function->{ID} . ": Blacklisted";
    	next;
    }

    if ($need_nl) { print "\n"; $need_nl = 0; }

    # Uniqueify function name (there are dupes, though I'm sure there shouldn't be)
    if ($usedfunctionnames->{$functionname}) {
        $functionname = uc($function->{ID}) . "_" . $functionname;
        print STDERR "De-duped function " . $function->{ARG} . " as $functionname\n";
    }
    $usedfunctionnames->{$functionname} = 1;


    my $desc = format_desc($function->{INFO_EN}, $function->{INFO});
    if ($DEBUG) {
        print Dumper($function);
        if ($function->{ARG_TABELLE} && $function->{ARG_TABELLE} ne '-') {
            print Dumper({ arg_table => $tables->{uc($function->{ARG_TABELLE})} });
        }
        if ($function->{RES_TABELLE} && $function->{RES_TABELLE} ne '-') {
            print Dumper({ res_table => $tables->{uc($function->{RES_TABELLE})} });
        }
    }
    printf "\n#define I3_PID_%s_%-49s %6s", $ECU, $functionname, $function->{ID};
    print "\n        // $desc" if ($desc ne '');

    # write the code
    printf(CODE "%-80s    // %s", "\n\n  case I3_PID_${ECU}_" . $functionname . ": {", $function->{ID});

    # Now deal with the results
    my $results = $function->{RES_TABELLE};
    $results = $tables->{uc($results)};
    if (! $results) {
	# Might just be a single result
        if ($function->{DATENTYP} && $function->{DATENTYP} ne '-') {
            $results = [ $function ];
            Dumper($results);
        }
    }
    if ($results) {
        my $offset = 0;
        my @codelines;
        foreach my $result (@$results) {
            print "\n";
            print STDERR Dumper({result => $result}) if ($DEBUG);
            my $desc = format_desc($result->{INFO_EN}, $result->{INFO});
            my $datatype = $result->{DATENTYP};
            my $mul = $result->{MUL};
            my $div = $result->{DIV};
            my $add = $result->{ADD};
            my $unit = $result->{EINHEIT};
            my $resultname = $result->{RESULTNAME};
            $resultname = $result->{NAME} unless ($resultname && $resultname ne "-");
            # De-dupe it
            if ($usedresultnames->{$resultname}) {
                print STDERR "De-duped result $resultname as " . uc($function->{ID}) . "_" . $resultname . "\n";
                $resultname = uc($function->{ID}) . "_" . $resultname;
            }
            $usedresultnames->{$resultname} = 1;
            # Build the macro expansion including any manipulations.
            my $expr;
            my $ctype;
            if ($datatype =~ /^data\[(\d+)\]$/) {
                print "\n    // Can't yet generate code for $resultname of type $datatype at offset $offset. But we account for the $1 bytes";
                print "\n        // $desc" if ($desc ne '');
                $offset += $1;
            }
            elsif ($datatype =~ /^string\[(\d+)\]$/) {
                print "\n    // Can't yet generate code for $resultname of type $datatype, at offset $offset. But we account for the $1 bytes";
                print "\n        // $desc" if ($desc ne '');
                $offset += $1;                
            }
            elsif (! $ctypes->{$datatype} ) {
                print "\n    // Can't process $resultname - don't know type $datatype (*** this will mean all the following offsets are wrong!!! ****)";
            } else {
                # For a bitfield we can look up the bit definitions.
                my $isbitfield = 0;
                if ($datatype eq "BITFIELD") {
                    $isbitfield = 1;
                    my $bits = $tables->{$resultname};
                    # print Dumper({ "resultname" => $resultname, "datatype" => $datatype, "bitsdesc" => $bits});
                    if ($bits && $bits->[0]) {
                        $datatype = $bits->[0]->{DATENTYP};
                        print "\n    // $resultname is a BITFIELD of size $datatype.  We don't yet generate definitions for each bit, we treat as the host data type";
                        print "\n        // $desc" if ($desc ne '');
                        foreach my $bit (@$bits) {
                            print "\n            // Mask: " . $bit->{MASKE} . " - " . $bit->{INFO_EN};
                        }
                    } else {
                        $datatype = "unsigned char";
                        print "\n    // $resultname is a BITFIELD of unknown size.  We don't yet generate definitions for each bit, and we GUESSED it is one byte ***";
                        print "\n        // $desc" if ($desc ne '');
                    }
                }

                $ctype = $ctypes->{$datatype};
                $expr = '(RXBUF_' . $types->{$datatype} . '(' . $offset . ')';
                if ($mul ne '-' && $mul != 1) {
                    $expr .= '*' . $mul . 'f';
                    $ctype = 'float';
                }
                if ($div ne '-' && $div != 1) {
                    $expr .= '/' . $div . 'f';
                    $ctype = 'float';
                }
                $expr .= (($add > 0) ? '+' : '') . $add if ($add ne '-' && $add != 0);
                    $expr .= ')';
                $offset += $sizes->{$datatype};

                printf "\n    #define I3_RES_%s_%-45s %s", $ECU, $resultname, $expr;
                printf "\n    #define I3_RES_%s_%-45s '%s'", $ECU, $resultname . '_UNIT', $unit if ($unit && $unit ne '-');
                printf "\n    #define I3_RES_%s_%-45s %s", $ECU, $resultname . '_TYPE', $ctype if ($ctype);
                print "\n        // $desc" if ($desc ne '');

                # code
                push @codelines, "    $ctype $resultname = $expr;\n";
                push @codelines, "        // $desc";
                print STDERR "Don't have format for $ctype\n" unless ($formats->{$ctype});
                push @codelines, "    ESP_LOGD(TAG, \"From ECU %s, pid %s: got %s=" . $formats->{$ctype} . "%s\\n\", \"$ECU\", \"" . $functionname . "\", \"$resultname\", $resultname, " . (($unit && $unit ne "-") ? "\"\\\"$unit\\\"\"" : "\"\"") . ");\n";
            }
        }
        # code
        print CODE "\n    if (datalen < $offset) {\n        ESP_LOGW(TAG, \"Received %d bytes for %s, expected %d\", datalen, \"I3_PID_${ECU}_" . $functionname . "\", $offset);\n        break;\n    }";
        print CODE "\n" . join('', @codelines);
    }

    # code
    print CODE "\n    // ==========  Add your processing here ==========\n    break;\n  }";


    # polllist
    printf POLLLIST "\n%-120s %s",  "  //{ I3_ECU_${ECU}_TX, I3_ECU_${ECU}_RX, VEHICLE_POLL_TYPE_OBDIIEXTENDED, I3_PID_${ECU}_" . $functionname . ",", " {  0,  0,  0,  0 }, 0, ISOTP_EXTADR },   // " . $function->{ID}; 
}

print "\n";
print POLLLIST "\n";
print CODE "\n";


sub format_desc {
    my ($en, $de) = @_;
    
    my $desc = $en || '';
    if ($desc eq '') {
	$desc = $de || '';
    } else {
	$desc .= " / " . $de if ($de);
    }
    if ($desc && $desc ne '') {
	$desc =~ s/(.{1,110}|\S{111,})(?:\s[^\S\r\n]*|\Z)/$1\n        \/\/ /g if (length $desc >= 110);
	$desc =~ s/(\n        \/\/ )?$//;
    }
    return $desc;
}

#          'result' => {
#                        'MASKE' => '-',
#                        'INFO' => "\x{c3}\x{9c}berlastz\x{c3}\x{a4}hler Sch\x{c3}\x{bc}tz K1",
#                        'DATENTYP' => 'unsigned int',
#                        'MUL' => '1.0',
#                        'INFO_EN' => 'Overload counter contactor K1',
#                        'ADD' => '0.0',
#                        'RESULTNAME' => 'STAT_OVERLOAD_K1_WERT',
#                        'NAME' => '-',
#                        'L/H' => 'high',
#                        'DIV' => '1.0',
#                        'EINHEIT' => '-'
#                      }
