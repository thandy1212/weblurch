
# Tests of the Parsing module

Here we import the module we're about to test.

    { Grammar, Tokenizer } = require '../src/parsing.duo'
    { OM, OMNode } = require '../src/openmath.duo'
    full = ( x ) -> require( 'util' ).inspect x, depth : null

## The Grammar class

This section tests just the existence of the main class (Grammar).

    describe 'Grammar and Tokenizer classes', ->

### should be defined

        it 'should be defined', ->
            expect( Grammar ).toBeTruthy()
            expect( Tokenizer ).toBeTruthy()

## A simple grammar

This section defines a very simple grammer for sums and products of
integers, then verifies that it can be applied to parse expressions in that
language.

    describe 'A simple grammar', ->

Define the grammar here.  D is for digit, I for (nonnegative) integer, M for
multiplication expression, and S for summation expression.

        G = null
        beforeEach ->
            G = new Grammar 'S'
            G.addRule 'D', /[0-9]/
            G.addRule 'I', 'D', 'I D'
            G.addRule 'M', 'I', [ 'M', /\*/, 'I' ]
            G.addRule 'S', 'M', [ 'S', /\+/, 'M' ]

### should parse nonnegative integers

The grammar should correctly parse nonnegative integers.

        it 'should parse nonnegative integers', ->
            expect( G.parse '5' ).toEqual \
                [ [ 'S', [ 'M', [ 'I', [ 'D', '5' ] ] ] ] ]
            expect( G.parse '19' ).toEqual \
                [ [ 'S', [ 'M', [ 'I', [ 'I', [ 'D', '1' ] ],
                                       [ 'D', '9' ] ] ] ] ]
            G.setOption 'addCategories', no
            G.setOption 'collapseBranches', yes
            expect( G.parse '5' ).toEqual [ '5' ]
            expect( G.parse '19' ).toEqual [ [ '1', '9' ] ]

### should parse products of nonnegative integers

The grammar should correctly parse products of nonnegative integers.

        it 'should parse products of nonnegative integers', ->
            expect( G.parse '7*5' ).toEqual \
                [ [ 'S', [ 'M', [ 'M', [ 'I', [ 'D', '7' ] ] ], '*',
                                [ 'I', [ 'D', '5' ] ] ] ] ]
            G.setOption 'addCategories', no
            G.setOption 'collapseBranches', yes
            expect( G.parse '7*5*3*1' ).toEqual \
                [ [ [ [ '7', '*', '5' ], '*', '3' ], '*', '1' ] ]

### should parse sums of products of nonnegative integers

The grammar should correctly parse sums of products of nonnegative integers.

        it 'should parse sums of products of nonnegative integers', ->
            expect( G.parse '1+2' ).toEqual \
                [ [ 'S', [ 'S', [ 'M', [ 'I', [ 'D', '1' ] ] ] ], '+',
                         [ 'M', [ 'I', [ 'D', '2' ] ] ] ] ]
            G.setOption 'addCategories', no
            G.setOption 'collapseBranches', yes
            expect( G.parse '3*6+9' ).toEqual \
                [ [ [ '3', '*', '6' ], '+', '9' ] ]
            expect( G.parse '3+6*9' ).toEqual \
                [ [ '3', '+', [ '6', '*', '9' ] ] ]
            G.setOption 'expressionBuilder', ( x ) ->
                if x instanceof Array then "(#{x.join ''})" else "#{x}"
            expect( G.parse '3+6*9' ).toEqual [ '(3+(6*9))' ]

## A simple tokenizer

This section defines a very simple tokenizer for numbers, identifiers,
string literals, parentheses, and the operations of arithmetic.  It then
verifies that it can be applied to tokenize expressions in that language.

    describe 'A simple tokenizer', ->

### should tokenize arithmetic expressions

