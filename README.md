# ServiceAction

Just spinning this up -- not yet released (i.e. doc updates to come later).

## Notes
set up configuration to log at info level for all:

    Action.configure do |c|
      c.global_debug_logging = false
      c.on_exception = ...
      c.top_level_around_hook = ...
    end

* document `error_message` (default/global + per-exception type)
* Note we have two custom validations: boolean: true and the implicit type: foo.  (maybe with array of types?)
    Note a third allows custom validations: `expects :foo, validate: ->(value) { "must be pretty big" unless value > 10 }` (error raised if any string returned OR if it raises an exception)
* call! -- will raise any exceptions OR our own Action::Failure if user-facing error occurred (otherwise non-bang will never raise)
    * note call! still logs completion even if failure (from configuration's on_exception)
* enqueue vs enqueue!
    * enqueue will not retry even if fails
    * enqueue! will go through normal sidekiq retries on any failure (including user-facing `fail_with`)
    * Note implicit GlobalID support (if not serializable, will get ArgumentError at callsite)

* General note: the inbound/outbound contexts are views into an underlying shared object (passed down through organize calls) -- modifications of one will affect the other (e.g. preprocessing inbound args implicitly transforms them on the underlying context, which is echoed if you also expose it on outbound).
* Configuring logging (will default to Rails.logger if available, else fall back to basic Logger (but can explicitly set via `self.logger = Logger.new($stdout`))
    Note `context_for_logging` is available (filtered to accessible attrs, filtering out sensitive values). Automatically passed into `on_exception` hook.

* setting `sensitive: true` on any param will filter that value out when inspecting or passing to on_exception
* feature: `noncritical do` - within this block, any exceptions will be logged (on_exception handler), but will NOT fail the interactor
    edge case: `fail_with` _will_ still fail the parent interactor
* logging - all entrance/exit logged by default at debug level. can set logger level, or define class method targeted_for_debug_logging? = true, or set the env var... (Ability to toggle on debug logging for any specific actor without going through CI run.)

* depends_on -- (CAUTION: if there are multiple calls per block, only the last one will be checked)

---

Composition: see composition_spec.rb -- note if you add e.g. an expects, it'll get ADDED to those from the base layer
Inheritance: work in progress

---

TODO: Delete this and the text below, and describe your gem

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/service_action`. To experiment with that code, run `bin/console` for an interactive prompt.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/teamshares/service_action.
