
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "combin.h"
#include "canon.h"
#include "compat.h"
#include "compos.h"
#include "exclus.h"

/* At present, char > 0x10ffff are unaffected without complaint, right? */
#define _VALID_UTF_MAX    (0x10ffff)
#define _OVER_MAX_UTF(uv) (_VALID_UTF_MAX < (uv))
#define _IsHangul(uv)     (0xAC00 <= (uv) && (uv) <= 0xD7A3)

/* Perl 5.6 ? */
#ifndef uvuni_to_utf8
#define uvuni_to_utf8   uv_to_utf8
#endif /* uvuni_to_utf8 */ 

/* Perl 5.6 ? */
#ifndef utf8n_to_uvchr
#define utf8n_to_uvchr  utf8_to_uv
#endif /* utf8n_to_uvchr */ 

/* this is used for reordering of combining characters (c.c.). */
typedef struct { U8 cc; UV uv; STRLEN cnt; } __UNF_cc;

int compare_cc(const void *a, const void *b)
{
    int ret_cc;
    ret_cc = (*(__UNF_cc*)a).cc - (*(__UNF_cc*)b).cc;
    if(ret_cc) return ret_cc;
    return (*(__UNF_cc*)a).cnt - (*(__UNF_cc*)b).cnt;
}

U8* _canonical (UV uv)
{
  U8 ***plane, **row;
  if(_OVER_MAX_UTF(uv)) return NULL;
  plane = __UNF_canon[uv >> 16];
  if(! plane) return NULL;
  row = plane[(uv >> 8) & 0xff];
  return row ? row[uv & 0xff] : NULL;
}

U8* _compat (UV uv)
{
  U8 ***plane, **row;
  if(_OVER_MAX_UTF(uv)) return NULL;
  plane = __UNF_compat[uv >> 16];
  if(! plane) return NULL;
  row = plane[(uv >> 8) & 0xff];
  return row ? row[uv & 0xff] : NULL;
}

UV getComposite (UV uv, UV uv2)
{
  __UNF_complist ***plane, **row, *cell, *i;

  if(! uv2 || _OVER_MAX_UTF(uv)) return 0;
  plane = __UNF_compos[uv >> 16];
  if(! plane) return 0;
  row = plane[(uv >> 8) & 0xff];
  if(! row) return 0;
  cell = row[uv & 0xff];
  if(! cell) return 0;

  for(i = cell; i->nextchar; i++) {
    if(uv2 == i->nextchar) return i->composite;
  }
  return 0;
}

U8 getCombinClass (UV uv)
{
  U8 **plane, *row;
  if(_OVER_MAX_UTF(uv)) return 0;
  plane = __UNF_combin[uv >> 16];
  if(! plane) return 0;
  row = plane[(uv >> 8) & 0xff];
  return row ? row[uv & 0xff] : 0;
}

SV* _call_decompHangul (pTHX_ UV uv)
{
  dSP;
  int count;
  SV* retsv;
  ENTER;
  SAVETMPS;
  PUSHMARK(SP);
  XPUSHs(sv_2mortal(newSVuv(uv)));
  PUTBACK;
  count = call_pv("Unicode::Normalize::decomposeHangul", G_SCALAR);
  SPAGAIN;
  if (count != 1)
    croak("Panic in Unicode::Normalize calling decomposeHangul\n");
  retsv = newSVsv(POPs);
  PUTBACK;
  FREETMPS;
  LEAVE;
  return retsv;
}

MODULE = Unicode::Normalize	PACKAGE = Unicode::Normalize

void
_compose(arg)
    SV * arg
  PROTOTYPE: $
  PREINIT:
    SV  *src, *dst, *tmp;
    U8  *s, *p, *e, *d, *t, curCC, preCC;
    UV uv, uvS, uvComp;
    STRLEN srclen, dstlen, tmplen, fromS, dstcur, retlen;
    bool beginning = TRUE;
  PPCODE:
    if(SvUTF8(arg)) {
	src = arg;
    } else {
	src = sv_mortalcopy(arg);
	sv_utf8_upgrade(src);
    }
    s = SvPV(src, srclen);
    e = s + srclen;
    dstlen = srclen + 1; /* equal or shorter, XXX */
    dst = sv_2mortal(newSV(dstlen));
    (void)SvPOK_only(dst);
    SvUTF8_on(dst);
    d = (U8*)SvPVX(dst);

  /* for uncomposed combining char */
    tmp = sv_2mortal(newSV(dstlen));
    (void)SvPOK_only(tmp);
    SvUTF8_on(tmp);

    for(p = s; p < e;){
	if(beginning) {
	    uvS = utf8n_to_uvchr(p, e - p, &retlen, 0);
	    p += retlen;

            if (getCombinClass(uvS)){ /* no Starter found yet */
		d = uvuni_to_utf8(d, uvS);
		continue;
	    }
            beginning = FALSE;
	}

    /* Starter */
	t = (U8*)SvPVX(tmp);
	fromS = 0;
	preCC = 0;

    /* to the next Starter */
	while(p < e) {
	    uv = utf8n_to_uvchr(p, e - p, &retlen, 0);
	    ++fromS;
	    p += retlen;
	    curCC = getCombinClass(uv);

	    if((1 < fromS) && preCC && preCC == curCC) {
		preCC = curCC;
		t = uvuni_to_utf8(t, uv);
	    } else {
		uvComp = getComposite(uvS, uv);
		if(uvComp && ! getExclusion(uvComp)) {
		    /* preCC not changed to curCC */
		    uvS = uvComp;
	        } else if (! curCC && p < e) { /* blocked */
		    break;
		} else {
		    preCC = curCC;
		    t = uvuni_to_utf8(t, uv);
		}
	    }
	}
	d = uvuni_to_utf8(d, uvS); /* composed char */
	if(tmplen = t - (U8*)SvPVX(tmp)) { /* uncomposed combining char */
	    t = (U8*)SvPVX(tmp);
	    while(tmplen--) *d++ = *t++;
	}
	uvS = uv;
    } /* for */
    dstcur = d - (U8*)SvPVX(dst);
    SvCUR_set(dst, dstcur);
    XPUSHs(dst);


