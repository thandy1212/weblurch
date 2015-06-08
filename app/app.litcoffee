
# Groups Plugin for [TinyMCE](http://www.tinymce.com)

This plugin adds the notion of "groups" to a TinyMCE editor.  Groups are
contiguous sections of the document, often nested but not otherwise
overlapping, that can be used for a wide variety of purposes.  This plugin
provides the following functionality for working with groups in a document.
 * defines the `Group` and `Groups` classes
 * provides methods for installing UI elements for creating and interacting
   with groups in the document
 * shows groups visually on screen in a variety of ways
 * calls update routines whenever group contents change, so that they can be
   updated/processed

It assumes that TinyMCE has been loaded into the global namespace, so that
it can access it.  It also requires [the overlay
plugin](overlayplugin.litcoffee) to be loaded in the same editor.

All changes made to the document by the user are tracked so that appropriate
events can be called in this plugin to update group objects.  The one
exception to this rule is that calls to the `setContents()` method of the
editor's selection, made by a client, cannot be tracked.  Thus if you call
such a method, you should call `groupChanged()` in any groups whose contents
have changed based on your call to `setContents()`.

# Global functions

The following two global functions determine how we construct HTML to
represent group boundaries (called "groupers") and how we decipher such HTML
back into information about the groupers.

First, how to create HTML representing a grouper.  The parameters are as
follows:  `typeName` is a string naming the type of the group, which must be
[registered](#registering-group-types); `image` is the path to the image
that will be used to represent this grouper; `openClose` must be either the
string "open" or the string "close"; `id` is a nonnegative integer unique to
this group; `hide` is a boolean representing whether the grouper should be
invisible in the document.

    grouperHTML = ( typeName, openClose, id, hide = yes, image ) ->
        hide = if hide then ' hide' else ''
        image ?= "images/red-bracket-#{openClose}.png"
        "<img src='#{image}' class='grouper #{typeName}#{hide}'
              id='#{openClose}#{id}'>"
    window.grouperHTML = grouperHTML

Second, how to extract group information from a grouper.  The two pieces of
information that are most important to extract are whether the grouper is an
open grouper or close grouper, and what its ID is.  This routine extracts
both and returns them in an object with the keys `type` and `id`.  If the
data is not available in the expected format, it returns `null`.

    grouperInfo = ( grouper ) ->
        info = /^(open|close)([0-9]+)$/.exec grouper?.getAttribute? 'id'
        if not info then return null
        result = openOrClose : info[1], id : parseInt info[2]
        more = /^grouper ([^ ]+)/.exec grouper?.getAttribute? 'class'
        if more then result.type = more[1]
        result
    window.grouperInfo = grouperInfo

# `Group` class

This file defines two classes, this one called `Group` and another
([below](#groups-class)) called `Groups`.  They are obviously quite
similarly named, but here is the distinction:  An instance of the `Group`
class represents a single section of text within the document that the user
has "grouped" together.  Thus each document may have zero or more such
instances.  Each editor, however, gets only one instance of the `Groups`
class, which manages all the `Group` instances in that editor's document.

## Group constructor

    class Group

The constructor takes as parameters the two DOM nodes that are its open and
close groupers (i.e., group boundary markers), respectively.  It does not
validate that these are indeed open and close grouper nodes, but just stores
them for later lookup.

The final parameter is an instance of the Groups class, which is the plugin
defined in this file.  Thus each group will know in which environment it
sits, and be able to communicate with that environment.  If that parameter
is not provided, the constructor will attempt to correctly detect it, but
providing the parameter is more efficient.

We call the contents changed event as soon as the group is created, because
any newly-created group needs to have its contents processed for the first
time (assuming a processing routine exists, otherwise the call does
nothing).  We pass "yes" as the second parameter to indicate that this is
the first call ever to `contentsChanged`, and thus the group type may wish
to do some initial setup.

        constructor: ( @open, @close, @plugin ) ->
            if not @plugin?
                for editor in tinymce.editors
                    if editor.getDoc() is @open.ownerDocument
                        @plugin = editor.Groups
                        break
            @contentsChanged yes, yes

This method returns the ID of the group, if it is available within the open
grouper.

        id: => grouperInfo( @open )?.id ? null

The first of the following methods returns the name of the type of the
group, as a string.  The second returns the type as an object, as long as
the type exists in the plugin stored in `@plugin`.

        typeName: => grouperInfo( @open )?.type
        type: => @plugin?.groupTypes?[@typeName()]

We provide the following two simple methods for getting and setting
arbitrary data within a group.  Clients should use these methods rather than
write to fields in a group instance itself, because these (a) guarantee no
collisions with existing properties/methods, and (b) mark that group (and
thus the document) dirty, and ensure that changes to a group's data bring
about any recomputation/reprocessing of that group in the document.

Because we use HTML data attributes to store the data, the keys must be
alphanumeric, optionally with dashes.  Furthermore, the data must be able to
be amenable to JSON stringification.

IMPORTANT:  If you call `set()` in a group, the changes you make will NOT be
stored on the TinyMCE undo/redo stack.  If you want your changes stored on
that stack, you should obey the following coding pattern.
 * Before you make any of your changes, call
   `editor.undoManager.beforeChange()`.
 * After you've made all of your changes, call `editor.undoManager.add()`.

You may or may not wish to have your changes stored on the undo/redo stack.
In general, if the change you're making to the group is in direct and
immediate response to the user's actions, then it should be on the undo/redo
stack, so that the user can change their mind.  However, if the change is
the result of a background computation, which was therefore not in direct
response to one of the user's actions, they will probably not expect to be
able to undo it, and thus you should not place the change on the undo/redo
stack.

        set: ( key, value ) =>
            if not /^[a-zA-Z0-9-]+$/.test key then return
            @open.setAttribute "data-#{key}", JSON.stringify [ value ]
            if @plugin?
                @plugin.editor.fire 'change'
                @plugin.editor.isNotDirty = no
                @contentsChanged()
        get: ( key ) =>
            try
                JSON.parse( @open.getAttribute "data-#{key}" )[0]
            catch e
                undefined

We will need to be able to query the contents of a group, so that later
computations on that group can use its contents to determine how to act.  We
provide functions for fetching the contents of the group as plain text, as
an HTML `DocumentFragment` object, or as an HTML string.

        contentAsText: => @innerRange()?.toString()
        contentAsFragment: => @innerRange()?.cloneContents()
        contentAsHTML: =>
            if not fragment = @contentAsFragment() then return null
            tmp = @open.ownerDocument.createElement 'div'
            tmp.appendChild fragment
            tmp.innerHTML

We can also set the contents of a group with the following function.  This
function can only work if `@plugin` is a `Groups` class instance.

        setContentAsText: ( text ) =>
            if not inside = @innerRange() then return
            @plugin?.editor.selection.setRng inside
            @plugin?.editor.selection.setContent text

Those functions rely on the `innerRange()` function, defined below, with a
corresponding `outerRange` function for the sake of completeness.  We use a
`try`/`catch` block because it's possible that the group has been removed
from the document, and thus we can no longer set range start and end points
relative to the group's open and close groupers.

        innerRange: =>
            range = @open.ownerDocument.createRange()
            try
                range.setStartAfter @open
                range.setEndBefore @close
                range
            catch e then null
        outerRange: =>
            range = @open.ownerDocument.createRange()
            try
                range.setStartBefore @open
                range.setEndAfter @close
                range
            catch e then null

The following function should be called whenever the contents of the group
have changed.  It notifies the group's type, so that the requisite
processing, if any, of the new contents can take place.  It is called
automatically by some handlers in the `Groups` class, below.

By default, it propagates the change event up the ancestor chain in the
group hierarchy, but that can be disabled by passing false as the parameter.

The second parameter indicates whether this is the first `contentsChanged`
call since the group was constructed.  By default, this is false, but is set
to true from the one call made to this function from the group's
constructor.

        contentsChanged: ( propagate = yes, firstTime = no ) =>
            @type()?.contentsChanged? this, firstTime
            if propagate then @parent?.contentsChanged yes

The following serialization routine is useful for sending groups to a Web
Worker for background processing.

        toJSON: =>
            data = { }
            for attr in @open.attributes
                if attr.nodeName[..5] is 'data-' and \
                   attr.nodeName[..9] isnt 'data-mce-'
                    try
                        data[attr.nodeName] =
                            JSON.parse( attr.nodeValue )[0]
            id : @id()
            typeName : @typeName()
            deleted : @deleted
            text : @contentAsText()
            html : @contentAsHTML()
            parent : @parent?.id() ? null
            children : ( child?.id() ? null for child in @children ? [ ] )
            data : data

The `Group` class should be accessible globally.

    window.Group = Group

# `Groups` class

We then define a class that will encapsulate all the functionality about
groups in the editor.  An instance of this class will be stored as a member
in the TinyMCE editor object.  It will keep track of many instances of the
`Group` class.

This convention is adopted for all TinyMCE plugins in the Lurch project;
each will come with a class, and an instance of that class will be stored as
a member of the editor object when the plugin is installed in that editor.
The presence of that member indicates that the plugin has been installed,
and provides access to the full range of functionality that the plugin
grants to that editor.

This particular plugin defines two classes, `Group` and `Groups`.  The differences are spelled out here:
 * Only one instance of the `Groups` class exists for any given editor.
   That instance manages global functionality about groups for that editor.
   Some of its methods create instances of the `Group` class.
 * Zero or more instances of the `Group` class exist for any given editor.
   Each instance corresponds to a single group in the document in that
   editor.

If there were only one editor, this could be changing by making all instance
methods of the `Groups` class into class methods of the `Group` class.  But
since there can be more than one editor, we need separate instances of that
"global" context for each, so we use a `Groups` class to do so.

## Groups constructor

    class Groups

        constructor: ( @editor ) ->

Each editor has a mapping from valid group type names to their attributes.

            @groupTypes = {}

It also has a list of the top-level groups in the editor, which is a forest
in which each node is a group, and groups are nested as hierarchies/trees.

            @topLevel = [ ]

The object maintains a list of unique integer ids for assigning to Groups in
the editor.  The list `@freeIds` is a list `[a_1,...,a_n]` such that an id
is available if and only if it's one of the `a_i` or is greater than `a_n`.
For this reason, the list begins as `[ 0 ]`.

            @freeIds = [ 0 ]

Install in the Overlay plugin for the same editor object a handler that
draws the groups surrounding the user's cursor.

            @editor.Overlay.addDrawHandler @drawGroups

When a free id is needed, we need a function that will give the next such
free id and then mark that id as consumed from the list.

        nextFreeId: =>
            if @freeIds.length > 1 then @freeIds.shift() else @freeIds[0]++

When an id in use becomes free, we need a function that will put it back
into the list of free ids.

        addFreeId: ( id ) =>
            if id < @freeIds[@freeIds.length-1]
                @freeIds.push id
                @freeIds.sort()

When a free id becomes used in some way other than through a call to
`nextFreeId`, we will want to be able to record that fact.  The following
function does so.

        setUsedID: ( id ) =>
            last = @freeIds[@freeIds.length-1]
            while last < id then @freeIds.push ++last
            i = @freeIds.indexOf id
            @freeIds.splice i, 1
            if i is @freeIds.length then @freeIds.push id + 1

## Registering group types

To register a new type of group, simply provide its name, as a text string,
together with an object of attributes.

The name string should only contain alphabetic characters, a through z, case
sensitive, hyphens, or underscores.  All other characters are removed. Empty
names are not allowed, which includes names that become empty when all
illegal characters have been removed.

Re-registering the same name with a new data object will overwrite the old
data object with the new one.  Data objects may have the following key-value
pairs.
 * key: `openImage`, value: a string pointing to the image file to use when
   the open grouper is visible, defaults to `'images/red-bracket-open.png'`
 * If instead you provide the `openImageHTML` tag, an image will be created
   for you by rendering the HTML you provide, and you need not provide an
   `openImage` key-value pair.
 * key: `closeImage`, complement to the previous, defaults to
   `'images/red-bracket-close.png'`
 * Similarly, `closeImageHTML` functions like `openImageHTML`.
 * any key-value pairs useful for placing the group into a menu or toolbar,
   such as the keys `text`, `context`, `tooltip`, `shortcut`, `image`,
   and/or `icon`

Clients don't actually need to call this function.  In their call to their
editor's `init` function, they can include in the large, single object
parameter a key-value pair with key `groupTypes` and value an array of
objects.  Each should have the key `name` and all the other data that this
routine needs, and they will be passed along directly.

        addGroupType: ( name, data = {} ) =>
            name = ( n for n in name when /[a-zA-Z_-]/.test n ).join ''
            @groupTypes[name] = data
            if data.hasOwnProperty 'text'
                plugin = this
                style = ->
                    result = [ ]
                    for own key, value of window.defaultEditorStyles
                        newkey = ''
                        for letter in key
                            if letter.toUpperCase() is letter
                                newkey += '-' + letter.toLowerCase()
                            else
                                newkey += letter
                        result.push "#{newkey}:#{value};"
                    result.join ' '
                if data.imageHTML?
                    data.image = imageURLForHTML data.imageHTML, style()
                if data.openImageHTML?
                    data.openImage = imageURLForHTML data.openImageHTML,
                        style()
                if data.closeImageHTML?
                    data.closeImage = imageURLForHTML data.closeImageHTML,
                        style()
                menuData =
                    text : data.text
                    context : data.context ? 'Insert'
                    onclick : => @groupCurrentSelection name
                    onPostRender : -> # must use -> here to access "this":
                        plugin.groupTypes[name].menuItem = this
                        plugin.updateButtonsAndMenuItems()
                if data.shortcut? then menuData.shortcut = data.shortcut
                if data.icon? then menuData.icon = data.icon
                @editor.addMenuItem name, menuData
                buttonData =
                    tooltip : data.tooltip
                    onclick : => @groupCurrentSelection name
                    onPostRender : -> # must use -> here to access "this":
                        plugin.groupTypes[name].button = this
                        plugin.updateButtonsAndMenuItems()
                key = if data.image? then 'image' else \
                    if data.icon? then 'icon' else 'text'
                buttonData[key] = data[key]
                @editor.addButton name, buttonData

The above function calls `updateButtonsAndMenuItems()` whenever a new button
or menu item is first drawn.  That function is also called whenever the
cursor in the document moves or the groups are rescanned.  It enables or
disables the group-insertion routines based on whether the selection should
be allowed to be wrapped in a group.  This is determined based on whether
the two ends of the selection are inside the same deepest group.

        updateButtonsAndMenuItems: =>
            left = @editor?.selection?.getRng()?.cloneRange()
            if not left then return
            right = left.cloneRange()
            left.collapse yes
            right.collapse no
            inSameGroup =
                @groupAboveCursor( left ) is @groupAboveCursor( right )
            for own name, type of @groupTypes
                type?.button?.disabled not inSameGroup
                type?.menuItem?.disabled not inSameGroup

## Inserting new groups

The following method will wrap the current selection in the current editor
in groupers (i.e., group endpoints) of the given type.  The type must be on
the list of valid types registered with `addGroupType`, above, or this will
do nothing.

        groupCurrentSelection: ( type ) =>

Ignore attempts to insert invalid group types.

            if not @groupTypes.hasOwnProperty type then return

Determine whether existing groupers are hidden or not, so that we insert the
new ones to match.

            hide = ( $ @allGroupers()?[0] ).hasClass 'hide'

Create data to be used for open and close groupers, a cursor placeholder,
and the current contents of the cursor selection.

            id = @nextFreeId()
            open = grouperHTML type, 'open', id, hide,
                @groupTypes[type].openImage
            close = grouperHTML type, 'close', id, hide,
                @groupTypes[type].closeImage

Wrap the current cursor selection in open/close groupers, with the cursor
placeholder after the old selection.

            sel = @editor.selection
            if sel.getStart() is sel.getEnd()

If the whole selection is within one element, then we can just replace the
selection's content with wrapped content, plus a cursor placeholder that we
immediately remove after placing the cursor back there.  We also keep track
of the close grouper element so that we can place the cursor immediatel to
its left after removing the cursor placeholder (or else the cursor may leap
to the start of the document).

                cursor = '<span id="put_cursor_here">\u200b</span>'
                content = @editor.selection.getContent()
                @editor.insertContent open + content + cursor + close
                cursor = ( $ @editor.getBody() ).find '#put_cursor_here'
                close = cursor.get( 0 ).nextSibling
                sel.select cursor.get 0
                cursor.remove()
                sel.select close
                sel.collapse yes
                newGroup = @grouperToGroup close
                newGroup.parent?.contentsChanged()
            else

But if the selection spans multiple elements, then we must handle each edge
of the selection separately.  We cannot use this solution in general,
because editing an element messes up cursor bookmarks within that element.

                range = sel.getRng()
                leftNode = range.startContainer
                leftPos = range.startOffset
                range.collapse no
                sel.setRng range
                @disableScanning()
                @editor.insertContent close
                range.setStart leftNode, leftPos
                range.setEnd leftNode, leftPos
                sel.setRng range
                @editor.insertContent open
                @enableScanning()
                range.setStart leftNode, leftPos
                range.setEnd leftNode, leftPos
                parentOfNewGroup = @groupAboveCursor range
                parentOfNewGroup?.contentsChanged()

## Hiding and showing "groupers"

The word "grouper" refers to the objects that form the boundaries of a group, and thus define the group's extent.  Each is an image with specific classes that define its partner, type, visibility, etc.  The following method applies or removes the visibility flag to all groupers at once, thus toggling their visibility in the document.

        allGroupers: => @editor.getDoc().getElementsByClassName 'grouper'
        hideOrShowGroupers: =>
            groupers = $ @allGroupers()
            if ( $ groupers?[0] ).hasClass 'hide'
                groupers.removeClass 'hide'
            else
                groupers.addClass 'hide'
            @editor.Overlay?.redrawContents()
            @editor.focus()

## Scanning

Scanning is the process of reading the entire document and observing where
groupers lie.  This has several purposes.
 * It verifyies that groups are well-formed (i.e., no unpaired groupers, no
   half-nesting).
 * It ensures the list of `@freeIds` is up-to-date.
 * It maintains an in-memory hierarchy of Group objects (to be implemented).

There are times when we need programmatically to make several edits to the
document, and want them to happen as a single unit, without the
`scanDocument` function altering the document's structure admist the work.
Document scanning can be disabled by adding a scan lock.  Do so with the
following two convenience functions.

        disableScanning: => @scanLocks = ( @scanLocks ?= 0 ) + 1
        enableScanning: =>
            @scanLocks = Math.max ( @scanLocks ? 0 ) - 1, 0
            if @scanLocks is 0 then @scanDocument()

Now the routine itself.

        scanDocument: =>
            if @scanLocks > 0 then return
            groupers = Array::slice.apply @allGroupers()
            gpStack = [ ]
            usedIds = [ ]
            @topLevel = [ ]
            before = @freeIds[..]
            index = ( id ) ->
                for gp, i in gpStack
                    if gp.id is id then return i
                -1

Scanning processes each grouper in the document.

            for grouper in groupers

If it had the grouper class but wasn't really a grouper, delete it.

                if not ( info = grouperInfo grouper )?
                    ( $ grouper ).remove()

If it's an open grouper, push it onto the stack of nested ids we're
tracking.

                else if info.openOrClose is 'open'
                    gpStack.unshift
                        id : info.id
                        grouper : grouper
                        children : [ ]

Otherwise, it's a close grouper.  If it doesn't have a corresponding open
grouper that we've already seen, delete it.

                else
                    if index( info.id ) is -1
                        ( $ grouper ).remove()
                    else

It has an open grouper.  In case that open grouper wasn't the most recent
thing we've seen, delete everything that's intervening, because they're
incorrectly positioned.

                        while gpStack[0].id isnt info.id
                            ( $ gpStack.shift().grouper ).remove()

Then allow the grouper and its partner to remain in the document, and pop
the stack, because we've moved past the interior of that group.
Furthermore, register the group and its ID in this Groups object.

                        groupData = gpStack.shift()
                        usedIds.push info.id
                        @registerGroup groupData.grouper, grouper
                        newGroup = @[info.id]

Assign parent and child relationships, and store this just-created group on
either the list of children for the next parent outwards in the hierarchy,
or the "top level" list if there is no surrounding group.

                        newGroup.children = groupData.children
                        for child in newGroup.children
                            child.parent = newGroup
                        if gpStack.length > 0
                            gpStack[0].children.push newGroup
                        else
                            @topLevel.push newGroup
                            newGroup.parent = null

Any groupers lingering on the "open" stack have no corresponding close
groupers, and must therefore be deleted.

            while gpStack.length > 0
                ( $ gpStack.shift().grouper ).remove()

Now update the `@freeIds` list to be the complement of the `usedIds` array.

            usedIds.sort()
            count = 0
            @freeIds = [ ]
            while usedIds.length > 0
                if count is usedIds[0]
                    usedIds.shift()
                else
                    @freeIds.push count
                count++
                if count > 20 then break
            @freeIds.push count

And any ID that is free now but wasn't before must have its group deleted
from this object's internal cache.  After we delete all of them from the
cache, we also call the group type's `deleted` method on each one, to permit
finalization code to run.  We also mark each with a "deleted" attribute set
to true, so that if there are any pending computations about that group,
they know not to bother actually modifying the group when they complete,
because it is no longer in the document anyway.

            after = @freeIds[..]
            while before[before.length-1] < after[after.length-1]
                before.push before[before.length-1] + 1
            while after[after.length-1] < before[before.length-1]
                after.push after[after.length-1] + 1
            becameFree = ( a for a in after when a not in before )
            deleted = [ ]
            for id in becameFree
                deleted.push @[id]
                @[id]?.deleted = yes
                delete @[id]
            group?.type()?.deleted? group for group in deleted

Invalidate the `ids()` cache ([defined below](
#querying-the-group-hierarchy)) so that the next time that function is run,
it recomputes its results from the newly-generated hierarchy in `topLevel`.

            delete @idsCache

If the Overlay plugin is in use, it should now redraw, since the list of
groups may have changed.  We put it on a slight delay, because there may
still be some pending cursor movements that we want to ensure have finished
before this drawing routine is called.  At the same time, we also update
the enabled/disabled state of group-insertion buttons and menu items.

            setTimeout =>
                @editor.Overlay?.redrawContents()
                @updateButtonsAndMenuItems()
            , 0

The above function needs to create instances of the `Group` class, and
associate them with their IDs.  The following function does so, re-using
copies from the cache when possible.

        registerGroup: ( open, close ) =>
            cached = @[id = grouperInfo( open ).id]
            if cached?.open isnt open or cached?.close isnt close
                @[id] = new Group open, close, this
            id

## Querying the group hierarchy

The results of the scanning process in [the previous section](#scanning) are
readable through the following functions.

The following method returns a list of all ids that appear in the Groups
hierarchy, in tree order.

        ids: =>
            if not @idsCache?
                @idsCache = [ ]
                recur = ( g ) =>
                    @idsCache.push g.id()
                    recur child for child in g.children
                recur group for group in @topLevel
            @idsCache

The following method finds the group for a given open/close grouper element
from the DOM.  It returns null if the given object is not an open/close
grouper, or does not appear in the group hierarchy.

        grouperToGroup: ( grouper ) =>
            if ( id = grouperInfo( grouper )?.id )? then @[id] else null

The following method finds the deepest group containing a given DOM Node.
It does so by a binary search through the groupers array for the closest
grouper before the node.  If it is an open grouper, the node is in that
group.  If it is a close grouper, the node is in its parent group.

        groupAboveNode: ( node ) =>
            if ( all = @allGroupers() ).length is 0 then return null
            less = ( a, b ) ->
                Node.DOCUMENT_POSITION_FOLLOWING & \
                    a.compareDocumentPosition( b )
            left = index : 0, grouper : all[0], leftOfNode : yes
            return @grouperToGroup left.grouper if left.grouper is node
            return null if not less left.grouper, node
            right = index : all.length - 1, grouper : all[all.length - 1]
            return @grouperToGroup right.grouper if right.grouper is node
            return null if less right.grouper, node
            loop
                if left.grouper is node
                    return @grouperToGroup left.grouper
                if right.grouper is node
                    return @grouperToGroup right.grouper
                if left.index + 1 is right.index
                    return null unless group = @grouperToGroup left.grouper
                    return if left.grouper is group.open then group \
                        else group.parent
                middle = Math.floor ( left.index + right.index ) / 2
                if less all[middle], node
                    left =
                        index : middle
                        grouper : all[middle]
                        leftOfNode : yes
                else
                    right =
                        index : middle
                        grouper : all[middle]
                        leftOfNode : no

The following method is like the previous, but instead of computing the
deepest group above a given node, it computes the deepest group above a
given cursor position.  This must be presented to the method in the form of
an HTML Range object that has the same start and end nodes and offsets, such
as one that has been collapsed.

        groupAboveCursor: ( cursor ) =>
            if cursor.startContainer instanceof @editor.getWin().Text
                return @groupAboveNode cursor.startContainer
            if cursor.startContainer.childNodes.length > cursor.startOffset
                elementAfter =
                    cursor.startContainer.childNodes[cursor.startOffset]
                itsGroup = @groupAboveNode elementAfter
                return if itsGroup?.open is elementAfter \
                    then itsGroup.parent else itsGroup
            if cursor.startContainer.childNodes.length > 0
                elementBefore =
                    cursor.startContainer.childNodes[cursor.startOffset - 1]
                itsGroup = @groupAboveNode elementBefore
                return if itsGroup?.close is elementBefore \
                    then itsGroup.parent else itsGroup
            @groupAboveNode cursor.startContainer

The following method generalizes the previous to HTML Range objects that do
not have the same starting and ending points.  The group returned will be
the deepest group containing both ends of the cursor.

        groupAboveSelection: ( range ) =>

Compute the complete ancestor chain of the left end of the range.

            left = range.cloneRange()
            left.collapse yes
            left = @groupAboveCursor left
            leftChain = [ ]
            while left isnt null
                leftChain.unshift left
                left = left.parent

Compute the complete ancestor chain of the right end of the range.

            right = range.cloneRange()
            right.collapse no
            right = @groupAboveCursor right
            rightChain = [ ]
            while right isnt null
                rightChain.unshift right
                right = right.parent

Find the deepest group in both ancestor chains.

            result = null
            while leftChain.length > 0 and rightChain.length > 0 and \
                  leftChain[0] is rightChain[0]
                result = leftChain.shift()
                rightChain.shift()
            result

## Change Events

The following function can be called whenever a certain range in the
document has changed, and groups touching that range need to be updated.  It
assumes that `scanDocument()` was recently called, so that the group
hierarchy is up-to-date.  The parameter must be a DOM Range object.

        rangeChanged: ( range ) =>
            group.contentsChanged no for group in @groupsTouchingRange range

That method uses `@groupsTouchingRange()`, which is implemented below.  It
uses the previous to get a list of all groups that intersect the given DOM
Range object, in the order in which their close groupers appear (which means
that child groups are guaranteed to appear earlier in the list than their
parent groups).

The return value will include all groups whose interior or groupers
intersect the interior of the range.  This includes groups that intersect
the range only indirectly, by being parents whose children intersect the
range, and so on for grandparent groups, etc.  When the selection is
collapsed, the only "leaf" group intersecting it is the one containing it.

This routine requires that `scanDocument` has recently been called, so that
groupers appear in perfectly matched pairs, correctly nested.

        groupsTouchingRange: ( range ) =>
            if ( all = @allGroupers() ).length is 0 then return [ ]
            firstInRange = 1 + @grouperIndexOfRangeEndpoint range, yes, all
            lastInRange = @grouperIndexOfRangeEndpoint range, no, all

If there are no groupers in the selected range at all, then just create the
parent chain of groups above the closest node to the selection.

            if firstInRange > lastInRange
                node = range.startContainer
                if node instanceof @editor.getWin().Element and \
                   range.startOffset < node.childNodes.length
                    node = node.childNodes[range.startOffset]
                group = @groupAboveNode node
                result = if group
                    if group.open is node
                        if group.parent then [ group.parent ] else [ ]
                    else
                        [ group ]
                else
                    [ ]
                while maybeOneMore = result[result.length-1]?.parent
                    result.push maybeOneMore
                return result

Otherwise walk through all the groupers in the selection and push their
groups onto a stack in the order that the close groupers are encountered.

            stack = [ ]
            result = [ ]
            for index in [firstInRange..lastInRange]
                group = @grouperToGroup all[index]
                if all[index] is group.open
                    stack.push group
                else
                    result.push group
                    stack.pop()

Then push onto the stack any open groupers that aren't yet closed, and any
ancestor groups of the last big group encountered, the only one whose parent
groups may not have been seen as open groupers.

            while stack.length > 0 then result.push stack.pop()
            while maybeOneMore = result[result.length-1].parent
                result.push maybeOneMore
            result

The above method uses `@grouperIndexOfRangeEndpoint`, which is defined here.
It locates the endpoint of a DOM Range object in the list of groupers in the
editor.  It performs a binary search through the ordered list of groupers.

The `range` parameter must be a DOM Range object.  The `left` paramter
should be true if you're asking about the left end of the range, false if
you're asking about the right end.

The return value will be the index into `@allGroupers()` of the last grouper
before the range endpoint.  Clearly, then, the grouper on the other side of
the range endpoint is the return value plus 1.  If no groupers are before
the range endpoint, this return value will be -1; a special case of this is
when there are no groupers at all.

The final parameter is optional; it prevents having to compute
`@allGroupers()`, in case you already have that data available.

        grouperIndexOfRangeEndpoint: ( range, left, all ) =>
            if ( all ?= @allGroupers() ).length is 0 then return -1
            endpoint = if left then Range.END_TO_START else Range.END_TO_END
            isLeftOfEndpoint = ( grouper ) =>
                grouperRange = @editor.getDoc().createRange()
                grouperRange.selectNode grouper
                range.compareBoundaryPoints( endpoint, grouperRange ) > -1
            left = 0
            return -1 if not isLeftOfEndpoint all[left]
            right = all.length - 1
            return right if isLeftOfEndpoint all[right]
            loop
                return left if left + 1 is right
                middle = Math.floor ( left + right ) / 2
                if isLeftOfEndpoint all[middle]
                    left = middle
                else
                    right = middle

## Drawing Groups

The following function draws groups around the user's cursor, if any.  It is
installed in [the constructor](#groups-constructor) and called by [the
Overay plugin](overlayplugin.litcoffee).

        drawGroups: ( canvas, context ) =>
            @bubbleTags = [ ]

We do not draw the groups if document scanning is disabled, because it means
that we are in the middle of a change to the group hierarchy, which means
that calls to the functions we'll need to figure out what to draw will give
unstable/incorrect results.

            if @scanLocks > 0 then return
            group = @groupAboveSelection @editor.selection.getRng()
            bodyStyle = null
            pad = 3
            padStep = 2
            radius = 4
            p4 = Math.pi / 4
            tags = [ ]
            while group
                type = group.type()
                color = type?.color ? '#444444'

Compute the sizes and positions of the open and close groupers.

                open = $ group.open
                close = $ group.close
                p = open.position()
                open =
                    top : p.top
                    left : p.left
                    bottom : p.top + open.height()
                    right : p.left + open.width()
                p = close.position()
                close =
                    top : p.top
                    left : p.left
                    bottom : p.top + close.height()
                    right : p.left + close.width()

If any of them has zero size, then that means that an image file (for an
open/close grouper) isn't yet loaded.  Thus we need to stop here and queue
up a later call to this same drawing routine, at which time the image file
may be loaded.

                if ( open.top is open.bottom or \
                     close.top is close.bottom or \
                     open.left is open.right or \
                     close.left is close.right ) and \
                   not ( $ group.open ).hasClass 'hide'
                    setTimeout ( => @editor.Overlay?.redrawContents() ), 100
                    return

Compute the group's tag contents, if any, and store where and how to draw
them.

                x1 = open.left - pad/3
                y1 = open.top - pad
                x2 = close.right + pad/3
                y2 = close.bottom + pad
                if tagString = type?.tagContents? group
                    style = @editor.getWin().getComputedStyle group.open
                    tags.push
                        content : tagString
                        corner : { x : x1, y : y1 }
                        color : color
                        style : "font-size:#{style.fontSize};
                                 font-family:#{style.fontFamily};"
                        group : group

Draw this group and then move one step up the group hierarchy, ready to draw
the next one on the next pass through the loop.

                context.fillStyle = context.strokeStyle = color
                if open.top is close.top

A rounded rectangle from open's top left to close's bottom right, padded by
`pad/3` in the x direction, `pad` in the y direction, and with corner radius
`radius`.

                    context.roundedRect x1, y1, x2, y2, radius
                else
                    if not bodyStyle?
                        bodyStyle = getComputedStyle @editor.getBody()
                        leftMar = parseInt bodyStyle['margin-left']
                        rightMar = parseInt bodyStyle['margin-right']
                    context.roundedZone x1, y1, x2, y2, open.bottom,
                        close.top, leftMar, rightMar, radius
                context.globalAlpha = 1.0
                context.lineWidth = 1.5
                context.stroke()
                context.globalAlpha = 0.3
                context.fill()
                group = group.parent
                pad += padStep

Now draw the tags on all the bubbles just drawn.  We proceed in reverse
order, so that outer tags are drawn behind inner ones.  We also track the
rectangles we've covered, and move any later ones upward so as not to
collide with ones drawn earlier.

We begin by measuring the sizes of the rectangles, and checking for
collisions.  Those that collide with previously-scanned rectangles are slid
upwards so that they don't collide anymore.  After all collisions have been
resolved, the rectangle's bottom boundary is reset to what it originally
was, so that the rectangle actually just got taller.

            tagsToDraw = [ ]
            while tags.length > 0
                tag = tags.shift()
                context.font = tag.font
                if not size = context.measureHTML tag.content, tag.style
                    setTimeout ( => @editor.Overlay?.redrawContents() ), 10
                    return
                x1 = tag.corner.x - padStep
                y1 = tag.corner.y - size.height - 2*padStep
                x2 = x1 + 2*padStep + size.width
                y2 = tag.corner.y
                for old in tagsToDraw
                    if rectanglesCollide x1, y1, x2, y2, old.x1, old.y1, \
                                         old.x2, old.y2
                        moveBy = old.y1 - y2
                        y1 += moveBy
                        y2 += moveBy
                y2 = tag.corner.y
                [ tag.x1, tag.y1, tag.x2, tag.y2 ] = [ x1, y1, x2, y2 ]
                tagsToDraw.unshift tag

Now we draw the tags that have already been sized for us by the previous
loop.

            for tag in tagsToDraw
                context.roundedRect tag.x1, tag.y1, tag.x2, tag.y2, radius
                context.globalAlpha = 1.0
                context.fillStyle = '#ffffff'
                context.fill()
                context.lineWidth = 1.5
                context.strokeStyle = tag.color
                context.stroke()
                context.globalAlpha = 0.7
                context.fillStyle = tag.color
                context.fill()
                context.fillStyle = '#000000'
                context.globalAlpha = 1.0
                context.drawHTML tag.content, tag.x1 + padStep, tag.y1,
                    tag.style
                @bubbleTags.unshift tag

# Installing the plugin

The plugin, when initialized on an editor, places an instance of the
`Groups` class inside the editor, and points the class at that editor.

    tinymce.PluginManager.add 'groups', ( editor, url ) ->
        editor.Groups = new Groups editor
        editor.on 'init', ( event ) -> editor.dom.loadCSS 'groupsplugin.css'
        for type in editor.settings.groupTypes
            editor.Groups.addGroupType type.name, type
        editor.addMenuItem 'hideshowgroups',
            text : 'Hide/show groups'
            context : 'View'
            onclick : -> editor.Groups.hideOrShowGroupers()

The document needs to be scanned (to rebuild the groups hierarchy) whenever
it changes.  The editor's change event is not reliable, in that it fires
only once at the beginning of any sequence of typing.  Thus we watch not
only for change events, but also for KeyUp events.  We filter the latter so
that we do not rescan the document if the key in question was only an arrow
key or home/end/pgup/pgdn.

In addition to rescanning the document, we also call the `rangeChanged`
event of the Groups plugin, to update any groups that overlap the range in
which the document was modified.

        editor.on 'change SetContent', ( event ) ->
            editor.Groups.scanDocument()
            if event?.level?.bookmark
                orig = editor.selection.getBookmark()
                editor.selection.moveToBookmark event.level.bookmark
                range = editor.selection.getRng()
                editor.selection.moveToBookmark orig
                editor.Groups.rangeChanged range
        editor.on 'KeyUp', ( event ) ->
            movements = [ 33..40 ] # arrows, pgup/pgdn/home/end
            modifiers = [ 16, 17, 18, 91 ] # alt, shift, ctrl, meta
            if event.keyCode in movements or event.keyCode in modifiers
                return
            editor.Groups.scanDocument()
            editor.Groups.rangeChanged editor.selection.getRng()

Whenever the cursor moves, we should update whether the group-insertion
buttons and menu items are enabled.

        editor.on 'NodeChange', ( event ) ->
            editor.Groups.updateButtonsAndMenuItems()

The following handler installs a context menu that is exactly like that
created by the TinyMCE context menu plugin, except that it appends to it
any custom menu items needed by any groups inside which the user clicked.

        editor.on 'contextMenu', ( event ) ->

Prevent the browser's context menu.

            event.preventDefault()

Figure out where the user clicked, and whether there are any groups there.

            x = event.clientX
            y = event.clientY
            if node = editor.getDoc().nodeFromPoint x, y
                group = editor.Groups.groupAboveNode node

Compute the list of normal context menu items.

            contextmenu = editor.settings.contextmenu or \
                'link image inserttable | cell row column deletetable'
            items = [ ]
            for name in contextmenu.split /[ ,]/
                item = editor.menuItems[name]
                if name is '|' then item = text : name
                if item then item.shortcut = '' ; items.push item

Add any group-specific context menu items.

            if newItems = group?.type()?.contextMenuItems group
                items.push text : '|'
                items = items.concat newItems

Construct the menu and show it on screen.

            menu = new tinymce.ui.Menu(
                items : items
                context : 'contextmenu'
            ).addClass( 'contextmenu' ).renderTo()
            editor.on 'remove', -> menu.remove() ; menu = null
            pos = ( $ editor.getContentAreaContainer() ).position()
            menu.moveTo x + pos.left, y + pos.top

When the user clicks in a bubble tag, we must discern which bubble tag
received the click, and trigger the tag menu for that group, if it defines
one.

We use the mousedown event rather than the click event, because the
mousedown event is the only one for which `preventDefault()` can function.
By the time the click event happens (strictly after mousedown), it is too
late to prevent the default handling of the event.

        editor.on 'mousedown', ( event ) ->
            x = event.clientX
            y = event.clientY
            for tag in editor.Groups.bubbleTags
                if tag.x1 < x < tag.x2 and tag.y1 < y < tag.y2
                    menuItems = tag.group?.type()?.tagMenuItems tag.group
                    menuItems ?= [
                        text : 'no actions available'
                        disabled : true
                    ]
                    menu = new tinymce.ui.Menu(
                        items : menuItems
                        context : 'contextmenu'
                    ).addClass( 'contextmenu' ).renderTo()
                    editor.on 'remove', -> menu.remove() ; menu = null
                    pos = ( $ editor.getContentAreaContainer() ).position()
                    menu.moveTo x + pos.left, y + pos.top
                    event.preventDefault()
                    break



# Load/Save Plugin for [TinyMCE](http://www.tinymce.com)

This plugin will leverage [jsfs](https://github.com/nathancarter/jsfs) to
add load and save functionality to a TinyMCE instance.  It assumes that both
TinyMCE and jsfs have been loaded into the global namespace, so that it can
access both.

# `LoadSave` class

We begin by defining a class that will contain all the information needed
regarding loading and saving a document.  An instance of this class will be
stored as a member in the TinyMCE editor object.

This convention is adopted for all TinyMCE plugins in the Lurch project;
each will come with a class, and an instance of that class will be stored as
a member of the editor object when the plugin is installed in that editor.
The presence of that member indicates that the plugin has been installed,
and provides access to the full range of functionality that the plugin
grants to that editor.

    class LoadSave

## Class variables

As a class variable, we store the name of the app.  We allow changing this
by a global function defined at the end of this file.  Be default, there is
no app name.  If one is provided, it will be used when filling in the title
of the page, upon changes to the filename and/or document dirty state.

        appName: null

It comes with a setter, so that if the app name changes, all instances will
automatically change their app names as well.

        @setAppName: ( newname = null ) ->
            LoadSave::appName = newname
            instance.setAppName newname for instance in LoadSave::instances

We must therefore track all instances in a class variable.

        instances: [ ]

## Constructor

A newly-constructed document defaults to being clean, having no filename,
and using the app name as the filesystem name.  These attributes can be
changed with the setters defined in the following section.

        constructor: ( @editor ) ->
            @setAppName LoadSave::appName
            @setFileSystem @appName
            @setFilepath FileSystem::pathSeparator # root
            setTimeout ( => @clear() ), 0

The following handlers exist for wrapping metadata around a document before
saving, or unwrapping after loading.  They default to null, but can be
overridden by a client by direct assignment of functions to these members.

The `saveMetaData` function should take no inputs, and yield as output a
single object encoding all the metadata as key-value pairs in the object.
It will be saved together with the document content.

The `loadMetaData` function should take as input one argument, an object
that was previously created by the a call to `saveMetaData`, and repopulate
the UI and memory with the relevant portions of that document metadata.  It
is called immediately after a document is loaded.

            @saveMetaData = @loadMetaData = null

Whenever the contents of the document changes, we mark the document dirty in
this object, which therefore adds the \* marker to the page title.

            @editor.on 'change', ( event ) => @setDocumentDirty yes

Now install into the editor controls that run methods in this object.  The
`control` method does something seemingly inefficient to duplicate the input
data object to pass to `addButton`, but this turns out to be necessary, or
the menu items look like buttons.  (I believe TinyMCE manipulates the object
upon receipt.)

            control = ( name, data ) =>
                buttonData =
                    icon : data.icon
                    shortcut : data.shortcut
                    onclick : data.onclick
                    tooltip : data.tooltip
                key = if data.icon? then 'icon' else 'text'
                buttonData[key] = data[key]
                @editor.addButton name, buttonData
                @editor.addMenuItem name, data
            control 'newfile',
                text : 'New'
                icon : 'newdocument'
                context : 'file'
                shortcut : 'ctrl+N'
                tooltip : 'New file'
                onclick : => @tryToClear()
            control 'savefile',
                text : 'Save'
                icon : 'save'
                context : 'file'
                shortcut : 'ctrl+S'
                tooltip : 'Save file'
                onclick : => @tryToSave()
            @editor.addMenuItem 'saveas',
                text : 'Save as...'
                context : 'file'
                shortcut : 'ctrl+shift+S'
                onclick : => @tryToSave null, ''
            control 'openfile',
                text : 'Open...'
                icon : 'browse'
                context : 'file'
                shortcut : 'ctrl+O'
                tooltip : 'Open file...'
                onclick : => @handleOpen()
            @editor.addMenuItem 'managefiles',
                text : 'Manage files...'
                context : 'file'
                onclick : => @manageFiles()

Lastly, keep track of this instance in the class member for that purpose.

            LoadSave::instances.push this

## Setters

We then provide setters for the `@documentDirty`, `@filename`, and
`@appName` members, because changes to those members trigger the
recomputation of the page title.  The page title will be of the form "app
name: document title \*", where the \* is only present if the document is
dirty, and the app name (with colon) are omitted if none has been specified
in code.

        recomputePageTitle: =>
            document.title = "#{if @appName then @appName+': ' else ''}
                              #{@filename or '(untitled)'}
                              #{if @documentDirty then '*' else ''}"
        setDocumentDirty: ( setting = yes ) =>
            @documentDirty = setting
            @recomputePageTitle()
        setFilename: ( newname = null ) =>
            @filename = newname
            @recomputePageTitle()
        setFilepath: ( newpath = null ) => @filepath = newpath
        setAppName: ( newname = null ) =>
            mustAlsoUpdateFileSystem = @appName is @fileSystem
            @appName = newname
            if mustAlsoUpdateFileSystem then @fileSystem = @appName
            @recomputePageTitle()
        setFileSystem: ( newname = @appName ) => @fileSystem = newname

## New documents

To clear the contents of the document, use this method in its `LoadSave`
member.  It handles notifying this instance that the document is then clean.
It does *not* check to see if the document needs to be saved first; it just
outright clears the editor.  It also clears the filename, so that if you
create a new document and then save, it does not save over your last
document.

        clear: =>
            @editor.setContent ''
            @setDocumentDirty no
            @setFilename null

Unlike the previous, this function *does* first check to see if the contents
of the editor need to be saved.  If they do, and they aren't saved (or if
the user cancels), then the clear is aborted.  Otherwise, clear is run.

        tryToClear: =>
            if not @documentDirty
                @clear()
                @editor.focus()
                return
            @editor.windowManager.open {
                title : 'Save first?'
                buttons : [
                    text : 'Save'
                    onclick : =>
                        @tryToSave ( success ) => if success then @clear()
                        @editor.windowManager.close()
                ,
                    text : 'Discard'
                    onclick : =>
                        @clear()
                        @editor.windowManager.close()
                ,
                    text : 'Cancel'
                    onclick : => @editor.windowManager.close()
                ]
            }

## Saving documents

To save the current document under the filename in the `@filename` member,
call the following function.  It returns a boolean indicating success or
failure.  If there is no filename in the `@filename` member, failure is
returned and no action taken.  If the save succeeds, mark the document
clean.

        save: =>
            if @filename is null then return
            tmp = new FileSystem @fileSystem
            tmp.cd @filepath
            objectToSave = [ @editor.getContent(), @saveMetaData?() ]
            if tmp.write @filename, objectToSave, yes # use compression
                @setDocumentDirty no

This function tries to save the current document.  When the save has been
completed or canceled, the callback will be called, with one of the
following parameters:  `false` means the save was canceled, `true` means it
succeeded, and any string means there was an error.  If the save succeeded,
the internal `@filename` field of this object may have been updated.

To force a save into a file other than the current `@filename`, pass the
other filename as the optional second parameter.  To force "save as"
behavior when there is a current `@filename`, pass null as the optional
second parameter.

        tryToSave: ( callback, filename = @filename ) =>

If there is a filename for the current document already in this object's
`@filename` member, then a save is done directly to that filename.  If there
is no filename, then a save dialog is shown.

            if filename
                @setFilename filename
                result = @save() # save happens even if no callback
                @editor.focus()
                return callback? result

There is not a readily available filename, so we must pop up a "Save as"
dialog.  First we create a routine for updating the dialog we're about to
show with an enabled/disabled Save button, based on whether there is a file
selected.

            refreshDialog = ->
                dialog = document.getElementsByClassName( 'mce-window' )[0]
                if not dialog then return
                for button in dialog.getElementsByTagName 'button'
                    if button.textContent is 'Save'
                        if filename
                            button.removeAttribute 'disabled'
                            button.parentNode.style.backgroundImage = null
                            button.parentNode.style.backgroundColor = null
                        else
                            button.setAttribute 'disabled', yes
                            button.parentNode.style.backgroundImage = 'none'
                            button.parentNode.style.backgroundColor = '#ccc'
                        break

Now we install a handler for when a file is selected, save that filename for
possible later use, and refresh the dialog.

            filename = null
            @saveFileNameChangedHandler = ( newname ) ->
                filename = newname
                refreshDialog()

Do the same thing for when the folder changes, but there's no need to
refresh the dialog in this case.

            filepath = null
            @changedFolderHandler = ( newfolder ) -> filepath = newfolder

We will also need to know whether the `save` function will overwrite an
existing file, so that we can verify that the user actually wants to do so
before we save.  The following function performs that check.

            saveWouldOverwrite = ( filepath, filename ) =>
                tmp = new FileSystem @fileSystem
                tmp.cd filepath
                null isnt tmp.type filename

Create a handler to receive the button clicks.  We do this here so that if
the dialog clicks a button programmatically, which then passes to us a
message that the button was clicked, we will still hear it through this
handler, because the `window.onmessage` handler installed at the end of this
file will call this function.

            @buttonClickedHandler = ( name, args... ) =>
                if name is 'Save'

If the file chosen already exists, ask the user if they're sure they want to
overwrite it.  If they say no, then we go back to the save dialog.  However,
the dialog, by default, resets itself to "manage files" mode whenever a
button is clicked.  So we put it back in "save file" mode before exiting.

                    if saveWouldOverwrite filepath, filename
                        if not confirm "Are you sure you want to overwrite
                          the file #{filename}?"
                            @tellDialog 'setFileBrowserMode', 'save file'
                            return

Now that we're sure the user wants to save, we store the path and filename
for use in later saves, and perform the save, closing the dialog.

                    @setFilepath filepath
                    @setFilename filename
                    @editor.windowManager.close()
                    result = @save() # save happens even if no callback
                    callback? result
                else if name is 'Cancel'
                    @editor.windowManager.close()
                    callback? no

Now we are sufficiently ready to pop up the dialog.  We use one made from
[filedialog/filedialog.html](filedialog.html), which was copied from [the
jsfs submodule](../jsfs/demo) and modified to suit the needs of this
application.

            @editor.windowManager.open {
                title : 'Save file...'
                url : 'filedialog/filedialog.html'
                width : 600
                height : 400
                buttons : [
                    text : 'Save'
                    subtype : 'primary'
                    onclick : => @buttonClickedHandler 'Save'
                ,
                    text : 'Cancel'
                    onclick : => @buttonClickedHandler 'Cancel'
                ]
            }, {
                fsName : @fileSystem
                mode : 'save file'
            }

## Loading documents

The following function loads into the editor the contents of the file.  It
must be a file containing a string of HTML, because that content will be
directly used as the content of the editor.  The current path and filename
of this plugin are set to be the parameters passed here.

        load: ( filepath, filename ) =>
            if filename is null then return
            if filepath is null then filepath = '.'
            tmp = new FileSystem @fileSystem
            tmp.cd filepath
            [ content, metadata ] = tmp.read filename
            @editor.setContent content
            @editor.focus()
            @setFilepath filepath
            @setFilename filename
            @setDocumentDirty no
            if metadata then @loadMetaData? metadata

The following function pops up a dialog to the user, allowing them to choose
a filename to open.  If they choose a file, it (with the current directory)
is passed to the given callback function.  If they do not choose a file, but
cancel the dialog instead, then null is passed to that callback to indicate
the cancellation. It makes the most sense to leave the callback function the
default, `@load`.

        tryToOpen: ( callback = ( p, f ) => @load p, f ) =>

First we create a routine for updating the dialog we're about to show with
an enabled/disabled Save button, based on whether there is a file selected.

            refreshDialog = =>
                dialog = document.getElementsByClassName( 'mce-window' )[0]
                if not dialog then return
                for button in dialog.getElementsByTagName 'button'
                    if button.textContent is 'Open'
                        if filename
                            button.removeAttribute 'disabled'
                            button.parentNode.style.backgroundImage = null
                            button.parentNode.style.backgroundColor = null
                        else
                            button.setAttribute 'disabled', yes
                            button.parentNode.style.backgroundImage = 'none'
                            button.parentNode.style.backgroundColor = '#ccc'
                        break

Now we install a handler for when a file is selected, save that filename for
possible later use, and refresh the dialog.

            filename = null
            @selectedFileHandler = ( newname ) ->
                filename = newname
                refreshDialog()

Do the same thing for when the folder changes, but there's no need to
refresh the dialog in this case.

            filepath = null
            @changedFolderHandler = ( newfolder ) -> filepath = newfolder

Create a handler to receive the button clicks.  We do this here so that if
the dialog clicks a button programmatically, which then passes to us a
message that the button was clicked, we will still hear it through this
handler, because the `window.onmessage` handler installed at the end of this
file will call this function.

            @buttonClickedHandler = ( name, args... ) =>
                if name is 'Open'
                    @editor.windowManager.close()
                    callback? filepath, filename
                else if name is 'Cancel'
                    @editor.windowManager.close()
                    callback? null, null

Now we are sufficiently ready to pop up the dialog.  We use one made from
[filedialog/filedialog.html](filedialog.html), which was copied from [the
jsfs submodule](../jsfs/demo) and modified to suit the needs of this
application.

            @editor.windowManager.open {
                title : 'Open file...'
                url : 'filedialog/filedialog.html'
                width : 600
                height : 400
                buttons : [
                    text : 'Open'
                    subtype : 'primary'
                    onclick : => @buttonClickedHandler 'Open'
                ,
                    text : 'Cancel'
                    onclick : => @buttonClickedHandler 'Cancel'
                ]
            }, {
                fsName : @fileSystem
                mode : 'open file'
            }
            refreshDialog()

The following handler for the "open" controls checks with the user to see if
they wish to save their current document first, if and only if that document
is dirty.  The user may save, or cancel, or discard the document.

        handleOpen: =>

First, if the document does not need to be saved, just do a regular "open."

            if not @documentDirty then return @tryToOpen()

Now, we know that the document needs to be saved.  So prompt the user with a
dialog box asking what they wish to do.

            @editor.windowManager.open {
                title : 'Save first?'
                buttons : [
                    text : 'Save'
                    onclick : =>
                        @editor.windowManager.close()
                        @tryToSave ( success ) =>
                            if success then @tryToOpen()
                ,
                    text : 'Discard'
                    onclick : =>
                        @editor.windowManager.close()
                        @tryToOpen()
                ,
                    text : 'Cancel'
                    onclick : => @editor.windowManager.close()
                ]
            }

## Communcating with dialogs

When a dialog is open, it is in an `<iframe>` within the main page, which
means that it can only communicate with the script environment of the main
page through message-passing.  This function finds the `<iframe>` containing
the file dialog and (if there was one) sends it the message given as the
argument list.

        tellDialog: ( args... ) ->
            frames = document.getElementsByTagName 'iframe'
            for frame in frames
                if 'filedialog/filedialog.html' is frame.getAttribute 'src'
                    return frame.contentWindow.postMessage args, '*'

## Managing files

The final menu item is one that shows a dialog for managing files in the
filesystem.  On desktop apps, no such feature is necessary, because every
operating system comes with a file manager of its own.  In this web app,
where we have a virtual filesystem, we must provide a file manager to access
it and move, rename, and delete files, create folders, etc.

        manageFiles: =>
            @editor.windowManager.open {
                title : 'Manage files'
                url : 'filedialog/filedialog.html'
                width : 700
                height : 500
                buttons : [
                    text : 'New folder'
                    onclick : => @tellDialog 'buttonClicked', 'New folder'
                ,
                    text : 'Done'
                    onclick : => @editor.windowManager.close()
                ]
            }, {
                fsName : @fileSystem
                mode : 'manage files'
            }

# Global stuff

## Installing the plugin

The plugin, when initialized on an editor, places an instance of the
`LoadSave` class inside the editor, and points the class at that editor.

    tinymce.PluginManager.add 'loadsave', ( editor, url ) ->
        editor.LoadSave = new LoadSave editor

## Event handler

When a file dialog sends a message to the page, we look through the existing
instances of the `LoadSave` class for whichever one wants to handle that
message.  Whichever one has a handler ready, we call that handler.

    window.onmessage = ( event ) ->
        handlerName = "#{event.data[0]}Handler"
        for instance in LoadSave::instances
            if instance.hasOwnProperty handlerName
                return instance[handlerName].apply null, event.data[1..]

## Global functions

Finally, the global function that changes the app name.

    window.setAppName = ( newname = null ) -> LoadSave::appName = newname



# Overlay Plugin for [TinyMCE](http://www.tinymce.com)

This plugin creates a canvas element that sits directly on top of the
editor.  It is transparent, and thus invisible, unless items are drawn on
it; hence it functions as an overlay.  It also passes all mouse and keyboard
events through to the elements beneath it, so it does not interefere with
the functionality of the rest of the page in that respect.

# `Overlay` class

We begin by defining a class that will contain all the information needed
about the overlay element and how to use it.  An instance of this class will
be stored as a member in the TinyMCE editor object.

This convention is adopted for all TinyMCE plugins in the Lurch project;
each will come with a class, and an instance of that class will be stored as
a member of the editor object when the plugin is installed in that editor.
The presence of that member indicates that the plugin has been installed,
and provides access to the full range of functionality that the plugin
grants to that editor.

    class Overlay

We construct new instances of the Overlay class as follows, and these are
inserted as members of the corresponding editor by means of the code [below,
under "Installing the Plugin."](#installing-the-plugin)

        constructor: ( @editor ) ->

The first task of the constructor is to create and style the canvas element,
inserting it at the appropriate place in the DOM.  The following code does
so.  Note the use of `rgba(0,0,0,0)` for transparency, the `pointer-events`
attribute for ignoring mouse clicks, and the fact that the canvas is a child
of the same container as the editor itself.

            @editor.on 'init', =>
                @container = @editor.getContentAreaContainer()
                @canvas = document.createElement 'canvas'
                ( $ @container ).after @canvas
                @canvas.style.position = 'absolute'
                @canvas.style['background-color'] = 'rgba(0,0,0,0)'
                @canvas.style['pointer-events'] = 'none'
                @canvas.style['z-index'] = '10'

We then allow any client to register drawing routines with this plugin, and
all registered routines will be called (in the order in which they were
registered) every time the canvas needs to be redrawn.  The following line
initializes the list of drawing handlers to empty.

            @drawHandlers = []
            @editor.on 'NodeChange', @redrawContents
            ( $ window ).resize @redrawContents

This function installs an event handler that, each time something in the
document changes, repositions the canvas, clears it, and runs all drawing
handlers.

        redrawContents: ( event ) =>
            @positionCanvas()
            if not context = @canvas?.getContext '2d' then return
            @clearCanvas context
            context.translate 0, ( $ @container ).position().top
            for doDrawing in @drawHandlers
                try
                    doDrawing @canvas, context
                catch e
                    console.log "Error in overlay draw function: #{e.stack}"

The following function permits the installation of new drawing handlers.
Each will receive two parameters (as shown in the code immediately above),
the first being the canvas on which to draw, and the second being the
drawing context.

        addDrawHandler: ( drawFunction ) -> @drawHandlers.push drawFunction

This function is part of the private API, and is used only by
`positionCanvas`, below.  It fetches the `<iframe>` used by the editor in
which this plugin was installed.

        getEditorFrame: ->
            for frame in window.frames
                if frame.document is @editor.getDoc()
                    return frame
            null

This function repositions the canvas, so that if the window is moved or
resized, then before redrawing takes place, the canvas reacts accordingly.
This is called only by the handler installed in the constructor, above.

        positionCanvas: ->
            con = $ @container
            can = $ @canvas
            if not con.position()? then return
            can.css 'top', 0
            can.css 'left', con.position().left
            can.width con.width()
            can.height con.position().top + con.height()
            @canvas.width = can.width()
            @canvas.height = can.height()

This function clears the canvas before drawing.  It is called only by the
handler installed in the constructor, above.

        clearCanvas: ( context ) ->
            context.clearRect 0, 0, @canvas.width, @canvas.height

# Installing the plugin

The plugin, when initialized on an editor, places an instance of the
`Overlay` class inside the editor, and points the class at that editor.

    tinymce.PluginManager.add 'overlay', ( editor, url ) ->
        editor.Overlay = new Overlay editor



# App Setup Script

## Specify app settings

First, specify that the app's name is "Lurch," so that will be used when
creating the title for this page (e.g., to show up in the tab in Chrome).

    setAppName 'Lurch'

Second, we initialize a very simple default configuration for the Groups
plugin.  It can be overridden by having any script assign to the global
variable `groupTypes`, overwriting this data.  Such a change must be done
before the page is fully loaded, when the `tinymce.init` call, below, takes
place.  For examples of how to do this, see
[the simple example app](simple-example.solo.litcoffee),
[the complex example app](complex-example.solo.litcoffee), and
[the mathematical example app](math-example.solo.litcoffee).

    window.groupTypes ?= [
        name : 'me'
        text : 'Meaningful expression'
        image : './images/red-bracket-icon.png'
        tooltip : 'Make text a meaningful expression'
        color : '#996666'
    ]

We also specify an icon to appear on the menu bar, at the very left.  This
can be overridden, in the same way as `window.groupTypes`, above.  (See the
same examples apps for specific code.)

    window.menuBarIcon ?=
        src : 'icons/apple-touch-icon-76x76.png'
        width : '26px'
        height : '26px'
        padding : '2px'

We also provide a set of styles to be added to the editor by default.
Clients can also override this object if they wish different styles.  (See
the same examples apps for specific code.)

    window.defaultEditorStyles ?=
        fontSize : '16px'

We can also provide the text for the Help/About menu item by overriding the
following in a separate configuration file.  (See the same examples apps for
specific code.)

    window.helpAboutText ?=
        'webLurch\n\nalpha\n\nnot yet intended for non-developer use'

## Add an editor to the app

This file initializes a [TinyMCE](http://www.tinymce.com/) editor inside the
[main app page](index.html).  It is designed to be used inside that page,
where [jQuery](http://jquery.com/) has already been loaded, thus defining
the `$` symbol used below.  Its use in this context causes the function to
be run only after the DOM has been fully loaded.

    $ ->

Create a `<textarea>` to be used as the editor.

        editor = document.createElement 'textarea'
        editor.setAttribute 'id', 'editor'
        document.body.appendChild editor

If the query string is telling us to switch the app into test-recording
mode, then do so.  This uses the main function defined in
[testrecorder.litcoffee](./testrecorder.litcoffee), which does nothing
unless the query string contains the code that invokes test-recording mode.

        maybeSetupTestRecorder()

We need the list of group types names so that we can include them in the
toolbar and menu initializations below.

        groupTypeNames = ( type.name for type in groupTypes )

Before loading TinyMCE, we load [a third-party plugin for editing math
equations](eqed/).

        tinymce.PluginManager.load 'equationeditor',
            '/app/eqed/plugins/equationeditor/plugin.min.js'

Install a TinyMCE instance in that text area, with specific plugins, toolbar
buttons, and context menu items as given below.

        tinymce.init
            selector : '#editor'
            auto_focus : 'editor'

These enable the use of the browser's built-in spell-checking facilities, so
that no server-side callback needs to be done for spellchecking.

            browser_spellcheck : yes
            gecko_spellcheck : yes
            statusbar : no

Not all of the following plugins are working yet, but most are.  A plugin
that begins with a hyphen is a local plugin written as part of this project.

            plugins : 'advlist table charmap colorpicker image link
                importcss paste print save searchreplace textcolor
                fullscreen -loadsave -overlay -groups equationeditor'

The third-party plugin for math equations requires the following stylesheet.

            content_css : 'eqed/mathquill.css'

The groups plugin requires that we add the following, to prevent resizing of
group boundary images.

            object_resizing : ':not(img.grouper)'

We then install two toolbars, with separators indicated by pipes (`|`).

            toolbar : [
                'newfile openfile savefile managefiles | print
                    | undo redo | cut copy paste
                    | alignleft aligncenter alignright alignjustify
                    | bullist numlist outdent indent blockquote | table'
                'fontselect styleselect | bold italic underline
                    textcolor subscript superscript removeformat
                    | link unlink | charmap image
                    | spellchecker searchreplace | equationeditor | ' + \
                    groupTypeNames.join ' '
            ]

We then customize the menus' contents as follows.

            menu :
                file :
                    title : 'File'
                    items : 'newfile openfile | savefile saveas
                           | managefiles | print'
                edit :
                    title : 'Edit'
                    items : 'undo redo
                           | cut copy paste pastetext
                           | selectall'
                insert :
                    title : 'Insert'
                    items : 'link media
                           | template hr
                           | me'
                view :
                    title : 'View'
                    items : 'visualaid hideshowgroups'
                format :
                    title : 'Format'
                    items : 'bold italic underline
                             strikethrough superscript subscript
                           | formats | removeformat'
                table :
                    title : 'Table'
                    items : 'inserttable tableprops deletetable
                           | cell row column'
                help :
                    title : 'Help'
                    items : 'about website'

Then we customize the context menu.

            contextmenu : 'link image inserttable
                | cell row column deletetable'

And finally, we include in the editor's initialization the data needed by
the Groups plugin, so that it can find it when that plugin is initialized.

            groupTypes : groupTypes

Each editor created will have the following `setup` function called on it.
In our case, there will be only one, but this is how TinyMCE installs setup
functions, regardless.

            setup : ( editor ) ->

Add a Help menu.

                editor.addMenuItem 'about',
                    text : 'About...'
                    context : 'help'
                    onclick : -> alert window.helpAboutText
                editor.addMenuItem 'website',
                    text : 'Lurch website'
                    context : 'help'
                    onclick : -> window.open 'http://www.lurchmath.org',
                        '_blank'

Install our DOM utilities in the TinyMCE's iframe's window instance.
Increase the default font size and maximize the editor to fill the page.
This requires not only invoking the "mceFullScreen" command, but also then
setting the height properties of many pieces of the DOM hierarchy (in a way
that seems like it ought to be handled for us by the fullScreen plugin).

                editor.on 'init', ->
                    installDOMUtilitiesIn editor.getWin()
                    for own key, value of window.defaultEditorStyles
                        editor.getBody().style[key] = value
                    setTimeout ->
                        editor.execCommand 'mceFullScreen'
                        walk = editor.iframeElement
                        while walk and walk isnt editor.container
                            if walk is editor.iframeElement.parentNode
                                walk.style.height = 'auto'
                            else
                                walk.style.height = '100%'
                            walk = walk.parentNode
                        for h in editor.getDoc().getElementsByTagName 'html'
                            h.style.height = 'auto'
                    , 0

Add an icon to the left of the File menu, if one has been specified.

                    if window.menuBarIcon?.src?
                        filemenu = ( editor.getContainer()
                            .getElementsByClassName 'mce-menubtn' )[0]
                        icon = document.createElement 'img'
                        icon.setAttribute 'src', window.menuBarIcon.src
                        icon.style.width = window.menuBarIcon.width
                        icon.style.height = window.menuBarIcon.height
                        icon.style.padding = window.menuBarIcon.padding
                        filemenu.insertBefore icon, filemenu.childNodes[0]

Workaround for [this bug](http://www.tinymce.com/develop/bugtracker_view.php?id=3162):

                    editor.getBody().addEventListener 'focus', ->
                        if editor.windowManager.getWindows().length isnt 0
                            editor.windowManager.close()

After the initialization function above has been run, each plugin will be
initialized.  The Groups plugin uses the following entry to know which group
types to create.



# Test Recording Loader

webLurch supports a mode in which it can record various keystrokes and
command invocations, and store them in the form of code that can be copied
and pasted into the source code for the app's unit testing suite.  This is
very handy for constructing new test cases without writing a ton of code.
It is also less prone to typographical and other small errors, since the
code is generated for you automatically.

That mode is implemented in two script files:
 * This file pops up a separate browser window that presents the
   test-recording UI.
 * That popup window uses the script
   [testrecorder.solo.litcoffee](#testrecorder.solo.litcoffee), which
   implements all that window's UI interactivity.

First, we have a function that switches the app into test-recording mode, if
and only if the query string equals "?test".  Test-recording mode uses a
popup window so that the main app window stays pristine and undisturbed, and
tests are recorded in the normal app environment.

    maybeSetupTestRecorder = ->
        if location.search is '?test'

Launch popup window.

            testwin = open './testrecorder.html', 'recording',
                "status=no, location=no, toolbar=no, menubar=no,
                left=#{window.screenX+($ window).width()},
                top=#{window.screenY}, width=400, height=600"

If the browser blocked it, notify the user.

            if not testwin
                alert 'You have asked to run webLurch in test-recording
                    mode, which requires a popup window.  Your browser has
                    blocked the popup window.  Change its settings or allow
                    this popup to use test-recording mode.'

If the browser did not block it, then it is loaded.  It loads its own
scripts for handling UI events for controls in the popup window.

Now we setup timers that (in 0.1 seconds) will install in the editor
listeners for various events that we want to record.

            installed = [ ]
            do installListeners = ->
                notSupported = ( whatYouDid ) ->
                    alert "You #{whatYouDid}, which the test recorder does
                        not yet support.  The current test has therefore
                        become corrupted, and you should reload this page
                        and start your test again.  You will need to limit
                        yourself to using only supported keys, menu items,
                        and mouse operations."
                try

If a keypress occurs for a key that can be typed (letter, number, space),
tell the test recorder window about it.  For any other type of key, tell the
user that we can't yet record it, so the test is corrupted.

                    if 'keypress' not in installed
                        tinymce.activeEditor.on 'keypress', ( event ) ->
                            letter = String.fromCharCode event.keyCode
                            if /[A-Za-z0-9 ]/.test letter
                                testwin.editorKeyPress event.keyCode,
                                    event.shiftKey, event.ctrlKey, event.altKey
                            else
                                notSupported "pressed the key with code
                                    #{event.keyCode}"
                        installed.push 'keypress'

If a keyup occurs for any key, do one of three things.  First, if it's a
letter, ignore it, because the previous case handles that better.  Second,
if it's shift/ctrl/alt/meta, ignore it.  Finally, if it's one of the special
keys we can handle (arrows, backspace, etc.), notify the test recorder about
it.  For any other type of key, tell the user that we can't yet record it,
so the test is corrupted.

                    if 'keyup' not in installed
                        tinymce.activeEditor.on 'keyup', ( event ) ->
                            letter = String.fromCharCode event.keyCode
                            if /[A-Za-z0-9 ]/.test letter then return
                            ignore = [ 16, 17, 18, 91 ] # shft,ctl,alt,meta
                            if event.keyCode in ignore then return
                            conversion =
                                8 : 'backspace'
                                13 : 'enter'
                                35 : 'end'
                                36 : 'home'
                                37 : 'left'
                                38 : 'up'
                                39 : 'right'
                                40 : 'down'
                                46 : 'delete'
                            if conversion.hasOwnProperty event.keyCode
                                testwin.editorKeyPress \
                                    conversion[event.keyCode],
                                    event.shiftKey, event.ctrlKey, event.altKey
                            else
                                notSupported "pressed the key with code
                                    #{event.keyCode}"
                        installed.push 'keyup'

Tell the test recorder about any mouse clicks in the editor.  If the user
is holding a ctrl, alt, or shift key while clicking, we cannot currently
support that, so we warn the user if they try to record such an action.

                    if 'click' not in installed
                        tinymce.activeEditor.on 'click', ( event ) ->
                            if event.shiftKey
                                notSupported "shift-clicked"
                            else if event.ctrlKey
                                notSupported "ctrl-clicked"
                            else if event.altKey
                                notSupported "alt-clicked"
                            else
                                testwin.editorMouseClick event.clientX,
                                    event.clientY
                        installed.push 'click'

Tell the test recorder about any toolbar buttons that are invoked in the
editor.

                    findAll = ( type ) ->
                        Array::slice.apply \
                            tinymce.activeEditor.theme.panel.find type
                    if 'buttons' not in installed
                        for button in findAll 'button'
                            do ( button ) ->
                                button.on 'click', ->
                                    testwin.buttonClicked \
                                        button.settings.icon
                        installed.push 'buttons'

Disable any drop-down menu, for which I am (as yet) unable to attach event
listeners.

                    object.disabled yes for object in \
                        [ findAll( 'splitbutton' )...,
                          findAll( 'listbox' )...,
                          findAll( 'menubutton' )... ]

Tell the test recording page that the main page has finished loading, and it
can show its contents.

                    testwin.enterReadyState()

If any of the above handler installations fail, the reason is probably that
the editor hasn't been initialized yet.  So just wait 0.1sec and retry.

                catch e
                    setTimeout installListeners, 100
