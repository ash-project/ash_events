defmodule AshEvents.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_events,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        "test.create": :test,
        "test.migrate": :test,
        "test.rollback": :test,
        "test.migrate_tenants": :test,
        "test.check_migrations": :test,
        "test.drop": :test,
        "test.generate_migrations": :test,
        "test.reset": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  if Mix.env() == :test do
    def application() do
      [
        mod: {AshEvents.TestApp, []},
        extra_applications: [:logger]
      ]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sourceror, "~> 1.7", only: [:dev, :test]},
      # {:ash, "~> 3.0"},
      {:ash, path: "../ash", override: true},
      {:ash_postgres, "~> 2.0", only: [:dev, :test]},
      {:faker, "~> 0.18", only: :test}
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
      "test.drop": "ash_postgres.drop"
    ]
  end
end