The tokenizer should correctly tokenize arithmetic expressions.

        it 'should tokenize arithmetic expressions', ->
            T = new Tokenizer
            T.addType /[a-zA-Z_][a-zA-Z_0-9]*/
            T.addType /\.[0-9]+|[0-9]+\.?[0-9]*/
            T.addType /"(?:[^\\"]|\\\\|\\")*"/
            T.addType /[()+/*-]/
            expect( T.tokenize '5' ).toEqual [ '5' ]
            expect( T.tokenize '19' ).toEqual [ '19' ]
            expect( T.tokenize '6-9' ).toEqual [ '6', '-', '9' ]
            expect( T.tokenize 'x*-5.0/(_tmp+k)' ).toEqual \
                [ 'x', '*', '-', '5.0', '/', '(', '_tmp', '+', 'k', ')' ]
            expect( T.tokenize 'alert("message")' ).toEqual \
                [ 'alert', '(', '"message"', ')' ]

### should support format functions

The tokenizer should permit `addType` to provide formatting functions that
change the token to be added to the tokens array, or even remove it
entirely.

        it 'should support format functions', ->
            T = new Tokenizer
            T.addType /\s/, -> null
            T.addType /[a-zA-Z_][a-zA-Z_0-9]*/
            T.addType /\.[0-9]+|[0-9]+\.?[0-9]*/
            T.addType /"(?:[^\\"]|\\\\|\\")*"/
            T.addType /\/((?:[^\\\/]|\\\\|\\\/)*)\//,
                ( text, match ) -> "RegExp(#{match[1]})"
            T.addType /[()+/*-]/
            expect( T.tokenize '5' ).toEqual [ '5' ]
            expect( T.tokenize '19' ).toEqual [ '19' ]
            expect( T.tokenize '6-9' ).toEqual [ '6', '-', '9' ]
            expect( T.tokenize 'x*-5.0/(_tmp+k)' ).toEqual \
                [ 'x', '*', '-', '5.0', '/', '(', '_tmp', '+', 'k', ')' ]
            expect( T.tokenize 'alert("message")' ).toEqual \
                [ 'alert', '(', '"message"', ')' ]
            expect( T.tokenize 'my(/regexp/)+6' ).toEqual \
                [ 'my', '(', 'RegExp(regexp)', ')', '+', '6' ]
            expect( T.tokenize '64 - 8320   + K' ).toEqual \
                [ '64', '-', '8320', '+', 'K' ]

### should support format strings

The tokenizer should permit `addType` to provide formatting strings that
change the token to be added to the tokens array.

        it 'should support format strings', ->
            T = new Tokenizer
            T.addType /[a-zA-Z_][a-zA-Z_0-9]*/
            T.addType /\.[0-9]+|[0-9]+\.?[0-9]*/
            T.addType /"(?:[^\\"]|\\\\|\\")*"/
            T.addType /\/((?:[^\\\/]|\\\\|\\\/)*)\//, 'RegExp(%1)'
            T.addType /[()+/*-]/
            expect( T.tokenize '5' ).toEqual [ '5' ]
            expect( T.tokenize '19' ).toEqual [ '19' ]
            expect( T.tokenize '6-9' ).toEqual [ '6', '-', '9' ]
            expect( T.tokenize 'x*-5.0/(_tmp+k)' ).toEqual \
                [ 'x', '*', '-', '5.0', '/', '(', '_tmp', '+', 'k', ')' ]
            expect( T.tokenize 'alert("message")' ).toEqual \
                [ 'alert', '(', '"message"', ')' ]
            expect( T.tokenize 'my(/regexp/)+6' ).toEqual \
                [ 'my', '(', 'RegExp(regexp)', ')', '+', '6' ]

## Tokenizing and parsing

Naturally tokenizing and parsing go hand-in-hand, the former usually paving
the way for the latter.  Here we test to be sure that the parser can handle
arbitrary array inputs, and that in particular it can handle the output of
a tokenizer.

    describe 'Tokenizing and parsing', ->

### should support parsing arrays

First we just test the parser alone, that it can handle arrays, which are
what the tokenizer will produce.  We use the same simple grammar for sums
and products of integers from earlier, but now we need not process
digit-by-digit, because we will provide the integers as single entres in the
input array, not each digit separately.

        it 'should support parsing arrays', ->
            G = new Grammar 'S'
            G.addRule 'I', /[0-9]+/
            G.addRule 'M', 'I', [ 'M', /\*/, 'I' ]
            G.addRule 'S', 'M', [ 'S', /\+/, 'M' ]
            expect( G.parse [ '5' ] ).toEqual \
                [ [ 'S', [ 'M', [ 'I', '5' ] ] ] ]
            expect( G.parse [ '19' ] ).toEqual \
                [ [ 'S', [ 'M', [ 'I', '19' ] ] ] ]
            G.setOption 'addCategories', no
            G.setOption 'collapseBranches', yes
            expect( G.parse [ '5' ] ).toEqual [ '5' ]
            expect( G.parse [ '19' ] ).toEqual [ '19' ]
            expect( G.parse [ '7', '*', '50', '*', '33', '*', '1' ] ) \
                .toEqual [ [ [ [ '7', '*', '50' ], '*', '33' ], '*', '1' ] ]
            G.setOption 'expressionBuilder', ( x ) ->
                if x instanceof Array then "(#{x.join ''})" else "#{x}"
            expect( G.parse [ '333', '+', '726', '*', '2349' ] ) \
                .toEqual [ '(333+(726*2349))' ]

