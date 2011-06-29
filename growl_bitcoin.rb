# encoding: utf-8 #
require 'rubygems'
require 'json'
require 'net/http'
require 'money'
require 'growl'

include Growl

bitmarket_eur_sell = bitmarket_eur_buy = bitmarket_eur_last = Money.new(0, "EUR")
mtgox_eur_sell = mtgox_eur_buy =mtgox_eur_last = Money.new(0, "USD")

max_wait_time_to_display = 9

def pdiff(pnew, pold)
  up_mark = 1.007
  down_mark = 0.993
  
  mark_down_exceeded = pnew < (pold * down_mark)
  mark_up_exceeded = pnew > (pold * up_mark)

  puts "[#{pold}; #{pnew}]\t\t\t mark_down_exceeded (#{(pold * down_mark)}): #{mark_down_exceeded}, \t\t\tmark_up_exceeded (#{(pold * up_mark)}): #{mark_up_exceeded}"
  
  return mark_down_exceeded || mark_up_exceeded
end

def bitmarket_getcurr
  uri = URI.parse("https://bitmarket.eu/api/ticker/")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)

  response = http.request(request)
  result = JSON.parse(response.body)
  #  currencies"=>{"EUR"=>{"sell"=>"12.02", "buy"=>"12.11", "last"=>"12.05"}
end
def mtgox_getcurr
  uri = URI.parse("https://mtgox.com/code/data/ticker.php")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)

  response = http.request(request)
  result = JSON.parse(response.body)
  #  currencies"=>{"EUR"=>{"sell"=>"12.02", "buy"=>"12.11", "last"=>"12.05"}
end


interrupted = false

trap("INT") { interrupted = true }
i = 0
while true do
  begin
    result = bitmarket_getcurr
  rescue 
    text = "Bitmarket.eu Timeout ERROR"
    notify_error text, :sticky => true
  end
  begin
    result2 = mtgox_getcurr
  rescue 
    text = "Mt.Gox Timeout ERROR"
    notify_error text, :sticky => true
  end
  begin
  puts "#{Time.new} - New query, i = #{i}\n"

  new_bitmarket_eur_sell = Money.new((result["currencies"]["EUR"]["sell"].to_f * 100.0).to_i, "EUR")
  new_bitmarket_eur_buy =  Money.new((result["currencies"]["EUR"]["buy"].to_f * 100.0).to_i, "EUR")
  new_bitmarket_eur_last = Money.new((result["currencies"]["EUR"]["last"].to_f * 100.0).to_i, "EUR")

  new_mtgox_eur_sell = Money.new((result2["ticker"]["sell"].to_f * 100.0).to_i, "USD")
  new_mtgox_eur_buy =  Money.new((result2["ticker"]["buy"].to_f * 100.0).to_i, "USD")
  new_mtgox_eur_last = Money.new((result2["ticker"]["last"].to_f * 100.0).to_i, "USD")

  bitmarket_changed = (pdiff(new_bitmarket_eur_sell, bitmarket_eur_sell) || pdiff(new_bitmarket_eur_buy, bitmarket_eur_buy) || pdiff(new_bitmarket_eur_last, bitmarket_eur_last)) 
  mtgox_changed = (pdiff(new_mtgox_eur_sell, mtgox_eur_sell) || pdiff(new_mtgox_eur_buy,  mtgox_eur_buy) || pdiff(new_mtgox_eur_last, mtgox_eur_last))
  
  changed = bitmarket_changed || mtgox_changed
  if i > max_wait_time_to_display || changed || i == 0
    text = ""
    if  i > max_wait_time_to_display || bitmarket_changed || i == 0
      text += "Bitmarket.eu"
      text += ": NIX PASSIERT (#{bitmarket_eur_last})" if !bitmarket_changed
      text += " #{new_bitmarket_eur_last > bitmarket_eur_last ? '++++++++' : '--------'}" 
      text += "\n[Last Trade] #{bitmarket_eur_last} € -> #{new_bitmarket_eur_last} €"  if pdiff(new_bitmarket_eur_last, bitmarket_eur_last)
      text += "\n[Last Sell] #{bitmarket_eur_sell} € -> #{new_bitmarket_eur_sell} €"  if pdiff(new_bitmarket_eur_sell, bitmarket_eur_sell)
      text += "\n[Last Buy] #{bitmarket_eur_buy} € -> #{new_bitmarket_eur_buy} €" if pdiff(new_bitmarket_eur_buy, bitmarket_eur_buy)
    end
    if  i > max_wait_time_to_display || mtgox_changed || i == 0
      text += "\n\nMt.Gox"
      text += ": NIX PASSIERT (#{mtgox_eur_last})" if !mtgox_changed
      text += " #{new_mtgox_eur_last > mtgox_eur_last ? '++++++++' : '--------'}" 
      text += "\n[Last Trade] #{mtgox_eur_last} $ -> #{new_mtgox_eur_last} $" if pdiff(new_mtgox_eur_last, mtgox_eur_last)
      text += "\n[Last Sell] #{mtgox_eur_sell} $ -> #{new_mtgox_eur_sell} $" if  pdiff(new_mtgox_eur_sell, mtgox_eur_sell)
      text += "\n[Last Buy] #{ mtgox_eur_buy} $ -> #{ new_mtgox_eur_buy} $"  if  pdiff(new_mtgox_eur_buy, mtgox_eur_buy)
    end
    
    Growl.notify {
      self.message = text
      self.image = "/Users/peterlampesberger/Bitcoin/bitcoin.png"
      sticky! if changed
    }
    
    if changed
      bitmarket_eur_sell = new_bitmarket_eur_sell
      bitmarket_eur_buy = new_bitmarket_eur_buy
      bitmarket_eur_last = new_bitmarket_eur_last

      mtgox_eur_sell = new_mtgox_eur_sell
      mtgox_eur_buy =  new_mtgox_eur_buy
      mtgox_eur_last = new_mtgox_eur_last
    end
    i = 1
  end
  rescue StandardError => e
    puts e.inspect
  end
  20.times do
    if interrupted
      puts "safe exit"
      exit
    end
    sleep 0.5
  end
  i += 1
end