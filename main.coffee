# slack
SLACK_CHANNEL_ID = 'XXXXXX' # 対象のチャンネルのID
SLACK_TOKEN = 'xoxb-XXXXXXXXXXXXXXXXXXXXXXXXX' # slackのトークン

Slack = require 'slack-client'
autoReconnect = true # エラーの時に自動で再接続するかどうか
autoMark = false # 投稿内容を既読にするかどうか
slack = new Slack(SLACK_TOKEN, autoReconnect, autoMark)

# ga
GOOGLE_SERVICE_ACCOUNT_KEY_FILE = __dirname + '/google-key.json' # キーファイル
GOOGLE_SERVICE_ACCOUNT_EMAIL = 'XXXXXXXXX@XXXXXXXX' # サービスアカウントのメールアドレス
GA_VIEW_ID = '111111'  # google analyticsのView ID

google = require 'googleapis'
moment = require 'moment'

# ga metrics @see https://developers.google.com/analytics/devguides/reporting/core/dimsmets
METRICS_VISITOR = 'ga:visitors'
METRICS_GOAL_NEWS_LETTER_JP = 'ga:goal16Completions' # ga:goalXXCompletionsの形式。XXの部分を1から20までの数字に変えて値を取得できる

jwt = new google.auth.JWT GOOGLE_SERVICE_ACCOUNT_EMAIL,
  GOOGLE_SERVICE_ACCOUNT_KEY_FILE,
  null,
  ['https://www.googleapis.com/auth/analytics.readonly']

slack.on 'open', ->
  console.log "Connected to #{slack.team.name} as @#{slack.self.name}"

  jwt.authorize (err, result) ->
    # エラーがある場合はログを出力して終了
    if err
      console.error err
      process.exit()

  # Analyticsに値を取得しに行く
    getDataOfYesterday()

slack.on 'message', (message) ->
    
  channel = slack.getChannelGroupOrDMByID message.channel
  user = slack.getUserByID message.user
  text = message.text

  console.log "received message #{text} in channel #{channel.name}"

  if text is 'freshtrax' and channel.name is 'slack_hacking'
    getDataOfYesterday()

slack.on 'error', (err) ->
  console.error "Error", err

slack.login()


getDataOfYesterday = () ->
  analytics = google.analytics 'v3'
  yesterdayStr = moment().subtract(1, 'days').format('YYYY-MM-DD')
  params = {
    'ids':        'ga:' + GA_VIEW_ID
    'start-date': yesterdayStr
    'end-date':   yesterdayStr
    'metrics':    METRICS_VISITOR + ',' + METRICS_GOAL_NEWS_LETTER_JP
    'auth':       jwt
  }
  analytics.data.ga.get params, (err, resp) ->

    # エラーがある場合はログを出力して終了
    if err
      console.error err
      process.exit()

    # エラーがない場合は値をログに出力
    visitorCount = resp.totalsForAllResults[METRICS_VISITOR]
    newsLetterCount = resp.totalsForAllResults[METRICS_GOAL_NEWS_LETTER_JP]

    msg = 'freshtrax statics\n' 
    msg += '[Yesterday]\n'
    msg += 'Users: ' + visitorCount + '\n'
    msg += 'NEWS_LETTER_JP: ' + newsLetterCount + '\n'
    msg += 'Conversion Rate: ' + (newsLetterCount / visitorCount * 100).toFixed(2)+ '%\n'

    channel = slack.getChannelGroupOrDMByID SLACK_CHANNEL_ID
    channel.send msg

    # openのイベントだけで投稿する場合は、投稿後に終了 
    # slack.disconnect()