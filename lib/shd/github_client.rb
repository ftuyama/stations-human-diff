require "jwt"
require "octokit"
require "openssl"

module SHD
  class GithubClient

    def self.username
      "#{ENV['STATIONS_GITHUB_APP_NAME'] || 'github-actions'}[bot]"
    end

    def self.generate
      Logger.info "Opening connection to Github..."

      if ENV["GITHUB_TOKEN"]
        # Github client alternative, using personal token
        client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"])
      else
        # Github app credentials
        client = Octokit::Client.new(
          client_id:     ENV['STATIONS_GITHUB_APP_CLIENT_ID'],
          client_secret: ENV['STATIONS_GITHUB_APP_CLIENT_SECRET'],
          bearer_token:  generate_webtoken,
        )

        installation = client.create_app_installation_access_token(ENV['STATIONS_GITHUB_APP_INSTALL_ID'])
        client.access_token = installation[:token]
      end

      client
    end

    def self.generate_webtoken
      private_key = OpenSSL::PKey::RSA.new(ENV['STATIONS_GITHUB_APP_PRIVATE_KEY_PEM'])

      payload = {
        iat: Time.now.to_i,                 # issued at time
        exp: Time.now.to_i + (10 * 60),     # JWT expiration time (10 minute maximum)
        iss: ENV['STATIONS_GITHUB_APP_ID'], # GitHub App's identifier
      }

      JWT.encode(payload, private_key, "RS256")
    end

    def self.commits(client:, pull:)
      client.pull_request_commits(
        pull["base"]["repo"]["full_name"],
        pull["number"],
      )
    end

    def self.own_comments(client:, pull:)
      client.issue_comments(
        pull["base"]["repo"]["full_name"],
        pull["number"],
      ).select do |comment|
        comment.user.login == GithubClient.username
      end
    end

    def self.remove_old_comments!(client:, pull:, comments:)
      Logger.info "Removing old comments..."

      comments.each do |comment|
        client.delete_comment(
          pull["base"]["repo"]["full_name"],
          comment.id,
        )
      end
    end

    def self.post_comment!(client:, pull:, body:)
      Logger.info "Posting comment to pull request..."

      client.add_comment(
        pull["base"]["repo"]["full_name"],
        pull["number"],
        body,
      )
    end

  end
end
