#include "glibc_slist_clean_data.h"

/*@ Import Coq Require Import glibc_slist_multi_merge_rel_lib */
/*@ Extern Coq (early_result :: * => * => *) */
/*@ Extern Coq (Permutation: {A} -> list A -> list A -> Prop) */
/*@ Extern Coq 
               (glibc_slist_clean_multi_merge_M: list Z -> list Z -> list Z -> program unit (list Z))
               (glibc_slist_clean_multi_merge_M_loop: list Z -> list Z -> list Z -> list Z -> program unit (list Z))
               (glibc_slist_clean_multi_merge_M_loop_end: (list Z) -> program unit (list Z))
               (glibc_slist_clean_multi_merge_M_loop_before: list Z -> list Z -> list Z -> program unit (early_result (list Z * list Z * list Z * list Z) (list Z)))
                */

struct list *glibc_slist_clean_multi_merge(struct list *x, struct list *y,
                                           struct list *z)
/*@ high_level_spec <= low_level_spec
    With l1 l2 l3
    Require sll(x, l1) * sll(y, l2) * sll(z, l3)
    Ensure exists l4, Permutation(l4, app(app(l1, l2), l3)) && sll(__return, l4)
 */;
struct list *glibc_slist_clean_multi_merge(struct list *x, struct list *y,
                                           struct list *z)
/*@ low_level_spec
    With X l1 l2 l3
    Require safeExec(ATrue, glibc_slist_clean_multi_merge_M(l1, l2, l3), X) && sll(x, l1) * sll(y, l2) * sll(z, l3)
    Ensure exists l4, safeExec(ATrue, return(l4), X) && sll(__return, l4)
 */
{
    struct list *cursor;
    struct list *node;
    int take_y;

    if (x == 0) {
        x = y;
        y = 0;
    }

    if (x == 0) {
        x = z;
        z = 0;
        return x;
    }

    cursor = x;
    take_y = 1;
    /*@ Inv exists ty l1 l2 l3 l4, safeExec(ATrue, bind(glibc_slist_clean_multi_merge_M_loop(l1,l2,l3,l4), glibc_slist_clean_multi_merge_M_loop_end), X) && cursor != 0 && take_y == ty && undef_data_at(&node, struct list*) * sllseg(x, cursor, l1) * sll(cursor, l2) * sll(y, l3) * sll(z, l4) */
    while (y != 0 || z != 0) {
        if (take_y && y != 0) {
            node = y;
            y = y->next;
        } else if (z != 0) {
            node = z;
            z = z->next;
        } else {
            node = y;
            y = y->next;
        }

        node->next = cursor->next;
        cursor->next = node;
        cursor = node;
        take_y = !take_y;

        if (cursor->next != 0) {
            cursor = cursor->next;
        }
    }
    return x;
}
