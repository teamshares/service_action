::: danger ALPHA
* TODO: convert this rough outline into actual documentation
:::


While coding:
* `expose`
* `fail!`
* `log`
* `try` - any exceptions raised by the block will trigger the on_exception handler, but then will be swallowed (the action is _not_ failed)
    * Edge case: explicit `fail!` calls _will_ still fail the action
* `hoist_errors`
    * Edge case: intent is a single action call in the block -- if there are multiple calls, only the last one will be checked (anything explicitly _raised_ will still be handled).
    <!-- TODO: is there difference between `SubAction.call!` and `hoist_errors { SubAction.call }`?? -->
* `context_for_logging` (and decent #inspect support)


