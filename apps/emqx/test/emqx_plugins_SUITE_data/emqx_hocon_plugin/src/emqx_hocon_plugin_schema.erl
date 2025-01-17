-module(emqx_hocon_plugin_schema).

-include_lib("typerefl/include/types.hrl").

-export([roots/0, fields/1]).

-behaviour(hocon_schema).

roots() -> ["emqx_hocon_plugin"].

fields("emqx_hocon_plugin") ->
    [{name, fun name/1}].

name(type) -> binary();
name(_) -> undefined.
