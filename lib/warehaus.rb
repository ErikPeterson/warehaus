require "warehaus/version"
require "httparty"
require "json"
require "zip"
require "fileutils"
require "pry"

module Warehaus
	$mode = "quiet"

	class Getter
		include HTTParty

		base_uri '3dwarehouse.sketchup.com'
		
		ENTITY_PATH = '/3dw/GetEntity'
		KMZ_PATH = '/warehouse/getpubliccontent'

		def initialize(url_or_id, dir='/tmp', name='warehouse-model')
			@name = name
			@path = dir
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
			@response = JSON.parse(self.class.get(ENTITY_PATH, @options), :symbolize_names => true)
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

		def download_kmz
			log("📥  Downloading KMZ file")
			@kmz = self.class.get(KMZ_PATH, @kmz_options).parsed_response
		end

		def write_kmz
			FileUtils::mkdir_p "#{@path}/.tmp"
			log("📝  Writing KMZ file")
			begin
				File.open("#{@path}/.tmp/#{@name}.kmz", "wb") do |f|
					f.write @kmz
				end
				FileUtils::mv "#{@path}/.tmp/#{@name}.kmz", "#{@path}/.tmp/#{@name}.zip"
			rescue Exception => e
				return raise_error e.message
			end
		end

		def unzip_kmz
			log("📁  Creating model directory")
			FileUtils::mkdir_p "#{@path}/untitled"

			log("🎊  Cracking open the ZIP file")
			Zip::File.open("#{@path}/.tmp/#{@name}.zip") do |zip_file|
				
				valid_paths = zip_file.entries.select do |entry|
					(entry.name =~ /models\//) != nil
				end
				
				valid_paths.each do |entry|

					if entry.name =~ /\.dae$/
						dest = "#{@path}/#{@name}.dae"
					else
						dest = "#{@path}/#{entry.name.match(/models\/(.*)$/)[1]}"
					end

					entry.extract(dest)
				end
			end
		end

		def cleanup
			log("🛀  Cleaning up")
			FileUtils.rm_rf("#{@path}")
		end

		def unbox
			log("📦  Beginning unbox!")
			fetch_entity
			get_kmz_id
			download_kmz
			write_kmz
			unzip_kmz
			cleanup
			"#{@path}/#{@name}"
		end

		def erase
			FileUtils.rm_rf "#{@path}/#{@name}"
		end

		def raise_error(msg)
			raise "Warehaus Error: #{msg}"
		end

		def log(msg)
			puts("Warehaus: #{msg}") if $mode == "verbose"
		end

		def self.from_hash(hash)
			hash[:models].each do |k, v|
				getter = self.new(v, "#{hash[:dir]}/#{k}", k)
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

			WareHaus::Gtter.from_hash(@json)

		end

		def v
			$mode = "verbose"
		end

		def unbox(args)
			fetcher = Warehaus::Getter.new(*args)
			fetcher.unbox
		end

		def self.help(method="none")
			puts "Usage: warehause -V <method> -- <arguments>..."
		end
	end


end
