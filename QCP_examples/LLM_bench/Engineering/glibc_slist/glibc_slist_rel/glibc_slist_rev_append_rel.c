#include "glibc_slist_clean_data.h"

/*@ Import Coq Require Import glibc_slist_rev_append_rel_lib */
/*@ Extern Coq 
               (glibc_slist_clean_rev_append_M: list Z -> list Z -> program unit (list Z))
               (glibc_slist_clean_rev_append_M_loop: list Z -> list Z -> program unit (list Z))
               (glibc_slist_clean_rev_append_M_loop_end: (list Z) -> program unit (list Z))
                */

struct list *glibc_slist_clean_rev_append(struct list *x, struct list *y)
/*@ high_level_spec <= low_level_spec
    With l1 l2
    Require sll(x, l1) * sll(y, l2)
    Ensure sll(__return, app(rev(l1), l2))
 */;
struct list *glibc_slist_clean_rev_append(struct list *x, struct list *y)
/*@ low_level_spec
    With X l1 l2
    Require safeExec(ATrue, glibc_slist_clean_rev_append_M(l1, l2), X) && sll(x, l1) * sll(y, l2)
    Ensure exists l3, safeExec(ATrue, return(l3), X) && sll(__return, l3)
 */
{
    struct list *t;

    /*@ Inv exists l1 l2, safeExec(ATrue, bind(glibc_slist_clean_rev_append_M_loop(l1,l2), glibc_slist_clean_rev_append_M_loop_end), X) && undef_data_at(&t, struct list*) * sll(x, l1) * sll(y, l2) */
    while (x != 0) {
        t = x->next;
        x->next = y;
        y = x;
        x = t;
    }
    return y;
}
