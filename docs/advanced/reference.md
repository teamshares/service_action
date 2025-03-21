::: danger ALPHA
* TODO: convert rough notes into actual documentation
:::

# How to _build_ an Action

* Hooks & call & rollback (screenshots on ticket)
* configuring logging (ENV["SA_DEBUG_TARGETS"])

## Class-level interface

* `expects`
* `exposes`
* `messages`

## Instance-level interface

* `expose`
* `fail!`
* `log`
* `try` - any exceptions raised by the block will trigger the on_exception handler, but then will be swallowed (the action is _not_ failed)
    * Edge case: explicit `fail!` calls _will_ still fail the action
* `hoist_errors`
    * Edge case: intent is a single action call in the block -- if there are multiple calls, only the last one will be checked (anything explicitly _raised_ will still be handled).
    <!-- TODO: is there difference between `SubAction.call!` and `hoist_errors { SubAction.call }`?? -->
* `context_for_logging` (and decent #inspect support)

### `expects` and `exposes`
* setting `sensitive: true` on any param will filter that value out when inspecting or passing to on_exception
* Note we have two custom validations: boolean: true and the implicit type: foo.  (maybe with array of types?)
    Note a third allows custom validations: `expects :foo, validate: ->(value) { "must be pretty big" unless value > 10 }` (error raised if any string returned OR if it raises an exception)


# How to _use_ an Action
* `call` and exception swallowing / consistent return interface

* `call!`
    <!-- TODO rough -->
    * call! -- will raise any exceptions OR our own Action::Failure if user-facing error occurred (otherwise non-bang will never raise)
    * note call! still logs completion even if failure (from configuration's on_exception)

---

::: danger ALPHA
Sidekiq integration is NOT YET TESTED/NOT YET USED IN OUR APP, and naming will very likely change to make it clearer which actions will be retried!
:::

* enqueue vs enqueue!
    * enqueue will not retry even if fails
    * enqueue! will go through normal sidekiq retries on any failure (including user-facing `fail!`)
    * Note implicit GlobalID support (if not serializable, will get ArgumentError at callsite)

---

`Action::Result`
    * ok?
    * error
    * exception
    * success
    * message


## Rough Notes

* General note: the inbound/outbound contexts are views into an underlying shared object (passed down through organize calls) -- modifications of one will affect the other (e.g. preprocessing inbound args implicitly transforms them on the underlying context, which is echoed if you also expose it on outbound).

* Configuring logging (will default to Rails.logger if available, else fall back to basic Logger (but can explicitly set via `self.logger = Logger.new($stdout`))
    Note `context_for_logging` is available (filtered to accessible attrs, filtering out sensitive values). Automatically passed into `on_exception` hook.

* logging - all entrance/exit logged by default at debug level. can set logger level, or define class method targeted_for_debug_logging? = true, or set the env var... (Ability to toggle on debug logging for any specific actor without going through CI run.)
