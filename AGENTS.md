# AGENTS.md

## Cursor Cloud specific instructions

This is a pure-Ruby gem (no Rails, no running servers). Development commands are documented in `CLAUDE.md`.

### Quick reference

| Task | Command |
|------|---------|
| Install deps | `bundle install` |
| Tests | `bundle exec rspec` |
| Lint | `bundle exec rubocop` |
| Both | `bundle exec rake` |
| Single spec | `bundle exec rspec spec/path/to_spec.rb` |

### Non-obvious caveats

- **Bundler 4.x required**: The lockfile was bundled with Bundler 4.0.6. Install with `sudo gem install bundler -v 4.0.6` if missing.
- **`libyaml-dev` must be installed**: The `psych` gem (transitive dep) needs `yaml.h`. Without `libyaml-dev`, `bundle install` fails on native extension build.
- **`vendor/bundle` path**: Gems are installed to `./vendor/bundle` via `.bundle/config` to avoid needing root write access to `/var/lib/gems`.
- **No real API calls in tests**: All HTTP interactions are stubbed with WebMock/VCR. No `DHAN_CLIENT_ID` or `DHAN_ACCESS_TOKEN` secrets are needed to run the test suite.
- **No services to start**: This is a library gem. There is no web server, database, or background worker. Testing is purely `bundle exec rspec` / `bundle exec rubocop`.
