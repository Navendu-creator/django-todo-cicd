# API for Adobe CC Extension

## Technology Stack

We use Sinatra and Elasticsearch

## Local setup

Install and launch elasticsearch.

Checkout the repo then

    bundle install
        
Configure your environment by copying .env.example to .env, app.yml.example to app.yml and database.yml.example to database.yml
Fill out the appropriate values for the relevant environments

You can put any of the relevant environment variables in .env - or you can set them elsewhere.

Set RACK_ENV to your 'local' or 'development' or whatever you need. 

You can populate the elasticsearch index using

    rake
    
Or, more explicitly

    rake populate_search
    
If you want to clear and recreate the index first, use    

    rake populate_search[1]
    
There is a 2nd parameters to set an offset for family indexing
    
    rake populate_search[0,1000]
    
And a 3rd parameter to specify the types to index, default is "designers foundries families"
    
    rake populate_search[0,1000,families]    
    

Start the Sinatra app with webrick using
    
    ruby api.rb
    
Or

    rackup -p8081

    
## Deployment
    
Uses capistrano

Basic deployment with

    bundle exec cap relevant_environment deploy
    
Populate a remotely configured elasticsearch index with
    
    bundle exec cap relevant_environment rake_task:invoke task=populate_search

Deployment specific config needs to be uploaded to the remote server e.g.

.env, app.yml and database.yml need to be uploaded to /home/passenger/adobe-extension-api/shared/config


# API response example:

http://adobeapi.fontshop.com/families?category=display&sort_by=bestsellers&sort_order=asc&page=1&limit=1

```json
{
  "results": [
    {
      "id": 12361,
      "name": "Daisy",
      "url": "http:\/\/www.fontshop.com\/families\/daisy",
      "typeface_count": 2,
      "webfonts_available": false,
      "family_url_string": "daisy",
      "layoutfont_id": 342992,
      "foundry": {
        "id": 532,
        "name": "LudwigType",
        "url": "http:\/\/www.fontshop.com\/foundries\/ludwigtype\/"
      },
      "typefaces": [
        {
          "id": 674524,
          "name": "Daisy Kursiv",
          "weight_name": "Kursiv",
          "layoutfont_id": 342991,
          "url": "http:\/\/www.fontshop.com\/families\/daisy\/kursiv\/"
        },
        {
          "id": 674525,
          "name": "Daisy Regular",
          "weight_name": "Regular",
          "layoutfont_id": 342992,
          "url": "http:\/\/www.fontshop.com\/families\/daisy\/regular\/"
        }
      ]
    }
  ],
  "limit": 1,
  "page": 1,
  "client": null
}
```
(from https://github.com/fontshop/adobe-extension/issues/1 )

<code>GET /families</code>

Optional and combinable filters (query string parameters):

name|default|values|notes
----|-------|------|-----
type|all|webfonts \| desktopfonts|
category|all|display \| serif \| slab \| script \| sans \| nonwestern \| blackletter|
q|-|a search term|Could be separate method
sort_by|alphabetic|alphabetic \| newest \| bestsellers|
sort_order|asc|asc \| desc|
limit|20|1...n|Results per page
page|1|1...n|
nested|typefaces,foundries,layoutfonts|typefaces,foundries,layoutfonts,designers…|nested models
ids|-|id,id,id|
similar_to|-|a family id|
client|none|webfonter \| adobe-plugin|Useful for applying tool-specific data filters
autocomplete|bool|true\|false|display autocomplete suggestions based on value of q

Auto Complete example response:

http://adobeapi.fontshop.com/families?autocomplete=true&q=serif&limit=3

```json
{
  "results": [
    {
      "id": 8366,
      "name": "FF Milo Serif",
      "typeface_count": 12,
      "webfonts_available": true,
      "family_url_string": "ff-milo-serif"
    },
    {
      "id": 1858,
      "name": "Fedra Serif",
      "typeface_count": 16,
      "webfonts_available": false,
      "family_url_string": "fedra-serif"
    },
    {
      "id": 5605,
      "name": "Rotis Serif",
      "typeface_count": 6,
      "webfonts_available": false,
      "family_url_string": "rotis-serif"
    }
  ],
  "limit": 3,
  "page": 1,
  "client": null
}
```

## Elasticsearch

The index is called 'extension-api'.

Check the mapping:

http://localhost:9200/extension-api/_mapping

List records:

http://localhost:9200/extension-api/families/_search?pretty=true&q=*:*&size=50

