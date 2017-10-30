require 'jekyll'
require 'picasa'

require_relative 'google-photos'

# Google responds with incorrect encoding if a User-Agent containing "gzip" is used
# BAD: ruby-gem-picasa-v0.9.1 (gzip)
# BAD: gzip
# GOOD: foo (blah)
# GOOD: ruby-gem-picasa-v0.9.1
# GOOD: foo
# GOOD: <none>
#
# https://github.com/morgoth/picasa/issues/41
Picasa::HTTP.instance_variable_get(:@default_options)[:headers]['User-Agent'].sub!(/ \(gzip\)/, '')

module Jekyll
  class PicasaClient < Picasa::Client
    DEFAULT_CONFIG = {
      'client_secrets_json' => 'secrets/gphoto_client_secrets.json',
      'tokens_yml' => 'secrets/gphoto_tokens.yml',
    }

    ERR_EMAIL = "Specify `gphoto.email` in _config.yml"
    ERR_CLIENT_SECRETS = <<-EOS
Login to Google API Console to register an app and create OAuth client_id and client_secret.
Then click on `DOWNLOAD JSON` and save the file to %s. This path comes from _config.yml
key `gphoto.client_secrets_json`.

https://console.developers.google.com/apis/credentials
EOS

    def initialize(config)
      config = DEFAULT_CONFIG.merge(config)
      email = config['email']
      client_secrets_json = File.expand_path(config['client_secrets_json'])
      tokens_yml = File.expand_path(config['tokens_yml'])

      raise ERR_EMAIL if email.nil?
      raise (ERR_CLIENT_SECRETS % client_secrets_json) unless File.file? client_secrets_json
      FileUtils.mkdir_p(File.dirname tokens_yml)

      auth = GooglePhotos::Auth.new(email, client_secrets_json, tokens_yml)

      super(user_id: email, access_token: auth.access_token)
    end
  end
end
