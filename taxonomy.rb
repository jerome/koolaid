#! /usr/bin/env ruby
require_relative 'matcher'

module Koan
class TaxonomyMatcher < Matcher

	def setup
		@ignore = {
				'medicine' => true,
				'and' => true,
				'&' => true,
		}
		@replace = {
				'orthopaedic' => 'orthopedic',
		}
		@endings = {
				'logy' => '',
				'ies' => '',
				'ist' => '',
				'ic' => '',
				'y' => '',
				's' => '',
		}
	end

	def output(src_code, dst_code, src_description, dst_description, location)
		if dst_code.nil?
			puts "#{src_code}\t__________\t#{src_description}\t__________"
		else
			parent = dst_code[0..3] + '00000X'
			if dst_code == parent || @dst_data[parent].nil?
				parent = ''
			else
				parent = " (#{@dst_data[parent]})"
			end
			puts "#{src_code}\t#{dst_code}\t#{src_description}\t#{dst_description}#{parent}"
		end
	end

end
end

Koan::TaxonomyMatcher.new.run
