# Used by "mix format"
spark_locals_without_parens = [
  advisory_lock_key_default: 1,
  advisory_lock_key_generator: 1,
  allow_nil?: 1,
  allowed_change_modules: 1,
  attribute_type: 1,
  clear_records_for_replay: 1,
  cloak_vault: 1,
  create_timestamp: 1,
  current_action_versions: 1,
  event_log: 1,
  ignore_actions: 1,
  only_actions: 1,
  persist_actor_primary_key: 2,
  persist_actor_primary_key: 3,
  primary_key_type: 1,
  public?: 1,
  record_id_type: 1,
  replay_non_input_attribute_changes: 1,
  replay_override: 2,
  replay_override: 3,
  route_to: 2,
  route_to: 3,
  update_timestamp: 1,
  versions: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ash, :ash_postgres, :ash_state_machine],
  plugins: [Spark.Formatter],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
