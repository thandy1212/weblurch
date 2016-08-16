
# Main webLurch Application

## Modular organization

This file is one of several files that make up the main webLurch
Application.  For more information on the app and the other files, see
[the first source code file in this set](main-app-basics-solo.litcoffee).

## Global list of labels

We store in the following array the latest data on the global list of
labeled expressions.

    labelPairs = [ ]

Each entry in that list will be an object that contains the following
members.

 * `target` - the expression being labeled; this can be either a Group
   instance from in the document or a canonical/complete form computed from
   one and imported from a dependency
 * `label` - the text content of the label; this must be a string
 * `source` - the expression that is the label; this can be either a Group
   instance from the document, an integer index into the list of embedded
   label attributes of the target itself, or a canonical/complete form
   computed from a group and imported from a dependency

Any other members are permitted as well, but will be ignored.

The list is kept ordered, according to an order relation that depends on the
order of groups in the document and its dependencies.  We define that
relation first.

 * We say Group A is before Group B in the document iff the open grouper for
   A is before the open grouper for B.
 * We say that a canonical form imported from a dependency is before all
   groups in the document.
 * Canonical forms imported from dependencies do not need to be ordered, so
   we choose an arbitrary order for them:  string ordering of their
   serialized form.
 * An attribute hidden in Group A comes after all groups that A comes after,
   before all groups that A comes before, and comes after A itself, and is
   ordered within all other embedded attributes of A alphabetically by key,
   then secondarily by index within that key's value list.

We define the following comparator embodying this.  To indicate that the
left object to be compared is a Group instance, pass it as group1, with
key1 and index1 undefined.  Similarly for the right object and group2, key2,
and index2.  To indicate that the left object is a complete form imported
from a dependency, pass it as group1, leaving key1 and index1 undefined.
Similarly for the right object.  To indicate that the left object is an
embedded attribute, pass the group it's embedded in as group1, and the key
as key1, and its index within that key's list of values as index1 (or zero
if the value is not a list).  Similarly for the right object.

    groupOrder = ( group1, key1, index1, group2, key2, index2 ) ->
        # case 1: left object comes from a dependency
        if group1 instanceof OM
            return if group2 instanceof OM
                group1.encode().localeCompare group2.encode()
            else
                -1
        # case 2: right object comes from a dependency
        if group2 instanceof OM then return 1
        # case 3: left object is visible in the document
        if not key1? or not index1?
            return if group1.open is group2.open
                if not key2? or not index2? then 0 else 1
            else
                strictNodeComparator group1.open, group2.open
        # case 4: left object is a hidden (embedded) attribute
        maybeResult = strictNodeComparator group1.open, group2.open
        if maybeResult isnt 0 then return maybeResult
        maybeResult = key1.localeCompare key2
        if maybeResult isnt 0 then return maybeResult
        index1 - index2

Now we define the order relation on pairs.

 * Define the "first" part of a pair to be either its source or target,
   whichever comes first according to the above ordering.
 * Define the "second" part of a pair to be either its source or target,
   whichever comes second according to the above ordering.
 * Pairs are dictionary ordered, primarily based on their second part, and
   secondarily based on their first part.

We define the following comparator embodying this.

    pairOrder = ( pairA, pairB ) ->
        [ group, key, index ] = [ pairA.source ]
        if typeof group is 'number'
            index = group
            group = pairA.target
            key = 'label'
        if groupOrder( group, key, index, pairA.target ) is -1
            [ firstA, secondA ] = [ group, pairA.target ]
        else
            [ firstA, secondA ] = [ pairA.target, group ]
        [ group, key, index ] = [ pairB.source ]
        if typeof group is 'number'
            index = group
            group = pairB.target
            key = 'label'
        if groupOrder( group, key, index, pairA.target ) is -1
            [ firstB, secondB ] = [ group, pairB.target ]
        else
            [ firstB, secondB ] = [ pairB.target, group ]
        result = groupOrder( secondA, undefined, undefined, secondB ) || \
            groupOrder( firstA, undefined, undefined, firstB )
        result

## Keeping the list up-to-date

The following function clears out that global list.

    clearLabelPairs = -> labelPairs = [ ]

We ensure that it is called whenever a new document is created, or the app
is launched, or a document is loaded.  Immediately after clearing out the
list, we also re-popuplate it, by calling `addExpression` (defined below)
on all visible expressions.

    window.afterEditorReadyArray.push ( editor ) ->
        oldLoadMetaDataHandler = editor.LoadSave.loadMetaData
        editor.LoadSave.loadMetaData = ( object ) ->
            clearLabelPairs()
            for grouper in editor.Groups.allGroupers()
                group = editor.Groups.grouperToGroup grouper
                if group.open is grouper and \
                   group.typeName() is 'expression'
                    addExpression group
            oldLoadMetaDataHandler object

## Functions for adding entries to the list

To record the fact that a given label applies to a given group, call the
following function, passing an object with the members documented
[above](#global-list-of-labels).

    addLabelPair = ( pair ) ->

If the list has length zero, we skip the binary search.

        if labelPairs.length is 0 then return labelPairs.push pair

Now we binary search for where we would insert the pair, using the fact that
the pair list is kept ordered.  If we actually find the pair, then we quit
and do nothing, because the pair is already in the list.

        bottom = 0
        top = labelPairs.length
        while bottom isnt top
            middle = Math.floor ( bottom + top ) / 2
            whichWay = pairOrder pair, labelPairs[middle]
            if whichWay is 0 then return
            if whichWay is -1 then top = middle else bottom = middle + 1

We did not find the pair, but `middle` is the index at which we should
insert it, so do so.

        if bottom is labelPairs.length
            labelPairs.push pair
        else
            labelPairs.splice bottom, 0, pair

You can add all the labels for an expression to the list by calling this one
function on the expression.  It will create all the pair objects necessary,
and pass each to `addLabelPair`.  The parameter can be a Group instance from
in the document, or a complete form imported from a dependency; if it is
neither of those things, this function does nothing.

    addExpression = ( expression ) ->
        labelKey = OM.encodeAsIdentifier 'label'

Handling internal labels works the same in all cases below, so we abstract
it into the following function.

        addInternalLabels = ( labelOrLabelList ) ->
            labels = if labelOrLabelList.type is 'a' and \
               labelOrLabelList.children[0].equals Group::listSymbol
                labelOrLabelList.children[1..]
            else
                [ labelOrLabelList ]
            for label, index in labels
                if value = label.value
                    addLabelPair
                        target : expression
                        source : index
                        label : value

In the case when the expression is a Group instance from the document, we
find all its external labels first, then all its internal labels second.

        if expression instanceof Group
            for external in expression.attributeGroupsForKey 'label'
                if external.children.length is 0
                    addLabelPair
                        target : expression
                        source : external
                        label : external.contentAsText()
            if not internals = expression.get labelKey
                return
            if internals = OM.decode internals.m
                addInternalLabels internals

In the case when the expression is an OpenMath object imported from a
dependency, we know it is in complete form, and so we can just consider its
"label" attribute, which will contain all its labels.

        else if expression instanceof OM
            internals = expression.getAttribute OM.sym labelKey, 'Lurch'
            if internals then addInternalLabels internals
