# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  locals_without_parens: [
    event_name: 1,
    event_version: 1,
    belongs_to_actor: 2,
    event_handler: 1,
    event_handler: 2,
    before_dispatch: 1,
    after_dispatch: 1
  ]
]
