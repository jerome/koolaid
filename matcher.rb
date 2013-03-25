require 'csv'
require 'optparse'

module Koan
class Matcher

	attr_accessor :ignore, :replace, :endings, :src_data, :dst_data, :wrk_data, :presplit
	attr_accessor :src_filename, :dst_filename, :src_columns, :dst_column, :separator, :headers, :favor_perfect_match

	def initialize
		@favor_perfect_match = true
		@separator = "\t"
		@headers = false

		@ignore = { }
		@replace = { }
		@endings = { }
		@src_columns = [ nil, nil ]
		@dst_columns = [ nil, nil ]
	end

	def run
		parse_options OptionParser.new
		setup

		csv_options = {
		  :col_sep => @separator,
		  :headers => @headers || !@src_columns[0].nil?,
		  :return_headers => @headers || !@src_columns[0].nil?,
		}
		@src_data = load_data(@src_filename, csv_options, @src_columns[0], @src_columns[1])

		csv_options = {
		  :col_sep => @separator,
		  :headers => @headers || !@dst_columns[0].nil?,
		  :return_headers => @headers || !@dst_columns[0].nil?,
		}
		@dst_data = load_data(@dst_filename, csv_options, @dst_columns[0], @dst_columns[1])

		@wrk_data = Hash.new
		@presplit = Hash.new
		@dst_data.each do |code, description|
			@wrk_data[code] = description.downcase
			@presplit[code] = normalize_words(@wrk_data[code])
			@wrk_data[code] = @presplit[code].join(' ')
		end

		location = Struct.new(:index, :count).new(0, 0)
		@src_data.each do |code, description|
			matches = find_matches(description)
			location.count = matches.size
			if matches.empty?
				location.index = 0
				output(code, nil, description, nil, location)
			else
				matches.each_with_index do |other, index|
					location.index = index
					output(code, other, description, @dst_data[other], location)
				end
			end
		end
	end

	def load_data(filename, options = {}, key = nil, value = nil)
		key_index = 0
		value_index = 1
		data = Hash.new

		CSV.foreach(filename, options) do |row|
			if row.respond_to?('header_row?') && row.header_row? && !key.nil? && !value.nil?
				key_index = row.index(key)
				value_index = row.index(value)
				raise "Key field not found: '#{key}'" if key_index.nil?
				raise "Value field not found: '#{value}'" if value_index.nil?
			else
				code = row[key_index]
				data[code] = row[value_index]
		  end
		end

		return data
	end

	def find_matches(s)
	  matches = []
	  s = s.downcase
	  has_perfect_match = false
	  src_words = normalize_words(s)

	  @wrk_data.each do |code, description|
		  if @favor_perfect_match
			  if s == description
					if has_perfect_match
						matches << code
					else
						has_perfect_match = true
						matches = [ code ]
					end
			  end
			  next if has_perfect_match
		  end

		  dst_words = @presplit[code]
	    max = dst_words.size()

	    hits = misses = 0
		  src_words.each do |word|
	      if description.include? word
	        hits += 1
	      else
	        misses += 1
	      end
	    end
	    matches << code if misses == 0
	    if max >= 2 && hits == max
	      matches = [ code ]
	      return matches
	    end
	  end

	  return matches if matches.size > 0

	  @wrk_data.each do |code, description|
	    hits = misses = 0
	    src_words.each do |word|
	      if description.include? word
	        hits += 1
	      else
	        misses += 1
	      end
	    end
	    matches << code if (1.0 * hits) / (hits + misses) > 0.66
	  end

	  return matches
	end

	def normalize_words(s)
		s.split(/[ \-\/]+/).map { |word| normalize_word(word) } .compact
	end

	def normalize_word(word)
		return nil if @ignore[word]
		word = @replace[word] unless @replace[word].nil?

		wlength = word.length
		@endings.each do |ending, replacement|
			elength = ending.length
			if word[wlength-elength..wlength-1] == ending
				return word[0..wlength-elength-1]
			end
		end

		return word
	end

	def parse_options(opts)
   opts.banner = "Usage: #{$0} [OPTIONS] files"
   opts.separator ''
   opts.separator 'Joins two code files together using the code descriptions'
   opts.separator ''
   opts.separator 'OPTIONS:'

   # Add arguments
   opts.on('--src SRC_FILENAME', 'Source data filename') do |value|
     @src_filename = value
   end

   opts.on('--dst DST_FILENAME', 'Destination data filename') do |value|
	   @dst_filename = value
   end

   opts.on('--scols COLUMNS', 'Source data columns (separated by a comma)') do |value|
     @src_columns = value.split(',')
   end

   opts.on('--dcols COLUMNS', 'Destination data columns (separated by a comma)') do |value|
	   @dst_columns = value.split(',')
   end

   opts.on('--sep SEPARATOR', 'Column separator') do |value|
	   puts value
     @separator = eval("\"#{value}\"")
   end

   opts.on('--headers', 'Files contain headers') do |value|
     @headers = true
   end

   opts.on('--imperfect', 'Do not favor perfect matches (ie. descriptions are the same)') do |value|
	   @favor_perfect_match = false
   end

   opts.on('-h', '--help', 'show this message') do
     puts opts
     exit false
   end

   opts.parse!

   # Verify arguments
   raise options_error(opts, 'Must specify source data filename') if @src_filename.nil?
   raise options_error(opts, 'Must specify destination data filename') if @dst_filename.nil?
   raise options_error(opts, 'Must specify only two source columns') if !@src_columns.nil? && @src_columns.size != 2
   raise options_error(opts, 'Must specify only two destination columns') if !@dst_columns.nil? && @dst_columns.size != 2
 end

 def options_error(opts, s)
   puts opts
   return s
 end

end
end