### should be chainable

Now we test that we can create a tokenizer whose output will flow naturally
into a parser.  This is (almost) the culmination of the entire module.  The
only remaining test is the next one below, which makes this process simpler,
but performs essentially the same functions.

        it 'should be chainable', ->
            T = new Tokenizer
            T.addType /\s/, -> null
            T.addType /[a-zA-Z_][a-zA-Z_0-9]*/
            T.addType /\.[0-9]+|[0-9]+\.?[0-9]*/
            T.addType /"(?:[^\\"]|\\\\|\\")*"/
            T.addType /[()+/*-]/
            G = new Grammar 'expr'
            G.addRule 'expr', 'sumdiff'
            G.addRule 'atomic', /[a-zA-Z_][a-zA-Z_0-9]*/
            G.addRule 'atomic', /\.[0-9]+|[0-9]+\.?[0-9]*/
            G.addRule 'atomic', /"(?:[^\\"]|\\\\|\\")*"/
            G.addRule 'atomic', [ /\(/, 'sumdiff', /\)/ ]
            G.addRule 'prodquo', [ 'atomic' ]
            G.addRule 'prodquo', [ 'prodquo', /[*/]/, 'atomic' ]
            G.addRule 'sumdiff', [ 'prodquo' ]
            G.addRule 'sumdiff', [ 'sumdiff', /[+-]/, 'prodquo' ]
            G.setOption 'addCategories', no
            G.setOption 'collapseBranches', yes
            G.setOption 'expressionBuilder', ( expr ) ->
                if expr[0] is '(' and expr[2] is ')' and expr.length is 3
                    expr[1]
                else
                    expr
            expect( G.parse T.tokenize 'ident-7.8/other' ).toEqual \
                [ [ 'ident', '-', [ '7.8', '/', 'other' ] ] ]
            expect( G.parse T.tokenize 'ident*7.8/other' ).toEqual \
                [ [ [ 'ident', '*', '7.8' ], '/', 'other' ] ]
            expect( G.parse T.tokenize 'ident*(7.8/other)' ).toEqual \
                [ [ 'ident', '*', [ '7.8', '/', 'other' ] ] ]

### should be connectable using a parser option

