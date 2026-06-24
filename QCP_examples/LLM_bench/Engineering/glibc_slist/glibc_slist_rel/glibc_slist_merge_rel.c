#include "glibc_slist_clean_data.h"

/*@ Import Coq Require Import glibc_slist_merge_rel_lib */
/*@ Extern Coq (early_result :: * => * => *) */
/*@ Extern Coq (Permutation: {A} -> list A -> list A -> Prop) */
/*@ Extern Coq 
               (glibc_slist_clean_merge_M: list Z -> list Z -> program unit (list Z))
               (glibc_slist_clean_merge_M_loop: list Z -> list Z -> list Z -> program unit (early_result (list Z) (list Z)))
               (glibc_slist_clean_merge_M_loop_end: (list Z) -> program unit (list Z))
               (glibc_slist_clean_merge_M_after_loop: early_result (list Z) (list Z) -> program unit (list Z))
               (glibc_slist_clean_merge_M_loop_before: list Z -> list Z -> program unit (early_result (list Z * list Z * list Z) (list Z)))
                */

struct list *glibc_slist_clean_merge(struct list *x, struct list *y)
/*@ high_level_spec <= low_level_spec
    With l1 l2
    Require sll(x, l1) * sll(y, l2)
    Ensure exists l3, Permutation(l3, app(l1, l2)) && sll(__return, l3)
 */;
struct list *glibc_slist_clean_merge(struct list *x, struct list *y)
/*@ low_level_spec
    With X l1 l2
    Require safeExec(ATrue, glibc_slist_clean_merge_M(l1, l2), X) && sll(x, l1) * sll(y, l2)
    Ensure exists l3, safeExec(ATrue, return(l3), X) && sll(__return, l3)
 */
{
    struct list *head;
    struct list *cursor;
    struct list *node;

    if (x == 0) {
        return y;
    }

    head = x;
    cursor = x;
    /*@ Inv exists l1 l2 l3, safeExec(ATrue, bind(glibc_slist_clean_merge_M_loop(l1,l2,l3), glibc_slist_clean_merge_M_after_loop), X) && x == x@pre && cursor != 0 && undef_data_at(&node, struct list*) * sllseg(head, cursor, l1) * sll(cursor, l2) * sll(y, l3) */
    while (y != 0) {
        node = y;
        y = y->next;
        node->next = cursor->next;
        cursor->next = node;
        cursor = node;
        if (cursor->next == 0) {
            cursor->next = y;
            return head;
        }
        cursor = cursor->next;
    }
    return head;
}
