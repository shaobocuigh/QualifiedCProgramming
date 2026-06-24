

#include "sll_def.h"
#include "safeexec_def.h"


/*@ Extern Coq (maketuple: list Z -> list Z ->  ((list Z) * (list Z)))
               (split_rec_rel: list Z -> list Z -> list Z -> program unit ((list Z) * (list Z)))
               (split_rel: list Z -> program unit ((list Z) * (list Z)))
               (reversepair: ((list Z) * (list Z)) -> program unit ((list Z) * (list Z)))
                */

/*@ Import Coq Require Import SimpleC.EE.QCP_demos_human.sll_merge_rel_lib */

void split_while(struct list * x, struct list * * p, struct list * * q)
  /*@ low_level_spec
      With l X
      Require safeExec(ATrue, split_rec_rel(l, nil, nil), X) &&
              sll(x, l) * sll(* p, nil) * sll(* q, nil)
      Ensure exists s1 s2,
              safeExec(ATrue, return(maketuple(s1, s2)), X) &&
              sll(* p, s1) * sll(* q, s2)
  */
{

  struct list * t;


  /*@ Inv
    exists l l1 l2,
      p == p@pre && q == q@pre &&
      safeExec(ATrue, split_rec_rel(l, l1, l2), X) && 
      sll(x, l) * sll(* p, l1) * sll(* q, l2) *
      undef_data_at(&t, struct list *) 
  */
  while (x != (void *)0)
  {
    /*@ exists l1, x != 0 && sll(x, l1)
        which implies 
        exists l1_new, l1 == cons(x->data, l1_new) && sll(x->next, l1_new)
    */
    t = x -> next;
    x -> next = * p;
    * p = x;
    x = t;
    /*@ exists l l1 l2 l_new x_data, 
        safeExec(ATrue, split_rec_rel(l, l1, l2), X) && l == cons(x_data, l_new) &&
        (* p) != 0 && (* p) -> data == x_data && sll((* p) -> next, l1) * sll(x,l_new) * sll(* q, l2) 
      which implies
      safeExec(ATrue, bind(split_rec_rel(l_new, l2, cons(x_data, l1)), reversepair)  , X) && sll(* p, cons(x_data, l1)) * sll(x,l_new) * sll(* q, l2) 
    */
    if (x != (void *)0)
    {
      /*@ exists l1, x != 0 && sll(x, l1)
        which implies 
        exists l1_new, l1 == cons(x->data, l1_new) && sll(x->next, l1_new)
      */
      t = x -> next;
      x -> next = * q;
      * q = x;
      x = t;
      /*@ exists l l1 l2 l_new x_data x_data2, 
        safeExec(ATrue, bind(split_rec_rel(l, l2, cons(x_data, l1)), reversepair) , X) && 
        l == cons(x_data2, l_new) &&
        (* q) != 0 && (* q) -> data == x_data2 && sll((* q) -> next, l2) * sll(x,l_new) * sll(* p, cons(x_data, l1))
      which implies
      safeExec(ATrue, split_rec_rel(l_new, cons(x_data, l1), cons(x_data2, l2)), X) && 
      sll(* p, cons(x_data, l1)) * sll(* q, cons(x_data2, l2)) *  sll(x,l_new) 
      */
    }
  }
}































