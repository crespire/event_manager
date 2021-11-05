# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone(number)
  number.gsub!(/[[:punct:]]/, '')
  return '(000) 000-0000' unless number.length.between?(10, 11)

  if number.length == 11 && number[0] == '1'
    '(%d%d%d) %d%d%d-%d%d%d%d' % number[1..-1].chars
  elsif number.length == 10
    '(%d%d%d) %d%d%d-%d%d%d%d' % number.chars
  else
    '(000) 000-0000'
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_collect = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone = clean_phone(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  reg_collect.push(DateTime.strptime(row[:regdate], '%m/%d/%y %k:%M'))
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  puts "#{name}'s number is #{phone}"
end

hours = reg_collect.map(&:hour)
hour, freq = hours.tally.max_by { |k, v| v }
puts "Most active hour is #{hour} with #{freq} occurences."

days = reg_collect.map { |date| date.strftime('%A') }
day, d_freq = days.tally.max_by { |k, v| v }
puts "The most active day is #{day} with #{d_freq} occurences."
