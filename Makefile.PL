use ExtUtils::MakeMaker;

# This code for XS-NOXS installer is shamelessly stolen
# after Gurusamy Sarathy's Data::Dumper. Thank you!

use File::Copy qw();

my $arg = $ARGV[0] || "";
my($DOXS, $DONOXS);
$DONOXS = shift if $arg =~ /^noxs/i
	and -f "MANIFEST"
	and -f "Normalize.pm";
$DOXS   = shift if $arg =~ /^xs/i
	and -f "MANIFEST.XS"
	and -f "Normalize.xs.XS"
	and -f "Normalize.pm.XS"
	and -f "mkheader";

if ($DONOXS) {
    print STDERR "Disabling XS in sources...\n";
}
elsif ($DOXS) {
    print STDERR "Enabling XS in sources...\n";

    do "mkheader";

    die "***** Failed, sources could be inconsistent! *****\n"
     unless File::Copy::move('MANIFEST',	'MANIFEST.NXS')
	and File::Copy::move('MANIFEST.XS',	'MANIFEST')
	and File::Copy::move('Normalize.pm',	'Normalize.pm.NXS')
	and File::Copy::move('Normalize.xs.XS',	'Normalize.xs')
	and File::Copy::move('Normalize.pm.XS',	'Normalize.pm');
}

WriteMakefile(
    'NAME'		=> 'Unicode::Normalize',
    'VERSION_FROM'	=> 'Normalize.pm', # finds $VERSION
    'PREREQ_PM'		=> {
	Lingua::KO::Hangul::Util => 0.06,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Normalize.pod', # retrieve abstract from module
       AUTHOR     => 'SADAHIRO Tomoyuki <SADAHIRO@cpan.org>') : ()),
);
