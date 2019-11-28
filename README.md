# Purely Functional Data Structures

This repository contains a variety of purely functional data
structures.

For now, it only contains data structures described in the book
"Purely Functional Data Structures" by Chris Okasaki.  The
implementations have been modified to feel more natural in Common
Lisp.  Many data structures from the book are not yet implemented.

In the future, this library may contain other data purely functional
structures as well.

## Data Structures

### Sets

#### `RED-BLACK-TREE-SET`

- `MAKE-RED-BLACK-TREE-SET`: `O(n log(n))`
- `WITH-MEMBER`: `O(log(n))`
- `WITHOUT-MEMBER`: `O(log(n))`
- `IS-MEMBER`: `O(log(n))`
- `IS-EMPTY`: `O(1)`

### Heaps

#### `LEFTIST-HEAP`

- `MAKE-LEFTIST-HEAP`: `O(n)`
- `HEAP-TOP`: `O(1)`
- `WITH-MEMBER`: `O(log(n))`
- `WITHOUT-HEAP-TOP`: `O(log(n))`
- `MERGE-HEAPS`: `O(log(n))`
- `IS-EMPTY`: `O(1)`

#### `BINOMIAL-HEAP`

- `MAKE-BINOMIAL-HEAP`: `O(n)`
- `HEAP-TOP`: `O(log(n))`
- `WITH-MEMBER`: `O(log(n))`
- `WITHOUT-HEAP-TOP`: `O(log(n))`
- `MERGE-HEAPS`: `O(log(n))`
- `IS-EMPTY`: `O(1)`

## Design decisions

### Dependencies

This project has a minimal set of dependencies.  Thus far, the core
data structures have no external dependencies other than Common Lisp
itself.  This allows the data structures to be used in almost any
project.

### `COMPARE`

Many functional data structures rely on establishing a relative
ordering between objects.  All such data structures accept a
comparator function at construction time.  The function should accept
two objects and return either `:LESS`, `:GREATER`, `:EQUAL`, or
`:UNEQUAL`.  If you are familiar with the `FSet` library, this should
sound familiar.  This library provides a comparison function for your
convenience: `COMPARE`.

The provided `COMPARE` generic function tries to avoid returning
`:UNEQUAL` as much as possible.  Data structures containing `:UNEQUAL`
objects typically perform much worse than they ought to.  So, avoiding
uneqaulity is very important.  As such, `COMPARE` establishes
orderings that you may not expect.  For example, `COMPARE` establishes
an ordering between things that are mutually `=`, such as `1`, `1.0`,
`(COMPLEX 1)`, and `(COMPLEX 1.0)`.  Its probably best if you think of
`COMPARE` as the ordering equivalent of a hash function.  The results
aren't necessarily meaningful, but they do have useful properties for
specific use cases.  If you want to have a meaningful ordering, you
can simply define your own comparator function.  The
`PFDS.SHCL.IO/COMPARE` package exports comparators for many common
types to help facilitate writing your own comparator.

Note that `COMPARE` assumes that instances of types provided by Common
Lisp are immutable.  You mustn't mutate objects in ways that change
their ordering after adding them to an ordering-dependent data
structure.  Since the ordering may depend on the `SXHASH` of the
object, its probably best to just avoid mutating them at all.  A
principled approach would be to return `:UNEQUAL` when comparing
un-`EQL` instances of a mutable type.  Unfortunately, that would
result in very common use cases becoming very inefficient.  For
example, its very common to use symbols and strings as members of a
set or keys in a map.  If all un-`EQL` symbols and strings are
`:UNEQUAL` then the performance for that use case will plummet.

For user-defined mutable data structures, you are strongly encouraged
to use the following `COMPARE` method.
```
(defmethod compare ((left my-type) (right my-type))
  (if (eql left right)
      :equal
      :unequal))
```
This ensures that the ordering invariants of data structures are not
violated by mutation.

### `DEFSTRUCT` vs `DEFCLASS`

For pure data structures, this library always uses `DEFSTRUCT` instead
of `DEFCLASS`.  Generally, `DEFCLASS` is the go-to way to define an
aggregate data type.  It offers a number of features that make
development much easier.  Ordinarily, these would be considered good
things.  Unfortunately, these features often run counter to the goal
of having immutable instances.

For example, a class definition can be updated at any time.  This has
the potential to change the contents of an instance of the class.  The
whole goal of a purely function data structure is to forbid mutation,
and so class redefinition cannot be permitted.  Similarly, the
initialization methods used by `DEFCLASS` are problematic.  Mutation
is an essential part of how instances are initialized.
pre-initialization state.

For purely functional data structures, less is more.  By restricting
ourselves to `DEFSTRUCT`, we get some substantial benefits.  We're
able to communicate to the compiler that the instance is immutable.  A
smart compiler can leverage this information to emit more efficient
code.  Furthermore, it allows the compiler to keep us honest.  It is
much more difficult to accidentally leak side effects when you can't
have them!

## Impure data structures

Some algorithms are best implemented with impure data structures.
When that happens, this library may also provide the impure data
structure it used.  Right now there is only one such data structure:
`IMPURE-QUEUE`.

The `IMPURE-QUEUE` is a queue that uses a circular buffer.  The queue
will automatically grow or shrink the buffer as the number of elements
changes.