We can set the tokenizer as an option on the parser and thus not have to
manually call the `tokenize` function.  It should be called automatically
for us.  Thus this test is exactly like the previous, except we just call
`G.parse` in each test, and verify that tokenization must therefore be
happening automatically.

        it 'should be connectable using a parser option', ->
            T = new Tokenizer
            T.addType /\s/, -> null
            T.addType /[a-zA-Z_][a-zA-Z_0-9]*/
            T.addType /\.[0-9]+|[0-9]+\.?[0-9]*/
            T.addType /"(?:[^\\"]|\\\\|\\")*"/
            T.addType /[()+/*-]/
            G = new Grammar 'expr'
            G.addRule 'expr', 'sumdiff'
            G.addRule 'atomic', /[a-zA-Z_][a-zA-Z_0-9]*/
            G.addRule 'atomic', /\.[0-9]+|[0-9]+\.?[0-9]*/
            G.addRule 'atomic', /"(?:[^\\"]|\\\\|\\")*"/
            G.addRule 'atomic', [ /\(/, 'sumdiff', /\)/ ]
            G.addRule 'prodquo', [ 'atomic' ]
            G.addRule 'prodquo', [ 'prodquo', /[*\/]/, 'atomic' ]
            G.addRule 'sumdiff', [ 'prodquo' ]
            G.addRule 'sumdiff', [ 'sumdiff', /[+-]/, 'prodquo' ]
            G.setOption 'addCategories', no
            G.setOption 'collapseBranches', yes
            G.setOption 'expressionBuilder', ( expr ) ->
                if expr[0] is '(' and expr[2] is ')' and expr.length is 3
                    expr[1]
                else
                    expr
            G.setOption 'tokenizer', T
            expect( G.parse 'ident-7.8/other' ).toEqual \
                [ [ 'ident', '-', [ '7.8', '/', 'other' ] ] ]
            expect( G.parse 'ident*7.8/other' ).toEqual \
                [ [ [ 'ident', '*', '7.8' ], '/', 'other' ] ]
            expect( G.parse 'ident*(7.8/other)' ).toEqual \
                [ [ 'ident', '*', [ '7.8', '/', 'other' ] ] ]

## A larger, useful grammar

This section creates and tests a grammar for parsing the output of the
`mathQuillToMeaning` function defined in
[setup.litcoffee](../app/setup.litcoffee).  It can be any of a wide variety
of common mathematical expressions supported by MathQuill, and converted to
string representation by `mathQuillToMeaning`.

The sample inputs used in the tests below were either manually captured from
a test run of `mathQuillToMeaning` from the JavaScript console in the main
app itself, or a natural modification of such data.  They are therefore
realistic.

    describe 'A larger, useful grammar', ->

Here we define the grammar.

        G = null
        beforeEach ->
            G = new Grammar 'expression'

Rules for numbers:

            G.addRule 'digit', /[0-9]/
            G.addRule 'nonnegint', 'digit'
            G.addRule 'nonnegint', [ 'digit', 'nonnegint' ]
            G.addRule 'integer', 'nonnegint'
            G.addRule 'integer', [ /-/, 'nonnegint' ]
            G.addRule 'float', [ 'integer', /\./, 'nonnegint' ]
            G.addRule 'float', [ 'integer', /\./ ]
            G.addRule 'infinity', [ /∞/ ]

Rule for variables:

            G.addRule 'variable', /[a-zA-Z\u0374-\u03FF]/

The above togeteher are called "atomics":

            G.addRule 'atomic', 'integer'
            G.addRule 'atomic', 'float'
            G.addRule 'atomic', 'variable'
            G.addRule 'atomic', 'infinity'

Rules for the operations of arithmetic:

            G.addRule 'factor', 'atomic'
            G.addRule 'factor', [ 'factor', /sup/, 'atomic' ]
            G.addRule 'factor', [ 'factor', /[%]/ ]
            G.addRule 'factor', [ /\$/, 'factor' ]
            G.addRule 'factor', [ 'factor', /sup/, /[∘]/ ]
            G.addRule 'prodquo', 'factor'
            G.addRule 'prodquo', [ 'prodquo', /[÷×·]/, 'factor' ]
            G.addRule 'prodquo', [ /-/, 'prodquo' ]
            G.addRule 'sumdiff', 'prodquo'
            G.addRule 'sumdiff', [ 'sumdiff', /[+±-]/, 'prodquo' ]

Rules for logarithms:

            G.addRule 'ln', [ /ln/, 'atomic' ]
            G.addRule 'log', [ /log/, 'atomic' ]
            G.addRule 'log', [ /log/, /sub/, 'atomic', 'atomic' ]
            G.addRule 'prodquo', 'ln'
            G.addRule 'prodquo', 'log'

Rules for the operations of set theory (still incomplete):

            G.addRule 'setdiff', 'variable'
            G.addRule 'setdiff', [ 'setdiff', /[∼]/, 'variable' ]

