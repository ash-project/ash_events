defmodule AshEventSource.Info do
  use Spark.InfoGenerator, extension: AshEventSource, sections: [:event_source]
end
