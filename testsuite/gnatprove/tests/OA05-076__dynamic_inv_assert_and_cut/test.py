from test_support import *

# The original ticket mentioned an issue in only Mont_Exp_Window, and
# indeed this code is only a subset of all the code in lsc-bignum from the
# upstream git repository.
#
# A huge amount of time is spent in gnatwhy3; to be investigated.

prove_all(steps=1,
          counterexample=False,
          prover=["z3"],
          opt=["--no-axiom-guard"])
