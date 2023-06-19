all:
	@rebar3 compile escriptize

test: force
	@rebar3 eunit

clean:
	@rebar3 clean

force: ;
