---
outline: deep
---


# How to _use_ an Action

## Common Case

An action is usually executed via `#call`, and _always_ returns an instance of the `Action::Result` class.

This means the result _always_ implements a consistent interface, including `ok?` and `error` (see [full details](/reference/action-result)) as well as any variables that it `exposes`.  Remember any exceptions have been swallowed.

As a consumer, you usually want a conditional that surfaces `error` unless the result is `ok?`, and otherwise takes whatever success action is relevant.

For example:

```ruby
class MessagesController < ApplicationController
  def create
    result = Actions::Slack::Post.call( # [!code focus]
      channel: "#engineering",
      message: params[:message],
    )

    if result.ok?  # [!code focus:2]
      @thread_id = result.thread_id # Because `thread_id` was explicitly exposed
      flash.now[:success] = "Sent the Slack message"
    else
      flash[:alert] = result.error # [!code focus]
      redirect_to action: :new
    end
  end
end
```

<!-- TODO: replace manual flash success with result.success (here and in guide?) -->


## Advanced Usage

### `#call!`

::: danger ALPHA
* TODO - flesh out this section
:::


* `call!`
    * call! -- will raise any exceptions OR our own Action::Failure if user-facing error occurred (otherwise non-bang will never raise)
    * note call! still logs completion even if failure (from configuration's on_exception)


### `#enqueue`

Before adopting this library, our code was littered with one-line workers whose only job was to fire off a service on a background job.  We were able to remove that entire glue layer by directly supporting enqueueing sidekiq jobs from the Action itself.

::: danger ALPHA
Sidekiq integration is NOT YET TESTED/NOT YET USED IN OUR APP, and naming will VERY LIKELY change to make it clearer which actions will be retried!
:::

* enqueue vs enqueue!
    * enqueue will not retry even if fails
    * enqueue! will go through normal sidekiq retries on any failure (including user-facing `fail!`)
    * Note implicit GlobalID support (if not serializable, will get ArgumentError at callsite)
