# Used by "mix format"
spark_locals_without_parens = [
  event_resource: 1,
  event_name: 1,
  event_version: 1,
  persist_actor_id: 2,
  persist_actor_id: 3,
  event_handler: 1,
  event_handler: 2,
  before_dispatch: 1,
  on_success: 1,
  route_to: 2,
  version: 1,
  versions: 1,
  ignore_actions: 1,
  clear_records_for_replay: 1
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
