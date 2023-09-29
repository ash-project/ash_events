# AshEvents

A fledgeling Ash extension for transforming Ash resources to use an event oriented architecture. This is still an experiment, it only supports create actions (but could be made to support updates and destroys without much trouble).

Caveats:

* We aren't storing the actor in any way. We would need to store actor information to perform authorization.
* the event_driven version is not really distinguishable from `ash_paper_trail` except that it has fewer features and writes to a single events resource.
* if you want to use this, you would have to do work to get it ready for your cases.

Configure the style using the `style` option, for example:

```elixir
events do
  style :event_sourced
end
```

The default is `:event_driven`, and generally means there is nothing to do
except integrate this extension.

## Event Driven

Event driven architecture is relatively simple. We encode the inputs to the action into an event and commit that event alongside the performance of the action, transactionally.

## Event Sourced

With event sourced, things change quite a bit. Instead of storing the event and performing the action, we only store the event, and it is *your responsibility* to take each event, perform the action it refers to and mark it as processed, in whatever way you see fit.
