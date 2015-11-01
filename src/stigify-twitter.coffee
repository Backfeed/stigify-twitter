# Config
# Environment Varialbes needed:
# HUBOT_TWITTER_CONSUMER_KEY
# HUBOT_TWITTER_CONSUMER_SECRET
# HUBOT_TWITTER_MENTION_ROOM
# HUBOT_TWITTER_MENTION_QUERY
# BF_X_ACCESS_TOKEN
# HUBOT_SLACK_TOKEN

oauth = require 'oauth'

twitter_bearer_token = null

module.exports = (robot) ->

  robot.hear /stigtwitter/i, (msg) ->
    robot.messageRoom process.env.HUBOT_TWITTER_MENTION_ROOM, "Stigify twitter in da house!"

  robot.brain.data.twitter_mention ?= {}

  key = process.env.HUBOT_TWITTER_CONSUMER_KEY
  secret = process.env.HUBOT_TWITTER_CONSUMER_SECRET
  if not key or not secret
    console.log "twitter_mention.coffee: HUBOT_TWITTER_CONSUMER_KEY and HUBOT_TWITTER_CONSUMER_SECRET are required. Get your tokens here: https://dev.twitter.com/apps"
    return

  twitterauth = new oauth.OAuth2(key, secret, "https://api.twitter.com/", null, "oauth2/token", null)

  twitterauth.getOAuthAccessToken "", {grant_type:"client_credentials"}, (e, access_token, refresh_token, results) ->
    twitter_bearer_token = access_token
    twitter_setup_search robot

  robot.respond /twitter search (.*)/i, (msg) ->
    robot.brain.data.twitter_mention.query = msg.match[1]
    robot.brain.data.twitter_mention.last_tweet = ""
    msg.send "Now searching Twitter for: #{twitter_query(robot)}"

  robot.respond /twitter search$/i, (msg) ->
    msg.send "Searching Twitter for: #{twitter_query(robot)}"


twitter_query = (robot) ->
  robot.brain.data.twitter_mention.query ||
    process.env.HUBOT_TWITTER_MENTION_QUERY


twitter_setup_search = (robot) ->
  if not twitter_bearer_token
    console.log "Invalid Twitter consumer key/secret!"
    return
  
  setInterval ->
    if twitter_query(robot)?
      twitter_search(robot)
  , 1000 * 60 * 1

  if twitter_query(robot)?
    twitter_search(robot)


twitter_search = (robot) ->
  last_tweet = robot.brain.data.twitter_mention.last_tweet || ''

  robot.http("https://api.twitter.com/1.1/search/tweets.json")
    .header("Authorization", "Bearer #{twitter_bearer_token}")
    .query(q: escape(twitter_query(robot)), since_id: last_tweet)
    .get() (err, response, body) ->
      tweets = JSON.parse(body)
      if tweets.statuses? and tweets.statuses.length > 0
        robot.brain.data.twitter_mention.last_tweet = tweets.statuses[0].id_str

        lastTweet = tweets.statuses[0]

        callContribution(robot, lastTweet)


callContribution = (robot, lastTweet) ->

  twitterHandle = lastTweet.user.screen_name
  
  contributionTitle = "Tweet: #{lastTweet.text} - @#{twitterHandle} http://twitter.com/#{lastTweet.user.screen_name}/status/#{lastTweet.id_str}"

  data = JSON.stringify
    channelId: process.env.STIGIFY_TWITTER_SLACK_CHANNEL_ID
    type: "tweet"
    contributors: [{ twitterHandle: twitterHandle, percentage: 100 }]
    title: contributionTitle
    description: ""
    slackAccessToken: process.env.HUBOT_SLACK_TOKEN

  options =
    # don't verify server certificate against a CA, SCARY!
    rejectUnauthorized: false

  robot.http("https://developslackext.elasticbeanstalk.com/contribution", options)
    .header('Content-Type', 'application/json')
    .header('User-Agent', 'DEAP')
    .header('x-access-token', process.env.BF_X_ACCESS_TOKEN)
    .post(data) (err, res, body) ->
      if err
        console.log("Encountered an error on callContribution: #{err}")
        return

      newContribution = JSON.parse(body)

      console.log(newContribution)

      contributionId = newContribution['id']

      if (!contributionId)
        console.log("#{twitterHandle} is not a backfeed member, not posting tweet as contribution!")
        return
      
      message = "New contribution submitted" + "\n" + contributionId + "\n" + contributionTitle

      robot.messageRoom process.env.HUBOT_TWITTER_MENTION_ROOM, message


# Slack has a hubot integration.
# The following code will trigger slack messages manually. it's not used anywhere for now.
# postContributionToSlack = (robot) ->
#   robot.messageRoom process.env.HUBOT_TWITTER_MENTION_ROOM, "postContributionToSlack!"
#   params = getSlackParams()

#   robot.http("https://slack.com/api/chat.postMessage?#{params}")
#     .header('Content-Type', 'application/json')
#     .post() (err, res, body) ->
#       if err
#         console.log("Encountered an error on postContributionToSlack: #{err}")
#         return

#       console.log("postContributionToSlack: body", body)

# getSlackParams = ->
#   text     = "*Tweet Contribution*"
#   token    = process.env.HUBOT_SLACK_TOKEN
#   channel  = "C0BSMN43U"
#   username = "backfeed-bot"
#   "token=#{token}&text=#{text}&channel=#{channel}&username=#{username}"