require_relative 'lib/env_agent/version'

Gem::Specification.new do |spec|
  spec.name = 'env-agent'
  spec.version = EnvAgent::VERSION
  spec.authors = ['Panos Dalitsouris']
  spec.summary = 'Link repos cloned outside a git checkout into it, from any worktree, without printing paths.'
  spec.description = 'env-agent resolves the external repos a project depends on from per-machine .env.agents ' \
                     'files and links them into every worktree, plus a Claude Code agent that sets them up.'
  spec.license = 'MIT'
  spec.homepage = 'https://github.com/PanosCodes/env-agent'
  spec.required_ruby_version = '>= 3.3'
  spec.files = Dir['lib/**/*.rb', 'exe/*', 'templates/*', 'README.md', 'LICENSE'] - Dir['lib/rubocop/**/*']
  spec.bindir = 'exe'
  spec.executables = ['env-agent']
  spec.require_paths = ['lib']
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'
end
