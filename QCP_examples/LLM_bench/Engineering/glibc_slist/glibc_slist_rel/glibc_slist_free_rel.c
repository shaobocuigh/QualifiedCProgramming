#include "glibc_slist_clean_data.h"

/*@ Import Coq Require Import glibc_slist_free_rel_lib */
/*@ Extern Coq 
               (glibc_slist_clean_free_M: list Z -> program unit unit)
               (glibc_slist_clean_free_M_loop: list Z -> program unit unit)
               (glibc_slist_clean_free_M_loop_end: unit -> program unit unit)
                */

void glibc_slist_clean_free(struct list *x)
/*@ high_level_spec <= low_level_spec
    With l1
    Require sll(x, l1)
    Ensure emp
 */;
void glibc_slist_clean_free(struct list *x)
/*@ low_level_spec
    With X l1
    Require safeExec(ATrue, glibc_slist_clean_free_M(l1), X) && sll(x, l1)
    Ensure safeExec(ATrue, return(tt), X) && emp
 */
{
    struct list *next;

    /*@ Inv exists l1, safeExec(ATrue, bind(glibc_slist_clean_free_M_loop(l1), glibc_slist_clean_free_M_loop_end), X) && undef_data_at(&next, struct list*) * sll(x, l1) */
    while (x != 0) {
        next = x->next;
        free_list_node(x);
        x = next;
    }
}
