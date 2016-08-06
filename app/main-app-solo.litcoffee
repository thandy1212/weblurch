
# Main webLurch Application

## Overview

webLurch is first a word processor whose UI lets users group/bubble sections
of their document, with the intent that those sections can be handled
semantically.  Second, it is also a particular use of that foundation, for
checking students' proofs.  [Read more about that dichotomy
here.](../README.md)

This file is the beginning of that main webLurch application, but it is not
yet complete.  The only complete implementation at present is [the desktop
version](http://lurchmath.org).

This file is loaded by [app.html](app.html), which is almost entirely
boilerplate code (as commented in its source), plus one line that imports
the compiled version of this file.

You can [see a live version of the resulting application online now](
http://nathancarter.github.io/weblurch/app/app.html).

## App Configuration

For details of what each line of code below does, see the documentation for
[demo apps and a developer tutorial](../doc/tutorial.md).

Set the application name, to appear in page title.

    setAppName 'Lurch'

Install the icon that appears to the left of the File menu.

    window.menuBarIcon =
        src : 'icons/apple-touch-icon-76x76.png'
        width : '26px'
        height : '26px'
        padding : '2px'

This application needs just one group type for now, but it will need more
later as this application becomes mature.

    window.groupTypes = [
        name : 'expression'
        text : 'Expression'
        imageHTML : '<font color="#996666">[ ]</font>'
        openImageHTML : '<font color="#996666">[</font>'
        closeImageHTML : '<font color="#996666">]</font>'
        tooltip : 'Make the selected text an expression'
        color : '#996666'
        shortcut : 'Ctrl+['
        LaTeXshortcut : '\\['

You can form a connection from any expression to any other, provided that no
cycle of connections is formed in the process.  Thus we write the
`reachable` function to test whether its first argument can (through zero or
more steps through connections) reach its second argument.

        connectionRequest : ( from, to ) ->
            reachable = ( source, target ) ->
                if source is target then return yes
                for c in source.connectionsOut()
                    next = tinymce.activeEditor.Groups[c[1]]
                    if reachable next, target then return yes
                no
            if reachable to, from
                alert 'Forming that connection would create a cycle,
                    which is not permitted.'
            else
                tinymce.activeEditor.undoManager.transact ->
                    from.connect to
                    if not from.get 'key' then from.set 'key', 'label'
                    if not from.get 'keyPosition'
                        from.set 'keyPosition', 'arrow'

When drawing expressions, draw all arrows that come in or go out.  (The
default is to only draw arrows that go out; we override that here, so that
an expression highlights both its attributes and those things for which it
is an attribute.)

        connections : ( group ) ->
            outs = group.connectionsOut()
            ins = group.connectionsIn()
            for cxn in [ ins..., outs... ]
                source = tinymce.activeEditor.Groups[cxn[0]]
                if source.get( 'keyPosition' ) is 'arrow'
                    cxn[2] = source.get 'key'
                if source.get( 'key' ) is 'premise'
                    cxn[3] = ( context ) -> context.setLineDash [ 3, 3 ]
            [ outs..., ins...,
              ( t[1] for t in outs )..., ( t[0] for t in ins )... ]

An expression used as an attribute, with the key stored in the attribute
itself, will show that key on its bubble tag.

        tagContents : ( group ) ->
            if group.get( 'keyPosition' ) is 'source'
                group.get 'key'
            else
                null

In the case where the tag shows the key, as in the code immediately above,
the tag menu should let the user move the tag out onto the arrow instead.

        tagMenuItems : ( group ) ->
            result = [ ]
            if group.get( 'keyPosition' ) is 'source'
                result.push
                    text : "Move \"#{group.get 'key'}\" onto arrow"
                    onclick : ->
                        tinymce.activeEditor.undoManager.transact ->
                            group.set 'keyPosition', 'arrow'
            result

However, when the attribute key is already shown on the arrow, the
expression should have a context menu item for moving it back.

        contextMenuItems : ( group ) ->
            result = [ ]
            if group.get( 'keyPosition' ) is 'arrow'
                result.push
                    text : "Move \"#{group.get 'key'}\" onto attribute"
                    onclick : ->
                        tinymce.activeEditor.undoManager.transact ->
                            group.set 'keyPosition', 'source'

The context menu should also contain a submenu for changing the key to any
of several common choices, or "Other..." which lets the user input any text
key they choose.

            result.push
                text : 'Change attribute key to...'
                menu : [
                    text : 'Label'
                    onclick : ->
                        tinymce.activeEditor.undoManager.transact ->
                            group.set 'key', 'label'
                ,
                    text : 'Reason'
                    onclick : ->
                        tinymce.activeEditor.undoManager.transact ->
                            group.set 'key', 'reason'
                ,
                    text : 'Premise'
                    onclick : ->
                        tinymce.activeEditor.undoManager.transact ->
                            group.set 'key', 'premise'
                ,
                    text : 'Other...'
                    onclick : ->
                        newKey = prompt 'Choose a new key:', group.get 'key'
                        if newKey
                            tinymce.activeEditor.undoManager.transact ->
                                group.set 'key', newKey
                ]
            result

    ]

In this app, groups have a special attribute called "canonical form," which
we want to be able to compute conveniently for all groups.  So we extend the
Group class itself.

The canonical form of an atomic group (one with no children) is the text
content of the group, which we encode as an OpenMath string.  The canonical
form of a non-atomic group is just the array of children of the group, which
we encode as an OpenMath application with the children in the same order.

    window.Group.prototype.canonicalForm = ->
        if @children.length is 0
            OM.str @contentAsText()
        else
            OM.app ( child.canonicalForm() for child in @children )...

Groups can also compute the list of attributes attached to them, returning
it as an array.  We provide the following extension to the Group class to
accomplish this.

    window.Group.prototype.attributeGroups = ( includePremises = no ) ->
        result = [ ]
        for connection in @connectionsIn()
            source = tinymce.activeEditor.Groups[connection[0]]
            if key = source.get 'key'
                if not includePremises and key is 'premise' then continue
                result.push source
        result

The following function is like the transitive closure of the previous; it
gives all groups that directly or indirectly attribute this group.

    window.Group.prototype.attributionAncestry = ( includePremises = no ) ->
        result = [ ]
        for group in @attributeGroups includePremises
            for otherGroup in [ group, group.attributionAncestry()... ]
                if otherGroup not in result then result.push otherGroup
        result

Leveraging the idea of a list of groups that attribute a given group, we can
implement the notion of "complete form."  This is the same as canonical
form, except that all attributes of the encoded group are also encoded,
using OpenMath attributions.  The keys are encoded as symbols using their
own names, and "Lurch" as the content dictionary.

    window.Group.prototype.completeForm = ( includePremises = no ) ->
        result = @canonicalForm()
        prepare = { }
        for group in @attributeGroups includePremises
            key = group.get 'key'
            ( prepare[key] ?= [ ] ).push group
        for key, list of prepare
            list = ( group.completeForm includePremises \
                for group in list.sort strictNodeComparator )
            result = OM.att result, OM.sym( key, 'Lurch' ),
                if list.length is 1
                    list[0]
                else
                    OM.app OM.sym( 'List', 'Lurch' ), list...
        result

Now we add a member function to the group class for embedding in an
expression an attribute expression, including its entire attribution
ancestry.

    window.Group.prototype.embedAttribute = ( key ) ->

For now, we support only the case where there is exactly one attribute
expression with the given key.

        groups = ( g for g in @attributeGroups() \
            when g.get( 'key' ) is key )
        if groups.length isnt 1 then return

The key to use inside this group is the expression key, encoded so that it
can function as an OpenMath identifier.  The value to use will have two
fields, the first ("m" for meaning) will be the complete form of the
attribute to embed.

        internalKey = OM.encodeAsIdentifier key
        internalValue = m : g.completeForm()

The second ("v" for visual) will be its representation in HTML form, for
later extraction back into the document if the user so chooses.  Before
computing that HTML representation, we disconnect the attribute from this
group.

        groups[0].disconnect this
        ancestry = groups[0].attributionAncestry()
        ancestry.sort strictNodeComparator
        internalValue.v =
            ( g.groupAsHTML() for g in [ groups[0], ancestry... ] ).join ''

Embed the data, then remove the attribute expression from the document.
Then delete every expression in the attribution ancestry iff it's not also
attributing another node outside the attribution ancestry.  Do all of this
in a single undo/redo transaction.

        groups[0].plugin.editor.undoManager.transact =>
            this.set internalKey, internalValue
            groups[0].remove()
            ancestorIds = [
                groups[0].id()
                ( a.id() for a in ancestry )...
            ]
            for ancestor in ancestry
                hasConnectionToNonAncestor = no
                for connection in ancestor.connectionsOut()
                    if connection[1] not in ancestorIds
                        hasConnectionToNonAncestor = yes
                        break
                ancestor.remove() unless hasConnectionToNonAncestor

Install the arrows UI for that group.

    window.useGroupConnectionsUI = yes

Use the MediaWiki, Settings, Dialogs, and Dropbox plugins.

    window.pluginsToLoad = [ 'mediawiki', 'settings', 'dialogs', 'dropbox' ]

Add several menu items:

    window.groupMenuItems =
        file_order : 'sharelink wikiimport wikiexport
                    | appsettings docsettings'

Sharing files with permalinks (shortened via goo.gl):

        sharelink :
            text : 'Share document...'
            context : 'file'
            onclick : ->
                page = window.location.href.split( '?' )[0]
                content = embedMetadata tinymce.activeEditor.getContent(),
                    tinymce.activeEditor.LoadSave.saveMetaData()
                url = page + '?document=' + encodeURIComponent content
                showURL = ( url ) ->
                    embed = "<iframe src='#{url}' width=800
                        height=600></iframe>"
                        .replace /&/g, '&amp;'
                        .replace /'/g, '&apos;'
                        .replace /"/g, '&quot;'
                        .replace /</g, '&lt;'
                        .replace />/g, '&gt;'
                    console.log embed
                    tinymce.activeEditor.Dialogs.alert
                        title : 'Permanent Sharing Links'
                        message : "
                            <h3>Sharing URL</h3>
                            <p>Copy this URL to your clipboard, and
                            paste wherever you like, such as email.</p>
                            <input type='text' size=50 id='firstURL'
                             value='#{url}'/>
                            <h3>Embedding HTML</h3>
                            <p>Copy this HTML to your clipboard, and paste
                            into any webpage or blog to embed a Lurch
                            instance with this document in it.</p>
                            <input type='text' size=50 value='#{embed}'/>
                            <script>
                            var all = document.getElementsByTagName(
                                'input' );
                            for ( var i = 0 ; i < all.length ; i++ ) {
                                all[i].addEventListener( 'focus',
                                    function ( event ) {
                                        var t = event.target;
                                        if ( t.select ) t.select();
                                        else t.setSelectionRange(
                                            0, t.value.length );
                                    } );
                            }
                            document.getElementById( 'firstURL' ).focus();
                            </script>"
                request = gapi?.client?.urlshortener?.url?.insert? \
                    resource : longUrl : url
                if not request? then return showURL url
                request.execute ( response ) ->
                    if response.id?
                        showURL response.id
                    else
                        showURL url

Importing from a wiki on the same server, and exporting to it as well:

        wikiimport :
            text : 'Import from wiki...'
            context : 'file'
            onclick : ->
                if appIsRunningOnGitHub() then return
                pageName = prompt 'Give the name of the page to import (case
                    sensitive)', 'Main Page'
                if pageName is null then return
                tinymce.activeEditor.MediaWiki.importPage pageName,
                    ( document, metadata ) ->
                        if metadata?
                            tinymce.activeEditor.Settings.document \
                                .metadata = metadata
        wikiexport :
            text : 'Export to wiki'
            context : 'file'
            onclick : ->
                if appIsRunningOnGitHub() then return
                pageName = tinymce.activeEditor.Settings.document.get \
                    'wiki_title'
                if not pageName?
                    tinymce.activeEditor.Dialogs.alert
                        title : 'Page Title not set'
                        message : '<p>You have not yet set the title under
                            which this document should be published on the
                            wiki.  See the document settings on the File
                            menu.</p>'
                    return
                username = tinymce.activeEditor.Settings.application.get \
                    'wiki_username'
                password = tinymce.activeEditor.Settings.application.get \
                    'wiki_password'
                if not username? or not password?
                    tinymce.activeEditor.Dialogs.alert
                        title : 'No Wiki Credentials'
                        message : '<p>You have not given your wiki username
                            and password to the application settings.  See
                            the application settings on the File menu.</p>'
                    return
                postCallback = ( result, error ) ->
                    if error
                        tinymce.activeEditor.Dialogs.alert
                            title : 'Posting Error'
                            message : "<p>Error when posting to the
                                wiki:</p>
                                <p>#{error}</p>"
                        return
                    match = /^[^/]+\/\/[^/]+\//.exec window.location.href
                    url = window.location.href[...match[0].length] + \
                        'wiki/index.php?title=' + \
                        encodeURIComponent pageName
                    tinymce.activeEditor.Dialogs.alert
                        title : 'Document Posted'
                        message : "<p>Posting succeeded.</p>
                            <p><a href='#{url}' target='_blank'>Visit posted
                            page.</a></p>"
                loginCallback = ( result, error ) ->
                    if error
                        tinymce.activeEditor.Dialogs.alert
                            title : 'Wiki Login Error'
                            message : "<p>Error when logging into the
                                wiki:</p>
                                <p>#{error}</p>"
                        return
                    content = tinymce.activeEditor.MediaWiki.embedMetadata \
                        tinymce.activeEditor.getContent(),
                        tinymce.activeEditor.Settings.document.metadata
                    tinymce.activeEditor.MediaWiki.exportPage pageName,
                        content, postCallback
                tinymce.activeEditor.MediaWiki.login username, password,
                    loginCallback

App-level and document-level settings dialogs:

        appsettings :
            text : 'Application settings...'
            context : 'file'
            onclick : -> tinymce.activeEditor.Settings.application.showUI()
        docsettings :
            text : 'Document settings...'
            context : 'file'
            onclick : -> tinymce.activeEditor.Settings.document.showUI()

Set up the Google API key for URL shortening.

    window.addEventListener 'load', ->
        gapi?.client?.setApiKey 'AIzaSyAf7F0I39DdI2jtD7zrPUa4eQvUXZ-K6W8'
        gapi?.client?.load 'urlshortener', 'v1', ->
    , no

Lastly, a few actions to take after the editor has been initialized.

    window.afterEditorReady = ( editor ) ->

Initialize the settings plugin for global app settings.

        A = editor.Settings.addCategory 'application'
        if not A.get 'filesystem' then A.set 'filesystem', 'dropbox'
        A.setup = ( div ) ->
            fs = A.get 'filesystem'
            div.innerHTML = [
                editor.Settings.UI.heading 'Wiki Login'
                editor.Settings.UI.info 'Entering a username and password
                    here does NOT create an account on the wiki.  You must
                    already have one.  If you do not, first visit
                    <a href="/wiki/index.php" target="_blank"
                       style="color: blue;">the wiki</a>,
                    create an account, then return here.'
                editor.Settings.UI.text 'Username',
                    'wiki_username', A.get( 'wiki_username' ) ? ''
                editor.Settings.UI.password 'Password',
                    'wiki_password', A.get( 'wiki_password' ) ? ''
                editor.Settings.UI.heading 'Open/Save Filesystem'
                editor.Settings.UI.radioButton \
                    'Dropbox (cloud storage, requires account)',
                    'filesystem', fs is 'dropbox', 'filesystem_dropbox'
                editor.Settings.UI.radioButton \
                    'Local Storage (kept permanently, in browser only)',
                    'filesystem', fs is 'local storage',
                    'filesystem_local_storage'
            ].join '\n'
        A.teardown = ( div ) ->
            elt = ( id ) -> div.ownerDocument.getElementById id
            A.set 'wiki_username', elt( 'wiki_username' ).value
            A.set 'wiki_password', elt( 'wiki_password' ).value
            A.setFilesystem if elt( 'filesystem_dropbox' ).checked then \
                'dropbox' else 'local storage'

Install in `A` a special handler for setting the filesytem, which updates UI
controls to respect that setting.

        A.setFilesystem = ( name ) ->
            A.set 'filesystem', name
            if name is 'dropbox'
                editor.LoadSave.installOpenHandler \
                    editor.Dropbox.openHandler
                editor.LoadSave.installSaveHandler \
                    editor.Dropbox.saveHandler
                editor.LoadSave.installManageFilesHandler \
                    editor.Dropbox.manageFilesHandler
            else
                editor.LoadSave.installOpenHandler()
                editor.LoadSave.installSaveHandler()
                editor.LoadSave.installManageFilesHandler()

Initialize the UI to whatever the user's current filesystem setting is.

        A.setFilesystem A.get 'filesystem'

Initialize the settings plugin for per-document settings.  Here we override
the default set/get methods (which use the browser's `LocalStorage`) and use
a metadata object that gets embedded in the document itself.

        D = editor.Settings.addCategory 'document'
        D.metadata = { }
        D.get = ( key ) -> D.metadata[key]
        D.set = ( key, value ) -> D.metadata[key] = value
        D.setup = ( div ) ->
            div.innerHTML = [
                editor.Settings.UI.heading 'Dependencies'
                "<div id='dependenciesSection'></div>"
                editor.Settings.UI.heading 'Wiki Publishing'
                editor.Settings.UI.text 'Publish to wiki under this title',
                    'wiki_title', D.get( 'wiki_title' ) ? ''
            ].join '\n'
            editor.Dependencies.installUI \
                div.ownerDocument.getElementById 'dependenciesSection'
        D.teardown = ( div ) ->
            elt = ( id ) -> div.ownerDocument.getElementById id
            D.set 'wiki_title', elt( 'wiki_title' ).value

Set up the load/save plugin with the functions needed for loading and saving
document metadata.

        editor.LoadSave.saveMetaData = ->
            # later, when this app knows what data it wants to export to
            # documents that depend on it, do so here, with a line like
            # D.metadata.exports = [ "some", "JSON", "here" ]
            D.metadata.dependencies = editor.Dependencies.export()
            D.metadata
        editor.LoadSave.loadMetaData = ( object ) ->
            D.metadata = object
            editor.Dependencies.import D.metadata.dependencies ? [ ]

If the query string told us to load a page from the wiki, or a page fully
embedded in a (possibly enormous) URL, do so.  Note that the way we handle
the enormous URLs is by storing them in the browser's `localStorage`, then
reloading the page without the query string, and then pulling the data from
`localStorage`.

        editor.MediaWiki.setIndexPage '/wiki/index.php'
        editor.MediaWiki.setAPIPage '/wiki/api.php'
        if match = /\?wikipage=(.*)/.exec window.location.search
            editor.MediaWiki.importPage decodeURIComponent match[1],
                ( document, metadata ) ->
                    if metadata? then editor.LoadSave.loadMetaData metadata
        if toAutoLoad = localStorage.getItem 'auto-load'
            try
                [ metadata, document ] = JSON.parse toAutoLoad
                setTimeout ->
                    localStorage.removeItem 'auto-load'
                    tinymce.activeEditor.setContent document
                    editor.LoadSave.loadMetaData metadata
                , 100
        if match = /\?document=(.*)/.exec window.location.search
            html = decodeURIComponent match[1]
            { metadata, document } = extractMetadata html
            localStorage.setItem 'auto-load',
                JSON.stringify [ metadata, document ]
            window.location.href = window.location.href.split( '?' )[0]

The following function is just to ensure that functionality that depends on
a wiki installation doesn't break when the app is served from GitHub.
Instead of breaking, the app will clearly state that...well, you can read
the message below for yourself.

    appIsRunningOnGitHub = ->
        result = /nathancarter\.github\.io/.test window.location.href
        if result
            tinymce.activeEditor.Dialogs.alert
                title : 'Not Available Here'
                message : '<p>That functionality requires MediaWiki to be
                    running on the server from which you\'re accessing this
                    web app.</p>
                    <p>On GitHub, we cannot run a MediaWiki server, so the
                    functionality is disabled.</p>
                    <p>The menu items remain for use in developer testing,
                    as we prepare for a dedicated server that will have
                    MediaWiki and the ability to publish documents to that
                    wiki with a single click, or edit them in Lurch with a
                    single click.</p>
                    <p>Try back soon!</p>'
        result
