package Unicode::Normalize;

use 5.006;
use strict;
use warnings;
use Carp;
use Lingua::KO::Hangul::Util 0.06;

our $VERSION = '0.12';
our $PACKAGE = __PACKAGE__;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( NFC NFD NFKC NFKD );
our @EXPORT_OK = qw(
    normalize decompose reorder compose
    getCanon getCompat getComposite getCombinClass isExclusion
);
our %EXPORT_TAGS = ( all => [ @EXPORT, @EXPORT_OK ] );

our $Combin = do "unicore/CombiningClass.pl"
    || do "unicode/CombiningClass.pl"
    || croak "$PACKAGE: CombiningClass.pl not found";

our $Decomp = do "unicore/Decomposition.pl"
    || do "unicode/Decomposition.pl"
    || croak "$PACKAGE: Decomposition.pl not found";

our %Combin; # $codepoint => $number      : combination class
our %Canon;  # $codepoint => \@codepoints : canonical decomp.
our %Compat; # $codepoint => \@codepoints : compat. decomp.
our %Compos; # $string    => $codepoint   : composite
our %Exclus; # $codepoint => 1            : composition exclusions

{
    my($f, $fh);
    foreach my $d (@INC) {
	use File::Spec;
	$f = File::Spec->catfile($d, "unicore", "CompExcl.txt");
	last if open($fh, $f);
	$f = File::Spec->catfile($d, "unicode", "CompExcl.txt");
	last if open($fh, $f);
	$f = undef;
    }
    croak "$PACKAGE: CompExcl.txt not found in @INC" unless defined $f;
    while(<$fh>){
	next if /^#/ or /^$/;
	s/#.*//;
	$Exclus{ hex($1) } =1 if /([0-9A-Fa-f]+)/;
    }
    close $fh;
}

##
## converts string "hhhh hhhh hhhh" to a numeric list
##
sub _getHexArray { map hex(), $_[0] =~ /([0-9A-Fa-f]+)/g }

while($Combin =~ /(.+)/g) {
    my @tab = split /\t/, $1;
    my $ini = hex $tab[0];
    if($tab[1] eq '') {
	$Combin{ $ini } = $tab[2];
    } else {
	$Combin{ $_ } = $tab[2] foreach $ini .. hex($tab[1]);
    }
}

while($Decomp =~ /(.+)/g) {
    my @tab = split /\t/, $1;
    my $compat = $tab[2] =~ s/<[^>]+>//;
    my $dec = [ _getHexArray($tab[2]) ]; # decomposition
    my $com = pack('U*', @$dec); # composable sequence
    my $ini = hex($tab[0]);
    if($tab[1] eq '') {
	$Compat{ $ini } = $dec;
	if(! $compat) {
	    $Canon{  $ini } = $dec;
	    $Compos{ $com } = $ini if @$dec > 1;
        }
    } else {
	foreach my $u ($ini .. hex($tab[1])){
	    $Compat{ $u } = $dec;
		if(! $compat){
		$Canon{  $u }   = $dec;
		$Compos{ $com } = $ini if @$dec > 1;
	    }
	}
    }
}

sub getCanonList {
    my @src = @_;
    my @dec = map $Canon{$_} ? @{ $Canon{$_} } : $_, @src;
    join(" ",@src) eq join(" ",@dec) ? @dec : getCanonList(@dec);
    # condition @src == @dec is not ok.
}

sub getCompatList {
    my @src = @_;
    my @dec = map $Compat{$_} ? @{ $Compat{$_} } : $_, @src;
    join(" ",@src) eq join(" ",@dec) ? @dec : getCompatList(@dec);
    # condition @src == @dec is not ok.
}

foreach my $key (keys %Canon) { # exhaustive decomposition
    $Canon{$key}  = [ getCanonList($key) ];
}

foreach my $key (keys %Compat) { # exhaustive decomposition
    $Compat{$key} = [ getCompatList($key) ];
}

sub getCombinClass ($) { $Combin{$_[0]} || 0 }

sub getCanon ($) { 
    return exists $Canon{$_[0]}
	? pack('U*', @{ $Canon{$_[0]} })
	: scalar decomposeHangul($_[0]);
}

sub getCompat ($) {
    return exists $Compat{$_[0]}
	? pack('U*', @{ $Compat{$_[0]} })
	: scalar decomposeHangul($_[0]);
}

sub getComposite ($$) {
    my $hangul = getHangulComposite($_[0], $_[1]);
    return $hangul if $hangul;
    return $Compos{ pack('U*', @_[0,1]) } || undef;
}

sub isExclusion ($) {
    return exists $Exclus{$_[0]} ? 1 : 0;
}

##
## string decompose(string, compat?)
##
sub decompose {
    my $hash = $_[1] ? \%Compat : \%Canon;
    return pack 'U*', map {
	$hash->{ $_ } ? @{ $hash->{ $_ } } :
	0xAC00 <= $_ && $_ <= 0xD7A3 ? decomposeHangul($_) : $_
    } unpack('U*', $_[0]);
}

