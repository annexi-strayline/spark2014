.. _How to Use GNATprove in a Team:

How to Use |GNATprove| in a Team
================================

The most common use of |GNATprove| is as part of a regular quality control or
quality assurance activity inside a team. Usually, |GNATprove| is run every
night on the current codebase, and during the day by developers either on their
computer or on servers. For both nightly and daily runs, |GNATprove| results
need to be shared between team members, either for viewing results or to
compare new results with the shared results. These various processes are
supported by specific ways to run |GNATprove| and share its results.

In all cases, the source code should not be shared directly (say, on a shared
drive) between developers, as this is bound to cause problems with file access
rights and concurrent accesses. Rather, the typical usage is for each user to
do a check out of the sources/environment, and use therefore her own
version/copy of sources and project files, instead of physically sharing
sources across all users.

The project file should also always specify a local, non shared, user writable
directory as object directory (whether explicitly or implicitly, as the absence
of an explicit object directory means the project file directory is used as
object directory).

Possible Workflows
------------------

Multiple workflows allow to use |GNATprove| in a team:

1. |GNATprove| is run on a server or locally, and no warnings or check messages
   should be issued. Typically this is achieved by suppressing spurious
   warnings and justifying unproved check messages.
2. |GNATprove| is run on a server or locally, and textual results are shared in
   Configuration Management.
3. |GNATprove| is run on a server, and textual results are sent to a third-party
   qualimetry tool (like GNATdashboard, SonarQube, SQUORE, etc.)
4. |GNATprove| is run on a server or locally, and the |GNATprove| session files
   are shared in Configuration Management.

In all workflows (but critically for the first workflow), messages can be
suppressed or justified. Indeed, like every sound and complete verification
tool, |GNATprove| may issue false alarms. A first step is to identify the type
of message:

* warnings can be suppressed, see :ref:`Suppressing Warnings`
* check messages can be justified, see :ref:`Justifying Check Messages`

Check messages from proof may also correspond to provable checks, which require
interacting with |GNATprove| to find the correct contracts and/or analysis
switches, see :ref:`How to Investigate Unproved Checks`.

The textual output in workflow 3 corresponds to the compiler-like output
generated by |GNATprove| and controlled with switches ``--report`` and
``--warnings`` (see :ref:`Running GNATprove from the Command Line`). By default
messages are issued only for unproved checks and warnings.

The textual output in workflow 2 comprises this compiler-like output, and
possibly additional output generated by |GNATprove| in file ``gnatprove.out``
(see :ref:`Effect of Mode on Output` and :ref:`Managing Assumptions`).

Workflow 4 requires sharing session files used by |GNATprove| to record the
state of formal verification on each source package. This is achieved by
specifying in the :ref:`Project Attributes` the ``Proof_Dir`` proof directory,
and sharing this directory under Configuration Management. To avoid conflicts,
it is recommended that developers do not push their local changes to this
directory in Configuration Management, but instead periodically retrieve an
updated version of the directory. For example, a nightly run on a server, or a
dedicated team member, can be responsible for updating the proof directory with
the latest version generated by |GNATprove|.

A benefit of workflow 4 compared to other workflows is that it avoids reproving
locally properties that were previously proved, as the shared session files
keep track of which checks were proved.

.. _Suppressing Warnings:

Suppressing Warnings
--------------------

|GNATprove| issues two kinds of warnings, which are controlled separately:

* Compiler warnings are controlled with the usual GNAT compilation switches:

  * ``-gnatws`` suppresses all warnings
  * ``-gnatwa`` enables all optional warnings
  * ``-gnatw?`` enables a specific warning denoted by the last character

    See the |GNAT Pro| User's Guide for more details. These should passed
    through the compilation switches specified in the project file.

* |GNATprove| specific warnings are controlled with switch ``--warnings``:

  * ``--warnings=off`` suppresses all warnings
  * ``--warnings=error`` treats warnings as errors
  * ``--warnings=continue`` issues warnings but does not stop analysis (default)

    The default is that |GNATprove| issues warnings but does not stop.

