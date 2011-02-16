grapherl
========
Create graphs of Erlang systems and programs.

Getting Started
---------------

First, install graphviz. On Ubuntu:

    $ sudo aptitude install graphviz

On OS X, download and install the [OS X version of graphviz][1] or use
[homebrew][2]:

    $ brew install graphviz

To compile grapherl, type:

    $ make

or the equivalent `./rebar compile`.

To start a grapherl shell after compilation, type:

    $ erl -pa ebin

Alternatively, compile a grapherl stand-alone executable by doing:

    $ ./rebar escriptize

This will produce a `grapherl` executable in the root directory. Use
the flags `-h` or `--help` to see wich arguments it needs.

Examples
--------
Here's some examples of using grapherl.

The following two calls are equal. They will both generate
`my_app.png` in the current directory.

    Eshell V5.7.5  (abort with ^G)
    1> grapherl:modules("/path/to/my_app", "my_app").
    ok
    2> grapherl:modules("/path/to/my_app/ebin", "my_app", [no_ebin]).
    ok

For example, if you have an Erlang release in the folder `my_node`,
you can create a application dependency graph in SVG format by doing
the following:

    Eshell V5.7.5  (abort with ^G)
    1> grapherl:applications("/path/to/my_node/lib", "my_node", [{type, svg}]).
    ok

This will create `my_node.svg` in the current directory.

Tips
---

If you're using Gnome under Linux, use the option `{open,
"gnome-open"}` to directly see the resulting image.

If you're using OS X, use the option `{open, "open"}`.

Contribute
----------

Should you find yourself using grapherl and have issues, comments or
feedback please [create an issue!] [3]

Patches are greatly appreciated!

[1]: http://www.pixelglow.com/graphviz/ "graphviz for OS X"
[2]: https://github.com/mxcl/homebrew "The missing package manager for OS"
[3]: http://github.com/eproxus/grapherl/issues "grapherl issue tracker"
