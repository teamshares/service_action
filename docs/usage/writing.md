---
outline: deep
---

# How to _build_ an Action

The core boilerplate is pretty minimal:

```ruby
class Foo
  include Action

  def call
    # ... do some stuff here?
  end
end
```

## Declare the interface

The first step is to determine what arguments you expect to be passed into `call`.  These are declared via the `expects` keyword.

If you want to expose any results to the caller, declare that via the `exposes` keyword.

Both of these optionally accept `type:`, `allow_blank:`, and any other ActiveModel validation (see: [reference](/reference/class)).


```ruby
class Foo
  include Action

  expects :name, type: String # [!code focus:2]
  exposes :meaning_of_life

  def call
    # ... do some stuff here?
  end
end
```

## Implement the action

Once the interface is defined, you're primarily focused on defining the `call` method.

To abort execution with a specific error message, call `fail!`.

If you declare that your action `exposes` anything, you need to actually `expose` it.

```ruby
class Foo
  include Action

  expects :name, type: String
  exposes :meaning_of_life

  def call
    fail! "Douglas already knows the meaning" if name == "Doug" # [!code focus]

    msg = "Hello #{name}, the meaning of life is 42"
    expose meaning_of_life: msg # [!code focus]
  end
end
```

See [the reference doc](/reference/instance) for a few more handy helper methods (e.g. `#log`).

## Customizing messages

::: danger ALPHA
* TODO: document `messages` setup
:::


## Lifecycle methods

In addition to `#call`, there are a few additional pieces to be aware of:

### `#rollback`

If you define a `#rollback` method, it'll be called (_before_ returning an `Action::Result` to the caller) whenever your action fails.

### Hooks

`before`, `after`, and `around` hooks are also supported.

### Concrete example

Given this series of methods and hooks:

```ruby
class Foo
  include Action

  before { log("before hook") }
  after { log("after hook") }

  def call
    log("in call")
    raise "oh no something borked"
  end

  def rollback
    log("rolling back")
  end
end
```

`Foo.call` would fail (because of the raise), but along the way would end up logging:

```text
before hook
in call
after hook
rolling back
```

## Debugging
Remember you can [enable debug logging](/reference/configuration.html#global-debug-logging) to print log lines before and after each action is executed.
