# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

import Config

if Mix.env() == :test do
  config :ash,
    validate_domain_resource_inclusion?: false,
    validate_domain_config_inclusion?: false,
    disable_async?: true,
    missed_notifications: :raise

  config :ash_events, AshEvents.TestRepo,
    username: "postgres",
    # sobelow_skip ["Config.Secrets"]
    password: "postgres",
    hostname: "localhost",
    database: "ash_events_test",
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10,
    pool: Ecto.Adapters.SQL.Sandbox,
    log: false,
    prepare: :unnamed

  config :ash_events,
    event_resource_primary_key_type: :uuid,
    ecto_repos: [AshEvents.TestRepo],
    token_signing_secret: "AKb07o/7PVJ8OBLvKyS7XFkcZKy6ZfSj",
    ash_domains: [
      AshEvents.EventLogs,
      AshEvents.Accounts
    ]

  config :ash_events, AshEvents.Vault,
    ciphers: [
      default: {
        Cloak.Ciphers.AES.GCM,
        tag: "AES.GCM.V1",
        key: Base.decode64!("1SdF1cWOVIJFvPnGPFjB2RQ7AdvUq7s8fCfOj1gPp0w="),
        iv_length: 12
      }
    ]
end

import_config "#{config_env()}.exs"
