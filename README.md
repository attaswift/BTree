# Logarithmic Collections for Swift

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


|--------------------------|-------------------------------------------|--------------------------|
| Operation                | `Dictionary<Key, Value>`                  | `Map<Key, Value>`        |
|--------------------------|-------------------------------------------|--------------------------|
| value semantics          | yes                                       | yes                      |
| `Key` must implement     | `Hashable`                                | `Comparable`             |
| `vs[k]`                  | O(1)                                      | O(log(n))                |
| `vs[k] = v`              | O(1)                                      | O(log(n))                |
| `vs[k] = nil`            | O(1)                                      | O(log(n))                |
| `vs.foreach(block)`      | O(n)                                      | O(n)                     |
| how to get sorted values | `vs.sort { $0.0 < $1.0 }` -- O(n*log(n))  | `values` -- O(1)         |
|--------------------------|-------------------------------------------|--------------------------|



|---------------------------|--------------------------|--------------------|
| Operation                 | `Array<Element>`         | `List<Element>`    |
|---------------------------|--------------------------|--------------------|
| value semantics           | yes                      | yes                |
| restriction on `Element`  | none                     | none               |
| `values[i]`               | O(1)                     | O(log(n))          |
| `values[i] = v`           | O(1)                     | O(log(n))          |
| `values.append(v)`        | O(1) (amortized)         | O(1) (amortized)   |
| `values.removeLast(v)`    | O(1)                     | O(log(n))          |
| `values.insert(v, at: i)` | O(n)                     | O(log(n))          |
| `values.removeAtIndex(i)` | O(n)                     | O(log(n))          |
| `values.foreach(block)`   | O(n)                     | O(n)               |
| sorted values             | O(n*log(n))              | O(n)               |
|---------------------------|--------------------------|--------------------|

