require 'jekyll-gh-pages'

# Github Pages at User level (not Project level) use the `source` branch, not `gh-pages`
ENV['BRANCH_NAME'] = 'master'

# HTTPS authentication doesn't work with SSH keys
ENV['REMOTE_NAME'] = 'origin-ssh'

task default: 'build'
