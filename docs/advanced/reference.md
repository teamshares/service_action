::: danger ALPHA
* TODO: convert rough notes into actual documentation
:::

## Rough Notes

Set up configuration to log at info level for all:

    Action.configure do |c|
      c.global_debug_logging = false
      c.on_exception = ...
      c.top_level_around_hook = ...
    end

* document `custom_error` (default/global + per-exception type)
* Note we have two custom validations: boolean: true and the implicit type: foo.  (maybe with array of types?)
    Note a third allows custom validations: `expects :foo, validate: ->(value) { "must be pretty big" unless value > 10 }` (error raised if any string returned OR if it raises an exception)
* call! -- will raise any exceptions OR our own Action::Failure if user-facing error occurred (otherwise non-bang will never raise)
    * note call! still logs completion even if failure (from configuration's on_exception)
* enqueue vs enqueue!
    * enqueue will not retry even if fails
    * enqueue! will go through normal sidekiq retries on any failure (including user-facing `fail!`)
    * Note implicit GlobalID support (if not serializable, will get ArgumentError at callsite)

* General note: the inbound/outbound contexts are views into an underlying shared object (passed down through organize calls) -- modifications of one will affect the other (e.g. preprocessing inbound args implicitly transforms them on the underlying context, which is echoed if you also expose it on outbound).
* Configuring logging (will default to Rails.logger if available, else fall back to basic Logger (but can explicitly set via `self.logger = Logger.new($stdout`))
    Note `context_for_logging` is available (filtered to accessible attrs, filtering out sensitive values). Automatically passed into `on_exception` hook.

* setting `sensitive: true` on any param will filter that value out when inspecting or passing to on_exception
* feature: `noncritical do` [UPDATE: `try do`] - within this block, any exceptions will be logged (on_exception handler), but will NOT fail the interactor
    edge case: `fail!` _will_ still fail the parent interactor
* logging - all entrance/exit logged by default at debug level. can set logger level, or define class method targeted_for_debug_logging? = true, or set the env var... (Ability to toggle on debug logging for any specific actor without going through CI run.)

* hoist_errors -- (CAUTION: if there are multiple calls per block, only the last one will be checked)

---

Composition: see composition_spec.rb -- note if you add e.g. an expects, it'll get ADDED to those from the base layer
Inheritance: work in progress
