-module(cmdb_sup).
-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).
-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    Dbs = lists:map(fun(Props) ->
                        maps:from_list(Props)
                    end, cmkit:config(dbs, cmdb)),
    
    Routers = [ db_spec(Db) || Db <- Dbs ],
    Cloud =  cloud_spec(Dbs),
    {ok, {{one_for_one, 0, 1}, [Cloud | Routers] }}.

cloud_spec(Dbs) ->
    cmkit:child_spec(cmdb_cloud, cmdb_cloud, [Dbs], worker).

db_spec(#{ name := Name}=Db) ->
    Mod = db_impl(Db),
    cmkit:child_spec(Name, Mod, [Db], worker).

db_impl(#{ scheme := http}) -> cmdb_client;
db_impl(#{ scheme := disc}) -> cmdb_dets;
db_impl(#{ scheme := memory}) -> cmdb_ets.

