use ExtUtils::MakeMaker;

# This code for XS-NOXS installer is shamelessly stolen
# after Gurusamy Sarathy's Data::Dumper. Thank you!

# a bit modified.

use File::Copy qw();

my $arg = $ARGV[0] || "";

if ($arg =~ /^no/i and -f "Normalize.xs") {
    print STDERR "Disabling XS in sources...\n";

    die "***** Failed, sources could be inconsistent! *****\n"
     unless File::Copy::move('MANIFEST',	'MANIFEST.XS')
	and File::Copy::move('MANIFEST.NXS',	'MANIFEST')
	and File::Copy::move('Normalize.pm',	'Normalize.pm.XS')
	and File::Copy::move('Normalize.xs',	'Normalize.xs.XS')
	and File::Copy::move('Normalize.pm.NXS','Normalize.pm');
}
if ($arg =~ /^xs/i and -f "Normalize.xs.XS") {
    print STDERR "Enabling XS in sources...\n";

    die "***** Failed, sources could be inconsistent! *****\n"
     unless File::Copy::move('MANIFEST',	'MANIFEST.NXS')
	and File::Copy::move('MANIFEST.XS',	'MANIFEST')
	and File::Copy::move('Normalize.pm',	'Normalize.pm.NXS')
	and File::Copy::move('Normalize.xs.XS',	'Normalize.xs')
	and File::Copy::move('Normalize.pm.XS',	'Normalize.pm');
}

my $PREREQ =  { # for NON-XS
	Lingua::KO::Hangul::Util => 0.06,
    }; # e.g., Module::Name => 1.1
my $clean = {};

if(-f "Normalize.xs") {
    print STDERR "Making header files for XS...\n";

    do "mkheader";
    $PREREQ = {};
    $clean = {FILES=> 'unfcan.h unfcmb.h unfcmp.h unfcpt.h unfexc.h'};
}


WriteMakefile(
    'NAME'		=> 'Unicode::Normalize',
    'VERSION_FROM'	=> 'Normalize.pm', # finds $VERSION
    'PREREQ_PM'		=> $PREREQ,
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Normalize.pm', # retrieve abstract from module
       AUTHOR     => 'SADAHIRO Tomoyuki <SADAHIRO@cpan.org>') : ()),
    clean => $clean,
);
