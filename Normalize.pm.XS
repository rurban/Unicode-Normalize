package Unicode::Normalize;

use 5.006;
use strict;
use warnings;
use Carp;

our $VERSION = '0.11';
our $PACKAGE = __PACKAGE__;

require Exporter;
require DynaLoader;
require AutoLoader;

our @ISA = qw(Exporter DynaLoader);
our @EXPORT = qw( NFC NFD NFKC NFKD );
our @EXPORT_OK = qw(
    normalize
    decompose reorder compose
    getCanon getCompat getComposite getCombinClass isExclusion
    NFC_check NFD_check NFKC_check NFKD_check
);
our %EXPORT_TAGS = ( all => [ @EXPORT, @EXPORT_OK ] );

bootstrap Unicode::Normalize $VERSION;

use constant CANON  => 0;
use constant COMPAT => 1;
use constant CHECKD => 1;

sub NFD  ($) { reorder(decompose($_[0], CANON )) }
sub NFKD ($) { reorder(decompose($_[0], COMPAT)) }

sub NFC  ($) { compose(reorder(decompose($_[0], CANON ))) }
sub NFKC ($) { compose(reorder(decompose($_[0], COMPAT))) }

sub NFD_check ($) {
    $_[0] = decompose($_[0], CANON );
    reorder($_[0], CHECKD);
}
sub NFKD_check($) {
    $_[0] = decompose($_[0], COMPAT);
    reorder($_[0], CHECKD);
}
sub NFC_check ($) {
    $_[0] = reorder(decompose($_[0], CANON ));
    compose($_[0], CHECKD);
}
sub NFKC_check($) {
    $_[0] = reorder(decompose($_[0], COMPAT));
    compose($_[0], CHECKD);
}

sub normalize($$)
{
  my $form = shift;
  $form eq 'D'  || $form eq 'NFD'  ? NFD ($_[0]) :
  $form eq 'C'  || $form eq 'NFC'  ? NFC ($_[0]) :
  $form eq 'KD' || $form eq 'NFKD' ? NFKD($_[0]) :
  $form eq 'KC' || $form eq 'NFKC' ? NFKC($_[0]) :
    croak $PACKAGE."::normalize: invalid form name: $form";
}

1;
__END__
