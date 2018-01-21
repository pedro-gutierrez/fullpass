-module(cmdb_write).
-behaviour(gen_statem).
-export([start_link/1]).
-export([init/1, callback_mode/0, terminate/3]).
-export([ready/3]).
-record(data, {config}).

callback_mode() ->
    state_functions.

start_link(Dbs) ->
    gen_statem:start_link({local, ?MODULE}, ?MODULE, [Dbs], []).

init([Dbs]) ->
    Config = lists:foldl(fun(#{ name := Name}=Db, Cfg) ->
                            maps:put(erlang:atom_to_list(Name), Db, Cfg)       
                         end, #{}, Dbs),
    cmkit:log({cmdb_write, node(), started}),
    {ok, ready, #data{config=Config}}.

ready({call, From}, {put, Ns, K, V}, #data{config=Config}=Data) ->
    Res = case Config of
        #{ Ns := #{ name := Name, replicas := Nodes }} ->
            R = [ gen_statem:call({Name, Node}, {put, K, V}) || Node <- Nodes ],
            cmdb_util:all_ok(R);
        _ ->
            {unknown, Ns}
    end,
    {keep_state, Data, {reply, From, Res}};

ready({call, From}, {put, Ns, Pairs}, #data{config=Config}=Data) ->
    Res = case Config of
        #{ Ns := #{ name := Name, replicas := Nodes }} ->
            R = [ gen_statem:call({Name, Node}, {put, Pairs}) || Node <- Nodes],
            cmdb_util:all_ok(R);
        _ ->
            {unknown, Ns}
    end,
    {keep_state, Data, {reply, From, Res}}.

terminate(Reason, _, #data{}) ->
    cmkit:log({cmdb_db, node(), terminated, Reason}),
    ok.