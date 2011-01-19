%%==============================================================================
%% Copyright 2010 Erlang Solutions Ltd.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================

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

-export([applications/2]).
-export([applications/3]).
-export([modules/2]).
-export([modules/3]).

%%==============================================================================
%% API Functions
%%==============================================================================

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
        Path = ifc(proplists:is_defined(no_ebin, Options),
                   Dir, filename:join([Dir, "ebin"])),
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

get_type(Options) ->
    atom_to_list(proplists:get_value(type, Options, png)).

file(Lines) ->
    ["digraph application_graph {", Lines, "}"].

uses(From, To) ->
    [ "\"" ++ atom_to_list(From) ++ "\"", " -> ", "\"" ++ atom_to_list(To) ++ "\"", $;].

create(Lines, Target, Options) ->
    case dot(file(Lines), Target, get_type(Options)) of
        {"", File}    ->
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
    TargetName = Target ++ "." ++ Type,
    Result = os:cmd(io_lib:format("dot -T~p -o~p ~p",
                                  [Type, TargetName, TmpFile])),
    ok = file:delete(TmpFile),
    {Result, TargetName}.

otp_apps() ->
    [appmon, et, public_key, asn1, eunit, reltool, common_test, gs,
     runtime_tools, compiler, hipe, sasl, cosEvent, ic, snmp,
     cosEventDomain, inets, ssh, cosFileTransfer, inviso, ssl,
     cosNotification, jinterface, stdlib, cosProperty, kernel,
     syntax_tools, cosTime, megaco, test_server, cosTransactions,
     mnesia, toolbar, crypto, observer, tools, debugger, odbc, tv,
     dialyzer, orber, typer, docbuilder, os_mon, webtool, edoc,
     otp_mibs, wx, erl_docgen, parsetools, xmerl, erl_interface,
     percept, erts, pman].

ok({ok, Result}) -> Result;
ok(Error)        -> throw(Error).


ifc(true, True, _)   -> True;
ifc(false, _, False) -> False.
