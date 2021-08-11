%%--------------------------------------------------------------------
%% Copyright (c) 2017-2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_coap_resource).

-include("emqx_coap.hrl").

-type context() :: any().
-type topic() :: binary().
-type token() :: token().

-type register() :: {topic(), token()}
                  | topic()
                  | undefined.

-type result() :: emqx_coap_message()
                | {has_sub, emqx_coap_message(), register()}.

-callback init(hocon:confg()) -> context().
-callback stop(context()) -> ok.
-callback get(emqx_coap_message(), hocon:config()) -> result().
-callback put(emqx_coap_message(), hocon:config()) -> result().
-callback post(emqx_coap_message(), hocon:config()) -> result().
-callback delete(emqx_coap_message(), hocon:config()) -> result().