Both types of warnings can be suppressed selectively by the use of pragma
``Warnings`` in the source code. For example, |GNATprove| issues three warnings
on procedure ``Warn``, which are suppressed by the three pragma ``Warnings`` in
the source code:

.. literalinclude:: /gnatprove_by_example/examples/warn.adb
   :language: ada
   :linenos:

Warnings with the specified message are suppressed in the region starting at
pragma ``Warnings Off`` and ending at the matching pragma ``Warnings On`` or at
the end of the file (pragma ``Warnings`` is purely textual, so its effect does
not stop at the end of the enclosing scope). The ``Reason`` argument string is
optional. A regular expression can be given instead of a specific message in
order to suppress all warnings of a given form. Pragma ``Warnings Off`` can be
added in a configuration file to suppress the corresponding warnings across all
units in the project. Pragma ``Warnings Off`` can be specified for an entity to
suppress all warnings related to this entity.

Pragma ``Warnings`` can also take a first argument of ``GNAT`` or ``GNATprove``
to specify that it applies only to GNAT compiler or GNATprove. For example, the
previous example can be modified to use these refined pragma ``Warnings``:

.. literalinclude:: /gnatprove_by_example/examples/warn2.adb
   :language: ada
   :linenos:

Besides the documentation benefit of using this refined version of pragma
``Warnings``, it makes it possible to detect useless pragma ``Warnings``, that
do not suppress any warning, with switch ``-gnatw.w``. Indeed, this switch can
then be used both during compilation with GNAT and formal verification with
GNATprove, as pragma ``Warnings`` that apply to only one tool can be identified
as such.

See the |GNAT Pro| Reference Manual for more details.

Additionally, |GNATprove| can issue warnings as part of proof, on preconditions
or postconditions or pragma ``Assume`` that are always false,
dead code after loops and unreachable
branches in assertions and contracts. These warnings are not enabled by
default, as they require calling a prover for each potential warning, which
incurs a small cost (1 sec for each property thus checked). They can be enabled
with switch ``--proof-warnings``, and their effect is controlled by switch
``--warnings`` and pragma ``Warnings`` as described previously.

Note that GNATprove, just like GNAT, suppresses warnings about unused variables
if their name contains any of the substrings DISCARD, DUMMY, IGNORE, JUNK,
UNUSED, in any casing.

.. _Suppressing Information Messages:

Suppressing Information Messages
--------------------------------

Information messages can be suppressed by the use of pragma ``Warnings`` in the
source code, like for warnings.

.. _Justifying Check Messages:

Justifying Check Messages
-------------------------

|GNATprove|'s analysis relies on the fact that, at any given point in the
program, previous checks on any execution reaching that program point have been
successful. Thus, given two successive assertions of the same property:

.. code-block:: ada

   pragma Assert (Prop);  --  possibly not proved
   pragma Assert (Prop);  --  proved

The second assertion will be reported as proved by |GNATprove|, even if the
first assertion is reported as not proved. This is because any execution that
fails the first assertion is not analyzed further by |GNATprove|.

Similarly, consider two successive calls to the same procedure with a
precondition:

.. code-block:: ada

   Proc (Args);  --  precondition possibly not proved
   Proc (Args);  --  precondition proved

The precondition of the second call will be reported as proved by |GNATprove|,
even if the precondition of the first call is reported as not proved. This is
because any execution that fails the first precondition is not analyzed further
by |GNATprove|.

This applies to all proof checks, and to a lesser extent to flow analysis
checks. For example, outputs of a subprogram are considered fully initialtized
in a caller, as explained in :ref:`Data Initialization Policy`. In particular,
such outputs are considered to have values that respect the constraints of
their type, which is used during proof.

Thus, the user should be careful when justifying check messages, as the
incorrect justification of a check message that could fail could also hide
other possible failures later for the same execution of the analyzed program.

.. _Direct Justification with Pragma Annotate:

Direct Justification with Pragma Annotate
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Check messages generated by |GNATprove|'s flow analysis or proof can be
selectively justified by adding a pragma ``Annotate`` in the source code. For
example, the check message about a possible division by zero in the return
expression below can be justified as follows:

