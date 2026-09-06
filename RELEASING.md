# Releasing

Badger is not published to RubyGems. A release is a tag, and a host takes
both gems from it in one git block, because the engine depends on the core
at exactly its own version:

```ruby
git "https://github.com/bobbymeyer/badger", tag: "v0.1.0" do
  gem "badger"
  gem "badger-rails"
end
```

`.github/workflows/release.yml` runs on the tag: it checks that the tag and
`Badger::VERSION` agree, runs both suites, builds both gems and opens a
GitHub release carrying them.

## Cutting a version

1. `lib/badger/version.rb` sets the version for both gems.
2. `CHANGELOG.md` turns the unreleased section into the version, with a date.
3. Merge to `main`, then tag it from `main` and push the tag.
4. Move each host's Gemfile to the new tag.

## What a host needs

The sidecar's Python packages, from `requirements.txt`, installed into the
interpreter named by `BADGER_PYTHON` (default `python3`). `bin/rails
badger:doctor` in the host says whether they are there.
