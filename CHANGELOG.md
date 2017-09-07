# 4.1.0 (2017-09-07)

This release updates the project to Swift 4 with no functional changes.

BTree is now part of the Attaswift project. The bundle identifiers in the supplied Xcode project have been updated accordingly.

Note that the URL for the package's Git repository has changed; please update your references.

# 4.0.2 (2017-02-07)

This release contains the following changes:

- BTree now compiles in Swift 3.1.
- [Issue #5][issue5]: There is a new `PerformanceTests` target in the Xcode project containing some simple benchmarks. This facility is experimental and may be replaced later.
- (Xcode project) The macOS deployment target was corrected to 10.9. Previously it was set at 10.11 by mistake.
- (Xcode project) The build number is now correctly set in the tvOS framework.
- (Xcode project) Code signing has been disabled, following Xcode 8 best practices.

[issue5]: https://github.com/attaswift/BTree/issues/5

# 4.0.1 (2016-11-08)

This is a quick bugfix release restoring support for the Swift Package Manager. It includes no source-level changes.

#### Bug Fixes

- [Issue #23][issue23]: BTree is not buildable with the Swift Package Manager

[issue23]: https://github.com/attaswift/BTree/issues/21

# 4.0.0 (2016-11-07)

This is a major release incorporating API-breaking changes. It also includes fixes for several high-severity bugs uncovered while working on new features, so this is a highly recommended upgrade.

#### Breaking changes

- To support multiset operations, some of `BTree`'s methods have grown a new required parameter specifying the key matching strategy. To get the original behavior, specify `.groupingMatches` as the matching strategy, except for `union`, as noted below. The compiler will provide fixits, but you'll still need to update the code by hand. This affects the following methods:

  * `BTree.isSubset(of:)`
  * `BTree.isStrictSubset(of:)`
  * `BTree.isSuperset(of:)`
  * `BTree.isStrictSuperset(of:)`
  * `BTree.union(:)` -- use the `.countingMatches` strategy to get the original, multiset-appropriate, behavior.
  * `BTree.distinctUnion(:)` -- removed; use `union` with the `.groupingMatches` strategy instead.
  * `BTree.subtracting(:)` (both overloads)
  * `BTree.intersection(:)` (both overloads)
  * `BTree.symmetricDifference(:)`

#### New Features

- `SortedBag` is a new generic collection implementing an ordered multiset.
- `BTreeMatchingStrategy` is a new public enum for selecting one of two matching strategies when comparing elements from two trees with duplicate keys.
- `BTree.index(forInserting:at:)` is a new method that returns the index at which a new element with the given key would be inserted into the tree.
- `SortedSet.indexOfFirstElement(after:)` is a new method that finds the lowest index whose key is greater than the specified key.
- `SortedSet.indexOfFirstElement(notBefore:)` is a new method that finds the lowest index whose key is greater than or equal to the specified key.
- `SortedSet.indexOfLastElement(before:)` is a new method that finds the greatest index whose key is less than the specified key.
- `SortedSet.indexOfLastElement(notAfter:)` is a new method that finds the greatest index whose key is less than or equal to the specified key.

#### Bug Fixes

- [Issue #19][issue19]: BTree concatenation, set operations sometimes corrupt their input trees
- [Issue #20][issue20]: Corrupt BTree merge results when duplicate keys leak across common subtree boundaries
- [Issue #21][issue21]: BTree comparisons (subset/superset) may assert on certain shared subtrees
- `SortedSet.update(with:)` now has a discardable result.

[issue19]: https://github.com/attaswift/BTree/issues/19
[issue20]: https://github.com/attaswift/BTree/issues/20
[issue21]: https://github.com/attaswift/BTree/issues/21


# 3.1.0 (2016-10-06)

This is a feature release extending the functionality of `SortedSet` and `Map` with several new methods.

#### New Features

##### `SortedSet`

Offset-based access
- `SortedSet.offset(of:)` returns the offset to a particular member of the set.
- `SortedSet.remove(atOffset:)` removes and returns the element at a particular offset in the set.

Range-based operations
- `SortedSet.count(elementsIn:)` returns the number of elements in the given open or closed range.
- `SortedSet.intersection(elementsIn:)` returns the result of intersecting the set with a given open or closed range.
- `SortedSet.formIntersection(elementsIn:)` is the in-place editing version of the above.
- `SortedSet.subtracting(elementsIn:)` returns a set without members in the given open or closed range.
- `SortedSet.subtract(elementsIn:)` is the in-place editing version of the previous method.

Shifting
- `SortedSet.shift(startingAt start: Element, by delta: Element.Stride)` is a new method for sorted sets with strideable elements. It adds `delta` to every element in the set that is greater than or equal to `start`. The elements are modified in place.

All of these new methods run in logarithmic time, except for `shift` whose complexity is linear.

##### `Map`

- `Map.offset(of:)` is a new method for finding the offset of a particular key in the map. It has logarithmic complexity.

#### Bug fixes

- The tvOS target now generates a framework that is explicitly restricted to only use extension-safe API.

# 3.0.0 (2016-09-24)

This release of BTree provides support for Swift 3.0, which involves extensive breaking API changes.

- All API names have been reviewed and renamed to follow current Swift guidelines. (See [SE-0023][se0023], [SE-0005][se0005], [SE-0006][se0006], [SE-0118][se0118], and possibly others.) The resulting changes are too numerous to list here. Unfortunately, resource constraints prevented me from including forwarding availability declarations for renamed APIs; fixits won't be available, you'll have to rename usages in your code by hand. (Sorry about that.)
- BTree's collection types now implement the new collection model described in [SE-0065][se0065]. `BTreeIndex` has been stripped of its public methods; use the new index manipulation methods in the various collection types instead. The underlying implementation hasn't been changed, but making the standalone index methods internal now allows for experimentation with more efficient indices without breaking API changes in the future.
- `OrderedSet` was renamed to `SortedSet`, to prevent confusion with the similar class in Foundation. For a short while, [SE-0086][se0086] renamed `NSOrderedSet` to `OrderedSet` in the Foundation framework, leading to a naming conflict with `BTree`. This was further aggravated by a naming lookup issue in the language itself that made it impossible to use the explicit name `BTree.OrderedSet` to work around the conflict. `NSOrderedSet` was quickly changed back to its original name, but the issue revealed that the two names are much too similar.
- `SortedSet` was adapted to implement the new `SetAlgebra` protocol in  [SE-0059][se0059].
- `List`s that contain objects now have an `arrayView` property that returns an `NSArray` with the exact same values as the `List` in O(1) time. This is useful for using B-tree based lists in APIs that need arrays, without copying elements. (For example, you can now use `NSCoder` to encode `List`s directly.) 
- Collection protocol conformance has been improved. `List` now explicitly conforms to `RandomAccessCollection`, while `Map` and `SortedSet` are now `BidirectionalCollection`s. This required no major changes as these types already implemented everything that was necessary for conformance to these stricter protocols, but now conformance is made explicit.

[se0023]: https://github.com/apple/swift-evolution/blob/master/proposals/0023-api-guidelines.md
[se0006]: https://github.com/apple/swift-evolution/blob/master/proposals/0006-apply-api-guidelines-to-the-standard-library.md
[se0005]: https://github.com/apple/swift-evolution/blob/master/proposals/0005-objective-c-name-translation.md
[se0118]: https://github.com/apple/swift-evolution/blob/master/proposals/0118-closure-parameter-names-and-labels.md
[se0086]: https://github.com/apple/swift-evolution/blob/master/proposals/0086-drop-foundation-ns.md
[se0059]: https://github.com/apple/swift-evolution/blob/master/proposals/0059-updated-set-apis.md
[se0065]: https://github.com/apple/swift-evolution/blob/master/proposals/0065-collections-move-indices.md

# 2.1.0 (2016-03-23)

This minor release updates the project for Swift 2.2, with no changes in the API or implementation.

# 2.0.0 (2016-03-06)

This is a major release that includes breaking API changes, plus major new features and bug fixes.

The package now implements all major features that were on my initial roadmap; further development will likely concentrate on refining the API, improving performance and adapting the package to new Swift versions. (Although it is never too late to propose new features!)

This release supports Swift 2.1.1. 

Swift 2.2 is conditionally supported; add `-DSwift22` to the Swift compiler flags to enable it. Note that this version of the module will compile with a number of warnings on 2.2; these will be fixed when Swift 2.2 is released.

Swift 3 is not yet supported. In particular, API names mostly follow Swift 2 conventions, although certain internal APIs are following the new design conventions.

#### New Features

##### General

- The README has been rewritten and greatly expanded in scope. It now includes a short intro and a detailed rationale section.
- The term "position" has been systematically replaced with "offset" throughout the entire API and documentation.

##### `BTree`

- The second component of `BTree`'s elements has been renamed from "payload" to "value" throughout the entire API and documentation. This is for consistency with other Swift key-value collections.
- `BTree` now includes efficient set operations: `union`, `distinctUnion`, `subtract`, `exclusiveOr`, and `intersect`. These are based on keys, and exploit the order of elements to detect when they can skip elementwise processing for specific subtrees. `subtract` and `intersect` also have overloads for selecting for keys contained in a sorted sequence.
- `BTree` now supports efficient tree comparison operations: `elementsEqual`, `isDisjointWith`, `isSubsetOf`, `isStrictSubsetOf`, `isSupersetOf`, and `isStrictSupersetOf`. All of these except the first work like set comparisons on the keys of the tree. They exploit the element order and detect shared nodes to skip over subtrees whenever possible. When `Value` is `Equatable`, you can now compare B-trees for equality using the `==` operator.
- `BTreeKeySelector` now includes an `After` case, which selects first the element that has a key that is larger than the specified key. This is occasionally useful.
- `BTree` now defines explicit overrides for the following methods on `SequenceType`: `prefix`, `suffix`, `prefixUpTo`, `prefixThrough`, `suffixFrom`, `dropLast`, `dropFirst`, `first`, `last`, `popFirst`, `popLast`, `removeFirst` and `removeLast`. 
The new implementations perform better than the default, index-based implementations provided by `CollectionType`. There are also new overloads for key-based slicing.
- `BTree` gained methods for starting a generator at any specific key, index or offset.
- The `withCursor` family of methods now allow their closure to return a value.
- `BTree.remove(:)` now returns the full element that was removed, not just the value component.
- Bulk loading initializers of `BTree` now respect the original order of elements, and optionally allow filtering out elements with duplicate keys. When initializing a `Map` from a sequence that contains duplicates, only the last element is kept for any key.
- New methods: `BTree.removeAtIndex(:)`, and  `BTree.removeAll()`
- `BTreeIndex` now contains efficient O(log(n)) implementations for `advancedBy` and `distanceTo`, replacing their default O(n) variants.
- `BTreeIndex` is now `Comparable`. However, comparing indices only makes sense if the indices belong to the same tree.
- `BTreeCursor` now has an `element` property that allows you to get or update the entire (key, value) pair at the current position.

##### `OrderedSet`

- `OrderedSet` is a new general-use wrapper around `BTree`, implementing a sorted analogue of `Set`.

##### `List`

- The generator type of `List` has been renamed from `ListGenerator` to `BTreeValueGenerator`.
- `List` explicitly implements `RangeReplaceableCollectionType`.
- You can now use `+` to concatenate two `List` values, just like you can with `Array`s.

##### `Map`

- `Map` now supports `elementsEqual`, complete with an `==` operator when its `Value` is `Equatable`.
- `Map` gained two methods for offset-based removal of elements: `removeAtOffset` and `removeAtOffsets`
- You can now merge two `Map` values into a single map using `merge`.
- You can extract a submap from a `Map` that includes or excludes a specific set or sequence of keys.

#### Improvements

- Navigation inside the B-tree is now unified under a single protocol, `BTreePath`, for all three flavors of tree paths: `BTreeStrongPath`, `BTreeWeakPath` and `BTreeCursorPath`.
- The complexity of `BTree.endIndex` has been reduced from O(log(n)) to O(1). This also improves the `endIndex` properties of `Map` and `OrderedSet`.
- Iterating over B-trees is now a bit faster, as getting to the successor of an item does not normally involve array lookups.
- `BTree.shiftSlots` is a new internal method for shifting elements between nodes at the same level. This operation is often useful while reorganizing/rebalancing the tree.
- The bulk loading algorithm has been extracted into a separate internal struct and generalized to allow appending full trees, not just elements.
- The generated docs now include nice method group headers splitting the method lists into organized chunks.

#### Bug fixes

- Fixed issue #3, "Crash when inserting Element in List".
- The copy-on-write semantics of `BTree.withCursor(at: Index)` have been fixed.
- `BTree` now never allows its arrays to get larger than their specified order. (Previously, `BTree.join` could allow arrays to grow twice the maximum size, leading to wasted capacity.)

# 1.1.0 (2016-02-24)

This is a feature release that includes the following changes:

#### New features

- `BTree`, `List` and `Map` are now their own subsequences. This makes slicing them much more convenient.
- `BTree` now includes a family of `subtree()` methods to create subtrees based on index, position or key ranges.
- `Map` now includes a family of `submap()` methods to create subtrees based on index, position or key ranges.
- `BTreeCursor.moveToKey(key, choosing: selector)` is a new method for repositioning a cursor at a specific key.
- `BTreeCursor.removeAll()` is a new method for removing all elements.
- `BTreeCursor.removeAllBefore(includingCurrent:)` is a new method that removes all elements before the current position.
- `BTreeCursor.removeAllAfter(includingCurrent:)` is a new method that removes all elements after the current position.
- `BTree.withCursorAt(index)` is a new method that allows you to create a cursor positioned at an index. (Note that it doesn't make sense to reposition a cursor that's already been created, since creating a cursor invalidates existing indices.)

#### Improvements

- The default tree order is now based on the full element size, not just the size of the key (like in 1.0.0). The maximum node size has been bumped to 16kiB to compensate for this.
- `BTreeIndex` now includes the slot number for each node on its path, making navigation a bit faster.
- Position-based searches now start at the end of the tree if the position we're looking for is likely closer to the end than the start. This is a potential 2x improvement.
- `BTree.indexOfPosition` now accepts the element count as a position, returning the tree's end index.

#### Other changes

- `BTreeCursor.insertBefore` has been renamed to `insert`.
- `BTreeCursor.isValid` is not a public property anymore; invalid cursors aren't supposed to leak to correct programs.
- There is now a shared tvOS scheme in the Xcode project. D'oh.
- All public APIs are now documented.
- `@warn_unused_result` attributes have been added for APIs that need them.

# 1.0.0 (2016-02-23)

Initial release of BTree.