##
## string reorder(string)
##
sub reorder {
    my @src = unpack('U*', $_[0]);

    for(my $i=0; $i < @src;){
	$i++, next if ! $Combin{ $src[$i] };

	my $ini = $i;
	$i++ while $i < @src && $Combin{ $src[$i] };

        my @tmp = sort {
		$Combin{ $src[$a] } <=> $Combin{ $src[$b] } || $a <=> $b
	    } $ini .. $i - 1;

	@src[ $ini .. $i - 1 ] = @src[ @tmp ];
    }
    return pack('U*', @src);
}


##
## string compose(string)
##
## S : starter; NS : not starter;
##
## composable sequence begins at S.
## S + S or (S + S) + S may be composed.
## NS + NS must not be composed.
##
sub compose
{
    my @src = unpack('U*', $_[0]);

    for(my $s = 0; $s+1 < @src; $s++){
	next unless defined $src[$s] && ! $Combin{ $src[$s] };
	 # S only; removed or combining are skipped as a starter.

	my($c, $blocked, $uncomposed_cc);
	for(my $j = $s+1; $j < @src && !$blocked; $j++){
	    ($Combin{ $src[$j] } ? $uncomposed_cc : $blocked) = 1;

	    # S + C + S => S-S + C would be blocked. XXX 
	    next if $blocked && $uncomposed_cc;

	    # blocked by same CC
	    next if defined $src[$j-1]   && $Combin{ $src[$j-1] } 
		&& $Combin{ $src[$j-1] } == $Combin{ $src[$j] };

	    $c = getComposite($src[$s], $src[$j]);

	    # no composite or is exclusion
	    next if !$c || $Exclus{$c};

	    # replace by composite
	    $src[$s] = $c; $src[$j] = undef;
	    if($blocked) { $blocked = 0 } else { -- $uncomposed_cc }
	}
    }
    return pack 'U*', grep defined(), @src;
}

##
## normalization forms
##

use constant CANON  => 0;
use constant COMPAT => 1;

sub NFD  ($) { reorder(decompose($_[0], CANON )) }
sub NFKD ($) { reorder(decompose($_[0], COMPAT)) }

sub NFC  ($) { compose(reorder(decompose($_[0], CANON ))) }
sub NFKC ($) { compose(reorder(decompose($_[0], COMPAT))) }

sub normalize($$)
{
    my $form = shift;
    $form =~ s/^NF//;
    return
	$form eq 'D'  ? NFD ($_[0]) :
	$form eq 'C'  ? NFC ($_[0]) :
	$form eq 'KD' ? NFKD($_[0]) :
	$form eq 'KC' ? NFKC($_[0]) :
      croak $PACKAGE."::normalize: invalid form name: $form";
}

##
## for Debug
##
sub _getCombin { wantarray ? %Combin : \%Combin }
sub _getCanon  { wantarray ? %Canon  : \%Canon  }
sub _getCompat { wantarray ? %Compat : \%Compat }
sub _getCompos { wantarray ? %Compos : \%Compos }
sub _getExclus { wantarray ? %Exclus : \%Exclus }

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

=head2 Normalization

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

=head2 Character Data

These functions are interface of character data used internally.
If you want only to get unicode normalization forms, 
you need not to call them by yourself.

=over 4

=item C<$canonical_decomposed = getCanon($codepoint)>

=item C<$compatibility_decomposed = getCompat($codepoint)>

If the character of the specified codepoint is canonically or 
compatibility decomposable (including Hangul Syllables),
returns the B<completely decomposed> string equivalent to it.

If it is not decomposable, returns undef.

=item C<$uv_composite = getComposite($uv_here, $uv_next)>

If the couple of two characters here and next (as codepoints) is composable
(including Hangul Jamo/Syllables and Exclusions),
returns the codepoint of the composite.

If they are not composable, returns undef.

=item C<$combining_class = getCombinClass($codepoint)>

Returns the combining class as integer of the character.

=item C<$is_exclusion = isExclusion($codepoint)>

Returns a boolean whether the character of the specified codepoint is
a composition exclusion.

=back

=head2 EXPORT

C<NFC>, C<NFD>, C<NFKC>, C<NFKD>: by default.

C<normalize> and other some functions: on request.

=head1 AUTHOR

SADAHIRO Tomoyuki, E<lt>SADAHIRO@cpan.orgE<gt>

  http://homepage1.nifty.com/nomenclator/perl/

  Copyright(C) 2001, SADAHIRO Tomoyuki. Japan. All rights reserved.

  This program is free software; you can redistribute it and/or 
  modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item http://www.unicode.org/unicode/reports/tr15/

Unicode Normalization Forms - UAX #15

=item L<Lingua::KO::Hangul::Util>

utility functions for Hangul Syllables

=back

=cut
