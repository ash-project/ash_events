# Used by "mix format"
spark_locals_without_parens = [
  allow_nil?: 1,
  attribute_type: 1,
  clear_records_for_replay: 1,
  current_action_versions: 1,
  event_log: 1,
  ignore_actions: 1,
  persist_actor_primary_key: 2,
  persist_actor_primary_key: 3,
  public?: 1,
  record_id_type: 1,
  replay_override: 2,
  replay_override: 3,
  route_to: 2,
  route_to: 3,
  versions: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ash, :ash_postgres],
  plugins: [Spark.Formatter],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