.. code-block:: ada

    return (X + Y) / (X - Y);
    pragma Annotate (GNATprove, False_Positive,
                     "divide by zero", "reviewed by John Smith");

The pragma has the following form:

.. code-block:: ada

    pragma Annotate (GNATprove, Category, Pattern, Reason);

where the following table explains the different entries:

.. tabularcolumns:: |l|p{4.5in}|

.. csv-table::
   :header: "Item", "Explanation"
   :widths: 1, 4

    "GNATprove",   "is a fixed identifier"
    "Category",    "is one of ``False_Positive`` or ``Intentional``"
    "Pattern",     "is a string literal describing the pattern of the check messages which shall be justified"
    "Reason",      "is a string literal providing a justification for reviews"

All arguments should be provided.

The *Category* currently has no impact on the behavior of the tool but serves a
documentation purpose:

* ``False_Positive`` indicates that the check cannot fail, although |GNATprove|
  was unable to prove it.

* ``Intentional`` indicates that the check can fail but that it is not
  considered to be a bug.

*Pattern* should be a substring of the check message to justify.

*Reason* is a string provided by the user as a justification for reviews. This
reason may be present in a |GNATprove| report.

Placement rules are as follows: in a statement list or declaration list, pragma
``Annotate`` applies to the preceding item in the list, ignoring other pragma
``Annotate``. If there is no preceding item, the pragma applies to the
enclosing construct. For example, if the pragma is the first element of the
then-branch of an if-statement, it will apply to condition in the
if-statement.

If the preceding or enclosing construct is a subprogram
body, the pragma applies to both the subprogram body and the spec including its
contract. This allows to place a justification for a check message issued by
|GNATprove| either on the spec when it is relevant for callers. Note that
this placement of a justification is ineffective on subprograms analyzed
only in the context of their calls (see details in
:ref:`Contextual Analysis of Subprograms Without Contracts`).

An aspect on a package or subprogram declaration/body can be used instead of a
pragma at the beginning of the corresponding declaration list inside the
declaration/body:

.. code-block:: ada

   package Pack with
     Annotate => (GNATprove, False_Positive,
                  "divide by zero", "reviewed by John Smith")
   is
      ...

   procedure Proc with
     Annotate => (GNATprove, False_Positive,
                  "divide by zero", "reviewed by John Smith")
   is
      ...

As a point of caution, the following placements of pragma Annotate will apply
the pragma to a possibly large range of source lines:

* when the pragma appears in a statement list after a block, it will apply to
  the entire block (e.g. an if statement including all branches, or a loop
  including the loop body).
* when the pragma appears directly after a subprogram body, it will apply to
  the entire body and the spec of the subprogram.

Users should take care to not justify checks which were not intended to be
justified, when placing pragma Annotate in such places.


.. literalinclude:: /gnatprove_by_example/examples/justifications.ads
   :language: ada
   :lines: 4-7

or on the body when it is an implementation choice that need not be visible
to users of the unit:

.. literalinclude:: /gnatprove_by_example/examples/justifications.ads
   :language: ada
   :lines: 9-10

.. literalinclude:: /gnatprove_by_example/examples/justifications.adb
   :language: ada
   :lines: 10-16

Pragmas ``Annotate`` of the form above that do not justify any check message
are useless and result in a warning by |GNATprove|. Like other warnings emitted
by |GNATprove|, this warning is treated like an error if the switch
``--warnings=error`` is set.

.. _Indirect Justification with Pragma Assume:

Indirect Justification with Pragma Assume
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Check messages generated by |GNATprove|'s proof can alternatively be justified
indirectly by adding a :ref:`Pragma Assume` in the source code, which allows the
check to be proved. For example, the check message about a possible integer
overflow in the assignment statement below can be justified as follows:

.. literalinclude:: /gnatprove_by_example/examples/assumptions.adb
   :language: ada
   :lines: 8-13