SV*
NFD(arg)
    SV * arg
  PROTOTYPE: $
  ALIAS:
    NFKD = 1
  PREINIT:
    SV *src, *dst;
    STRLEN srclen, dstlen, retlen, stk_cc_max;
    U8 *s, *e, *p, *d, *r, curCC;
    UV uv;
    __UNF_cc * stk_cc;
  CODE:
    if(SvUTF8(arg)) {
	src = arg;
    } else {
	src = sv_mortalcopy(arg);
	sv_utf8_upgrade(src);
    }
    dst = newSV(1);
    (void)SvPOK_only(dst);
    SvUTF8_on(dst);

    stk_cc_max = 10; /* enough as an initial value? */
    stk_cc = New(0, stk_cc, stk_cc_max, __UNF_cc);

    /* decompose */
    s = (U8*)SvPV(src,srclen);
    e = s + srclen;
    for(p = s; p < e;){
	uv = utf8n_to_uvchr(p, e - p, &retlen, 0);
	p += retlen;
	r = (ix == 0) ? _canonical(uv) : _compat(uv);
	if(r) {
	    sv_catpv(dst, r);
	} else if(_IsHangul(uv)) {
	    sv_catsv(dst, _call_decompHangul(uv));
	} else {
	    sv_catpvn(dst, p - retlen, retlen);
	}
    }

    /* reorder */
    d = (U8*)SvPV(dst,dstlen);
    e = d + dstlen;
    for(p = d; p < e;){
	U8 *cc_in;
	STRLEN cc_len, cc_iter, cc_num;

	uv = utf8n_to_uvchr(p, e - p, &retlen, 0);
	p += retlen;
	cc_num = 1;
	curCC = getCombinClass(uv);
	if(! (curCC && p < e)) continue; else cc_in = p - retlen;

	stk_cc[cc_num-1].cc  = curCC;
	stk_cc[cc_num-1].uv  = uv;
	stk_cc[cc_num-1].cnt = cc_num;

	while(p < e) {
	    uv = utf8n_to_uvchr(p, e - p, &retlen, 0);
	    curCC = getCombinClass(uv);
	    if(!curCC) break;
	    p += retlen;
	    cc_num++;
	    if(stk_cc_max <= cc_num) { /* extend if need */
		stk_cc_max = cc_num;
		stk_cc = Renew(stk_cc, stk_cc_max, __UNF_cc);
	    }
	    stk_cc[cc_num-1].cc  = curCC;
	    stk_cc[cc_num-1].uv  = uv;
	    stk_cc[cc_num-1].cnt = cc_num;
	}

	 /* only one c.c. in cc_len from cc_in, no need of reordering */
	if(cc_num < 2) continue;

	qsort((void*)stk_cc, cc_num, sizeof(__UNF_cc), compare_cc);

	cc_len = p - cc_in;
	p = cc_in;
	for(cc_iter = 0; cc_iter < cc_num; cc_iter++) {
	    p = uvuni_to_utf8(p, stk_cc[cc_iter].uv);
	}
    }
    Safefree(stk_cc);
    RETVAL = dst;
  OUTPUT:
    RETVAL

U8
getCombinClass(uv)
    UV uv

bool
getExclusion(uv)
    UV uv

UV
getComposite(uv, uv2)
    UV uv
    UV uv2

SV*
getCanon(uv)
    UV uv
  PROTOTYPE: $
  ALIAS:
    getCompat = 1
  PREINIT:
    U8 * rstr;
  CODE:
    rstr = ix ? _compat(uv) : _canonical(uv);
    if(!rstr) XSRETURN_UNDEF;
    RETVAL = newSVpvn(rstr, strlen(rstr));
    SvUTF8_on(RETVAL);
  OUTPUT:
    RETVAL
