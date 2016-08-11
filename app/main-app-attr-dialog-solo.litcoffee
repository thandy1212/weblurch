
# Main webLurch Application

## Modular organization

This file is one of several files that make up the main webLurch
Application.  For more information on the app and the other files, see
[the first source code file in this set](main-app-basics-solo.litcoffee).

## Attributes dialog

This module creates the functions related to the attributes dialog for an
expression in the document.  That dialog is a large and complex piece of the
UI, so it deserves to have its code grouped into a single file, this one.

## Utilities

The following routine converts any canonical form into a reasonable HTML
representation of the expression, but which is not intended for insertion
into a live document.  (It is superficial only, not containing any embedded
data.)

    canonicalFormToHTML = ( form ) ->
        type = tinymce.activeEditor.Groups.groupTypes.expression
        inside = if form.type is 'st' then form.value else \
            ( canonicalFormToHTML child for child in form.children ).join ''
        type.openImageHTML + inside + type.closeImageHTML

## The dialog action

The following function creates an on-click handler for a given group.  That
is, you call this function on a group, and it returns a function that can be
used as the on-click handler for the "Attributes..." item of the context
menu for that group.

    window.attributesActionForGroup = ( group ) ->
        reload = ->
            tinymce.activeEditor.windowManager.close()
            showDialog()
        showDialog = ->
            summary = "<p>Expression:
                #{canonicalFormToHTML group.canonicalForm()}</p>
                <table border=0 cellpadding=5 cellspacing=0 width=100%>"

Create a table listing all attributes, both external and internal.  The code
here follows a similar pattern to that in `Group::completeForm`, defined in
[another file](main-app-group-class-solo.litcoffee).

            addRow = ( key, value = '', type = '', links = '' ) ->
                summary += "<tr><td width=33% align=left>#{key}</td>
                                <td width=33% align=left>#{value}</td>
                                <td width=24% align=right>#{type}</td>
                                <td width=10% align=right>#{links}</td>
                            </tr>"
            addRule = -> summary += "<tr><td colspan=4><hr></td></tr>"
            prepare = { }
            for attribute in group.attributeGroups()
                key = attribute.get 'key'
                ( prepare[key] ?= [ ] ).push attribute
            for key in group.keys()
                if decoded = OM.decodeIdentifier key
                    prepare[decoded] ?= [ ]

The following utility functions make it easy to encode any JSON data as the
ID of a hyperlink, button, or text input, and to decode the ID as well.
This way we can tag a link/button/etc. in the dialog with any data we like,
and it will be handed to us (for decoding) in our event handler for the
on-click event of the link.

            encodeId = ( json ) -> OM.encodeAsIdentifier JSON.stringify json
            decodeId = ( href ) -> JSON.parse OM.decodeIdentifier href
            encodeLink = ( text, json, style = yes, hover ) ->
                style = if style then '' else \
                    'style="text-decoration: none; color: black;" '
                hover = if hover then " title='#{hover}'" else ''
                "<a href='#' id='#{encodeId json}' #{style} #{hover}
                  >#{text}</a>"
            encodeButton = ( text, json ) ->
                "<input type='button' id='#{encodeId json}'
                        value='#{text}'/>"
            encodeTextInput = ( text, json ) ->
                "<input type='text' id='#{encodeId json}' value='#{text}'/>"

This code, too, imitates that of `Group::completeForm`.

            firstTime = yes
            for key, list of prepare
                if not firstTime then addRule()
                if embedded = group.get OM.encodeAsIdentifier key
                    list.push group
                strictGroupComparator = ( a, b ) ->
                    strictNodeComparator a.open, b.open
                showKey = key + ' ' +
                    encodeLink '&#x1f589;', [ 'edit key', key ], no,
                        'Edit attribute key'
                for attr in list.sort strictGroupComparator
                    if attr is group
                        expression = OM.decode embedded.m
                        if expression.type is 'a' and \
                           expression.children[0].equals \
                                Group::listSymbol
                            for meaning, index in expression.children[1..]
                                addRow showKey,
                                    canonicalFormToHTML( meaning ),
                                    'hidden ' + encodeLink( '&#x1f441;',
                                        [ 'show', key ], no,
                                        'Show attribute' ),
                                    encodeLink( '&#10007;',
                                        [ 'remove from internal list',
                                            key, index ], no,
                                        'Remove attribute' )
                                showKey = ''
                        else
                            addRow showKey,
                                canonicalFormToHTML( expression ),
                                'hidden ' + encodeLink( '&#x1f441;',
                                    [ 'show', key ], no, 'Show attribute' ),
                                encodeLink( '&#10007;',
                                    [ 'remove internal solo', key ], no,
                                    'Remove attribute' )
                            showKey = ''
                    else
                        addRow showKey,
                            canonicalFormToHTML( attr.canonicalForm() ),
                            'visible ' + encodeLink( '&#x1f441;',
                                [ 'hide', key ], no, 'Hide attribute' ),
                            encodeLink( '&#10007;',
                                [ 'remove external', attr.id() ], no,
                                'Remove attribute' )
                        showKey = ''
                firstTime = no
            summary += '</table>'
            if Object.keys( prepare ).length is 0
                summary += '<p>The expression has no attributes.</p>'

