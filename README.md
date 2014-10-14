# Warehaus

This gem is a work in progress that allows you to programatically retrieve usable collada
and image files from the Sketchup 3D Warehouse.

Currently, the gem can be used as a class or through its CLI.

## Installation

Add this line to your application's Gemfile:

    gem 'warehaus'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install warehaus

## Usage

### CLI

```
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
		[identifier] is a url or `contentId` for a Sketchup Warehouse model. 
		[path] is the path to the root directory to write the unboxed files 
		into. [name] will be the name of the directory containing the unboxed 
		files, and will also be the name of the collada file within that 
		directory.
	json [path]
		[path] is a path to a json file to parse and use for unboxing. see the
		github docs for information on the strucure of this file
	help
		prints help
```

### Class

Simply:

```ruby

require 'warehaus'

```

And then you can do:

```ruby

Warehaus::Getter.new(URL, ROOT_PATH, NAME);

```

Or:

```ruby

WareHause::Getter.from_hash(HASH_OF_RESOURCES)

```

### Hash/JSON import format

```json

{
	"dir":"path/to/root/dir",
	"models":{
		"name_of_model1":"http://urltomodel1onsketchup.com/blah",
		"name_of_model2":"content_id_of_model_2"
	}
}

```
