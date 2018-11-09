require 'scraperwiki'
require 'uri'
require 'json'
require 'faraday'

def hash_to_query(hash)
  return URI.encode(hash.map{|k,v| "#{k}=#{v}"}.join("&"))
end

apikey = ENV["MORPH_GOOGLE_MAPS_API_KEY"]

areas = [
    {
        name: 'Bali',
        location: '-8.340530,115.091907',
        radius: 170_000,
        keywords: ['motorbike rental', 'bike rental', 'motorbike rent', 'bike rent', 'sewa motor', 'rental motor']
    },
    {
        name: 'Thailand',
        location: '15.870000,100.992500',
        radius: 1_000_000,
        keywords: ['motorbike rental', 'bike rental', 'motorbike rent', 'bike rent', 'rental motor', 'เช่ารถจักรยานยนต์', 'จักรยานเช่า', 'รถจักรยานยนต์ให้เช่า', 'จักรยานให้เช่า']
    },
    {
        name: 'Philippines',
        location: '12.879700,121.774000',
        radius: 1_000_000,
        keywords: ['motorbike rental', 'bike rental', 'motorbike rent', 'bike rent', 'rental motor', 'motorsiklo rental']
    }
]

areas.each do |area|
    area_name = area[:name]
    puts "ON AREA #{area_name}"

    area[:keywords].each do |keyword|
      puts "ON KEYWORD #{keyword}"

      page = 1
      pagetoken = nil

      loop do
        params = hash_to_query({
          key: apikey,
          location: '-8.340530,115.091907',
          radius: 170000,
          keyword: keyword,
          pagetoken: pagetoken
        })

        list_response = Faraday.get("https://maps.googleapis.com/maps/api/place/nearbysearch/json?#{params}")
        data = JSON.parse list_response.body rescue Hash.new
        next_page_token = data['next_page_token']

        puts "ON PAGE #{page}"

        data['results'].each do |place|
          placeid = place['place_id']
          puts "ON PLACE #{placeid}"

          details_response = Faraday.get("https://maps.googleapis.com/maps/api/place/details/json?key=#{apikey}&placeid=#{placeid}&fields=name,rating,price_level,international_phone_number,formatted_address,website,permanently_closed,place_id,vicinity,geometry,url")
          details = (JSON.parse details_response.body rescue Hash.new)['result']

          if !details.nil?
            ScraperWiki.save_sqlite(["place_id"], {
              "place_id" =>                   details['place_id'],
              "name" =>                       details['name'],
              "rating" =>                     details['rating'],
              "price_level" =>                details['price_level'],
              "international_phone_number" => details['international_phone_number'],
              "formatted_address" =>          details['formatted_address'],
              "website" =>                    details['website'],
              "permanently_closed" =>         details['permanently_closed'],
              "vicinity" =>                   details['vicinity'],
              "latitude" =>                   details['geometry']['location']['lat'],
              "longitude" =>                  details['geometry']['location']['lng'],
              "url" =>                        details['url'],
              "area" =>                       area_name
            })
          end
        end

        break if next_page_token.nil?
        pagetoken = next_page_token
        page += 1
      end
    end
end

puts "DONE"
