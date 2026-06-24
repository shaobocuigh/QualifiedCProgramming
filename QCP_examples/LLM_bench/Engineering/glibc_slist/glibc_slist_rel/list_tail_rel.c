#include "glibc_slist_clean_data.h"

/*@ Import Coq Require Import list_tail_rel_lib */
/*@ Extern Coq (early_result :: * => * => *) */
/*@ Extern Coq 
               (maketuple: {A} {B} -> A -> B -> (A * B))
               (list_tail_M: list Z -> program unit (list Z * Z))
               (list_tail_M_loop: list Z -> list Z -> program unit (list Z * Z))
               (list_tail_M_loop_end: (list Z * Z) -> program unit (list Z * Z))
               (list_tail_M_loop_before: list Z -> program unit (early_result (list Z * list Z) (list Z * Z)))
                */

struct list *list_tail(struct list *x)
/*@ high_level_spec <= low_level_spec
    With l1
    Require x != 0 && sll(x, l1)
    Ensure exists l2 v, l1 == app(l2, cons(v, nil)) && __return != 0 && store(&(__return->next), struct list *, 0) * store(&(__return->data), int, v) * sllseg(x, __return, l2)
 */;
struct list *list_tail(struct list *x)
/*@ low_level_spec
    With X l1
    Require safeExec(ATrue, list_tail_M(l1), X) && x != 0 && sll(x, l1)
    Ensure exists l2 v, safeExec(ATrue, return(maketuple(l2, v)), X) && __return != 0 && store(&(__return->next), struct list *, 0) * store(&(__return->data), int, v) * sllseg(x, __return, l2)
 */
{
    if (x == 0) {
        return 0;
    }

    /*@ Inv exists l1 l2, safeExec(ATrue, bind(list_tail_M_loop(l1,l2), list_tail_M_loop_end), X) && x != 0 && sllseg(x@pre, x, l1) * sll(x, l2) */
    while (x->next != 0) {
        x = x->next;
    }
    return x;
}
