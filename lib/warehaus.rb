require "warehaus/version"
require "httparty"
require "net/http"
require "uri"
require "json"
require "zip"
require "fileutils"

module Warehaus
	$mode = "quiet"

	class Getter
		include HTTParty

		BASE_URI = '3dwarehouse.sketchup.com'
		base_uri BASE_URI
		ENTITY_PATH = '/3dw/GetEntity'
		KMZ_PATH = '/warehouse/getpubliccontent'

		def initialize(url_or_id, dir='./', name='warehouse-model')
			@name = name
			@path = dir
			@model_path = @path + '/' + @name
			@options = {
				:query => {
					:id => parse_input(url_or_id)
				}
			}
		end

		def parse_input(input)
			(input =~ /^[\w|\-|\d]+$/) ? input : input.match(/id=([\w|\-|\d]+)/)[1]
		end

		def fetch_entity
			log("📠  Fetching JSON representation of model")
			@response ||= JSON.parse(self.class.get(ENTITY_PATH, @options), :symbolize_names => true)
		end

		def get_kmz_id
			log("🔍  Checking for KMZ id in JSON")

			if !@response[:binaries] 
				return log("No KMZ file available for this object 💣")
			end
				
			if @response[:binaries][:ks]
				kmz_id = @response[:binaries][:ks][:id]
			else
				@response[:binaries].each{ |k, bin|
					kmz_id = bin[:id] if (bin[:originalFileName] =~ /kmz$/) != nil
				}
				if !kmz_id
					return log("No KMZ file available for this object 💣")
				end
			end

			@kmz_options = {
				:query =>{
					:contentId => kmz_id,
					:fn => "#{@name}.kmz"
				}
			}
		end

		def download_kmz(tries=3, redirect=false)
			return raise_error 'HTTP Redirect too deep' if tries == 0
			
			log("📥  Downloading KMZ file") unless redirect

			FileUtils::mkdir_p "#{@model_path}/.tmp"
			url = redirect ? URI.parse( redirect ) : URI.parse("http://" + BASE_URI + "#{KMZ_PATH}?contentId=#{@kmz_options[:query][:contentId]}&fn=#{@kmz_options[:query][:fn]}")
			
			begin
				resp = Net::HTTP.get_response(url)
			rescue Exception => e
				return raise_error e.message
			end

				
			case resp
			    when Net::HTTPSuccess then

		    		File.open("#{@model_path}/.tmp/#{@name}.kmz", "wb") do |file|
		        
		        		file.write(resp.body)
		        
		        	end
		    	
		    		FileUtils.mv "#{@model_path}/.tmp/#{@name}.kmz", "#{@model_path}/.tmp/#{@name}.zip"
		        
		        when Net::HTTPRedirection then
		   			download_kmz( tries-1, resp['location'])
		   		else raise_error("Response neither successful nor redirecting")
		    end
			

		end

		def unzip_kmz
			log("📁  Creating model directory")
			FileUtils::mkdir_p "#{@model_path}/untitled"

			log("🎊  Cracking open the ZIP file")
			Zip::File.open("#{@model_path}/.tmp/#{@name}.zip") do |zip_file|
				
				valid_paths = zip_file.entries.select do |entry|
					(entry.name =~ /models\//) != nil
				end
				
				valid_paths.each do |entry|

					if entry.name =~ /\.dae$/
						dest = "#{@model_path}/#{@name}.dae"
					else
						dest = "#{@model_path}/#{entry.name.match(/models\/(.*)$/)[1]}"
					end

					entry.extract(dest)
				end
			end
		end

		def cleanup
			log("🛀  Cleaning up")
			FileUtils.rm_rf("#{@model_path}")
		end

		def unbox
			log("📦  Beginning unbox!")
			fetch_entity
			get_kmz_id
			download_kmz
			unzip_kmz
			"#{@path}/#{@name}/"
		end

		def erase
			FileUtils.rm_rf "#{@model_path}"
		end

		def raise_error(msg)
			raise "Warehaus Error: #{msg}"
		end

		def log(msg)
			puts("Warehaus: #{msg}") if $mode == "verbose"
		end

		def self.from_hash(hash)
			hash[:models].each do |k, v|

				getter = self.new(v, "#{hash[:dir]}", k.to_s)
				getter.unbox
			end
		end


	end

	class CLI
		
		def initialize(args)
			@options = args
						.select{|arg| (arg =~ /^\-/) != nil}
						.map{|arg| arg.gsub(/^\-/,'')}

			set_options

			stripped_args = args.reject{|arg| (arg =~ /^\-/) != nil}
			@method = stripped_args[0]
			@arguments = stripped_args[1..-1]
			self.send(@method, @arguments)
		end

		def set_options
			@options.each{ |opt| self.send(opt)}
		end

		def json(args)

			File.open(args[0]) do |file|
				@json = JSON.parse(file.read, :symbolize_names => true)
			end

			Warehaus::Getter.from_hash(@json)

		end

		def v
			$mode = "verbose"
		end

		def unbox(args)
			fetcher = Warehaus::Getter.new(*args)
			fetcher.unbox
		end

		def help(method="none")
			puts <<eol

WAREHAUS

NAME
	warehaus

SYNOPSIS
	warehouse COMMAND [-v] [ARGS]

DESCRIPTION
	Takes URLS or IDs for Sketchup Warehouse models, grabs their collada 
	resources, and unpacks them into a target directory

OPTIONS
	-v
		Prints logging and debug information

WAREHAUS COMMANDS
	unbox  [identifier] [path=./] [name=warehouse_model]
		Unpacks Sketchup model identified by [identifier] to [path]/[name]/[name].dae
	json [path]
		[path] is a path to a json file to parse and use for unboxing. see the
		github docs for information on the strucure of this file
	help
		prints help

eol
		end
	end


end
