
# Tests for the `DOMEditAction` class

Pull in the utility functions in
[phantom-utils](phantom-utils.litcoffee.html) that make it
easier to write the tests below.  Then follow the same structure
for setting up tests as documented more thoroughly in
[the basic unit test](basic-spec.litcoffee.html).

    { phantomDescribe } = require './phantom-utils'

## DOMEditAction class

    phantomDescribe 'DOMEditAction class', './app/index.html', ->

### should exist

That is, the class should be defined in the global namespace of
the browser after loading the main app page.

        it 'should exist', ( done ) =>
            @page.evaluate ( -> DOMEditAction ),
            ( err, result ) ->
                expect( result ).toBeTruthy()
                done()

### should have "appendChild" instances

That is, we should be able to construct instances of the class with
the type "appendChild", as described [in the documentation for the
class's constructor](domeditaction.litcoffee.html#constructor).
These will have a `toAppend` member that stores the child to be
appended.

        it 'should have "appendChild" instances', ( done ) =>
            @page.evaluate ->
                div = document.getElementById '0'
                span = document.createElement 'span'
                T = new DOMEditAction 'appendChild', div, span
                result = [
                    T.tracker is DOMEditTracker.instances[0]
                    T.node
                    T.toAppend
                ]
                result
            , ( err, result ) ->
                expect( result[0] ).toBeTruthy()
                expect( result[1] ).toEqual []
                expect( result[2] ).toEqual tagName : 'SPAN'
                done()

### should have "insertBefore" instances

That is, we should be able to construct instances of the class with
the type "insertBefore", as described [in the documentation for the
class's constructor](domeditaction.litcoffee.html#constructor).
These will have a `toInsert` member that stores the child to be
inserted, as well as an integer member `insertBefore` that is the
index that the newly inserted child will have after insertion.

        it 'should have "insertBefore" instances', ( done ) =>
            @page.evaluate ->
                div = document.getElementById '0'
                span = document.createElement 'span'
                T = new DOMEditAction 'insertBefore', div, span
                result = [
                    T.tracker is DOMEditTracker.instances[0]
                    T.node
                    T.toInsert
                    T.insertBefore
                ]
            , ( err, result ) ->
                expect( result[0] ).toBeTruthy()
                expect( result[1] ).toEqual []
                expect( result[2] ).toEqual tagName : 'SPAN'
                expect( result[3] ).toEqual 1
                done()

