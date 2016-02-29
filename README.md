# Fast Ordered Collections for Swift Using In-Memory B-Trees 

[![Swift 2.1](https://img.shields.io/badge/Swift-2.1-blue.svg)](https://developer.apple.com/swift/) [![Documented](https://img.shields.io/badge/docs-97%-brightgreen.svg)](http://lorentey.github.io/BTree/api)
[![License](https://img.shields.io/badge/licence-MIT-blue.svg)](http://cocoapods.org/pods/BTree)
[![Platform](https://img.shields.io/cocoapods/p/BTree.svg)](http://cocoapods.org/pods/BTree)

[![Build Status](https://travis-ci.org/lorentey/BTree.svg?branch=master)](https://travis-ci.org/lorentey/BTree)
[![Code Coverage](https://codecov.io/github/lorentey/BTree/coverage.svg?branch=master)](https://codecov.io/github/lorentey/BTree?branch=master)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![Version](https://img.shields.io/cocoapods/v/BTree.svg)](http://cocoapods.org/pods/BTree)

<!-- [![Documented](https://img.shields.io/cocoapods/metrics/doc-percent/BTree.svg)](http://lorentey.github.io/BTree/api) -->

## Overview

This project provides an efficient in-memory b-tree implementation in pure Swift, and several useful
ordered collection types that use b-trees for their underlying storage.

-   [`Map<Key, Value>`][Map] implements an ordered mapping from unique comparable keys to arbitrary values.  
    It is like `Dictionary` in the standard library, but it does not require keys to be hashable, 
    it has strong guarantees on worst-case performance, and it maintains its elements in a well-defined
    order.

-   [`List<Element>`][List] implements a random-access collection of arbitrary elements. 
    It is like `Array` in the standard library, but lookup, insertion and removal of elements at
    any index have logarithmic complexity. 
    (`Array` has O(1) lookup, but insertion and removal at an arbitrary index costs O(n).)
    Concatenation of two lists of any size, inserting a list into another list at any position,
    removal of any subrange of elements, or extraction of an arbitrary sub-list are also
    operations with O(log(*n*)) complexity.

-   `OrderedSet<Element>` (*coming soon!*) implements an ordered collection of unique comparable elements.
    It is like `Set` in the standard library, but lookup, insertion and removal of any element
    has logarithmic complexity. Elements in an `OrderedSet` are kept sorted in ascending order.
    Operations working on full sets (such as taking the union, intersection or difference) 
    can take as little as O(log(*n*)) time if the elements in the source sets aren't interleaved.

-   [`BTree<Key, Payload>`][BTree] is the underlying primitive collection that serves as base storage
    for all of the above collections. It is a general key-value store with full support
    for elements with duplicate keys; it provides a sum of all operations individually provided
    by the higher-level abstractions above (and more!).

    The `BTree` type is public; you may want to use it if you need a collection flavor that 
    isn't provided by default (such as a MultiMap or a Bag), 
    or if you need to use an operation that isn't exposed by the wrappers.
    
All of these collections are structs and implement the same copy-on-write value semantics as
standard Swift collection types like `Array` and `Dictionary`. (In fact, copy-on-write works even
better with these than standard collections; read on to find out why!)

[Map]: http://lorentey.github.io/BTree/api/Structs/Map.html
[List]: http://lorentey.github.io/BTree/api/Structs/List.html

### [Reference Documentation][doc]

The project includes [a nicely formatted reference document][doc] generated from the documentation comments
embedded in its source code.

[doc]: http://lorentey.github.io/BTree/api

## What Are B-Trees?

[B-trees][b-tree wiki] are search trees that provide an ordered key-value store with excellent performance
characteristics.  In essence, each node maintains a sorted array of its own elements, and
another array for its children.  The tree is kept balanced by three constraints: 

1. Only the root node is allowed to be less than half full.
2. No node may be larger than the maximum size.
3. The leaf nodes are all at the same level.

Compared to other popular search trees such as [red-black trees][red-black tree] or [AVL trees][avl wiki], 
B-trees have huge nodes: nodes often contain hundreds (or even thousands) of key-value pairs and children.

This module implements a "vanilla" B-tree where every node contains full key-value pairs. 
(The other popular type is the [B+-tree][b-plus tree] where only leaf nodes contain values; 
internal nodes contain only copies of keys.
This often makes more sense on an external storage device with a fixed block size, but it is less useful for 
an in-memory implementation.)

Each node in the tree also maintains the count of all elements under it. 
This makes the tree an [order statistic tree], where efficient positional lookup is possible.

[b-tree wiki]: https://en.wikipedia.org/wiki/B-tree
[red-black tree]: https://github.com/lorentey/RedBlackTree
[avl wiki]: https://en.wikipedia.org/wiki/AVL_tree
[order statistic tree]: https://en.wikipedia.org/wiki/Order_statistic_tree
[b-plus tree]: https://en.wikipedia.org/wiki/B%2B_tree

## Why In-Memory B-Trees?

The Swift standard library offers heavily optimized arrays and hash tables, but omits linked lists and
tree-based data structures. This is a result of the Swift engineering team spending resources 
(effort, code size) on the abstractions that provide the biggest bang for the buck. 

> Indeed, the library lacks even a basic [double-ended queue][deque] construct -- 
> although Cocoa's `Foundation` framework does include one in `NSArray`.

[deque]: https://github.com/lorentey/Deque

However, some problems call for a wider variety of data structures. 

In the past, linked lists and low-order search trees such as red-black trees were frequently employed;
however, the performance of these constructs on modern hardware is greatly limited
by their heavy use of pointers.

[B-trees][b-tree wiki] were originally invented in the 1970s as a data structure for slow external storage
devices. As such, they are strongly optimized for locality of reference: 
they prefer to keep data in long contiguous buffers and they keep pointer derefencing to a minimum.
(Dereferencing a pointer in a B-tree usually meant reading another block of data from the spinning hard drive,
which is a glacially slow device compared to the main memory.)

Today's computers have multi-tiered memory architectures; they rely on caching to keep the system
performant. This means that locality of reference has become a hugely important property for in-memory
data structures, too. The referencing overhead can be so significant that 
[red-black trees are often slower than a primitive sorted array][benchmark tweet] even for surprisingly 
large element counts.

[benchmark tweet]: https://twitter.com/lorentey/status/687973876391931904

Arrays are the epitome of reference locality, so the Swift stdlib's heavy emphasis on `Array` as the
universal collection type is well justified.

For example, using a single array to hold a sorted list of items has quite horrible asymptotical
complexity when there are many elements. However, up to a certain maximum size, a simple array is in fact 
the most efficient way to represent a sorted list.

![Typical benchmark results for ordered collections](http://lorentey.github.io/BTree/images/Ordered%20Collections%20in%20Swift.png)

The benchmark above demonstrates this really well: insertion into a sorted array is O(n^2) when there are
many items, but it is still much faster than a red-black tree with its attractive-looking O(n * log(n)) 
solution. At the beginning of the curve, up to about *eighteen thousand items*, a sorted array 
implementation imported from an external module is very consistently about 6-7 faster than a red-black tree, 
with a slope that is indistinguishable from O(n * log(n)). Even after it catches up to quadratic complexity, 
it takes about a *hundred thousand items* for the sorted array to become slower than the red-black tree!
This is remarkable.

> The benchmark is based on [my own red-black tree implementation][red-black tree] that uses a single flat array to store
> node data. A [more typical implementation][airspeed-velocity] would store each node in a separately allocated object, so
> it would likely be even slower than this.

[airspeed-velocity]: http://airspeedvelocity.net/2015/07/22/a-persistent-tree-using-indirect-enums-in-swift/

Inside their nodes, B-trees use arrays (or array-like contiguous buffers) to hold item data. 
They guarantee that these arrays never get longer than the optimal maximum; when they would grow larger,
a new node is split off. So B-trees make perfect sense as an in-memory data structure.

(Here is a question to think about, thogh: how many times do you need to work with a hundred thousand
items in a typical app? Or even twenty thousand?)

> The exact cutoff point depends on the type/size of elements that you work with, and the capabilities 
> of the compiler. This benchmark used tiny 8-byte integer elements, hence the huge number.
> When/if the Swift compiler learns to specialize non-stdlib generics across module boundaries,
> imported collections will become consistently faster (especially for value types), which will reduce 
> the optimal element count. 

> (This effect is already visible on the benchmark for the "inlined" sorted array (light green), which was implemented
> in the same module as the benchmarking loop. That line starts curving up much sooner, at about 2000 elements.)

> The chart above is a [log-log plot][loglog] which makes it easy to compare the polynomial exponents of 
> the complexity curves of competing algorithms at a glance. The slope of an O(*n^2*) algorithm 
> (like insertion into a sorted array, green curves) on a log-log chart is twice of that of a 
> O(*n*) (like appending *n* items to an unsorted array, light blue curve) or O(*n* * log(*n*)) one 
> (like inserting into a red-black tree, red curve).

> Note that the big gap between collections imported from
> stdlib and those imported from external modules is caused by a [limitation in the current Swift compiler/ABI](#perf) 
> that will probably get (at least partially) solved in future compiler versions.)


[loglog]: https://en.wikipedia.org/wiki/Log–log_plot


### Laundry List of Issues with Standard Collection Types

The data structures implemented by `Array`, `Dictionary` and `Set` are remarkably versatile:
a huge class of problems is easily and efficiently solved by simple combinations of these abstractions.
However, they aren't without drawbacks: you have probably run into cases when the standard collections
exhibit suboptimal behavior:

1.  Efficient insertion/removal from the middle of an `Array` is not possible.

2.  The all-or-nothing [copy-on-write behavior][cow] of `Array`, `Dictionary` and `Set` can lead to performance problems
    that are hard to detect and fix.
    If the underlying storage buffer is being shared by multiple collection instances, the modification of a single element 
    in any of the instances requires creating a full copy of every element. 
    
    It is not at all obvious from the code when this happens, and it is even harder to reliably check for. 
    You can't (easily) write unit tests to check against accidental copying of items with value semantics!

3.  With standard collection types, you often need to think about memory management.

    Arrays and dictionaries never release memory until they're entirely deallocated; 
    a long-lived collection may hold onto a large piece of memory due to an earlier, temporary spike in the 
    number of its elements. This is a form of subtle resource leak that can be hard to detect.
    On memory-constrained systems, wasting too much space may cause abrupt process termination.

    Appending a new element to an array, or inserting a new element into a dictionary or a set are 
    usually constant time operations, but they sometimes take O(*n*) time when the collection exhausts its allocated capacity.
    These spikes in execution time cause are often undesired, but preventing them requires careful size analysis.  
    If you reserve too little space, you'll still get spikes; if you reserve too much, you're wasting memory.
    
4.  The order of elements in a `Dictionary` or a `Set` is undefined, and it isn't even stable:
    it may change after seemingly simple mutations. Two collections with the exact same set of elements may store
    them in wildly different order.

5.  Hashing collections require their keys to be `Hashable`. If you want to use your own type as the key, 
    you need to write a hash function yourself. It is annoyingly hard to write a good hash function, and 
    it is even harder to test that it is not produces too many collisions for the sets of values your code 
    will typically use.

6.  The possibility of hash collisions make `Dictionary` and `Set` badly suited for tasks which require
    guaranteed worst-case performance. (E.g. server code may face low-bandwidth denial of service attacks due to
    [artificial hash collisions][hash dos].)

7.  Array concatenation takes O(*n*) time, because it needs to put a copy of every element from both arrays 
    into a new contiguous buffer.

8.  Merging dictionaries or taking the union/intersection etc. of two sets are all costly
    O(*n*) operations, even if the elements aren't interleaved at all.

9.  Creating an independently editable sub-dictionary or subset requires elementwise iteration over either
    the entire collection, or the entire set of potential target items. This is often impractical, especially
    when the collection is large but sparse.
    
    Getting an independently editable sub-array out of an array takes time that is linear in the size of the result. 
    (`ArraySlice` is often helpful, but it is most effective as a short-lived read-only view in temporary local variables.)


These issues don't always matter. In fact, lots of interesting problems can be solved without 
running into any of them. When they do occur, the problems they cause are often insignificant.
Even when they cause significant problems, it is usually straightforward to work around them by chosing a
slightly different algorithm. 

But sometimes you run into a case where the standard collection types are too slow, 
and it would be too painful to work around them.
    
[hash dos]: http://arstechnica.com/business/2011/12/huge-portions-of-web-vulnerable-to-hashing-denial-of-service-attack/
[cow]: https://en.wikipedia.org/wiki/Copy-on-write


### B-Trees to the Rescue! 

B-trees solve all of the issues above. 
(Of course, they come with a set of different issues of their own. Life is hard.)

Let's enumerate:

1.  Insertion or removal from any position in a B-tree-based data structure takes O(log(*n*)) time, no matter what.

2.  Like standard collection types, B-trees implement full copy-on-write value semantics.
    Copying a b-tree into another variable takes O(1) time; mutations of a copy do not affect the original instance.
    
    However, B-trees implement a greatly improved version of copy-on-write that is not all-or-nothing: 
    each node in the tree may be independently shared with other trees. 
    
    If you need to insert/remove/update a single element, B-trees will copy at most O(log(*n*)) elements to satisfy
    value semantics, even if the tree was entirely shared before the mutation.

3.  Storage management in B-trees is granular; you do not need to reserve space for a B-tree in advance, and
    they never allocate more memory than they need to store the actual number of elements they contain.
    
    Storage is gradually allocated and released in small increments as the tree grows and shrinks.
    Storage is only copied when mutating shared elements, and even then it is done in small batches.
    
    The performance of B-trees is extremely stable, with no irregular spikes ever.
    
    (Note that there is a bit of leeway in allocations to make balancing the tree fast. 
    In the worst case, a B-tree may only be filled at 50% of space it allocates.)

4.  B-trees always keep their items sorted in ascending key order, and they provide efficient positional lookups.
    You can get the *i*th smallest/largest item in a tree in O(log(*n*)) time.

5.  Keys of a B-tree need to be `Comparable`, not `Hashable`. It is often significantly easier to 
    write comparison operators than hash functions; it is also much easier to verify that the implementation works 
    correctly. A buggy `<` operator will typically lead to obvious issues that are relatively easy to catch; 
    a badly collisioning hash may go undetected for years.

6.  Adversaries (or blind chance) will never produce a set of elements for which B-trees behave especially badly.
    The performance of B-trees only depends on the size of the tree, not its contents. 
    (Provided that key comparison also behaves uniformly, of course. 
    If you allow multi-megabyte strings as keys, you're gonna have a bad time.)

7.  Concatenation of any two B-trees takes O(log(*n*)) time. For trees that aren't of a trivial size, the result 
    will share some of its nodes with the input trees, deferring most copying until the time the tree needs to be modified.
    (Which may never happen.) Copy-on-write really shines with B-trees!
    
8.  Merging the contents of two B-trees into a single tree takes O(*n*) time in the worst case, but
    if the elements aren't too badly interleaved, it can often finish in O(log(*n*)) time by linking entire subtrees
    into the result in one go.
    
    Set operations on the keys of a B-tree (such as calculating the intersection set, subtraction set, 
    symmetric difference, etc.) also exploit the same trick for a huge performance boost.
    If the input trees are mutated versions of the same original tree, these operations are also able 
    to skip elementwise processing of entire subtrees that are shared between the inputs.

9.  The `SubSequence` of a B-tree is also a B-tree. You can slice and dice B-trees to your liking:
    getting a fully independent copy of any prefix, suffix or subrange in a tree only takes O(log(*n*)) time.


### Notes on the Code

-   [`BTree`][BTree] is a generic struct with copy-on-write value semantics.  Internally, it stores its data in
    nodes with a fixed maximum size, arranged in a tree.  `BTree` type provides a full set of hand-tuned 
    high-level operations to work with elements of a B-tree.
    
    Nodes are represented by instances of a [reference type][BTreeNode] that is not exported as public API.
    (Low-level access to individual tree nodes would be tricky to get right, and it would prevent
    future optimizations, such as moving node counts up to parent nodes.)

-   By default, the tree order (a.k.a., the fanout, or the maximum number of children) is set such
    that [each node stores about 16KiB data][BTreeNode]. Larger node sizes make lookups faster, while
    insertion/removal becomes slower -- 16KiB is a good enough approximation of the optimal node size
    on most modern systems.  (But you can also set a custom node size if you know better. Note though
    that you cannot mix-n-match trees of different orders.)  Thus, on a 64-bit system, a B-tree
    holding `Int` elements will store about 2047 elements per node. Wow!

-   Individual b-tree nodes may be independently shared between multiple b-trees.  When mutating a
    (partially or fully) shared tree, copy-on-write is restricted to only clone the nodes whose subtree is
    actually affected by the mutation. This has the following consequences:
  
    - Nodes cannot contain a reference to their parent node, because it is not necessarily unique. 
    
    - Mutations of shared trees are typically much cheaper than copying the entire collection at once, 
      which is what standard collection types do.
      
    - The root node is never shared between trees that are not equal.


-   There is a [`BTreeGenerator`][BTreeGenerator] and a [`BTreeIndex`][BTreeIndex] that provide the
    usual generator/indexing semantics. While individual element lookup usually takes O(log(n))
    operations, iterating over all elements via these interfaces requires linear time. Note that
    [`forEach`][BTree.forEach] has a specialized recursive implementation, which makes it the fastest
    way to iterate over b-trees.

-   [`BTreeCursor`][BTreeCursor] is an easy-to-use, general-purpose batch editing facility that allows you to
    manipulate the elements of a b-tree conveniently and highly efficiently. You can use a cursor to
    walk over the contents of a tree, modifying/inserting/removing elements as needed without a
    per-element log(n) lookup overhead. If you need to insert or remove a bunch or consecutive elements,
    it is better to use the provided bulk removal/insertion methods than to process them individually 
    (Range operations have O(log(*n*)) complexity vs. elementwise processing takes O(*k* * log(n)).)

-   [`BTree`][BTree] allows elements with duplicate keys to be stored in the tree. 
    (In fact, `List` works by using the same (empty) key for all elements.) 

    All methods that take a key to find an element [let you (optionally) specify][BTreeKeySelector] if you
    want to work with the first or last matching element, or if you're happy with any match. The latter
    option is sometimes faster as it often allows the search to stop at the topmost matching element. There
    is also a selector that looks for the element *after* the specified key -- this can be nice to determine
    the position of the end of a range of matching items.

-   Each node keeps track of the number of items in its entire subtree, so 
    [efficient positional lookup][BTree.elementAtPosition]
    is possible.  For any *i*, you can get, set, remove or insert the *i*th item in the tree in log(n) time.

-   `BTree` includes a [bulk loading algorithm][BTree.bulkLoad] that efficiently initializes fully loaded
    trees from any sorted sequence. You can also specify a fill factor that's less than 100% if you expect to
    insert data into the middle of the tree later; leaving some space available may reduce work to keep the
    tree balanced. The bulk loader can optionally filter out duplicate keys for you. It verifies that the
    elements are in the correct order and traps if they aren't.
    
-   Constructing a B-tree from an unsorted sequence of elements inserts the elements into the tree one by
    one; no buffer is allocated to sort elements before loading them into the tree. This is done more
    efficiently than calling `BTree.insert` with each element one by one, but it is likely still slower than
    a quicksort. (So sort elements on your own if you can spare the extra memory.)

-   The package contains O(log(n)) methods to [extract a range of elements as a new b-tree][BTree.subtree]
    and to [insert a b-tree into another b-tree][BTreeCursor.insertTree]. (Keys need to remain ordered
    correctly, though.)
    
-   Merge operations (such as `BTree.union` and `BTree.exclusiveOr`) are highly tuned to detect when
    they can skip over entire subtrees on their input, linking them into the result or skipping their contents
    as required. For input trees that contain long runs of distinct elements, these operations
    can finish in as little as O(log(*n*)) time.

[BTree]: http://lorentey.github.io/BTree/api/Structs/BTree.html
[BTreeNode]: https://github.com/lorentey/BTree/blob/master/Sources/BTreeNode.swift
[BTreeKeySelector]: http://lorentey.github.io/BTree/api/Enums/BTreeKeySelector.html
[BTreeGenerator]: http://lorentey.github.io/BTree/api/Structs/BTreeGenerator.html
[BTreeIndex]: http://lorentey.github.io/BTree/api/Structs/BTreeIndex.html
[BTreeCursor]: http://lorentey.github.io/BTree/api/Structs/BTreeCursor.html
[BTree.elementAtPosition]: http://lorentey.github.io/BTree/api/Structs/BTree.html#/s:FV5BTree5BTree17elementAtPositionu0_Rq_Ss10Comparable_FGS0_q_q0__FSiTq_q0__
[BTree.forEach]: http://lorentey.github.io/BTree/api/Structs/BTree.html#/s:FV5BTree5BTree7forEachu0_Rq_Ss10Comparable_FGS0_q_q0__FzFzTq_q0__T_T_
[BTree.bulkLoad]: http://lorentey.github.io/BTree/api/Structs/BTree.html#/s:FV5BTree5BTreecu0__Rq_Ss10Comparableqd__Ss12SequenceTypezqqqd__S2_9GeneratorSs13GeneratorType7ElementTq_q0___FMGS0_q_q0__FT14sortedElementsqd__5orderSi10fillFactorSd_GS0_q_q0__
[BTreeCursor.insertTree]: http://lorentey.github.io/BTree/api/Classes/BTreeCursor.html#/s:FC5BTree11BTreeCursor6insertu0_Rq_Ss10Comparable_FGS0_q_q0__FGVS_5BTreeq_q0__T_
[BTree.subtree]: http://lorentey.github.io/BTree/api/Structs/BTree.html#/s:FV5BTree5BTree7subtreeu0_Rq_Ss10Comparable_FGS0_q_q0__FT4fromq_2toq__GS0_q_q0__


## Remark on Performance of Imported Generics
<a name="perf"></a>

The Swift compiler is not yet able to specialize generics across module boundaries, which puts a
considerable limit on the performance achievable by collection types imported from external
modules. (This doesn't impact stdlib, which gets special treatment.)

Relying on `import` will incur a 10-200x slowdown, which may or may not be OK for your project.  If
raw performance is essential, you'll need to put the collection implementations in the same module
as your code. (And don't forget to enable whole module optimization!) I know of no good way to work
around this with the current compiler. (Other than hacking stdlib to include these types, that is.)
