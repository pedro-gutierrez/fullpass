-module(fullpass_user).
-behaviour(cmaggregate).
-export([mode/0, init/1, handle/2, topic/0, topic/1, missing/1]).
-record(data, {id, profile, sessions}).

mode() ->
  one_worker.

topic() ->
  profile.

topic({profile, #{<<"id">> := Id}, _}) ->
  {profile, Id}.

init({profile, Id}) ->
  #data{id=Id, sessions=#{}}.

handle({profile, #{<<"id">> := Id}=P, Conn}, 
       #data{id=Id, sessions=_Sessions}=Data) ->
  cmcluster:event({session, {cmkit:uuid(), P, Conn}}),
  %cmcluster:sub(T),
  %cmcluster:event({T, a}),
  %cmcluster:event({T, #{status => started, profile => Id}}),
  %Conn ! SessionId,
  %Data#data{profile=P, sessions=maps:put(SessionId, Conn, Sessions)};
  Data#data{profile=P};

handle({{session, Id}, none, Conn}, Data) ->
  with_session(Id, Conn, Data, 
               fun(Data2) -> 
                   Data2
               end,
               fun(P, Data2) ->
                   Conn ! P,
                   Data2
               end);

handle(Msg, Data) ->
  io:format("unexpected messag: ~p~n", [Msg]),
  Data.

with_session(Id, Conn, #data{sessions=Sessions, profile=P}=Data, Err, Next) ->
  case maps:is_key(Id, Sessions) of
    true ->
      case maps:get(Id, Sessions) of
        Conn ->
          Next(P, Data);
        _ ->
          Sessions2 = maps:put(Id, Conn, Sessions),
          Data2 = Data#data{sessions=Sessions2},
          Next(P, Data2)
      end;
    false ->
      Err(Data)
  end.

missing({{session, _}, _, _}=Msg) ->
  io:format("handling missing for: ~p~n", [Msg]),
  ok.
