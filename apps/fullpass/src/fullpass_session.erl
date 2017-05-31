-module(fullpass_session).
-behaviour(cmaggregate).
-export([mode/0, init/1, handle/2, topic/0, topic/1, missing/1, timeout/1]).
-record(data, {id, profile, conn}).

mode() ->
  one_worker.

topic() ->
  session.

topic({session, {Id, _Profile, _Conn}, _}) ->
  {session, Id}.

init({session, Id}) ->
  #data{id=Id}.

handle({session, {Id, P, Conn}, _}, #data{id=Id}=Data) ->
  Conn ! Id,
  Data#data{profile=P, conn=Conn};

handle({{session,Id}, _, Conn}, #data{id=Id, profile=P}=Data) ->
  Conn ! P,
  Data#data{conn=Conn};

handle({{session, Id}, Conn}, #data{id=Id}=Data) ->
  Data#data{conn=Conn}.

missing({{session, _}=T, none, Conn}) ->
  {replay, {T, {T, Conn}}};

missing(_) ->
  ignore.

timeout(Data) ->
  io:format("got timeout: ~p~n", [Data]),
  {stop, Data}.