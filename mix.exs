defmodule EMQXUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      # apps_path: "apps",
      app: :emqx_mix,
      version: pkg_vsn(),
      # start_permanent: Mix.env() == :prod,
      start_permanent: false,
      deps: deps(),
      releases: releases()
    ]
  end

  def application() do
    [
      mod: {:emqx_machine_app, []},
      # extra_applications: [:mnesia, :runtime_tools],
      extra_applications: []
    ]
  end

  defp elixirc_paths(_), do: ["apps/emqx"]

  defp deps do
    [
      {:jiffy, github: "emqx/jiffy", tag: "1.0.5", override: true},
      {:jsx, "~> 3.1", override: true},
      {:gun, github: "emqx/gun", tag: "1.3.4", override: true},
      {:cuttlefish,
       github: "emqx/cuttlefish",
       manager: :rebar3,
       system_env: [{"CUTTLEFISH_ESCRIPT", "true"}],
       override: true},
      {:getopt, github: "emqx/getopt", tag: "v1.0.2", override: true},
      {:cowboy, github: "emqx/cowboy", tag: "2.8.2", override: true},
      {:cowlib, "~> 2.8", override: true},
      {:ranch, "~> 2.0", override: true},
      {:poolboy, github: "emqx/poolboy", tag: "1.5.2", override: true},
      {:esockd, github: "emqx/esockd", tag: "5.8.0", override: true},
      {:gproc, "~> 0.9", override: true},
      {:eetcd, "~> 0.3", override: true},
      {:grpc, github: "emqx/grpc-erl", tag: "0.6.2", override: true},
      {:pbkdf2, github: "emqx/erlang-pbkdf2", tag: "2.0.4", override: true},
      {:typerefl, github: "k32/typerefl", tag: "0.8.4", manager: :rebar3, override: true},
      {:gen_rpc, github: "emqx/gen_rpc", tag: "2.5.1", override: true},
      {:gen_coap, github: "emqx/gen_coap", tag: "v0.3.2", override: true},
      {:snabbkaffe, github: "kafka4beam/snabbkaffe", tag: "0.14.0", override: true},
      {:emqx_http_lib, github: "emqx/emqx_http_lib", tag: "0.4.0", override: true},
      ####
      {:quicer, github: "emqx/quic", tag: "0.0.9", override: true},
      {:ecpool, github: "emqx/ecpool", tag: "0.5.1"},
      {:ehttpc, github: "emqx/ehttpc", tag: "0.1.12"},
      {:hocon, github: "emqx/hocon", tag: "0.22.0", override: true, runtime: false},
      {:mria, github: "emqx/mria", tag: "0.1.4", override: true},
      {:minirest, github: "emqx/minirest", tag: "1.2.7"},
      {:rulesql, github: "emqx/rulesql", tag: "0.1.4"},
      ####
      {:emqx, path: "apps/emqx", in_umbrella: true},
      {:emqx_authz, path: "apps/emqx_authz", in_umbrella: true},
      {:emqx_conf, path: "apps/emqx_conf", in_umbrella: true},
      {:emqx_connector, path: "apps/emqx_connector", in_umbrella: true},
      {:emqx_resource, path: "apps/emqx_resource", in_umbrella: true, complile: :mix},
      {:emqx_authn, path: "apps/emqx_authn", in_umbrella: true},
      {:emqx_plugin_libs, path: "apps/emqx_plugin_libs", in_umbrella: true},
      {:emqx_bridge, path: "apps/emqx_bridge", in_umbrella: true},
      {:emqx_retainer, path: "apps/emqx_retainer", in_umbrella: true},
      {:emqx_statsd, path: "apps/emqx_statsd", in_umbrella: true},
      {:emqx_auto_subscribe, path: "apps/emqx_auto_subscribe", in_umbrella: true},
      {:emqx_machine, path: "apps/emqx_machine", in_umbrella: true},
      {:emqx_modules, path: "apps/emqx_modules", in_umbrella: true},
      {:emqx_dashboard, path: "apps/emqx_dashboard", in_umbrella: true},
      {:emqx_gateway, path: "apps/emqx_gateway", in_umbrella: true},
      {:emqx_prometheus, path: "apps/emqx_prometheus", in_umbrella: true},
      {:emqx_rule_engine, path: "apps/emqx_rule_engine", in_umbrella: true},
      {:emqx_exhook, path: "apps/emqx_exhook", in_umbrella: true},
      {:emqx_psk, path: "apps/emqx_psk", in_umbrella: true},
      {:emqx_limiter, path: "apps/emqx_limiter", in_umbrella: true},
      # undef minirest error without this one...
      {:emqx_management, path: "apps/emqx_management", in_umbrella: true},
    ] ++ ((enable_bcrypt() && [{:bcrypt, github: "emqx/erlang-bcrypt", tag: "0.6.0"}]) || [])
  end

  defp releases do
    [
      # emqx: fn ->
      #   [
      #     applications: EmqxReleaseHelper.applications(),
      #     steps: [:assemble, &EmqxReleaseHelper.run/1]
      #   ]
      # end
      emqx: [
        applications: [
          runtime_tools: :permanent,
          emqx: :load,
          # emqx_conf: :load, # as per rebar.config.erl
          emqx_conf: :permanent,
          emqx_machine: :permanent,
          mnesia: :load,
          ekka: :load,
          emqx_plugin_libs: :load,
          emqx_resource: :permanent,
          emqx_connector: :permanent,
          emqx_authn: :permanent,
          emqx_authz: :permanent,
          # emqx_auto_subscribe: :permanent,
          emqx_gateway: :permanent,
          emqx_exhook: :permanent,
          emqx_bridge: :permanent,
          emqx_rule_engine: :permanent,
          emqx_modules: :permanent,
          emqx_management: :permanent,
          emqx_dashboard: :permanent,
          emqx_retainer: :permanent,
          emqx_statsd: :permanent,
          emqx_prometheus: :permanent,
          emqx_psk: :permanent,
          emqx_limiter: :permanent,
          emqx_mix: :none,
        ]
      ]
    ]
  end

  def enable_bcrypt do
    not match?({:win_32, _}, :os.type())
  end

  def project_path do
    Path.expand("..", __ENV__.file)
  end

  def pkg_vsn do
    project_path()
    |> Path.join("pkg-vsn.sh")
    |> System.cmd([])
    |> elem(0)
    |> String.trim()
    |> String.split("-")
    |> Enum.reverse()
    |> tl()
    |> Enum.reverse()
    |> fix_vsn()
    |> Enum.join("-")
  end

  # FIXME: remove hack
  defp fix_vsn([vsn | extras]) do
    if Version.parse(vsn) == :error do
      [vsn <> ".0" | extras]
    else
      [vsn | extras]
    end
  end
end
