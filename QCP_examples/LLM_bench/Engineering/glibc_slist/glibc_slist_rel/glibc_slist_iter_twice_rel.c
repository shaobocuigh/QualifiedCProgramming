#include "glibc_slist_clean_data.h"

/*@ Import Coq Require Import glibc_slist_iter_twice_rel_lib */
/*@ Extern Coq 
               (maketuple: {A} {B} -> A -> B -> (A * B))
               (glibc_slist_clean_iter_twice_M: list Z -> program unit (list Z * Z))
               (glibc_slist_clean_iter_twice_M_loop: list Z -> list Z -> Z -> program unit (list Z * Z))
               (glibc_slist_clean_iter_twice_M_loop_end: (list Z * Z) -> program unit (list Z * Z))
               (range: list Z -> Prop)
                */
/*@ Extern Coq (list_sum: list Z -> Z) */

long glibc_slist_clean_iter_twice(struct list *x)
/*@ high_level_spec <= low_level_spec
    With l1
    Require range(l1) && sll(x, l1)
    Ensure __return == list_sum(l1) && sll(x@pre, l1)
 */;
long glibc_slist_clean_iter_twice(struct list *x)
/*@ low_level_spec
    With X l1
    Require range(l1) && safeExec(ATrue, glibc_slist_clean_iter_twice_M(l1), X) && sll(x, l1)
    Ensure exists l2 r, safeExec(ATrue, return(maketuple(l2, r)), X) && __return == r && sll(x@pre, l2)
 */
{
    long sum;

    sum = 0;
    /*@ Inv exists s l1 l2, safeExec(ATrue, bind(glibc_slist_clean_iter_twice_M_loop(l1,l2,s), glibc_slist_clean_iter_twice_M_loop_end), X) && store(&sum, long, s) * sllseg(x@pre, x, l1) * sll(x, l2) */
    while (x != 0) {
        sum += x->data;
        x = x->next;
        if (x != 0) {
            sum += x->data;
            x = x->next;
        }
    }
    return sum;
}
