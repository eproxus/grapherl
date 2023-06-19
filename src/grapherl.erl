%% @author Adam Lindberg <eproxus@gmail.com>
%% @doc Create graphs of Erlang systems and programs.
%%
%% Valid options are the following:
%% <dl>
%%   <dt>`type'</dt><dd>The type of the file as an atom. This can be
%%     all extensions that graphviz (`dot') supports. Default is `png'.</dd>
%%   <dt>`open'</dt><dd>Command to run on resulting file as a
%%     string. This command will with the output file generated from
%%     `dot' as input.</dd>
%%   <dt>`verbose'</dt><dd>Make `xref' verdbose. Default is `false'.</dd>
%%   <dt>`warnings'</dt><dd>Make `xref' print warnings. Default is `false'</dd>
%% </dl>
-module(grapherl).

-copyright("Erlang Solutions Ltd.").
-author("Adam Lindberg <eproxus@gmail.com>").

-export([main/1]).
-export([applications/2]).
-export([applications/3]).
-export([modules/2]).
-export([modules/3]).

-ifdef(TEST).
-include("grapherl_tests.hrl").
-endif.

%%==============================================================================
%% API Functions
%%==============================================================================

%% @hidden
main(Args) ->
    {ok, {Flags, _Rest} = Options} = getopt:parse(options(), Args),
    case lists:member(help, Flags) of
        true  -> print_options(), halt(0);
        false -> run(Options)
    end.

run({Options, [Dir, Target]}) ->
    case get_mode(Options) of
        {app, RestOpt} -> run(applications, [Dir, Target, RestOpt]);
        {mod, RestOpt} -> run(modules, [Dir, Target, RestOpt])
    end;
run({_Options, _Other}) ->
    print_options(), halt(1).

get_mode(Options) ->
    case proplists:split(Options, [app, mod]) of
        {[[app], []], Rest} -> {app, Rest};
        {[[], [mod]], Rest} -> {mod, Rest}
    end.

options() ->
    [{help, $h, "help", undefined,
      "Display this help text"},
     {mod, $m, "modules", undefined,
      "Analyse module dependencies (mutually exclusive)"},
     {app, $a, "applications", undefined,
      "Analyse application dependencies (mutually exclusive)"},
     {type, $t, "type", string,
      "Output file type (also deduced from file name)"}].

print_options() ->
    getopt:usage(options(), filename:basename(escript:script_name()),
                 "SOURCE OUTPUT",
                 [{"SOURCE", "The source directory to analyse"},
                  {"OUTPUT", "Target ouput file"}]).

run(Fun, Args) ->
    try apply(?MODULE, Fun, Args) of
        ok ->
            halt(0);
        {error, Error} ->
            io:format("grapherl: error: ~p~n", [Error]),
            halt(2)
    catch
        error:type_not_specified ->
            io:format("grapherl: error: File type not specified~n"),
            halt(2)
    end.

%% @equiv applications(Dir, Target, [{type, png}])
applications(Dir, Target) ->
    applications(Dir, Target, [{type, png}]).

%% @doc Generate an application dependency graph based on function calls.
%%
%% `Dir' is the library directory of the release you want to graph. `Target'
%5 is the target filename (without extension).
applications(Dir, Target, Options) ->
    check_dot(),
    try
        initialize_xref(?MODULE, Options),
        ok(xref:add_release(?MODULE, Dir, {name, ?MODULE})),
        Excluded = ifc(proplists:is_defined(include_otp, Options),
                       [], otp_apps())
            ++ proplists:get_value(excluded, Options, []),
        {ok, Results} = xref:q(?MODULE, "AE"),
        Relations = [uses(F, T) ||
                        {F, T} <- Results,
                        F =/= T,
                        not lists:member(F, Excluded),
                        not lists:member(T, Excluded)],
        create(["node [shape = tab];"] ++ Relations, Target, Options),
        stop_xref(?MODULE)
    catch
        throw:Error ->
            stop_xref(?MODULE),
            Error
    end.


%% @equiv application(App, Target, [{type, png}])
modules(Dir, Target) ->
    modules(Dir, Target, []).

