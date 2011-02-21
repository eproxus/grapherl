-include_lib("eunit/include/eunit.hrl").

get_mode_test_() ->
    {inparallel, [?_assertEqual({app, []}, get_mode([app])),
                  ?_assertEqual({mod, []}, get_mode([mod])),
                  ?_assertEqual({app, [other]}, get_mode([app, other])),
                  ?_assertEqual({app, [other]}, get_mode([other, app]))]}.

get_type_test_() ->
    {inparallel, [?_assertEqual("png", get_type([{type, png}], "")),
                  ?_assertEqual("png", get_type([], "test.png")),
                  ?_assertError(type_not_specified, get_type([], "test"))]}.

add_extension_test_() ->
    {inparallel, [?_assertEqual("test.png", add_extension("test", "png")),
                  ?_assertEqual("test.png", add_extension("test.png", "png"))]}.
