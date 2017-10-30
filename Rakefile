# Github Pages at User level (not Project level) use the `source` branch, not `gh-pages`
ENV['BRANCH_NAME'] = 'master'
ENV['JEKYLL_OPTS'] = '--verbose --trace'

task default: 'build'

# Rake tasks to automate GitHub Pages: https://github.com/chikathreesix/jekyll-gh-pages
#
# Copied with modifications from gem 'jekyll-gh-pages':
# * allow passing command-line options to Jekyll via environment variable JEKYLL_OPTS
#
require 'fileutils'

remote_name = ENV.fetch("REMOTE_NAME", "origin")
branch_name = ENV.fetch("BRANCH_NAME", "gh-pages")
jekyll_opts = ENV.fetch("JEKYLL_OPTS", "")

PROJECT_ROOT = `git rev-parse --show-toplevel`.strip
BUILD_DIR    = File.join(PROJECT_ROOT, "build")
GH_PAGES_REF = File.join(BUILD_DIR, ".git/refs/remotes/#{remote_name}/#{branch_name}")

directory BUILD_DIR

file GH_PAGES_REF => BUILD_DIR do
  repo_url = nil

  cd PROJECT_ROOT do
    repo_url = `git config --get remote.#{remote_name}.url`.strip
  end

  cd BUILD_DIR do
    sh "git init"
    sh "git remote add #{remote_name} #{repo_url}"
    sh "git fetch #{remote_name}"

    if `git branch -r` =~ /#{branch_name}/
      sh "git checkout #{branch_name}"
    else
      sh "git checkout --orphan #{branch_name}"
      sh "touch index.html"
      sh "git add ."
      sh "git commit -m 'initial #{branch_name} commit'"
      sh "git push #{remote_name} #{branch_name}"
    end
  end
end

desc "Prepare for build"
task :prepare => GH_PAGES_REF

desc "Watch"
task :watch do
  sh "bundle exec jekyll serve --watch"
end

desc "Build static files"
task :build do
  cd PROJECT_ROOT do
    if File.exist?('_config_prod.yml')
      sh "bundle exec jekyll build #{jekyll_opts} --destination #{BUILD_DIR} --config _config.yml,_config_prod.yml"
    else
      sh "bundle exec jekyll build #{jekyll_opts} --destination #{BUILD_DIR}"
    end
  end
end

desc "Deploy static files to gh-pages branch"
task :deploy => [:build] do
  message = nil
  suffix = ENV["COMMIT_MESSAGE_SUFFIX"]

  cd PROJECT_ROOT do
    head = `git log --pretty="%h" -n1`.strip
    message = ["Site updated to #{head}", suffix].compact.join("\n\n")
  end

  cd BUILD_DIR do
    sh 'git add --all'
    if /nothing to commit/ =~ `git status`
      puts "No changes to commit."
    else
      sh "git commit -m \"#{message}\""
    end
    sh "git push #{remote_name} #{branch_name}"
  end
end

require 'httparty'

class FacebookClient
  include HTTParty
  base_uri 'https://graph.facebook.com'
  format :json

  def self.post_to_page(page_id, page_access_token, body)
    opts = {
      headers: {'Authorization' => 'Bearer ' + page_access_token},
      body: body
    }
    response = post("/#{page_id}/feed", opts)
    raise "Got an unsuccessful HTTP code #{response.code} from Facebook: #{response.body}" if response.code.to_i >= 400
    response.parsed_response['id']
  end
end

desc "Maybe post a link to Facebook if a new page was created on the site"
task :post_to_facebook do
  page_id = ENV['FB_PAGE_ID']
  access_token = ENV['FB_PAGE_ACCESS_TOKEN']
  if page_id.nil? or access_token.nil?
    puts "Environment variables FB_PAGE_ID and FB_PAGE_ACCESS_TOKEN must be specified"
    return
  end

  cd BUILD_DIR do
    base_url = YAML.load_file(File.join(PROJECT_ROOT, '_config.yml'))['url']
    added_urls = `git diff-tree --no-commit-id --name-status -r HEAD~1..HEAD`
                    .lines
                    .map(&:split)
                    .select {|status, name| status=='A' and name =~ /\.html$/}
                    .reject {|_, name| name.include? '/tags/' or name.include? '/categories/'}
                    .map {|_, name| File.join(base_url, name).sub(/\/index.html/i, '')}
    unless added_urls.empty?
      post = {
        link: added_urls[0],
        message: added_urls[1..-1].join("\n")
      }
      puts "Posting the following to Facebook Page #{page_id}: #{post}"
      id = FacebookClient.post_to_page(page_id, access_token, post)
      puts "Success! Post id returned was #{id}"
    end
  end
end
