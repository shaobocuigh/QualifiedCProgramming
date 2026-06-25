/*
Given a map, return true if all keys are strings in lower
case || all keys are strings in upper case, else return false.
The function should return false is the given map is empty.
Examples:
check_map_case({{"a","apple"}, {"b","banana"}}) should return true.
check_map_case({{"a","apple"}, {"A","banana"}, {"B","banana"}}) should return false.
check_map_case({{"a","apple"}, {"8","banana"}, {"a","apple"}}) should return false.
check_map_case({{"Name","John"}, {"Age","36"}, {"City","Houston"}}) should return false.
check_map_case({{"STATE","NC"}, {"ZIP","12345"} }) should return true.
*/

#include "ptr_array2_def.h"

/*@ Import Coq Require Import SimpleC.EE.QCP_demos_LLM.two_d_functional_spec_lib */
/*@ Extern Coq (CheckDictCaseResult : list (list Z) -> Z -> Z -> Prop)
               (DictCasePrefixState : list (list Z) -> Z -> Z -> Z -> Z -> Prop)
               (DictCaseScanState : list (list Z) -> Z -> Z -> Z -> Z -> Z -> Prop)
*/

int check_dict_case(const char** keys, int dict_size)
/*@ With rows
    Require 0 <= dict_size && dict_size <= 100 &&
            Zlength(rows) == dict_size &&
            (forall (k: Z), (0 <= k && k < dict_size) => (1 < Zlength(Znth(k, rows, nil)) && Zlength(Znth(k, rows, nil)) <= 100 && Znth(Zlength(Znth(k, rows, nil)) - 1, Znth(k, rows, nil), 0) == 0)) &&
            (forall (k: Z) (i: Z), (0 <= k && k < dict_size && 0 <= i && i < Zlength(Znth(k, rows, nil)) - 1) => (Znth(i, Znth(k, rows, nil), 0) != 0)) &&
            CharPtrArray2::full(keys, dict_size, rows)
    Ensure CheckDictCaseResult(rows, dict_size, __return) &&
           CharPtrArray2::full(keys, dict_size, rows)
*/
{
    int islower=0,isupper=0;
    if (dict_size==0) return 0;
    /*@ Inv Assert
        0 <= k && k <= dict_size@pre &&
        0 <= dict_size@pre && dict_size@pre <= 100 &&
        dict_size@pre != 0 &&
        dict_size == dict_size@pre &&
        keys == keys@pre &&
        Zlength(rows) == dict_size@pre &&
        (forall (r: Z), (0 <= r && r < dict_size@pre) => (1 < Zlength(Znth(r, rows, nil)) && Zlength(Znth(r, rows, nil)) <= 100 && Znth(Zlength(Znth(r, rows, nil)) - 1, Znth(r, rows, nil), 0) == 0)) &&
        (forall (r: Z) (i: Z), (0 <= r && r < dict_size@pre && 0 <= i && i < Zlength(Znth(r, rows, nil)) - 1) => (Znth(i, Znth(r, rows, nil), 0) != 0)) &&
        0 <= islower && islower <= 1 &&
        0 <= isupper && isupper <= 1 &&
        DictCasePrefixState(rows, dict_size@pre, k, islower, isupper) &&
        CharPtrArray2::full(keys@pre, dict_size@pre, rows)
    */
    for (int k=0;k<dict_size;k++)
    {
        /*@ Assert
            exists row_ptr,
            0 <= k && k < dict_size@pre &&
            0 <= dict_size@pre && dict_size@pre <= 100 &&
            dict_size@pre != 0 &&
            dict_size == dict_size@pre &&
            keys == keys@pre &&
            Zlength(rows) == dict_size@pre &&
            (forall (r: Z), (0 <= r && r < dict_size@pre) => (1 < Zlength(Znth(r, rows, nil)) && Zlength(Znth(r, rows, nil)) <= 100 && Znth(Zlength(Znth(r, rows, nil)) - 1, Znth(r, rows, nil), 0) == 0)) &&
            (forall (r: Z) (i: Z), (0 <= r && r < dict_size@pre && 0 <= i && i < Zlength(Znth(r, rows, nil)) - 1) => (Znth(i, Znth(r, rows, nil), 0) != 0)) &&
            0 <= islower && islower <= 1 &&
            0 <= isupper && isupper <= 1 &&
            DictCasePrefixState(rows, dict_size@pre, k, islower, isupper) &&
            CharPtrArray2::missing_i(keys@pre, dict_size@pre, k, row_ptr, rows) *
            data_at(keys@pre + (k * sizeof(char *)), char *, row_ptr) *
            CharArray::full(row_ptr, Zlength(Znth(k, rows, nil)), Znth(k, rows, nil))
        */
        const char* key=keys[k];

        /*@ Assert
            exists row_ptr,
            0 <= k && k < dict_size@pre &&
            0 <= dict_size@pre && dict_size@pre <= 100 &&
            dict_size@pre != 0 &&
            dict_size == dict_size@pre &&
            keys == keys@pre &&
            key == row_ptr &&
            Zlength(rows) == dict_size@pre &&
            (forall (r: Z), (0 <= r && r < dict_size@pre) => (1 < Zlength(Znth(r, rows, nil)) && Zlength(Znth(r, rows, nil)) <= 100 && Znth(Zlength(Znth(r, rows, nil)) - 1, Znth(r, rows, nil), 0) == 0)) &&
            (forall (r: Z) (i: Z), (0 <= r && r < dict_size@pre && 0 <= i && i < Zlength(Znth(r, rows, nil)) - 1) => (Znth(i, Znth(r, rows, nil), 0) != 0)) &&
            0 <= islower && islower <= 1 &&
            0 <= isupper && isupper <= 1 &&
            DictCasePrefixState(rows, dict_size@pre, k, islower, isupper) &&
            CharPtrArray2::missing_i(keys@pre, dict_size@pre, k, row_ptr, rows) *
            data_at(keys@pre + (k * sizeof(char *)), char *, row_ptr) *
            CharArray::full(row_ptr, Zlength(Znth(k, rows, nil)), Znth(k, rows, nil))
        */
        /*@ Inv Assert
            exists row_ptr,
            0 <= i && i < Zlength(Znth(k, rows, nil)) &&
            0 <= k && k < dict_size@pre &&
            0 <= dict_size@pre && dict_size@pre <= 100 &&
            dict_size@pre != 0 &&
            dict_size == dict_size@pre &&
            keys == keys@pre &&
            key == row_ptr &&
            Zlength(rows) == dict_size@pre &&
            (forall (r: Z), (0 <= r && r < dict_size@pre) => (1 < Zlength(Znth(r, rows, nil)) && Zlength(Znth(r, rows, nil)) <= 100 && Znth(Zlength(Znth(r, rows, nil)) - 1, Znth(r, rows, nil), 0) == 0)) &&
            (forall (r: Z) (i0: Z), (0 <= r && r < dict_size@pre && 0 <= i0 && i0 < Zlength(Znth(r, rows, nil)) - 1) => (Znth(i0, Znth(r, rows, nil), 0) != 0)) &&
            0 <= islower && islower <= 1 &&
            0 <= isupper && isupper <= 1 &&
            DictCaseScanState(rows, dict_size@pre, k, i, islower, isupper) &&
            CharPtrArray2::missing_i(keys@pre, dict_size@pre, k, row_ptr, rows) *
            data_at(keys@pre + (k * sizeof(char *)), char *, row_ptr) *
            CharArray::full(row_ptr, Zlength(Znth(k, rows, nil)), Znth(k, rows, nil))
        */
        for (int i=0;key[i]!='\0';i++)
        {
            if (key[i]<'A' || (key[i]>'Z' && key[i]<'a') || key[i]>'z') return 0;
            if (key[i]>='A' && key[i]<='Z') isupper=1;
            if (key[i]>='a' && key[i]<='z') islower=1;
            if (isupper+islower==2) return 0;
        }
        /*@ Assert
            0 <= k && k < dict_size@pre &&
            0 <= islower && islower <= 1 &&
            0 <= isupper && isupper <= 1 &&
            keys == keys@pre &&
            dict_size == dict_size@pre &&
            0 <= dict_size@pre && dict_size@pre <= 100 &&
            dict_size@pre != 0 &&
            Zlength(rows) == dict_size@pre &&
            (forall (r: Z), (0 <= r && r < dict_size@pre) => (1 < Zlength(Znth(r, rows, nil)) && Zlength(Znth(r, rows, nil)) <= 100 && Znth(Zlength(Znth(r, rows, nil)) - 1, Znth(r, rows, nil), 0) == 0)) &&
            (forall (r: Z) (i0: Z), (0 <= r && r < dict_size@pre && 0 <= i0 && i0 < Zlength(Znth(r, rows, nil)) - 1) => (Znth(i0, Znth(r, rows, nil), 0) != 0)) &&
            DictCasePrefixState(rows, dict_size@pre, k + 1, islower, isupper) &&
            store(&key, char *, key) *
            CharPtrArray2::full(keys@pre, dict_size@pre, rows)
        */

    }
    return 1;
}
