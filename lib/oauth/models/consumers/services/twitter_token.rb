require 'twitter'
class TwitterToken < ConsumerToken
  TWITTER_SETTINGS={:site=>"http://twitter.com"}
  def self.consumer
    @consumer||=OAuth::Consumer.new credentials[:key],credentials[:secret],TWITTER_SETTINGS
  end
  
  def self.create_from_request_token(user,token,secret,oauth_verifier)
    logger.info "create_from_request_token"
    request_token=OAuth::RequestToken.new consumer,token,secret
    access_token=request_token.get_access_token :oauth_verifier=>oauth_verifier

    unless user # if no user logged in via username/password create a new federated user (User subclass)
      twitter_oauth=Twitter::OAuth.new consumer.key, consumer.secret
      twitter_oauth.authorize_from_access access_token.token, access_token.secret  
      twitter_credentials = Twitter::Base.new(twitter_oauth).verify_credentials

      twitter_login = FederatedUser.custom_login(twitter_credentials, service_name)
      twitter_user = User.find_by_login twitter_login # this user login before?

      unless twitter_user
        twitter_user = FederatedUser.new(twitter_credentials, {:login=>twitter_login,:service_provider=>service_name.to_s})
        twitter_user.save(perform_validation=false)
        twitter_user.federated_user_activate!
      end
      user = twitter_user
    end

    logger.info self.inspect
    logger.info user.inspect
    existing_token = TwitterToken.find_by_user_id(user.id)
    if existing_token
      existing_token.destroy
    end
    create :user_id=>user.id,:token=>access_token.token,:secret=>access_token.secret 

  end

  def update(tweet)
    client.update tweet
  end
   
  def client
    unless @client
      @twitter_oauth=Twitter::OAuth.new TwitterToken.consumer.key,TwitterToken.consumer.secret
      @twitter_oauth.authorize_from_access token,secret
      @client=Twitter::Base.new(@twitter_oauth)
    end
    
    @client
  end
end