Rules for various structures, like fractions, which are treated indivisibly,
and thus as if they were atomics:

            G.addRule 'fraction',
                [ /fraction/, /\(/, 'atomic', 'atomic', /\)/ ]
            G.addRule 'atomic', 'fraction'
            G.addRule 'root', [ /√/, 'atomic' ]
            G.addRule 'root', [ /nthroot/, 'atomic', /√/, 'atomic' ]
            G.addRule 'atomic', 'root'
            G.addRule 'decoration', [ /overline/, 'atomic' ]
            G.addRule 'decoration', [ /overarc/, 'atomic' ]
            G.addRule 'atomic', 'decoration'

So far we've only defined rules for forming mathematical nouns, so we wrap
the highest-level non-terminal defined so far, sumdiff, in the label "noun."

            G.addRule 'noun', 'sumdiff'
            G.addRule 'noun', 'setdiff'

Rule for forming sentences from nouns, by placing relations between them:

            G.addRule 'atomicsentence', [ 'noun', /[=≠≈≃≤≥<>]/, 'noun' ]
            G.addRule 'atomicsentence', [ /[¬]/, 'atomicsentence' ]
            G.addRule 'sentence', 'atomicsentence'

Rule for groupers:

            G.addRule 'atomic', [ /\(/, 'noun', /\)/ ]
            G.addRule 'atomicsentence', [ /\(/, 'sentence', /\)/ ]

And finally, place "expression" at the top of the grammar; one is permitted
to use this grammar to express mathematical nouns or complete sentences:

            G.addRule 'expression', 'noun'
            G.addRule 'expression', 'sentence'

A function that recursively assembles OpenMath nodes from the hierarchy of
arrays created by the parser:

            G.setOption 'expressionBuilder', ( expr ) ->
                symbols =
                    '+' : OM.symbol 'plus', 'arith1'
                    '-' : OM.symbol 'minus', 'arith1'
                    '±' : OM.symbol 'plusminus', 'multiops'
                    '×' : OM.symbol 'times', 'arith1'
                    '·' : OM.symbol 'times', 'arith1'
                    '÷' : OM.symbol 'divide', 'arith1'
                    '^' : OM.symbol 'power', 'arith1'
                    '∞' : OM.symbol 'infinity', 'nums1'
                    '√' : OM.symbol 'root', 'arith1'
                    '∼' : OM.symbol 'set1', 'setdiff'
                    '=' : OM.symbol 'eq', 'relation1'
                    '<' : OM.symbol 'lt', 'relation1'
                    '>' : OM.symbol 'gt', 'relation1'
                    '≠' : OM.symbol 'neq', 'relation1'
                    '≈' : OM.symbol 'approx', 'relation1'
                    '≤' : OM.symbol 'le', 'relation1'
                    '≥' : OM.symbol 'ge', 'relation1'
                    '≃' : OM.symbol 'modulo_relation', 'integer2'
                    '¬' : OM.symbol 'not', 'logic1'
                    '∘' : OM.symbol 'degrees', 'units'
                    '$' : OM.symbol 'dollars', 'units'
                    '%' : OM.symbol 'percent', 'units'
                    'ln' : OM.symbol 'ln', 'transc1'
                    'log' : OM.symbol 'log', 'transc1'
                    'unary-' : OM.symbol 'unary_minus', 'arith1'
                    'overarc' : OM.symbol 'overarc', 'decoration'
                    'overline' : OM.symbol 'overline', 'decoration'
                build = ( head, args... ) ->
                    if typeof head is 'number' then head = expr[head]
                    for arg, index in args
                        if typeof arg is 'number'
                            args[index] = OM.decode expr[arg]
                    tmp = OM.application symbols[head], args...
                    if G.expressionBuilderDebug
                        console.log 'build', head, args..., '-->', tmp
                    tmp
                result = switch expr[0]
                    when 'digit', 'nonnegint' then expr[1..].join ''
                    when 'integer'
                        OM.integer parseInt expr[1..].join ''
                    when 'float'
                        intvalue = OM.decode( expr[1] ).value
                        fullvalue = parseFloat \
                            "#{intvalue}#{expr[2..].join ''}"
                        OM.float fullvalue
                    when 'variable' then OM.variable expr[1]
                    when 'infinity' then symbols[expr[1]]
                    when 'sumdiff', 'prodquo'
                        switch expr.length
                            when 4 then build 2, 1, 3
                            when 3 then build 'unary-', 2
                    when 'factor'
                        switch expr.length
                            when 4
                                if expr[3] is '∘'
                                    build '×', 1, symbols['∘']
                                else
                                    build '^', 1, 3
                            when 3
                                if expr[2] is '%'
                                    build '×', 1, symbols['%']
                                else
                                    build '×', 2, symbols['$']
                    when 'fraction' then build '÷', 3, 4
                    when 'root'
                        switch expr.length
                            when 3 then build '√', 2, OM.integer 2
                            when 5 then build '√', 4, 2
                    when 'ln' then build 'ln', 2
                    when 'log'
                        switch expr.length
                            when 3 then build 'log', OM.integer( 10 ), 2
                            when 5 then build 'log', 3, 4
                    when 'atomic'
                        if expr.length is 4 and expr[1] is '(' and \
                           expr[3] is ')' then expr[2]
                    when 'atomicsentence'
                        switch expr.length
                            when 4 then build 2, 1, 3
                            when 3 then build 1, 2
                    when 'decoration' then build 1, 2
                if not result? then result = expr[1]
                if result instanceof OMNode then result = result.encode()
                if G.expressionBuilderDebug
                    console.log JSON.stringify( expr ), '--->', result
                result

