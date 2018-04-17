-module(yup).
-record(splist, {left = [], right = []}).
-export([interpreter/2]).

interpreter(Code, Tape) ->
	register(parent, self()),
	Child = spawn_link(?MODULE, parse, [#splist{right = Code}, #splist{right = Tape}]),
	receive
		{Child, output, OutTape} -> OutTape;
		X -> X
	after 200000 -> timeout
	end.

unsplist(#splist{left = Left, right = Right}) ->
	lists:reverse(Left, Right).

terminate(Tape = #splist{}) ->
	parent ! {self(), output, unsplist(Tape)},
	exit(normal).

inc_splist(#splist{left = Left, right = [R|Ight]}) ->
	#splist{left = [R|Left], right = Ight}.

rewind(1, Code, Tape = #splist{right = [0|_]}) ->
	parse(inc_splist(Code), Tape);
rewind(Count, Code = #splist{}, Tape) ->
	case Code#splist.left of
		[Tk|Tks] ->
			NewCode = #splist{left = Tks, right = [Tk|Code#splist.right]},
			if
				Tk =:= $[ ->
					case Count of
						1 -> parse(Code, Tape);
						_ -> rewind(Count - 1, NewCode, Tape)
					end;
				Tk =:= $] ->
					rewind(Count + 1, NewCode, Tape);
				true -> rewind(Count, NewCode, Tape)
			end;
		[] -> end_of_this_world
	end.

unwind(Count, Code = #splist{}, Tape = #splist{right = [0|_]}) ->
	case Code#splist.right of
		[Tk|_] ->
			if
				Tk =:= $] ->
					case Count of
						1 -> parse(Code, Tape);
						_ -> unwind(Count - 1, inc_splist(Code), Tape)
					end;
				Tk =:= $[ ->
					unwind(Count + 1, inc_splist(Code), Tape);
				true -> unwind(Count, inc_splist(Code), Tape)
			end;
		[] -> end_of_this_world
	end;
unwind(1, Code, Tape) ->
	parse(inc_splist(Code), Tape).

flip(Code, #splist{left = Left, right = [Tk|Tks]}) ->
	case Tk of
		$0 -> Flip = $1;
		$1 -> Flip = $0
	end,
	parse(inc_splist(Code), #splist{left = Left, right = [Flip|Tks]}).

mv_ptr_right(Code, Tape = #splist{right = [_|Tks]}) ->
	case Tks of
		[] -> terminate(Tape);
		_ -> parse(inc_splist(Code), inc_splist(Tape))
	end.

mv_ptr_left(Code, Tape = #splist{left = [Tk|Tks], right = Right}) ->
	case Tks of
		[] -> terminate(Tape);
		_ -> parse(inc_splist(Code), #splist{left = Tks, right = [Tk|Right]})
	end.

parse(#splist{right = []}, Tape) ->
	terminate(Tape);
parse(Code = #splist{right = [Tk|_]}, Tape) ->
	case Tk of
		$< -> mv_ptr_left(Code, Tape);
		$> -> mv_ptr_right(Code, Tape);
		$* -> flip(Code, Tape);
		$[ -> unwind(1, Code, Tape);
		$] -> rewind(1, Code, Tape)
	end.
