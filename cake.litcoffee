
# Build process definitions

This file defines the build processes in this repository.
It is imported by the `Cakefile` in this repository,
the source code of which is kept to a one-liner,
so that most of the repository can be written
in [the literate variant of CoffeeScript](
http://coffeescript.org/#literate).

We keep a set of build utilities in a separate module, which we
now load.

    build = require './buildutils'

## Easy way to build all

If you want to build and test evertything, just run `cake all`.
It simply invokes all the other tasks, defined below.

    build.task 'all', 'Build app, testapp, docs, and run tests', ->
        build.enqueue 'app', 'testapp', 'test', 'doc'

## Requirements

Verify that `npm install` has been run in this folder, then import
other modules we'll need later (which were installed by npm
install).

    build.verifyPackagesInstalled()
    { parseString } = require 'xml2js'
    fs = require 'fs'

## Constants

These constants define how the functions below perform.

    title = 'webLurch'
    srcdir = './src/'
    appdir = './app/'
    tappdir = './testapp/'
    srcout = 'weblurch.litcoffee'
    tappout = 'testapp.litcoffee'
    docdir = './doc/'
    doctmp = 'template.html'
    testdir = './test/'
    repdir = './reports/'
    mapfile = './reports/unit-test-names.json'
    mainpg = 'index.md'

## The `app` build process

    build.asyncTask 'app', 'Build the main app', ( done ) ->

Before building the app, ensure that the output folder exists.

        fs.mkdirSync appdir unless fs.existsSync appdir

Next concatenate all `.litcoffee` source files into one.

        all = ( fs.readFileSync name for name in \
            build.dir srcdir, /\.litcoffee$/ )
        fs.writeFileSync appdir+srcout, all.join( '\n\n' ), 'utf8'

Run the compile process defined in
[the build utilities module](buildutils.litcoffee.html).
This compiles, minifies, and generates source maps.

        build.compile appdir+srcout, done

## The `testapp` build process

This build process is nearly identical to that of `app`.

    build.asyncTask 'testapp', 'Build the testapp', ( done ) ->

Before building, ensure that the output folder exists.

        fs.mkdirSync tappdir unless fs.existsSync tappdir

Next concatenate all `.litcoffee` source files from the test app
directory into one.

        all = ( fs.readFileSync name for name in \
            build.dir tappdir, /\.litcoffee$/ \
            when name.indexOf( tappout ) is -1 )
        fs.writeFileSync tappdir+tappout, all.join( '\n\n' ),
            'utf8'

Run the compile process defined in
[the build utilities module](buildutils.litcoffee.html).
This compiles, minifies, and generates source maps.

        build.compile tappdir+tappout, done

## The `doc` build process

    build.task 'doc', 'Build the documentation', ->

Fetch all files in the source directory, plus this file,
plus any `.md` files in the `doc/` dir that need converting,
and the template HTML output file from the `doc/` directory.

        all = ( f for f in build.dir( '.', /\.litcoffee$/,
                                      srcdir, /\.litcoffee$/,
                                      testdir, /\.litcoffee$/,
                                      docdir, /\.md$/,
                                      tappdir, /\.litcoffee$/ ) \
            when f.indexOf( tappout ) is -1 )
        html = fs.readFileSync docdir + doctmp, 'utf8'

Build a file navigation list from those files' names.

        nav = {}
        navtxt = '<h3 align=center>Navigation</h3><br>'
        for file in all
            end = ( path = file.split '/' ).pop()
            if end is mainpg
                navtxt += "<h3><a href='#{mainpg}.html'>" +
                          "Main Page</a></h3>"
            else
                ( nav[path.join '/'] ?= [] ).push {
                    file : end, text : end }
        ( nav[appdir[...-1]] ?= [] ).push {
            file : ".#{appdir}index", text : 'index.html' }
        ( nav[tappdir[...-1]] ?= [] ).push {
            file : ".#{tappdir}index", text : 'index.html' }
        for path in ( Object.keys nav ).sort()
            navtxt += "<p>#{path || './'}</p><ul>"
            for e in nav[path]
                navtxt += "<li><a href='#{e.file}.html'>" +
                          "#{e.text}</a></li>"
            navtxt += '</ul>'