Using pragma ``Assume`` is more powerful than using pragma ``Annotate``, as the
property assumed may be used to prove more than one check. Thus, one should in
general use pragma ``Annotate`` rather than pragma ``Assume`` to justify simple
runtime checks. There are some cases though where using a pragma ``Assume`` may
be preferred. In particular:

* To keep assumptions local:

  .. code-block:: ada

      pragma Assume (<External_Call's precondition>,
                     "because for these internal reasons I know it holds");
      External_Call;

  If the precondition of ``External_Call`` changes, it may not be valid anymore
  to assume it here, though the assumption will stay True for the same reasons
  it used to be. Incompatible changes in the precondition of ``External_Call``
  will lead to a failure in the proof of External_Call's precondition.

* To sum up what is expected from the outside world so that it can be reviewed
  easily:

  .. code-block:: ada

      External_Find (A, E, X);
      pragma Assume (X = 0 or (X in A'Range and A (X) = E),
                     "because of the documentation of External_Find");

  Maintenance and review is easier with a single pragma ``Assume`` than if it is
  spread out into various pragmas ``Annotate``. If the information is required
  at several places, the pragma ``Assume`` can be factorized into a procedure:

  .. code-block:: ada

      function External_Find_Assumption (A : Array, E : Element, X : Index) return Boolean
      is (X = 0 or (X in A'Range and A (X) = E))
      with Ghost;

      procedure Assume_External_Find_Assumption (A : Array, E : Element, X : Index) with
       Ghost,
       Post => External_Find_Assumption (A, E, X)
      is
         pragma Assume (External_Find_Assumption (A, E, X),
                        "because of the documentation of External_Find");
      end Assume_External_Find_Assumption;

      External_Find (A, E, X);
      Assume_External_Find_Assumption (A, E, X);

In general, assumptions should be kept as small as possible (only assume what
is needed for the code to work). Indirect justifications with pragma
``Assume`` should be carefully inspected as they can easily introduce errors
in the verification process.

Sharing Proof Results Via a Memcached Server
--------------------------------------------

|GNATprove| can cache and share results between distinct runs of the tool,
even across several computers, via a Memcached server. To use this feature, you
need to setup a memcached server (see https://memcached.org/) on your network
or on your local machine. Then, if you add the option
``--memcached-server=hostname:portnumber`` to your invocation of gnatprove (or
use the ``Switches`` Attribute of the ``Prove`` Package of your project file),
then caching will be used, and speedups should be observed in many cases.

.. _Managing Assumptions:

Managing Assumptions
--------------------

Because |GNATprove| analyzes separately subprograms and packages, its results
depend on assumptions about other subprograms and packages. For example,
the verification that a subprogram is free from run-time errors depends on the
property that all the subprograms it calls implement their specified
contract. If a program is completely analyzed with |GNATprove|, |GNATprove|
will report messages on those other subprograms, if they might not implement
their contract correctly. But in general, a program is partly
in |SPARK| and partly in other languages, mostly Ada, C and assembly
languages. Thus, assumptions on parts of the program that cannot be analyzed
with |GNATprove| need to be recorded for verification by other means, like
testing, manual analysis or reviews.

When switch ``--assumptions`` is used, |GNATprove| generates information about
remaining assumptions in its result file ``gnatprove.out``. These remaining
assumptions need to be justified to ensure that the desired verification
objectives are met. An assumption on a subprogram may be generated in various
cases:

* the subprogram was not analyzed (for example because it is marked
  ``SPARK_Mode => Off``)

* the subprogram was not completely verified by |GNATprove| (that is, some
  unproved checks remain)

Note that currently, only assumptions on called subprograms are output, and not
assumptions on calling subprograms.

The following table explains the meaning of assumptions and claims which
gnatprove may output:

.. tabularcolumns:: |l|p{4.5in}|

.. csv-table::
   :header: "Assumption", "Explanation"
   :widths: 2, 4

    "effects on parameters and global variables", "The subprogram does not read or write any other parameters or global variables than what is described in its spec (signature + data dependencies)."
    "absence of run-time errors", "The subprogram is free from run-time errors."
    "the postcondition", "The postconditon of the subprogram holds after each call of the subprogram."
