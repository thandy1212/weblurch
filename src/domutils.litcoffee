
# Utility functions for working with the DOM

## Address

The address of a node `N` in an ancestor node `M` is an array `a`
of non-negative integer indices such that
`M.childNodes[a[0]].childNodes[a[1]]. ...
.childNodes[a[a.length-1]] == N`.  Think of it as the path one must
walk through children to get from `M` down to `N`.  Special cases:
 * If the array is of length 1, then `M == N.parentNode`.
 * If the array is empty, `[]`, then `M == N`.
 * If `M` is not an ancestor of `N`, then we say the address of `N`
   within `M` is null (not an array at all).

The following member function of the `Node` class adds the address
function to that class.  Using the `M` and `N` from above, one
would call it like `N.address M`.  [See below](#index) for its
inverse function, `index`.

It computes the address of any one DOM node within any other.
If the parameter (the ancestor, called `M` above) is not supplied,
then it defaults to the top-level Node above `N`
(i.e., the furthest-up ancestor, with no `.parentNode`,
which usually means it's the global variable `document`).

    Node.prototype.address = ( ancestor = null ) ->

The base case comes in two flavors.
First, if the parameter is this node, then the correct result is
the empty array.

        if this is ancestor then return []

Second, if we've reached the top level then we must consider the
second parameter.  Were we restricted to a specific ancestor?  If
so, we didn't find it, so return null.  If not, return the empty
array, because we have reached the top level.

        if not @parentNode
            return if ancestor then null else []

Otherwise, recur up the ancestor tree, and concatenate our own
index in our parent with the array we compute there, if there is
one.

        recur = @parentNode.address ancestor
        if recur is null then return null
        recur.concat [ Array.prototype.slice.apply(
            @parentNode.childNodes ).indexOf this ]

## Index

This function is an inverse for `address`,
[defined above](#address).

The node at index `I` in node `N` is the descendant `M` of `N` in
the node hierarchy such that `M.address N` is `I`.
In short, if `N` is any ancestor of `M`, then
`N.index(M.address(N)) == M`.

Keeping in mind that an address is simply an array of nonnegative
integers, the implementation is simply repeated lookups in some
`childNodes` arrays.  It is therefore quite short, with most of
the code going to type safety.

    Node.prototype.index = ( address ) ->

Require that the parameter be an array.

        if address not instanceof Array
            throw Error 'Node address function requires an array'

If the array is empty, we've hit the base case of this recursion.

        if address.length is 0 then return this

Othwerise, recur on the child whose index is the first element of
the given address.  There are two safety checks here.  First, we
verify that the index we're about to look up is a number (otherwise
things like `[0]` will be treated as zero, which is probably
erroneous).  Second, the `?.` syntax below ensures that that index
is valid, so that we do not attempt to call this function
recursively on something other than a node.

        if typeof address[0] isnt 'number' then return undefined
        @childNodes[address[0]]?.index address[1..]

## Serialization

These methods are for serializing and unserializing DOM nodes to
objects that are amenable to JSON processing.  Documentation and
testing for them is forthcoming.

    Node.prototype.toJSON = ->
        if @textContent then return @textContent
        if this not instanceof Element
            throw Error "Cannot serialize this node: #{this}"
        result =
            tagName : @tagName
            attributes : { }
            children : [ chi.toJSON() for chi in @childNodes ]
        for attribute in @attributes
            result.attributes[attribute.name] = attribute.value
        result

    Node.fromJSON = ( json ) ->
        if typeof json is 'string' then return json
        if not 'tagName' of json
            throw Error "Object has no tagName: #{this}"
        result = document.createElement json.tagName
        for own key, value of json.attributes
            result.setAttribute key, value
        for child in json.children
            result.appendChild Node.fromJSON child
        result

