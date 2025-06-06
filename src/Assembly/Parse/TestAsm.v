From Coq Require Import String.
From Coq Require Import List.
Require Import Crypto.Util.ErrorT.
Require Import Crypto.Util.Strings.Show.
Require Import Crypto.Assembly.Parse.
Require Crypto.Assembly.Parse.Examples.fiat_25519_carry_square_optimised.
Require Crypto.Assembly.Parse.Examples.fiat_25519_carry_square_optimised_seed10.
Require Crypto.Assembly.Parse.Examples.fiat_25519_carry_square_optimised_seed20.
Require Crypto.Assembly.Parse.Examples.fiat_p256_mul_optimised_seed11.
Require Crypto.Assembly.Parse.Examples.fiat_p256_mul_optimised_seed12.
Require Crypto.Assembly.Parse.Examples.fiat_p256_mul_optimised_seed4.
Require Crypto.Assembly.Parse.Examples.fiat_p256_square_optimised_seed103.
Require Crypto.Assembly.Parse.Examples.fiat_p256_square_optimised_seed46.
Require Crypto.Assembly.Parse.Examples.fiat_p256_square_optimised_seed6.
Require Crypto.Assembly.Parse.Examples.boringssl_nasm_full_mul_p256.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_gcc_14_1_O0.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_gcc_14_1_O1.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_gcc_14_1_O2.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_gcc_14_1_O3.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_gcc_14_1_Os.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_clang_19_1_0_O0.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_clang_19_1_0_O1.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_clang_19_1_0_O2.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_clang_19_1_0_O3.
Require Crypto.Assembly.Parse.Examples.fiat_25519_all_clang_19_1_0_Os.
Import ListNotations.
Local Open Scope list_scope.
Local Open Scope string_scope.

(* for i in $(echo *.asm | xargs wc -l | sort -h | grep -o '[^ ]*ȧsm'); do echo "Goal parse_correct_on_debug ${i%.*}.example."; echo "Proof. Time native_compute. exact eq_refl. Abort."; echo 'Redirect "log" Compute parse '"${i%.*}.example."; done *)
Goal parse_correct_on_debug fiat_25519_carry_square_optimised_seed20.example.
Proof. Time native_compute. exact eq_refl. Abort.
Redirect "log" Compute parse fiat_25519_carry_square_optimised_seed20.example.
Goal parse_correct_on_debug fiat_25519_carry_square_optimised.example.
Proof. Time native_compute. exact eq_refl. Abort.
Redirect "log" Compute parse fiat_25519_carry_square_optimised.example.
Goal parse_correct_on_debug fiat_25519_carry_square_optimised_seed10.example.
Proof. Time native_compute. exact eq_refl. Abort.
Redirect "log" Compute parse fiat_25519_carry_square_optimised_seed10.example.
Goal parse_correct_on_debug fiat_p256_square_optimised_seed46.example.
Proof. Time native_compute. exact eq_refl. Abort.
Redirect "log" Compute parse fiat_p256_square_optimised_seed46.example.
Goal parse_correct_on_debug fiat_p256_mul_optimised_seed4.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_p256_mul_optimised_seed4.example.*)
Goal parse_correct_on_debug fiat_p256_square_optimised_seed103.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_p256_square_optimised_seed103.example.*)
Goal parse_correct_on_debug fiat_p256_mul_optimised_seed11.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_p256_mul_optimised_seed11.example.*)
Goal parse_correct_on_debug fiat_p256_mul_optimised_seed12.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_p256_mul_optimised_seed12.example.*)
Goal parse_correct_on_debug fiat_p256_square_optimised_seed6.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_p256_square_optimised_seed6.example.*)
Goal parse_correct_on_debug boringssl_nasm_full_mul_p256.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse boringssl_nasm_full_mul_p256.example.*)
Goal parse_correct_on_debug fiat_25519_all_gcc_14_1_O0.example.
Proof. Time native_compute. exact eq_refl. Abort.
(* Redirect "log" Compute parse fiat_25519_all_gcc_14_1_O0.example. *)
Goal parse_correct_on_debug fiat_25519_all_gcc_14_1_O1.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_gcc_14_1_O1.example.*)
Goal parse_correct_on_debug fiat_25519_all_gcc_14_1_O2.example.
Proof. Time native_compute. Fail exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_gcc_14_1_O2.example.*)
Goal parse_correct_on_debug fiat_25519_all_gcc_14_1_O3.example.
Proof. Time native_compute. Fail exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_gcc_14_1_O3.example.*)
Goal parse_correct_on_debug fiat_25519_all_gcc_14_1_Os.example.
Proof. Time native_compute.  exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_gcc_14_1_Os.example.*)
Goal parse_correct_on_debug fiat_25519_all_clang_19_1_0_O0.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_clang_19_1_0_O0.example.*)
Goal parse_correct_on_debug fiat_25519_all_clang_19_1_0_O1.example.
Proof. Time native_compute. exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_clang_19_1_0_O1.example.*)
Goal parse_correct_on_debug fiat_25519_all_clang_19_1_0_O2.example.
Proof. Time native_compute. Fail exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_clang_19_1_0_O2.example.*)
Goal parse_correct_on_debug fiat_25519_all_clang_19_1_0_O3.example.
Proof. Time native_compute. Fail exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_clang_19_1_0_O3.example.*)
Goal parse_correct_on_debug fiat_25519_all_clang_19_1_0_Os.example.
Proof. Time native_compute. Fail exact eq_refl. Abort.
(*Redirect "log" Compute parse fiat_25519_all_clang_19_1_0_Os.example.*)
