---
outline: deep
---

# Introduction

This library provides a set of conventions for where to put your business logic in Rails (or other Ruby) applications.

## The basic idea

Your logic goes in a <abbr title="Plain Old Ruby Object">PORO</abbr>. The only requirements are `include Action` and a `call` method:

```ruby
class Foo
  include Action

  def call
    log "Doesn't do much, but this technically works..."
  end
end
```

These humble beginnings give you:

  * Clear calling semantics: `Foo.call`
  * A [consistent return interface](./#return-interface): always responds to `ok?`, `error` has a safe-to-show-users string if not `ok?`


## Inputs and Outflows

### Overview

Most actions need input, though. No need for any `def initialize` boilerplate, just:

  * Declare what inputs the class will _receive_ via `expects :foo`.

    You pass the `expect`ed keyword arguments to `call`, then reference their values as local `attr_reader`s.
  * Declare what outputs the class will _expose_ via `exposes :bar`.

    Within your action you use `expose :foo, <value>` to set a value that will be available on the return interface.

::: info
By design you cannot access anything you do not explicitly `expose` from outside the action itself.  Making the external interface explicit helps maintainability by ensuring you can refactor internals without breaking existing callsites.
:::

### Details
Both of those keywords support a variety of options:

| Option | Example | Meaning |
| -- | -- | -- |
| `sensitive` | `expects :password, sensitive: true` | Filters the fields value when logging, reporting errors, or calling `inspect`
| `default` | `expects :foo, default: 123` | If `foo` isn't provided, it'll default to this value
| `allow_blank` | `expects :foo, allow_blank: true` | Don't fail if the value is blank
| `type` | `expects :foo, type: String` | Custom validator -- fail unless `foo.is_a?(String)`
| anything else | `expects :foo, inclusion: { in: [:apple, :peach] }` | Any other arguments will be processed as ActiveModel validations (i.e. as if passed to `validate :foo, <...>` on an ActiveRecord model)

If any expectations fail, the action will fail early and set `error` to a generic error message (because a failed validation means _you_ called _your own_ service wrong; there's nothing the end user can do about that).

::: warning
The declarative `expects` interface is a contract you are making _with yourself_ (and your fellow developers). **This is _not_ for validating user input** -- [there's a Form Object pattern for that](/advanced/validating-user-input).
:::

### Putting it together

```ruby
class Actions::Slack::Post
  include Action
  VALID_CHANNELS = [ ... ]

  expects :channel, default: VALID_CHANNELS.first, inclusion: { in: VALID_CHANNELS } # [!code focus:4]
  expects :message, type: String

  exposes :thread_id, type: String

  def call
    response = client.chat_postMessage(channel:, text: message)
    the_thread_id = response["ts"]

    expose :thread_id, the_thread_id # [!code focus]
  end

  private

  def client = Slack::Web::Client.new
end
```

## Error handling

::: tip BIG IDEA
By design, `result.error` is always safe to show to the user.

:star_struck: The calling code usually only cares about `ok?` and `error` -- no complex error handling needed.
:::

### Overview

We make a clear distinction between user-facing and internal errors.

#### User-facing errors (`fail_with`)

For _known_ failure modes, you can call `fail_with("Some user-facing explanation")` at any time to abort execution and set `result.error` to your custom message.

#### Internal errors (uncaught `raise`)

Otherwise, any raised exception will be swallowed and the action failed (i.e. _not_ `ok?`). `result.error` will be set to a generic "Something went wrong" error message.

The swallowed exception will be available on `result.exception` for your introspection, but it'll also be passed to your `on_exception` handler so, [with a bit of configuration](/getting-started/), you can trust that any exceptions have been logged to your error tracking service automatically (one more thing the dev doesn't need to think about).

### Details

::: danger ALPHA
* TODO:  document the on_exception configuration
* TODO: document how to override the generic error + add per-error-type string mappings
:::

### Putting it together

```ruby
class Actions::Slack::Post
  include Action

  expects :channel, default: VALID_CHANNELS.first
  expects :message, type: String
  expects :user, type: User

  exposes :thread_id, type: String

  before do
    # NOTE: this could be done at the top of `call`, but using a before hook leaves the main method more scannable
    fail_with "You are not authorized to post to '#{channel}'" unless authorized? # [!code focus]
  end

  def call
    response = client.chat_postMessage(channel:, text: message)
    the_thread_id = response["ts"]

    expose :thread_id, the_thread_id
  end

  private

  def client = Slack::Web::Client.new

  def authorized?
    # ... your user authorization logic
  end
end
```

## Consistent return interface {#return-interface}

The return value of an Action call always has the same shape:

| Method | Description |
| -- | -- |
| `ok?` | `true` if the call succeeded, `false` if not.
| `error` | Will _always_ be set to a safe-to-show-users string if not `ok?`
| any `expose`d values | guaranteed to be set if `ok?`, since they have outgoing presence validation by default

::: danger ALPHA
* TODO: link to a reference page for the full interface.
:::


Which gives a simple common usage pattern:


```ruby
class MessagesController < ApplicationController
  def create
    result = Actions::Slack::Post.call( # [!code focus]
      channel: "#engineering",
      message: params[:message],
      user: current_user,
    )

    if result.ok?  # [!code focus:2]
      @thread_id = result.thread_id
      flash.now[:success] = "Sent the Slack message"
    else
      flash[:alert] = result.error # [!code focus]
      redirect_to action: :new
    end
  end
end
```

Note this simple pattern handles multiple levels of "failure":
* Showing specific user-facing flash messages for any arbitrary logic you want in your action (from `fail_with`)
* Showing generic error message if anything went wrong internally (e.g. the Slack client raised an exception -- it's been logged for the team to investigate, but the controller doesn't need to care _what_ went wrong)
* Showing generic error message if any of your declared interface expectations fail (e.g. if the exposed `thread_id`, which we pulled from Slack's API response, somehow _isn't_ a String)