Read each source file and place its marked-down version into the
HTML template, saving it into the docs directory.

        for file in all
            end = file.split( '/' ).pop()
            beginning = end.split( '.' ).shift()
            console.log "\tCreating #{end}.html..."
            myhtml = html.replace( 'LEFT',
                                   "#{title} source code docs" )
                         .replace( 'RIGHT', navtxt )
                         .replace( 'MIDDLE', build.md2html file )
                         .replace( /<pre><code>/g,
                                   '<pre class="hljs"><code>' )
                         .replace( 'TITLE',
                                   "#{title} docs: #{beginning}" )
            fs.writeFileSync "#{docdir+end}.html", myhtml, 'utf8'

## The `test` build process

    build.asyncTask 'test', 'Run all unit tests', ( done ) ->

First remove all old reports in the test reports folder.
If we do not do this, then any deleted tests will still have their
reports lingering in the output folder forever.

        for report in fs.readdirSync repdir
            fs.unlinkSync repdir + report

Run [jasmine](http://jasmine.github.io/) on all files in the
`test/` folder, and produce output in `junitreport` format (a
bunch of XML files).

        ( require 'child_process' ).exec \
            "node node_modules/jasmine-node/lib/jasmine-node/" +
            "cli.js --junitreport --verbose --coffee " +
            "--forceexit #{testdir}",
        ( err, stdout, stderr ) ->
            console.log stdout + stderr if stdout + stderr

Now that the tests have been run, see if they created a file
mapping the unit test names to the files in which they are defined.
If so, we will use it below to create links from test results to
test definition files.

            try
                mapping = JSON.parse fs.readFileSync mapfile
            catch error
                mapping = null

Create the header for the test output page and two functions for
flagging test passes/failures with the appropriate CSS classes.

            md = '''
                 # Autogenerated test results

                 This file was autogenerated by the build system.


                 '''
            pass = '<span class="test-pass">Pass</span>'
            fail = ( x ) ->
                "<span class='test-fail'>Failure #{x}</span>"

Read those XML files and produce [Markdown](markdown) output,
all together into a single output file.

            for report in build.dir repdir, /\.xml$/i
                parseString fs.readFileSync( report ),
                ( err, result ) ->
                    for item in result.testsuites.testsuite

Create header for this test.  Use the `mapping` computed above to
create links, if possible.

                        name = item.$.name
                        md += "# #{name} (#{item.$.time} ms)"
                        if name of mapping
                            escapedName = build.escapeHeading name
                            md += " <font size=-1>" +
                                  "<a href='#{mapping[name]}" +
                                  ".html##{escapedName}'>" +
                                  "see source</a></font>"
                        md += '\n\n'

Create subheader for each case in the test.  Again, use the
`mapping` computed above to create links, if possible.

                        for c in item.testcase
                            cn = c.$.name
                            md += "### #{cn} (#{c.$.time} ms)"
                            if item.$.name of mapping
                                esc = build.escapeHeading c.$.name
                                md += " <font size=-1>" +
                                      "<a href='" +
                                      "#{mapping[item.$.name]}." +
                                      "html##{esc}'>see source" +
                                      "</a></font>"
                            md += '\n\n'

Create list item for each failure, or one single item reporting
a pass if there were no failures.

                            if c.failure
                                for f in c.failure
                                    md += " * #{fail f}\n\n"
                            else
                                md += " * #{pass}\n\n"

Create a footer for this test, summarizing its time and totals.

                        md += "Above tests run at " +
                              "#{item.$.timestamp}.  " +
                              "Tests: #{item.$.tests} - " +
                              "Errors: #{item.$.errors} - " +
                              "Failures: #{item.$.failures}\n\n"

That output file goes in the `doc/` folder for later processing
by the doc task, defined above.

            fs.writeFileSync "#{docdir}/test-results.md",
                md, 'utf8'
            done()

