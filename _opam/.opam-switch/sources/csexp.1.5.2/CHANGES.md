# 1.5.2

- Fix `Csexp.serialised_length`. Previously, it would under count by 2 because
  it did not take the parentheses into account. (#22, @jchavarri)

# 1.5.1

- Drop dependency on result and compatibility with OCaml 4.02 (#17,
  @rgrinberg)

# 1.5.0

Replaced by 1.5.1 because of accidentally breaking compat with 4.03.

# 1.4.0

- Add a `Csexp.t` type and extend `Csexp` to include the module from the functor
  application (#14, @rgrinberg)

# 1.3.2

- The project now builds with dune 1.11.0 and onward (#12, @voodoos)

# 1.3.1

- Fix compatibility with 4.02.3

# 1.3.0

- Add a "feed" API for parsing. This new API let the user feed
  characters one by one to the parser. It gives more control to the
  user and the handling of IO errors is simpler and more
  explicit. Finally, it allocates less (#9, @jeremiedimino)

- Fixes `input_opt`; it was could never return [None] (#9, fixes #7,
  @jeremiedimino)

- Fixes `parse_many`; it was returning s-expressions in the wrong
  order (#10, @rgrinberg)

# 1.2.3

- Fix `parse_string_many`; it used to fail on all inputs (#6, @rgrinberg)

# 1.2.2

- Fix compatibility with 4.02.3

# 1.2.1

- Remove inclusion of the `Result` module, which was accidentally
  added in a previous PR. (#3, @rgrinberg)

# 1.2.0

- Expose low level, monad agnostic parser. (#2, @mefyl)

# 1.1.0

- Add compatibility up-to OCaml 4.02.3 (with disabled tests). (#1, @voodoos)

# 1.0.0

- Initial release
