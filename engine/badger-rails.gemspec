require_relative "../lib/badger/version"

Gem::Specification.new do |spec|
  spec.name        = "badger-rails"
  spec.version     = Badger::VERSION
  spec.authors     = [ "Bobby Meyer" ]
  spec.email       = [ "bobby@bobbymeyer.com" ]
  spec.homepage    = "https://github.com/bobbymeyer/badger"
  spec.summary     = "Badger, the badge generator, as a Rails engine."
  spec.description = <<~TEXT.strip
    Badges composed as documents and rendered by the badger gem, with an
    editor, a colorway against a palette, a read-only JSON API and a Ruby
    interface, so a later tool can ask for a badge the way this one asks
    Pandatone for a palette.
  TEXT
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*"].select { |path| File.file?(path) }
  end

  # The core: geometry, fitting, type setting. Same version, same repository.
  spec.add_dependency "badger", Badger::VERSION

  spec.add_dependency "rails", ">= 8.0", "< 9"
  # The typographic style every screen is set in, declared here rather than
  # taken from the host on faith.
  spec.add_dependency "its-swiss", "~> 0.8"
  # The palettes a badge is dressed in come from Pandatone, and so does the
  # dresser that asks for them and holds the answer.
  spec.add_dependency "pandatone", ">= 0.2"
  spec.add_dependency "propshaft", ">= 1.0", "< 3"
  spec.add_dependency "importmap-rails", ">= 2.0", "< 4"
  spec.add_dependency "turbo-rails", ">= 2.0", "< 3"
  spec.add_dependency "stimulus-rails", ">= 1.3", "< 2"
end
