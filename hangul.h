/*
 * hangul.h
 *
 *   This file is for the Perl module Lingua::KO::Hangul::Util.
 *
 * last modified  Wed Oct 31 21:44:15 2001
 *

AUTHOR SADAHIRO Tomoyuki, SADAHIRO@cpan.orgE
  http://homepage1.nifty.com/nomenclator/perl/

  Copyright(C) 2001, SADAHIRO Tomoyuki. Japan. All rights reserved.

  This program is free software; you can redistribute it and/or 
  modify it under the same terms as Perl itself.
 *
 */

#ifndef HANGUL_H
#define HANGUL_H

#define Hangul_SBase  0xAC00
#define Hangul_SFinal 0xD7A3
#define Hangul_SCount  11172

#define Hangul_NCount    588

#define Hangul_LBase  0x1100
#define Hangul_LFinal 0x1112
#define Hangul_LCount     19

#define Hangul_VBase  0x1161
#define Hangul_VFinal 0x1175
#define Hangul_VCount     21

#define Hangul_TBase  0x11A7
#define Hangul_TFinal 0x11C2
#define Hangul_TCount     28

#define Hangul_IsS(u)  ((Hangul_SBase <= (u)) && ((u) <= Hangul_SFinal))
#define Hangul_IsN(u)  (! (((u) - Hangul_SBase) % Hangul_TCount))
#define Hangul_IsLV(u) (Hangul_IsS(u) && Hangul_IsN(u))
#define Hangul_IsL(u)  ((Hangul_LBase <= (u)) && ((u) <= Hangul_LFinal))
#define Hangul_IsV(u)  ((Hangul_VBase <= (u)) && ((u) <= Hangul_VFinal))
#define Hangul_IsT(u)  ((Hangul_TBase <= (u)) && ((u) <= Hangul_TFinal))

#define Hangul_BName "HANGUL SYLLABLE "
#define Hangul_BNameLen 16
#define Hangul_LLenMax   2
#define Hangul_VLenMax   3
#define Hangul_TLenMax   2
#define Hangul_NameMax  23

#define IsHangulNameV(c) ( \
  (c) == 'A' || (c) == 'E' || (c) == 'I' || (c) == 'O' || \
  (c) == 'U' || (c) == 'W' || (c) == 'Y' )

#define IsHangulNameC(c) ( \
  (c) == 'G' || (c) == 'N' || (c) == 'D' || (c) == 'R' || (c) == 'L' || \
  (c) == 'M' || (c) == 'B' || (c) == 'S' || (c) == 'J' || (c) == 'C' || \
  (c) == 'K' || (c) == 'T' || (c) == 'P' || (c) == 'H' )

U8* hangul_JamoL[] = { /* Initial (HANGUL CHOSEONG) */
    "G", "GG", "N", "D", "DD", "R", "M", "B", "BB",
    "S", "SS", "", "J", "JJ", "C", "K", "T", "P", "H"
  };

U8* hangul_JamoV[] = { /* Medial (HANGUL JUNGSEONG) */
    "A", "AE", "YA", "YAE", "EO", "E", "YEO", "YE", "O",
    "WA", "WAE", "OE", "YO", "U", "WEO", "WE", "WI", "YU", "EU", "YI", "I"
  };

U8* hangul_JamoT[] = { /* Final (HANGUL JONGSEONG) */
    "", "G", "GG", "GS", "N", "NJ", "NH", "D", "L", "LG", "LM",
    "LB", "LS", "LT", "LP", "LH", "M", "B", "BS",
    "S", "SS", "NG", "J", "C", "K", "T", "P", "H"
  };

#endif	/* HANGUL_H */
