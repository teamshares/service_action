# Getting Started

::: danger ALPHA
This section will document global configuration for your Actions (i.e. what steps to take so you can rely on all your swallowed exceptions getting reported to your tracking service).
:::


```ruby
  Action.configure do |c|
    # Set up configuration to log at info level for all:
    c.global_debug_logging = false

    c.on_exception = ...

    c.top_level_around_hook = ...
  end
```
