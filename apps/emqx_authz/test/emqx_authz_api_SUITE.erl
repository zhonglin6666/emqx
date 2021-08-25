%%--------------------------------------------------------------------
%% Copyright (c) 2020-2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_authz_api_SUITE).

-compile(nowarn_export_all).
-compile(export_all).

-include("emqx_authz.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-define(CONF_DEFAULT, <<"authorization_rules: {rules: []}">>).

-import(emqx_ct_http, [ request_api/3
                      , request_api/5
                      , get_http_data/1
                      , create_default_app/0
                      , delete_default_app/0
                      , default_auth_header/0
                      , auth_header/2
                      ]).

-define(HOST, "http://127.0.0.1:8081/").
-define(API_VERSION, "v5").
-define(BASE_PATH, "api").

-define(RULE1, #{<<"type">> => <<"http">>,
                 <<"config">> => #{
                    <<"url">> => <<"https://fake.com:443/">>,
                    <<"headers">> => #{},
                    <<"method">> => <<"get">>,
                    <<"request_timeout">> => 5000}
                }).
-define(RULE2, #{<<"type">> => <<"mongo">>,
                 <<"config">> => #{
                        <<"mongo_type">> => <<"single">>,
                        <<"server">> => <<"127.0.0.1:27017">>,
                        <<"pool_size">> => 1,
                        <<"database">> => <<"mqtt">>,
                        <<"ssl">> => #{<<"enable">> => false}},
                 <<"collection">> => <<"fake">>,
                 <<"find">> => #{<<"a">> => <<"b">>}
                }).
-define(RULE3, #{<<"type">> => <<"mysql">>,
                 <<"config">> => #{
                     <<"server">> => <<"127.0.0.1:27017">>,
                     <<"pool_size">> => 1,
                     <<"database">> => <<"mqtt">>,
                     <<"username">> => <<"xx">>,
                     <<"password">> => <<"ee">>,
                     <<"auto_reconnect">> => true,
                     <<"ssl">> => #{<<"enable">> => false}},
                 <<"sql">> => <<"abcb">>
                }).
-define(RULE4, #{<<"type">> => <<"pgsql">>,
                 <<"config">> => #{
                     <<"server">> => <<"127.0.0.1:27017">>,
                     <<"pool_size">> => 1,
                     <<"database">> => <<"mqtt">>,
                     <<"username">> => <<"xx">>,
                     <<"password">> => <<"ee">>,
                     <<"auto_reconnect">> => true,
                     <<"ssl">> => #{<<"enable">> => false}},
                 <<"sql">> => <<"abcb">>
                }).
-define(RULE5, #{<<"type">> => <<"redis">>,
                 <<"config">> => #{
                     <<"server">> => <<"127.0.0.1:27017">>,
                     <<"pool_size">> => 1,
                     <<"database">> => 0,
                     <<"password">> => <<"ee">>,
                     <<"auto_reconnect">> => true,
                     <<"ssl">> => #{<<"enable">> => false}},
                 <<"cmd">> => <<"HGETALL mqtt_authz:%u">>
                }).

all() ->
    emqx_ct:all(?MODULE).

groups() ->
    [].

init_per_suite(Config) ->
    meck:new(emqx_resource, [non_strict, passthrough, no_history, no_link]),
    meck:expect(emqx_resource, create, fun(_, _, _) -> {ok, meck_data} end),
    meck:expect(emqx_resource, update, fun(_, _, _, _) -> {ok, meck_data} end),
    meck:expect(emqx_resource, health_check, fun(_) -> ok end),
    meck:expect(emqx_resource, remove, fun(_) -> ok end ),

    ekka_mnesia:start(),
    emqx_mgmt_auth:mnesia(boot),

    ok = emqx_config:init_load(emqx_authz_schema, ?CONF_DEFAULT),
    ok = emqx_ct_helpers:start_apps([emqx_management, emqx_authz], fun set_special_configs/1),
    {ok, _} = emqx:update_config([authorization, cache, enable], false),
    {ok, _} = emqx:update_config([authorization, no_match], deny),

    Config.

end_per_suite(_Config) ->
    {ok, _} = emqx_authz:update(replace, []),
    emqx_ct_helpers:stop_apps([emqx_resource, emqx_authz, emqx_management]),
    meck:unload(emqx_resource),
    ok.

