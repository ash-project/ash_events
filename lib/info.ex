defmodule AshEvents.Info do
  use Spark.InfoGenerator, extension: AshEvents, sections: [:events]
end
