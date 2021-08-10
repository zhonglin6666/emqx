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

-define(CONF_DEFAULT, <<"authorization: {rules: []}">>).

all() ->
    emqx_ct:all(?MODULE).

groups() ->
    [].

init_per_suite(Config) ->
    ekka_mnesia:start(),
    emqx_mgmt_auth:mnesia(boot),
    ok = emqx_ct_helpers:start_apps([emqx_management, emqx_authz], fun set_special_configs/1),
    ok = emqx_config:update([zones, default, authorization, cache, enable], false),
    ok = emqx_config:update([zones, default, authorization, enable], true),

    Config.

end_per_suite(_Config) ->
    ok = emqx_authz:update(replace, []),
    emqx_ct_helpers:stop_apps([emqx_authz, emqx_management]),
    ok.

set_special_configs(emqx_management) ->
    emqx_config:put([emqx_management], #{listeners => [#{protocol => http, port => 8081}],
        applications =>[#{id => "admin", secret => "public"}]}),
    ok;
set_special_configs(emqx_authz) ->
    emqx_config:put([authorization], #{rules => []}),
    ok;
set_special_configs(_App) ->
    ok.

%%------------------------------------------------------------------------------
%% Testcases
%%------------------------------------------------------------------------------

t_post(_) ->
    {ok, 200, Result1} = request(get, uri(["authorization"]), []),
    ?assertEqual([], get_rules(Result1)),

    {ok, 201, _} = request(post, uri(["authorization"]),
                           #{<<"action">> => <<"all">>, <<"permission">> => <<"deny">>,
                             <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}),
    {ok, 201, _} = request(post, uri(["authorization"]),
                           #{<<"action">> => <<"all">>, <<"permission">> => <<"deny">>,
                             <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}),
    {ok, 201, _} = request(post, uri(["authorization"]),
                           #{<<"action">> => <<"all">>, <<"permission">> => <<"deny">>,
                             <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}),
    {ok, 200, Result2} = request(get, uri(["authorization"]), []),
    ?assertEqual(3, length(get_rules(Result2))),

    {ok, 204, _} = request(put, uri(["authorization"]),
                           [ #{<<"action">> => <<"all">>, <<"permission">> => <<"allow">>, <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}
                           , #{<<"action">> => <<"all">>, <<"permission">> => <<"allow">>, <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}
                           , #{<<"action">> => <<"all">>, <<"permission">> => <<"allow">>, <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}
                           , #{<<"action">> => <<"all">>, <<"permission">> => <<"allow">>, <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}
                           ]),

    {ok, 200, Result3} = request(get, uri(["authorization"]), []),
    Rules = get_rules(Result3),
    ?assertEqual(4, length(Rules)),

    lists:foreach(fun(#{<<"permission">> := Allow}) ->
                          ?assertEqual(<<"allow">>, Allow)
                  end, Rules),

    #{<<"annotations">> := #{<<"id">> := Id}} = lists:nth(2, Rules),

    {ok, 204, _} = request(put, uri(["authorization", binary_to_list(Id)]),
                           #{<<"action">> => <<"all">>, <<"permission">> => <<"deny">>,
                             <<"principal">> => <<"all">>, <<"topics">> => [<<"#">>]}),

    {ok, 200, Result4} = request(get, uri(["authorization", binary_to_list(Id)]), []),
    ?assertMatch(#{<<"annotations">> := #{<<"id">> := Id},
                   <<"permission">> := <<"deny">>
                  }, jsx:decode(Result4)),

    lists:foreach(fun(#{<<"annotations">> := #{<<"id">> := Id}}) ->
                    {ok, 204, _} = request(delete, uri(["authorization", binary_to_list(Id)]), [])
                  end, Rules),
    {ok, 200, Result5} = request(get, uri(["authorization"]), []),
    ?assertEqual([], get_rules(Result5)),
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