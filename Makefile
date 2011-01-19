all:
	@./rebar compile escriptize

test: force
	@./rebar eunit

clean:
	@./rebar clean

force: ;