%% @doc Generate a module dependency graph for an application.
%%
%% `Dir' is the directory of the application. `Target' is the target
%% filename (without extension).
%%
%% All modules in the `ebin' folder in the directory specified in
%% `Dir' will be included in the graph. The option `no_ebin' will, if
%% set to true or just included as an atom, use the `Dir' directory as
%% a direct source for .beam files.
modules(Dir, Target, Options) ->
    %% TODO: Thickness of arrows could be number of calls?
    check_dot(),
    try
        initialize_xref(?MODULE, Options),
        Path = get_path(Dir),
        ok(xref:add_directory(?MODULE, Path)),
        Modules = case ok(xref:q(?MODULE, "AM")) of
                      [] -> throw({error, no_modules_found});
                      Else  -> Else
                  end,
        Query = "ME ||| ["
            ++ string:join(["'" ++ atom_to_list(M) ++ "'" || M <- Modules], ",")
            ++ "]",
        {ok, Results} = xref:q(?MODULE, Query),
        Relations = [uses(F, T) || {F, T} <- Results, F =/= T],
        create(["node [shape = box];"]
               ++ [["\"" ++ atom_to_list(M) ++ "\"", $;] || M <- Modules]
               ++ Relations, Target, Options),
        stop_xref(?MODULE)
    catch
        throw:Error ->
            stop_xref(?MODULE),
            Error
    end.

%%==============================================================================
%% Internal Functions
%%==============================================================================

get_path(Dir) ->
    case filelib:wildcard(filename:join(Dir, "*.beam")) of
        []     -> filename:join(Dir, "ebin");
        _Beams  -> Dir
    end.

initialize_xref(Name, Options) ->
    case xref:start(Name) of
        {error, {already_started, _}} ->
            stop_xref(Name),
            xref:start(Name);
        {ok, _Ref} ->
            ok
    end,
    XRefOpts = [{verbose, proplists:is_defined(verbose, Options)},
                {warnings, proplists:is_defined(warnings, Options)}],
    ok = xref:set_default(Name, XRefOpts).

stop_xref(Ref) ->
    xref:stop(Ref),
    ok.

get_type(Options, Target) ->
    case proplists:get_value(type, Options) of
        undefined -> type_from_filename(Target);
        Type when is_atom(Type) -> atom_to_list(Type);
        Type -> Type
    end.

type_from_filename(Filename) ->
    case filename:extension(Filename) of
        ""          -> erlang:error(type_not_specified);
        "." ++ Type -> Type
    end.

file(Lines) ->
    ["digraph application_graph {", Lines, "}"].

uses(From, To) ->
    ["\"" ++ atom_to_list(From) ++ "\"", " -> ",
     "\"" ++ atom_to_list(To) ++ "\"", $;].

create(Lines, Target, Options) ->
    case dot(file(Lines), Target, get_type(Options, Target)) of
        {ok, File}    ->
            case proplists:get_value(open, Options) of
                undefined -> ok;
                Command -> os:cmd(Command ++ " " ++ File), ok
            end;
        {Error, _File} ->
            {error, hd(string:tokens(Error, "\n"))}
    end.

check_dot() ->
    case os:cmd("dot -V") of
        "dot " ++ _ ->
            ok;
        _Else ->
            erlang:error("dot was not found, please install graphviz",[])
    end.

dot(File, Target, Type) ->
    TmpFile = string:strip(os:cmd("mktemp -t " ?MODULE_STRING ".XXXX"), both, $\n),
    ok = file:write_file(TmpFile, File),

    TargetName = add_extension(Target, Type),
    Result = case Type of
            "dot" -> file:write_file(TargetName, File);
            _ ->
                case os:cmd(io_lib:format("dot -T~p -o~p ~p", [Type, TargetName, TmpFile])) of
                    "" -> ok;
                    X -> X
                end
    end,
    {Result, TargetName}.

add_extension(Target, Type) ->
    case filename:extension(Target) of
        "." ++ Type -> Target;
        _Else -> Target ++ "." ++ Type
    end.

otp_apps() ->
    {ok, Apps} = file:list_dir(filename:join(code:root_dir(), "lib")),
    [list_to_atom(hd(string:tokens(A, "-"))) || A <- Apps].

ok({ok, Result}) -> Result;
ok(Error)        -> throw(Error).

ifc(true, True, _)   -> True;
ifc(false, _, False) -> False.
