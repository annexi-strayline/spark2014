------------------------------------------------------------------------------
--                                                                          --
--                           GNAT2WHY COMPONENTS                            --
--                                                                          --
--                        F L O W . A N A L Y S I S                         --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--                Copyright (C) 2013-2019, Altran UK Limited                --
--                                                                          --
-- gnat2why is  free  software;  you can redistribute  it and/or  modify it --
-- under terms of the  GNU General Public License as published  by the Free --
-- Software  Foundation;  either version 3,  or (at your option)  any later --
-- version.  gnat2why is distributed  in the hope that  it will be  useful, --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public License  distributed with  gnat2why;  see file COPYING3. --
-- If not,  go to  http://www.gnu.org/licenses  for a complete  copy of the --
-- license.                                                                 --
--                                                                          --
------------------------------------------------------------------------------

--  This package looks at the produced graphs and emits error messages

with Sinfo; use Sinfo;

package Flow.Analysis is

   procedure Analyse_Main (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Is_Main;
   --  If FA corresponds to a main program, we ensure that all globals it
   --  references are initialized.

   procedure Sanity_Check (FA   : in out Flow_Analysis_Graphs;
                           Sane :    out Boolean);
   --  Check the following basic properties:
   --     - is aliasing present (using the flag FA.Aliasing_Present)?
   --     - absence of variables in default initializations of record
   --       components and discriminants (SPARK LRM 4.4(2))
   --     - are all global variables used declared as such?
   --     - are we updating a variable we shouldn't (in parameter / global or
   --       package external state in an elaboration)
   --
   --  Complexity is O(N)

   procedure Sanity_Check_Postcondition (FA   : in out Flow_Analysis_Graphs;
                                         Sane : in out Boolean)
   with Pre => Sane and then
               FA.Kind in Kind_Subprogram
                        | Kind_Package_Body
                        | Kind_Package;
   --  Check Post, Refined_Post and Initial_Condition for use of variables we
   --  have not introduced through a global or parameter.
   --
   --  Complexity is O(N)

   procedure Find_Unwritten_Exports (FA : in out Flow_Analysis_Graphs);
   --  Find outputs which are never written to.
   --
   --  Complexity is O(N)

   procedure Find_Ineffective_Imports_And_Unused_Objects
     (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Subprogram | Kind_Task;
   --  Find all ineffective initial values and all unused objects.
   --
   --  Complexity is O(N^2) and O(N) respectively.

   procedure Find_Non_Elaborated_State_Abstractions
     (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Package | Kind_Package_Body;
   --  Find uses of state abstractions that belong to other non-elaborated
   --  packages.
   --
   --  Complexity is O(N)

   procedure Find_Ineffective_Statements (FA : in out Flow_Analysis_Graphs);
   --  Find all ineffective statements.
   --
   --  Complexity is O(N^2)

   procedure Find_Dead_Code (FA : in out Flow_Analysis_Graphs);
   --  Find all obviously dead code.
   --
   --  Complexity is O(N)

   procedure Find_Use_Of_Uninitialized_Variables
     (FA : in out Flow_Analysis_Graphs);
   --  Check all variables read (explicit and implicit) and issue either info
   --  messages or low/med/high checks depending on whether the variable is
   --  initialized/default initialized.
   --
   --  Complexity is O(N^2)

   procedure Find_Input_Only_Used_In_Assertions
     (FA : in out Flow_Analysis_Graphs);
   --  Detect global inputs that are only used in assertions (and therefore
   --  should be Proof_In).

   procedure Find_Stable_Elements (FA : in out Flow_Analysis_Graphs);
   --  Find stable loop statements.
   --
   --  Complexity is O(N^2)

   procedure Find_Exports_Derived_From_Proof_Ins
     (FA : in out Flow_Analysis_Graphs);
   --  Find exports derived from global variables with mode Proof_In.
   --
   --  Complexity is O(N^2) - (due to path search on each element of the
   --  precomputed dependency map)

   procedure Find_Hidden_Unexposed_State (FA : in out Flow_Analysis_Graphs);
   --  This procedure looks for hidden state variables and missing Part_Of
   --  indicators. Also detects hideen state that has a Part_Of indicator but
   --  is not mentioned in any refinement.
   --
   --  In particular:
   --
   --  1. It issues a medium check for Part_Of constituents that are not listed
   --     in the refinement (when there is one).
   --
   --  2. It issues a medium check for hidden states in the package body that
   --     are not constituents of any state abstraction.
   --
   --  3. It emits an error if there is any missing Part_Of indicator for
   --     constants with variable input (SPARK RM 7.2.6(2-3)) that are:
   --     * declared immidiately within the private part of a given package;
   --     * part of the visible state of a package that is declared immediately
   --       within the private part of a given package;
   --     * part of the visible state of a private child.
   --
   --  Note that the front-end enforces Part_Of on hidden state in all cases
   --  except for constants, since it cannot tell between a constant with
   --  variable input (which needs Part_Of) and one without (which does not)
   --  and this is why we have this check here.

   procedure Find_Impossible_To_Initialize_State
     (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Package | Kind_Package_Body;
   --  Finds state abstractions that are not mentioned in an Initializes aspect
   --  and are not pure global outputs of any of the package's subprograms.
   --  This makes it impossible for users of these package's to initialize
   --  those state abstractions.
   --
   --  Complexity is O(N)

   procedure Check_Depends_Contract (FA : in out Flow_Analysis_Graphs);
   --  Check the given Depends contract against the reality; do nothing if
   --  there is no such contract.
   --
   --  Complexity is O(N^2)

   procedure Check_Initializes_Contract (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Package | Kind_Package_Body;
   --  Check if the Initializes contract has extra or missing dependencies.
   --
   --  Complexity is O(N^2)

   procedure Check_Refined_State_Contract (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Package | Kind_Package_Body;
   --  Check if the Refined_State references any constant without variable
   --  inputs and if so emits a check. This enforces SPARK RM 7.2.2(16).

   procedure Check_Potentially_Blocking (FA : in out Flow_Analysis_Graphs)
   with Pre => Ekind (Scope (FA.Spec_Entity)) = E_Protected_Type;
   --  Check for potentially blocking operations in protected actions
   --
   --  The current implementation emits a message for each statement that
   --  involves a potentially blocking operation. This is enough to easily
   --  identify delay statements and entry call statements this is enough
   --  (but frontend flags them with a warning anyway).
   --
   --  For a call on a subprogram whose body contains a potentially blocking
   --  operation the idea is that once AI12-0064, i.e. the Nonblocking aspect,
   --  is implemented, the users should annotate subprograms called directly
   --  in the statements flagged by this routine as Nonblocking. This way they
   --  will progressively arrive at the one with a potentially blocking
   --  statement.
   --
   --  ??? An external call on a protected subprogram with the same target
   --  object as that of the protected action deserves a dedicated diagnostics.

   procedure Check_Prefixes_Of_Attribute_Old (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Subprogram | Kind_Task;
   --  We issue a high check whenever a variable that serves as a prefix of a
   --  'Old attribute is NOT an import.
   --
   --  Complexity is O(N)

   procedure Check_Consistent_AS_For_Private_Child
     (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Package | Kind_Package_Body;
   --  Check if the refinement of the parent package contains the state of the
   --  private child with Part_Of aspect.

   procedure Check_Aliasing (FA : in out Flow_Analysis_Graphs);
   --  Check each procedure call for aliasing
   --
   --  Complexity is O(N^2)

   procedure Check_Constant_After_Elaboration
     (FA : in out Flow_Analysis_Graphs);
   --  Enforce SPARK RM 6.1.4(2). Checks that:
   --  * a subprogram does not modify variables that have
   --    Constant_After_Elaboration set
   --  * a subprogram or entry having an Input or Proof_In global marked as
   --    Constant_After_Elaboration shall not be called during library unit
   --    elaboration.
   --
   --  Complexity is O(N)

   procedure Check_Function_For_Volatile_Effects
     (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Subprogram | Kind_Task;
   --  Checks that the subprogram does not have any volatile effects except if
   --  so specified. This check is only doing something when called on
   --  functions. We also issue a warning if we are dealing with a volatile
   --  function that has no volatile effects.
   --
   --  Complexity is O(N)

   procedure Check_Ghost_Procedure_Outputs (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind = Kind_Subprogram;
   --  Check if the ghost procedure has any non-ghost (global) outputs. This is
   --  to enforce SPARK RM 6.9(20).

   procedure Check_Concurrent_Accesses (GNAT_Root : Node_Id)
   with Pre => Nkind (GNAT_Root) = N_Compilation_Unit;
   --  Check exclusivity rules for concurrent accesses to library-level objects

   procedure Check_CAE_In_Preconditions (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind = Kind_Subprogram;
   --  Check that preconditions of protected operations only reference global
   --  variables that have Constant_After_Elaboration set.

   procedure Check_Elaborate_Body (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind = Kind_Package_Body
               and then Is_Compilation_Unit (FA.Analyzed_Entity);
   --  Checks that the compilation unit package has Elaborate_Body applied if
   --  at least one variable declared in the specification is modified in the
   --  package elaboration.

   procedure Check_Terminating_Annotation (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind = Kind_Subprogram;
   --  Checks if the terminating annotation is consistent with the results from
   --  flow analysis, emits a message if not.

   procedure Check_Termination (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind = Kind_Subprogram;
   --  This is currently only used by the hidden debug flag --flow-termination
   --
   --  It puts a warning or info message on the analyzed subprogram based on
   --  Is_Potentially_Nonreturning, so that it can be tested separately (as the
   --  impact it has on proof is not necessarily obvious or easy to trigger).

   procedure Check_State_Volatility_Escalation
     (FA : in out Flow_Analysis_Graphs)
   with Pre => FA.Kind in Kind_Package | Kind_Package_Body;
   --  Any external abstract state can be annotated with precise volatility
   --  information, here we need to make sure that we do not have anything
   --  exceeding what the contract allows.

private

   type Var_Use_Kind is (Use_Read, Use_Write, Use_Any);

   function First_Variable_Use (N        : Node_Id;
                                Scope    : Flow_Scope;
                                Var      : Flow_Id;
                                Precise  : Boolean;
                                Targeted : Boolean := False)
                                return Node_Id;
   --  Given a node N, traverse the tree to find the most deeply nested node
   --  which still uses Var. If Precise is True look only for Var (for example
   --  R.Y), otherwise also look for the entire variable represented by Var (in
   --  our example we'd also look for R).
   --
   --  When Targeted is set, we only search under specific nodes of the AST:
   --
   --    * For assignment statement, we only look at the right hand side of the
   --      assignment.
   --
   --    * For if statements we only check under the condition.
   --
   --  If we cannot find any suitable node we return N itself.

   function First_Variable_Use (FA      : Flow_Analysis_Graphs;
                                Var     : Flow_Id;
                                Kind    : Var_Use_Kind;
                                Precise : Boolean)
                                return Node_Id;
   --  Find a suitable node in the tree which uses the given variable. If
   --  Precise is True look only for Var (for example R.Y), otherwise we also
   --  look for the entire variable represented by Var (in our example we'd
   --  also look for R).
   --
   --  If no suitable node can be found we return FA.Analyzed_Entity as a
   --  fallback.

end Flow.Analysis;