### should parse numbers

        it 'should parse numbers', ->

An integer first (which also counts as a float):

            input = '1 0 0'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.integer 100 ).toBeTruthy()

A floating point value second:

            input = '3 . 1 4 1 5 9'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple '3.14159' ).toBeTruthy()

Let's pretend infinity is a number, and include it in this test.

            input = [ '∞' ]
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'nums1.infinity' ).toBeTruthy()

### should parse variables

        it 'should parse variables', ->

Roman letters, upper and lower case:

            input = [ "x" ]
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.variable 'x' ).toBeTruthy()
            input = [ "R" ]
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.variable 'R' ).toBeTruthy()

Greek letters:

            input = [ "α" ]
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.variable 'α' ).toBeTruthy()
            input = [ "π" ]
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.variable 'π' ).toBeTruthy()

### should parse simple arithmetic expressions

By this, we mean sums, differences, products, and quotients.

        it 'should parse simple arithmetic expressions', ->

Try one of each operation in isolation:

            input = '6 + k'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'arith1.plus(6,k)' ).toBeTruthy()
            node = OM.decode output[1]
            input = '1 . 9 - T'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'arith1.minus(1.9,T)' ) \
                .toBeTruthy()
            input = '0 . 2 · 0 . 3'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'arith1.times(0.2,0.3)' ) \
                .toBeTruthy()
            input = 'v ÷ w'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'arith1.divide(v,w)' ) \
                .toBeTruthy()
            input = 'v ± w'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'multiops.plusminus(v,w)' ) \
                .toBeTruthy()
            input = '2 sup k'.split ' '
            G.expressionBuilderDebug = yes
            output = G.parse input
            G.expressionBuilderDebug = no
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'arith1.power(2,k)' ) \
                .toBeTruthy()

Now try same-precedence operators in sequence, and ensure that they
left-associate.

            input = '5 . 0 - K + e'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.plus(arith1.minus(5.0,K),e)' ).toBeTruthy()
            input = '5 . 0 × K ÷ e'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.divide(arith1.times(5.0,K),e)' ).toBeTruthy()
            input = 'a sup b sup c'.split ' '
            output = G.parse input

            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.power(arith1.power(a,b),c)' ).toBeTruthy()

Now try different-precendence operators in combination, and ensure that
precedence is respected.

            input = '5 . 0 - K · e'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.minus(5.0,arith1.times(K,e))' ).toBeTruthy()
            input = '5 . 0 × K + e'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.plus(arith1.times(5.0,K),e)' ).toBeTruthy()
            input = 'u sup v × w sup x'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.times(arith1.power(u,v),arith1.power(w,x))' ) \
                .toBeTruthy()