set_special_configs(emqx_management) ->
    emqx_config:put([emqx_management], #{listeners => [#{protocol => http, port => 8081}],
        applications =>[#{id => "admin", secret => "public"}]}),
    ok;
set_special_configs(emqx_authz) ->
    emqx_config:put([authorization_rules], #{rules => []}),
    ok;
set_special_configs(_App) ->
    ok.

%%------------------------------------------------------------------------------
%% Testcases
%%------------------------------------------------------------------------------

t_api(_) ->
    {ok, 200, Result1} = request(get, uri(["authorization"]), []),
    ?assertEqual([], get_rules(Result1)),

    lists:foreach(fun(_) ->
                        {ok, 204, _} = request(post, uri(["authorization"]), ?RULE1)
                  end, lists:seq(1, 20)),
    {ok, 200, Result2} = request(get, uri(["authorization"]), []),
    ?assertEqual(20, length(get_rules(Result2))),

    lists:foreach(fun(Page) ->
                          Query = "?page=" ++ integer_to_list(Page) ++ "&&limit=10",
                          Url = uri(["authorization" ++ Query]),
                          {ok, 200, Result} = request(get, Url, []),
                          ?assertEqual(10, length(get_rules(Result)))
                  end, lists:seq(1, 2)),

    {ok, 204, _} = request(put, uri(["authorization"]), [?RULE1, ?RULE2, ?RULE3, ?RULE4]),

    {ok, 200, Result3} = request(get, uri(["authorization"]), []),
    Rules = get_rules(Result3),
    ?assertEqual(4, length(Rules)),
    ?assertMatch([ #{<<"type">> := <<"http">>}
                 , #{<<"type">> := <<"mongo">>}
                 , #{<<"type">> := <<"mysql">>}
                 , #{<<"type">> := <<"pgsql">>}
                 ], Rules),

    #{<<"annotations">> := #{<<"id">> := Id}} = lists:nth(2, Rules),

    {ok, 204, _} = request(put, uri(["authorization", binary_to_list(Id)]), ?RULE5),

    {ok, 200, Result4} = request(get, uri(["authorization", binary_to_list(Id)]), []),
    ?assertMatch(#{<<"type">> := <<"redis">>}, jsx:decode(Result4)),

    lists:foreach(fun(#{<<"annotations">> := #{<<"id">> := Id0}}) ->
                    {ok, 204, _} = request(delete, uri(["authorization", binary_to_list(Id0)]), [])
                  end, Rules),
    {ok, 200, Result5} = request(get, uri(["authorization"]), []),
    ?assertEqual([], get_rules(Result5)),
    ok.

t_move_rule(_) ->
    {ok, _} = emqx_authz:update(replace, [?RULE1, ?RULE2, ?RULE3, ?RULE4, ?RULE5]),
    [#{annotations := #{id := Id1}},
     #{annotations := #{id := Id2}},
     #{annotations := #{id := Id3}},
     #{annotations := #{id := Id4}},
     #{annotations := #{id := Id5}}
    ] = emqx_authz:lookup(),

    {ok, 204, _} = request(post, uri(["authorization", Id4, "move"]),
                           #{<<"position">> => <<"top">>}),
    ?assertMatch([#{annotations := #{id := Id4}},
                  #{annotations := #{id := Id1}},
                  #{annotations := #{id := Id2}},
                  #{annotations := #{id := Id3}},
                  #{annotations := #{id := Id5}}
                 ], emqx_authz:lookup()),

    {ok, 204, _} = request(post, uri(["authorization", Id1, "move"]),
                           #{<<"position">> => <<"bottom">>}),
    ?assertMatch([#{annotations := #{id := Id4}},
                  #{annotations := #{id := Id2}},
                  #{annotations := #{id := Id3}},
                  #{annotations := #{id := Id5}},
                  #{annotations := #{id := Id1}}
                 ], emqx_authz:lookup()),

    {ok, 204, _} = request(post, uri(["authorization", Id3, "move"]),
                           #{<<"position">> => #{<<"before">> => Id4}}),
    ?assertMatch([#{annotations := #{id := Id3}},
                  #{annotations := #{id := Id4}},
                  #{annotations := #{id := Id2}},
                  #{annotations := #{id := Id5}},
                  #{annotations := #{id := Id1}}
                 ], emqx_authz:lookup()),

    {ok, 204, _} = request(post, uri(["authorization", Id2, "move"]),
                           #{<<"position">> => #{<<"after">> => Id1}}),
    ?assertMatch([#{annotations := #{id := Id3}},
                  #{annotations := #{id := Id4}},
                  #{annotations := #{id := Id5}},
                  #{annotations := #{id := Id1}},
                  #{annotations := #{id := Id2}}
                 ], emqx_authz:lookup()),

    ok.

%%--------------------------------------------------------------------
%% HTTP Request
%%--------------------------------------------------------------------

request(Method, Url, Body) ->
    Request = case Body of
        [] -> {Url, [auth_header("admin", "public")]};
        _ -> {Url, [auth_header("admin", "public")], "application/json", jsx:encode(Body)}
    end,
    ct:pal("Method: ~p, Request: ~p", [Method, Request]),
    case httpc:request(Method, Request, [], [{body_format, binary}]) of
        {error, socket_closed_remotely} ->
            {error, socket_closed_remotely};
        {ok, {{"HTTP/1.1", Code, _}, _Headers, Return} } ->
            {ok, Code, Return};
        {ok, {Reason, _, _}} ->
            {error, Reason}
    end.

uri() -> uri([]).
uri(Parts) when is_list(Parts) ->
    NParts = [E || E <- Parts],
    ?HOST ++ filename:join([?BASE_PATH, ?API_VERSION | NParts]).

get_rules(Result) ->
    maps:get(<<"rules">>, jsx:decode(Result), []).