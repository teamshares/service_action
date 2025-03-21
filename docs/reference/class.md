::: danger ALPHA
* TODO: convert this rough outline into actual documentation
:::

## Class-level interface

* `expects`
* `exposes`
* `messages`

### `expects` and `exposes`
* setting `sensitive: true` on any param will filter that value out when inspecting or passing to on_exception
* Note we have two custom validations: boolean: true and the implicit type: foo.  (maybe with array of types?)
    Note a third allows custom validations: `expects :foo, validate: ->(value) { "must be pretty big" unless value > 10 }` (error raised if any string returned OR if it raises an exception)

### #call and #rollback

### hooks