Verify that unary negation works.

            input = '- 7'.split ' '
            output = G.parse input
            expect( output.length ).toBe 2
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple '-7' ).toBeTruthy()
            node = OM.decode output[1]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'arith1.unary_minus(7)' ) \
                .toBeTruthy()
            input = 'A + - B'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.plus(A,arith1.unary_minus(B))' ).toBeTruthy()
            input = '- A + B'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.plus(arith1.unary_minus(A),B)' ).toBeTruthy()
            input = '- A sup B'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.unary_minus(arith1.power(A,B))' ).toBeTruthy()

### should respect parentheses

That is, we can override precedence using parentheses, and the correct
expression trees are created.

        it 'should respect parentheses', ->

First, verify that a chain of sums left-associates.

            input = '6 + k + 5'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.plus(arith1.plus(6,k),5)' ).toBeTruthy()

Now verify that we can override that with parentheses.

            input = '6 + ( k + 5 )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.plus(6,arith1.plus(k,5))' ).toBeTruthy()

And verify that parentheses override precedence as well.  Contrast the
following tests to those at the end of the previous section, which tested
the default precendence of these operators.

            input = '( 5 . 0 - K ) · e'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.times(arith1.minus(5.0,K),e)' ).toBeTruthy()
            input = '5 . 0 × ( K + e )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.times(5.0,arith1.plus(K,e))' ).toBeTruthy()
            input = '- ( K + e )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.unary_minus(arith1.plus(K,e))' ).toBeTruthy()
            input = '- ( A sup B )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.unary_minus(arith1.power(A,B))' ).toBeTruthy()

### should support fractions

Fractions come as text of the form "fraction ( N D )" where N and D are the
numerator and denominator expressions respectively.

        it 'should support fractions', ->

Let's begin with fractions of atomics.

            input = 'fraction ( 1 2 )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.divide(1,2)' ).toBeTruthy()
            input = 'fraction ( p q )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.divide(p,q)' ).toBeTruthy()

Now we'll try fractions of larger things

            input = 'fraction ( ( 1 + t ) 3 )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.divide(arith1.plus(1,t),3)' ).toBeTruthy()
            input = 'fraction ( ( a + b ) ( a - b ) )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.divide(arith1.plus(a,b),arith1.minus(a,b))' ) \
                .toBeTruthy()

And lastly we verify that parsing takes place correctly inside the
numerator and denominator of fractions.

            input = 'fraction ( ( 1 + 2 × v ) ( - w ) )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.divide(arith1.plus(1,arith1.times(2,v)),' + \
                'arith1.unary_minus(w))' ).toBeTruthy()

### should support square roots and nth roots

Square roots come as text of the form "√ E" where E is an expression.
Nth roots come as text of the form "nthroot N √ E" where N is an expression
outside the radical (the N in Nth root) and E is the expression whose root
is being expressed.  For example, the third root of x is "nthroot 3 √ x".

        it 'should support square roots and nth roots', ->

First, square roots of simple expressions.

            input = '√ 2'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.root(2,2)' ).toBeTruthy()
            input = '√ ( 1 0 - k + 9 . 6 )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.root(arith1.plus(arith1.minus(10,k),9.6),2)' ) \
                .toBeTruthy()

Second, nth roots of simple expressions.

            input = 'nthroot p √ 2'.split ' '
            output = G.parse input

            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.root(2,p)' ).toBeTruthy()
            input = 'nthroot 5 0 √ ( 1 0 - k + 9 . 6 )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.root(arith1.plus(arith1.minus(10,k),9.6),50)' ) \
                .toBeTruthy()

Next, square roots of fractions and of other roots, and placed in context.

            input = 'fraction ( 6 √ fraction ( 1 2 ) )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.divide(6,arith1.root(arith1.divide(1,2),2))' ) \
                .toBeTruthy()
            input = '√ ( 1 + √ 5 ) + 1'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.plus(arith1.root(arith1.plus(' + \
                '1,arith1.root(5,2)),2),1)' ).toBeTruthy()

