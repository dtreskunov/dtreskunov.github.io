require 'googleauth'
require 'googleauth/stores/file_token_store'

module GooglePhotos
  class Auth
    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
    SCOPE = 'https://picasaweb.google.com/data/'

    attr_reader :user_id

    def initialize(user_id, client_secrets_json, tokens_yml)
      @user_id = user_id
      @client_secrets_json = client_secrets_json
      @tokens_yml = tokens_yml
    end

    def access_token
      @credentials ||= credentials
      @credentials.refresh! if @credentials.expired?
      @credentials.access_token
    end

    private

    def credentials
      client_id = Google::Auth::ClientId.from_file(@client_secrets_json)
      token_store = Google::Auth::Stores::FileTokenStore.new(:file => @tokens_yml)
      authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

      credentials = authorizer.get_credentials(@user_id)
      if credentials.nil?
        url = authorizer.get_authorization_url(base_url: OOB_URI )
        puts "Open the following URL in your browser and enter the resulting code:\n\n#{url}"
        code = gets
        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: @user_id, code: code, base_url: OOB_URI)
      end
      credentials
    end
  end
end
