package Unicode::Normalize;

use 5.006;
use strict;
use warnings;
use Carp;
use Lingua::KO::Hangul::Util;

our $VERSION = '0.06';
our $PACKAGE = __PACKAGE__;

require Exporter;
require DynaLoader;
require AutoLoader;

our @ISA = qw(Exporter DynaLoader);
our @EXPORT = qw( NFC NFD NFKC NFKD );
our @EXPORT_OK = qw( normalize getCanon getCompat
		getComposite getCombinClass getExclusion);
our %EXPORT_TAGS = ( all => [ @EXPORT, @EXPORT_OK ] );

bootstrap Unicode::Normalize $VERSION;

# NFK?D and _compose are in XS.

sub NFC($)  { _compose(scalar composeHangul(NFD ($_[0]))) }

sub NFKC($) { _compose(scalar composeHangul(NFKD($_[0]))) }

sub normalize($$)
{
  my $form = shift;
  $form eq 'D'  || $form eq 'NFD'  ? NFD ($_[0]) :
  $form eq 'C'  || $form eq 'NFC'  ? NFC ($_[0]) :
  $form eq 'KD' || $form eq 'NFKD' ? NFKD($_[0]) :
  $form eq 'KC' || $form eq 'NFKC' ? NFKC($_[0]) :
    croak $PACKAGE."::normalize: invalid form name: $form";
}

##
## "hhhh hhhh hhhh" to (dddd, dddd, dddd)
##
sub _getHexArray
{
  my $str = shift;
  map hex(), $str =~ /([0-9A-Fa-f]+)/g;
}

1;
__END__

=head1 NAME

Unicode::Normalize - normalized forms of Unicode text

=head1 SYNOPSIS

  use Unicode::Normalize;

  $string_NFD  = NFD($raw_string);  # Normalization Form D
  $string_NFC  = NFC($raw_string);  # Normalization Form C
  $string_NFKD = NFKD($raw_string); # Normalization Form KD
  $string_NFKC = NFKC($raw_string); # Normalization Form KC

   or

  use Unicode::Normalize 'normalize';

  $string_NFD  = normalize('D',  $raw_string);  # Normalization Form D
  $string_NFC  = normalize('C',  $raw_string);  # Normalization Form C
  $string_NFKD = normalize('KD', $raw_string);  # Normalization Form KD
  $string_NFKC = normalize('KC', $raw_string);  # Normalization Form KC

=head1 DESCRIPTION

=over 4

=item C<$string_NFD = NFD($raw_string)>

returns the Normalization Form D (formed by canonical decomposition).


=item C<$string_NFC = NFC($raw_string)>

returns the Normalization Form C (formed by canonical decomposition
followed by canonical composition).

=item C<$string_NFKD = NFKD($raw_string)>

returns the Normalization Form KD (formed by compatibility decomposition).

=item C<$string_NFKC = NFKC($raw_string)>

returns the Normalization Form KC (formed by compatibility decomposition
followed by B<canonical> composition).

=item C<$normalized_string = normalize($form_name, $raw_string)>

As C<$form_name>, one of the following names must be given.

  'C'  or 'NFC'  for Normalization Form C
  'D'  or 'NFD'  for Normalization Form D
  'KC' or 'NFKC' for Normalization Form KC
  'KD' or 'NFKD' for Normalization Form KD

=back

=head2 EXPORT

C<NFC>, C<NFD>, C<NFKC>, C<NFKD>: by default.

C<normalize>: on request.

=head1 AUTHOR

SADAHIRO Tomoyuki, E<lt>SADAHIRO@cpan.orgE<gt>

  http://homepage1.nifty.com/nomenclator/perl/

  Copyright(C) 2001, SADAHIRO Tomoyuki. Japan. All rights reserved.

  This program is free software; you can redistribute it and/or 
  modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item L<Lingua::KO::Hangul::Util>

utility functions for Hangul Syllables

=item http://www.unicode.org/unicode/reports/tr15/

Unicode Normalization Forms - UAX #15

=back

=cut
