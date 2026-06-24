#include "glibc_slist_clean_data.h"

/*@ Import Coq Require Import glibc_slist_rev_rel_lib */
/*@ Extern Coq 
               (glibc_slist_clean_rev_M: list Z -> program unit (list Z))
               (glibc_slist_clean_rev_M_loop: list Z -> list Z -> program unit (list Z))
               (glibc_slist_clean_rev_M_loop_end: (list Z) -> program unit (list Z))
                */

struct list *glibc_slist_clean_rev(struct list *x)
/*@ high_level_spec <= low_level_spec
    With l1
    Require sll(x, l1)
    Ensure sll(__return, rev(l1))
 */;
struct list *glibc_slist_clean_rev(struct list *x)
/*@ low_level_spec
    With X l1
    Require safeExec(ATrue, glibc_slist_clean_rev_M(l1), X) && sll(x, l1)
    Ensure exists l2, safeExec(ATrue, return(l2), X) && sll(__return, l2)
 */
{
    struct list *w;
    struct list *t;

    w = 0;
    /*@ Inv exists l1 l2, safeExec(ATrue, bind(glibc_slist_clean_rev_M_loop(l1,l2), glibc_slist_clean_rev_M_loop_end), X) && undef_data_at(&t, struct list*) * sll(w, l1) * sll(x, l2) */
    while (x != 0) {
        t = x->next;
        x->next = w;
        w = x;
        x = t;
    }
    return w;
}
