# A Collection of Frequently Useful Swift Collections

[![Build Status](https://travis-ci.org/lorentey/TreeCollections.svg?branch=master)](https://travis-ci.org/lorentey/TreeCollections)
[![codecov.io](https://codecov.io/github/lorentey/TreeCollections/coverage.svg?branch=master)](https://codecov.io/github/lorentey/TreeCollections?branch=master)

This project provides efficient (benchmark-driven) implementations for several frequently useful collection types 
in pure Swift that aren't provided by the standard library:

- `Map<Key, Value>` implements an ordered, tree-based mapping from `Key` to `Value` instances. 
  It is like `Dictionary<Key, Value>` in the standard library, but it uses `Comparable` keys and provides 
  logarithmic time complexity for lookup, removal and insertion. `Map`'s generator returns items in 
  increasing key order. While individual lookup is logarithmic, iterating over all elements of the map 
  has linear time complexity.

- `List<Element>` implements a tree-based collection of arbitrary elements. It is like `Array<Element>` in the standard
  library, but it supports insertion and removal of individual elements at any index in the list in O(log(n)) time. 
  In exchange, looking up an arbitrary index also costs O(log(n)).

All collections are structs and implement the same copy-on-write value semantics as standard collection types like 
`Array` and `Dictionary`. (Tree-based collections actually use Arrays for their underlying node storage.)

The module includes implementations of red-black trees and in-memory b-trees that might be reusable elsewhere.

This project is a work in progress. Some parts are approaching production readiness, but nothing is stable yet.

## Note on Performance

The Swift compiler is not yet able to specialize generics across module boundaries, which puts a considerable limit
on the performance achievable by collection types imported from external modules. (This doesn't impact stdlib, which 
gets special treatment.)

Relying on `import` will incur a 50-200x slowdown, which may or may not be OK for your project. 
If raw performance is essential, you'll need to put the collection implementations in the same module
as your code. I have a couple of ideas that might make this a little more pleasant than it sounds, but for now, there is no
good way around this limitation.
