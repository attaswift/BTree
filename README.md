# In-Memory B-Trees and Ordered Collections in Swift

[![Build Status](https://travis-ci.org/lorentey/BTree.svg?branch=master)](https://travis-ci.org/lorentey/BTree)
[![codecov.io](https://codecov.io/github/lorentey/BTree/coverage.svg?branch=master)](https://codecov.io/github/lorentey/BTree?branch=master)

This project provides an efficient in-memory b-tree implementation in pure Swift, and several useful
collection types that use b-trees for their underlying storage.

## B-Trees

B-trees are search trees that provide an ordered key-value store with excellent performance
characteristics.  The b-tree implementation provided by this package has the following features:

- `BTree` is a generic struct with copy-on-write value semantics.  Internally, it stores its data in
  nodes with a fixed maximum size, arranged in a tree. Nodes are represented by instances of an
  internal reference type.  In essence, each node maintains a sorted array of its own elements, and
  another array for its children.  The tree is kept balanced by three constraints: (1) only the root
  node is allowed to be less than half full, (2) no node may be larger than the maximum size, and
  (3) the leaf nodes are all at the same level.

- By default, the tree order (i.e., the maximum number of children for internal nodes) is set such
  that each node stores about 8KiB data. Larger node sizes make lookups faster, while
  insertion/removal becomes slower -- 8KiB is a good enough approximation of the optimal node size
  on most modern systems.  (But you can also set a custom node size if you know better.)
  
- The `BTree` type provides a full set of hand-tuned high-level operations to work with elements of
  a b-tree.  Low-level access to individual tree nodes is easy to get wrong and thus it isn't
  available in the public API.  This makes the interface a lot easier to use.

- Individual b-tree nodes may be independently shared between multiple b-trees.  When mutating a
  (partially or fully) shared tree, copy-on-write is restricted to only clone the nodes that are
  actually to be modified by the mutation. This is often more efficient than copying everything at
  once, which is what standard collection types do.

- `BTree` allows elements with duplicate keys to be stored in the tree. All methods that take a key
  to find an element let you (optionally) specify if you want to work with the first or last
  matching element, or if you're happy with any match. The latter option is sometimes faster as it
  often allows the search to stop at the topmost matching element.

- Each node keeps track of the number of items in its entire subtree, so efficient positional lookup
  is possible.  For any *i*, you can get the *i*th item in the tree in log(n) time.

- `BTree` includes a bulk loading algorithm that efficiently initializes fully loaded trees from any
  sorted sequence.  (You can also specify a fill factor that's less than 100% if you expect to
  insert data into the middle of the tree later; leaving some space available may reduce work to
  keep the tree balanced.)

- The package contains O(log(n)) methods to concatenate b-trees, to extract a range of elements as a
  new b-tree, and to insert a b-tree into another b-tree. (Keys need to remain ordered correctly,
  though.)

- `BTreeCursor` is an easy-to-use, general-purpose batch editing facility that allows you to
  manipulate the elements of a b-tree conveniently and highly efficiently. You can use a cursor to
  walk over the contents of a tree, modifying/inserting/removing elements as needed without a
  per-element log(n) lookup overhead.

- There is a `BTreeGenerator` and a `BTreeIndex` that provide the usual generator/indexing
  semantics.  While individual element lookup usually takes O(log(n)) operations, iterating over all
  elements via these interfaces requires linear time. Note that `forEach` has a specialized
  recursive implementation, which makes it the fastest way to iterate over b-trees.

## Tree-based Collection Types

The package includes implementations for several frequently useful collection types that aren't
provided by the standard library. All of them are based on `BTree`, and (besides being highly useful
on their own) their source provides great examples on using the `BTree` API.

- `Map<Key, Value>` implements an ordered mapping from comparable keys to arbitrary values.  It is
  like `Dictionary` in the standard library, but it does not require keys to be hashable, it has
  strong guarantees on worst-case performance, and it maintains its elements in a well-defined
  order.

- `List<Element>` implements a random-access collection of arbitrary elements. It is like `Array` in
  the standard library, but lookup, insertion and removal of elements at any index have logarithmic
  complexity. (`Array` has O(1) lookup, but insertion and removal at an arbitrary index costs O(n).)

All of these collections are structs and implement the same copy-on-write value semantics as
standard Swift collection types like `Array` and `Dictionary`. (In fact, because of the underlying
`BTree`, copy-on-write typically only needs to copy O(log(n)) elements for a single-element
mutation.)

## Note on Performance

The Swift compiler is not yet able to specialize generics across module boundaries, which puts a
considerable limit on the performance achievable by collection types imported from external
modules. (This doesn't impact stdlib, which gets special treatment.)

Relying on `import` will incur a 10-200x slowdown, which may or may not be OK for your project.  If
raw performance is essential, you'll need to put the collection implementations in the same module
as your code. (And don't forget to enable whole module optimization!) I know of no good way to work
around this with the current compiler. (Other than including these types in the stdlib, that is.)

One way to fix this is to change Swift to include serialized SIL in the compiled code of
types/methods specially marked in the source. This may or may not happen soon.
