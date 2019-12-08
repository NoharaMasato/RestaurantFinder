require 'bundler/setup'
require 'json'
require 'net/http'
require 'line/bot'
require 'uri'

GURUNAVI_URL="https://api.gnavi.co.jp/RestSearchAPI/v3" 

def getShopFromGuruNavi(lat,lon)
  uri=URI(GURUNAVI_URL)
  uri.query=URI.encode_www_form({
    keyid: ENV["GURUNAVI_API_KEY"],
    latitude: lat,
    longitude: lon
  })
  puts "uri=#{uri}"
  response_json=Net::HTTP.get(uri)
  puts "restran_reponse_json=#{response_json}"
  return JSON.parse(response_json)["rest"]
end

def get_shops(result)
    hash_result = JSON.parse result #レスポンスが文字列なのでhashにパースする
    shops = hash_result["rest"] #ここでお店情報が入った入れつとなる
    return shops
end

def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
end

def get_name(user_id) #ユーザー情報の取得
    response = @client.get_profile(user_id)
    case response
    when Net::HTTPSuccess then
	      username = JSON.parse(response.body)['displayName'] #名前が取得できる
	      `curl -X POST -H 'Content-type: application/json' --data '{"text":"#{username}"}' https://hooks.slack.com/services/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`
	      return username
    end
end

def webhook(event:, context:)
    puts "event=#{event}"
    signature = event['headers']['X-Line-Signature']
    puts "signature=#{signature}"
    body = event['body']
    puts "body=#{body}"
    # unless client.validate_signature(body, signature)
    #   puts 'signature_error' # for debug
    #   return {statusCode: 400, body: JSON.generate('signature_error')}
    # end

    events = client.parse_events_from(body)#ここでlineに送られたイベントを検出している
    # messageのtext: に指定すると、返信する文字を決定することができる
    #event.message['text']で送られたメッセージを取得することができる
    shop_name = "" #変数をこの段階で定義しておく

    user_id = events[0]["source"]["userId"]
    get_name(user_id)

    events.each { |line_message|
        puts "line_message=#{line_message}"
	      if line_message.message['text'] #送信情報が文字列の場合
	      		# category = Category.find_by('category_name LIKE ?', "%#{line_message.message['text']}%")
	      		# if category != nil #送られてきたものがカテゴリーの情報の場合
	      		# 	user.category_code = category.category_s_code
	      		# 	user.save
	      		# else
	      		# 	place = line_message.message['text'] #ここで位置情報を得る
	      		# 	unless user.category_code
            #     result=getShopFromGuruNavi(pla=place)
				    #   else #カテゴリーが指定されている場合
				    #   	category = user.category_code
            #     result=getShopFromGuruNavi(pla=place,cat=category)
				    #     user.category_code = nil
				    #     user.save
				    #   end
				    #   shops = get_shops(result)
			      # end
	      elsif line_message.message["address"] #送信情報が位置情報の場合
	      	latitude = line_message.message['latitude']
		      longitude = line_message.message['longitude']
          shops=getShopFromGuruNavi(latitude,longitude)
		      #shops = get_shops(result)
	      end

        if shops.any?
          if shops.class == Array
            shop = shops.sample
          else
            shop = shops
          end
          url = shop["url_mobile"] #サイトのURLを送る
          shop_name = shop["name"] #店の名前
          category = shop["category"] #カテゴリー
          open_time = shop["opentime"] #空いている時間
          holiday = shop["holiday"] #定休日

          if open_time.class != String #空いている時間と定休日の二つは空白の時にHashで返ってくるので、文字列に治そうとするとエラーになる。そのため、クラスによる場合分け。
              open_time = ""
          end
          if holiday.class != String
              holiday = ""
          end
          if shop_name != nil && url != nil && category != nil
            response = "【店名】" + shop_name + "\n" + "【カテゴリー】" + category + "\n" + "【営業時間と定休日】" + open_time + "\n" + holiday + "\n" + url
          end
        else
          response = "該当店舗はありません"
        end

        event = JSON.parse event["body"]
        puts event

        message = {
          type: 'text',
          text: response
        }
        client.reply_message(event["events"][0]["replyToken"], message)
    }
end

