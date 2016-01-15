# Ordered Collections for Swift

[![Build Status](https://travis-ci.org/lorentey/TreeCollections.svg?branch=master)](https://travis-ci.org/lorentey/TreeCollections)
[![codecov.io](https://codecov.io/github/lorentey/TreeCollections/coverage.svg?branch=master)](https://codecov.io/github/lorentey/TreeCollections?branch=master)

This project implements two collection types in pure Swift that use red-black trees as the underlying data structure:

- `Map<Key, Value>` implements a tree-based mapping from `Key` to `Value` instances. 
  It is like `Dictionary<Key, Value>` in the standard library, but it uses `Comparable` keys and provides 
  logarithmic time complexity for lookup, removal and insertion. `Map`'s generator returns items in order of 
  increasing key. Walking over all elements of the map this way has linear time complexity.

- `List<Element>` implements a tree-based collection of arbitrary elements. It is like `Array<Element>` in the standard library,
  but it supports insertion and removal of individual elements at any index in the list in O(log(n)) time. In exchange,
  looking up an index also costs O(log(n))

Both collections are structs and exhibit the same copy-on-write value semantics as the standard collection types.
(Internally, tree nodes are stored in a single `Array`.)

This project is a work in progress. 

