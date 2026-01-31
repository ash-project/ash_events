# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.MixProject do
  use Mix.Project

  @version "0.5.1"

  @description """
  The extension for tracking changes to your resources via a centralized event log, with replay functionality.
  """

  def project do
    [
      app: :ash_events,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: &docs/0,
      description: @description,
      source_url: "https://github.com/ash-project/ash_events",
      homepage_url: "https://github.com/ash-project/ash_events",
      dialyzer: [
        plt_add_apps: [:mix]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.create": :test,
        "test.migrate": :test,
        "test.rollback": :test,
        "test.migrate_tenants": :test,
        "test.check_migrations": :test,
        "test.drop": :test,
        "test.generate_migrations": :test,
        "test.reset": :test,
        tidewave: :test
      ]
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash", override: true]
      "main" -> [git: "https://github.com/ash-project/ash.git", override: true]
      version -> "~> #{version}"
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    application(Mix.env())
  end

  defp application(:test) do
    [
      mod: {AshEvents.TestApp, []},
      extra_applications: [:logger]
    ]
  end

  defp application(_) do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: [
        "Torkild Kjevik <torkild.kjevik@boitano.no>"
      ],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README*
        CHANGELOG* documentation usage-rules.md),
      links: %{
        "GitHub" => "https://github.com/ash-project/ash_events",
        "Changelog" => "https://github.com/ash-project/ash_events/blob/main/CHANGELOG.md",
        "Discord" => "https://discord.gg/HTHRaaVPUc",
        "Website" => "https://ash-hq.org",
        "Forum" => "https://elixirforum.com/c/elixir-framework-forums/ash-framework-forum",
        "REUSE Compliance" => "https://api.reuse.software/info/github.com/ash-project/ash_events"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      extras: [
        {"README.md", title: "Home"},
        {"documentation/dsls/DSL-AshEvents.EventLog.md",
         search_data: Spark.Docs.search_data_for(AshEvents.EventLog)},
        {"documentation/dsls/DSL-AshEvents.Events.md",
         search_data: Spark.Docs.search_data_for(AshEvents.Events)},
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls',
        "About AshEvents": [
          "CHANGELOG.md"
        ]
      ],
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:ash, ash_version("~> 3.5")},
      {:git_ops, "~> 2.0", only: [:dev], runtime: false},
      {:sourceror, "~> 1.7", only: [:dev, :test]},
      {:ash_postgres, "~> 2.0"},
      {:ash_authentication, ">= 4.10.0", only: [:dev, :test]},
      {:faker, "~> 0.18", only: :test},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:picosat_elixir, "~> 0.2", only: [:dev, :test]},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ash_cloak, "~> 0.1", only: [:dev, :test]},
      {:cloak, "~> 1.1", only: [:dev, :test]},
      {:ash_state_machine, "~> 0.2", only: [:dev, :test]},
      {:ash_phoenix, "~> 2.0", only: [:dev, :test]},
      {:bandit, "~> 1.0", only: [:dev, :test]},
      {:tidewave, ">= 0.5.0", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      "test.generate_migrations": "ash_postgres.generate_migrations",
      "test.check_migrations": "ash_postgres.generate_migrations --check",
      "test.migrate_tenants": "ash_postgres.migrate --tenants",
      "test.migrate": "ash_postgres.migrate",
      "test.rollback": "ash_postgres.rollback",
      "test.create": "ash_postgres.create",
      "test.reset": ["test.drop", "test.create", "test.migrate", "ash_postgres.migrate --tenants"],
      "test.drop": "ash_postgres.drop",
      tidewave:
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4022) end)'",
      sobelow: "sobelow --skip -i Config.HTTPS",
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ],
      credo: "credo --strict",
      "spark.formatter": "spark.formatter --extensions AshEvents.EventLog,AshEvents.Events",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshEvents.EventLog,AshEvents.Events"
    ]
  end
end
