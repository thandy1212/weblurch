
# Build process definitions

This file defines the build processes in this repository. It is imported by
the `Cakefile` in this repository, the source code of which is kept to a
one-liner, so that most of the repository can be written in [the literate
variant of CoffeeScript]( http://coffeescript.org/#literate).

We keep a set of build utilities in a separate module, which we now load.

    build = require './buildutils'

## Easy way to build all

If you want to build and test evertything, just run `cake all`. It simply
invokes all the other tasks, defined below.

    build.task 'all', 'Build app and run tests', ->
        build.enqueue 'app', 'test'

## Requirements

Verify that `npm install` has been run in this folder, then import other
modules we'll need later (which were installed by npm install).

    build.verifyPackagesInstalled()
    { parseString } = require 'xml2js'
    fs = require 'fs'
    exec = require( 'child_process' ).exec

## Constants

These constants define how the functions below perform.

    title = 'webLurch'
    srcdir = './src/'
    appdir = './app/'
    srcout = 'weblurch.litcoffee'
    appout = 'app.litcoffee'
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

Also compile any files specific to the main app (as opposed to the test
app), which will sit in the app folder rather than the source folder.

        all = ( fs.readFileSync name for name in \
            build.dir( appdir, /\.litcoffee$/ ) \
            when name.indexOf( srcout ) is -1 and
                 name.indexOf( appout ) is -1 )
        fs.writeFileSync appdir+appout, all.join( '\n\n' ), 'utf8'

Run the compile process defined in [the build utilities
module](buildutils.litcoffee.html). This compiles, minifies, and generates
source maps.

        build.compile appdir+srcout, ->
        build.compile appdir+appout, done

## The `test` build process

    build.asyncTask 'test', 'Run all unit tests', ( done ) ->

First remove all old reports in the test reports folder. If we do not do
this, then any deleted tests will still have their reports lingering in the
output folder forever.

        fs.mkdirSync repdir unless fs.existsSync repdir
        for report in fs.readdirSync repdir
            fs.unlinkSync repdir + report

Run [jasmine](http://jasmine.github.io/) on all files in the `test/` folder,
and produce output in `junitreport` format (a bunch of XML files).

        exec "node node_modules/jasmine-node/lib/jasmine-node/" +
             "cli.js --junitreport --verbose --coffee " +
             "--forceexit #{testdir}",
        ( err, stdout, stderr ) ->
            console.log stdout + stderr if stdout + stderr

Now that the tests have been run, see if they created a file mapping the
unit test names to the files in which they are defined. If so, we will use
it below to create links from test results to test definition files.

            try
                mapping = JSON.parse fs.readFileSync mapfile
            catch error
                mapping = null

Create the header for the test output page and two functions for flagging
test passes/failures with the appropriate CSS classes.

            md = '''
                 # Autogenerated test results

                 This file was autogenerated by the build system.


                 '''
            pass = '<span class="test-pass">Pass</span>'
            re = /^([0-9]+): Expected (.*) to equal (.*)\.$/
            fail = ( x ) ->

The following if/try block is a simple attempt at formatting object code
nicer.  It will not work in all situations, but it is nice for those
situations in which it does work.  The difficult-to-read output that comes
to the console will appear much more nicely in the web output, and the
developer can look there to help compare the unmatched objects.

                if m = re.exec x
                    try
                        obj1 = JSON.parse m[2] \
                            .replace( /'/g, '"' ) \
                            .replace( /([{,])\s*(\w+)\s*:/g,
                                '$1 "$2" :' )
                        obj2 = JSON.parse m[3] \
                            .replace( /'/g, '"' ) \
                            .replace( /([{,])\s*(\w+)\s*:/g,
                                '$1 "$2" :' )
                        x = "#{m[1]}: Expected these to be equal:
                            <br>
                            <table width=100% cellspacing=0
                                   cellpadding=0>
                            <tr><td>
                            Actual:
                            \n
                            \n```
                            \n#{JSON.stringify obj1, null, 2}
                            \n```
                            \n
                            \n</td><td>
                            Expected:
                            \n
                            \n```
                            \n#{JSON.stringify obj2, null, 2}
                            \n```
                            \n</td></tr></table>"
                "<span class='test-fail'>Failure #{x}</span>"

Read those XML files and produce [Markdown](markdown) output, all together
into a single output file.

            for report in build.dir repdir, /\.xml$/i
                parseString fs.readFileSync( report ),
                ( err, result ) ->
                    for item in result.testsuites.testsuite

Create header for this test and a subheader for each case within it.

                        name = item.$.name
                        md += "## #{name} (#{item.$.time} ms)\n\n"
                        for c in item.testcase
                            cn = c.$.name
                            md += "### #{cn} (#{c.$.time} ms)\n\n"

Create list item for each failure, or one single item reporting a pass if
there were no failures.

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

That output file goes in the `doc/` folder for later processing by the doc
task, defined above.

            fs.writeFileSync "#{testdir}/test-results.md",
                md, 'utf8'
            done()

## The `pages` build process

After changes are made to the master branch of this repository in git, we
eventually want to propagate them to the gh-pages branch, because that
branch is the one that github uses as the basis for the project web pages
(hence the name, short for "github pages"). Usually you should do this
before pushing commits to github, so that the website on github reflects the
latest state of the repository.

This build task switches to the gh-pages branch, merges in all changes from
master, re-runs all other build tasks, commits the resulting documentation
changes, and switches branches back to master.  It's just what you should
run before pushing to github.

It's an asynchronous task because it uses `exec`.  We begin with switching
to gh-pages and merging in changes.

    build.asyncTask 'pages',
    'Update gh-pages branch before pushing', ( done ) ->
        console.log '''
            In case any step of this lengthy process goes wrong,
            here are the commands that are about to be run, so
            that you can complete the process:
                git checkout gh-pages
                git merge master
                cake app
                git commit -a -m 'Updating gh-pages with latest app build'
                git checkout master
            '''.yellow
        runShellCommands [
            {
                description : 'Switching to gh-pages branch...'.green
                command : 'git checkout gh-pages'
            }
            {
                description : 'Merging in changes...'.green
                command : 'git merge master'
            }
        ], ->
            console.log 'Building app in gh-pages...'.green
            build.enqueue 'app', ->
                runShellCommands [
                    {
                        description : 'Committing changes... (which may fail
                            if there were no changes to tha app itself; in
                            that case, just git checkout master and push.)'
                            .green
                        command : "git commit -a -m 'Updating gh-pages with
                            latest generated docs'"
                    }
                    {
                        description : 'Going back to master...'.green
                        command : 'git checkout master'
                    }
                ], ->
                    console.log 'Done.'.green
                    console.log '''
                    If you're happy with the results of this process, just \
                    type "git push" to publish them.
                    '''

We report that we're done with this task once we enqueue those things, so
that the build system will then start processing what we put on the queue.

            done()