Show the dialog, and listen for any links that were clicked.

            tinymce.activeEditor.Dialogs.alert
                title : 'Attributes'
                message : summary
                onclick : ( data ) ->
                    try [ type, key, index ] = decodeId data.id

They may have clicked "Remove" on an embedded attribute that's just one
entry in an entire embedded list.  In that case, we need to decode the list
(both its meaning and its visuals), and remove the specified entries.  We
then put the data right back into the group from which we extracted it.

The `reload()` function just closes and re-opens this same dialog.  There
will be a brief flicker, but then its content will be up-to-date.  We can
try to remove that flicker some time in the future, or come up with a
slicker way to reload the dialog's content.

                    if type is 'remove from internal list'
                        internalKey = OM.encodeAsIdentifier key
                        internalValue = group.get internalKey
                        meaning = OM.decode internalValue.m
                        meaning = OM.app meaning.children[0],
                            meaning.children[1...index+1]...,
                            meaning.children[index+2...]...
                        visuals = decompressWrapper internalValue.v
                        visuals = visuals.split '\n'
                        visuals.splice index, 1
                        visuals = visuals.join '\n'
                        internalValue =
                            m : meaning.encode()
                            v : compressWrapper visuals
                        group.plugin.editor.undoManager.transact ->
                            group.set internalKey, internalValue
                        reload()

They may have clicked "Remove" on an embedded attribute that's not part of
a list.  This case is easier; we simply remove the entire attribute and
reload the dialog.

                    else if type is 'remove internal solo'
                        group.plugin.editor.undoManager.transact ->
                            group.clear OM.encodeAsIdentifier key
                        reload()

They may have clicked "Remove" on a non-embedded attribute.  This case is
also easy; we simply disconnect the attribute from the attributed group.
As usual, we then reload the dialog.

                    else if type is 'remove external'
                        group.plugin.editor.undoManager.transact ->
                            tinymce.activeEditor.Groups[key].disconnect \
                                group
                        reload()

If they clicked "Show" on any hidden attribute, we unembed it, then reload
the dialog.

                    else if type is 'show'
                        group.unembedAttribute key
                        reload()

If they clicked "Hide" on any visible attribute, we embed it, then reload
the dialog.

                    else if type is 'hide'
                        group.embedAttribute key
                        reload()

If they asked to change the text of a key, then prompt for a new key.  Check
to be sure the key they entered is valid, and if so, in one single undo/redo
transaction, change the keys of all external and internal attributes that
had the old key, to have the new key instead.  If it is invalid, tell the
user why.

                    else if type is 'edit key'
                        tinymce.activeEditor.Dialogs.prompt
                            title : 'Enter new key'
                            message : "Change \"#{key}\" to what?"
                            okCallback : ( newKey ) ->
                                if not /^[a-zA-Z0-9-_]+$/.test newKey
                                    tinymce.activeEditor.Dialogs.alert
                                        title : 'Invalid key'
                                        message : 'Keys can only contain
                                            Roman letters, decimal digits,
                                            hyphens, and underscores (no
                                            spaces or other punctuation).'
                                        width : 300
                                        height : 200
                                    return
                                if group.attributeGroupsForKey( newKey ) \
                                   .length > 0
                                    tinymce.activeEditor.Dialogs.alert
                                        title : 'Invalid key'
                                        message : 'That key is already in
                                            use by a different attribute.'
                                        width : 300
                                        height : 200
                                    return
                                tinymce.activeEditor.undoManager.transact ->
                                    attrs = group.attributeGroupsForKey key
                                    for attr in attrs
                                        attr.set 'key', newKey
                                    encKey = OM.encodeAsIdentifier key
                                    encNew = OM.encodeAsIdentifier newKey
                                    tmp = group.get encKey
                                    group.clear encKey
                                    group.set encNew, tmp
                                    reload()