Finally, nth roots containing more complex expressions.

            input = 'nthroot ( 2 + t ) √ ( 1 ÷ ∞ )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.root(arith1.divide(1,nums1.infinity),' + \
                'arith1.plus(2,t))' ).toBeTruthy()

### should support logarithms of all types

This includes natural logarithms, "ln x", logarithms with an assumed base
10, "log x", and logarithms with an explicit base, "log sub 2 8".

        it 'should support logarithms of all types', ->

Natural logarithms of a simple thing and a larger thing.

            input = 'ln x'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'transc1.ln(x)' ).toBeTruthy()
            input = 'ln fraction ( 2 ( x + 1 ) )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'transc1.ln(arith1.divide(2,arith1.plus(x,1)))' ) \
                .toBeTruthy()

Logarithms with an implied base 10, of a simple thing and a larger thing.

            input = 'log 1 0 0 0'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'transc1.log(10,1000)' ) \
                .toBeTruthy()
            input = 'log ( e sup x × y )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'transc1.log(10,arith1.times(arith1.power(e,x),y))' ) \
                .toBeTruthy()

Logarithms with an explicit base, of a simple thing and a larger thing.

            input = 'log sub ( 3 1 ) 6 5'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple 'transc1.log(31,65)' ) \
                .toBeTruthy()
            input = 'log sub ( - t ) ( k + 5 )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'transc1.log(arith1.unary_minus(t),arith1.plus(k,5))' ) \
                .toBeTruthy()

### should support sentences

Sentences are formed by using relations (such as equality or less than) to
connect two nouns, or by negating existing sentences.

        it 'should support sentences', ->

First, relations among nouns.

            input = '2 < 3'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.lt(2,3)' ).toBeTruthy()
            input = '- 6 > k'.split ' '
            output = G.parse input
            expect( output.length ).toBe 2
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.gt(-6,k)' ).toBeTruthy()
            node = OM.decode output[1]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.gt(arith1.unary_minus(6),k)' ).toBeTruthy()
            input = 't + u = t + v'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.eq(arith1.plus(t,u),arith1.plus(t,v))' ) \
                .toBeTruthy()
            input = 't + u = t + v'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.eq(arith1.plus(t,u),arith1.plus(t,v))' ) \
                .toBeTruthy()

            input = 't + u ≠ t + v'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.neq(arith1.plus(t,u),arith1.plus(t,v))' ) \
                .toBeTruthy()
            input = 'fraction ( a ( 7 + b ) ) ≈ 0 . 7 5'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.approx(arith1.divide(' + \
                'a,arith1.plus(7,b)),0.75)' ).toBeTruthy()
            input = 't sup 2 ≤ 1 0'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.le(arith1.power(t,2),10)' ).toBeTruthy()
            input = '1 + 2 + 3 ≥ 6'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'relation1.ge(arith1.plus(arith1.plus(1,2),3),6)' ) \
                .toBeTruthy()
            input = 'k ≃ l'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'integer2.modulo_relation(k,l)' ) \
                .toBeTruthy()

### should support units

Units are formed by multiplying a value by the symbol for "degrees,"
"dollars," or "percent."  These are not symbols in any official OpenMath
content dictionary, but are supported by MathQuill, so I include symbols
for them here.

        it 'should support units', ->

            input = '1 0 0 %'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.times(100,units.percent)' ).toBeTruthy()
            input = '$ ( d + 5 0 )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.times(arith1.plus(d,50),units.dollars)' ) \
                .toBeTruthy()
            input = '4 5 sup ∘'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'arith1.times(45,units.degrees)' ).toBeTruthy()

### should support decorations (overline, overarc)

These use nonstandard symbols and apply them like functions to the
expression with the arc or line over it.

        it 'should support decorations (overline, overarc)', ->

            input = 'overline ( x )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'decoration.overline(x)' ).toBeTruthy()
            input = 'overarc ( 6 - fraction ( e 3 ) )'.split ' '
            output = G.parse input
            expect( output.length ).toBe 1
            node = OM.decode output[0]
            expect( node instanceof OMNode ).toBeTruthy()
            expect( node.equals OM.simple \
                'decoration.overarc(arith1.minus(6,arith1.divide(e,3)))' ) \
                .toBeTruthy()