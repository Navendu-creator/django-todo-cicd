#!/bin/env ruby
# encoding: utf-8
#
require 'bundler/setup'

require 'dotenv'
Dotenv.load('config/.env')

require 'mysql2'

require './lib/elastic_client'

# integrate FS Core
require 'searchkick' # not sure why we need this
require 'fs_core'
ActiveSupport::Dependencies.autoload_paths += Dir[FsCore::Engine.root + "app/models/concerns"]
ActiveSupport::Dependencies.autoload_paths += Dir[FsCore::Engine.root + "app/models"]

db_config = YAML.load(ERB.new(
    File.new('config/database.yml').read).result(binding))[ENV['RACK_ENV']]
ActiveRecord::Base.establish_connection(db_config)


# fixme: monkey path the renderer for now - the problem is the default scope lazy loading the font atoms which breaks find_each
module Renderer
  def self.included(base)
    base.class_eval do
      default_scope { eager_load(:layoutfont) }
    end
    base.belongs_to :layoutfont
    base.belongs_to :web_layoutfont, foreign_key: :layoutfont_id, primary_key: :id
    base.has_one :font_atom, foreign_key: :md5_checksum, primary_key: :layoutfont_id
  end
end

# Populate Elastic Search Indexes for the Extension API from the fontshop DB
task :populate_search, [:clear, :family_offset, :types] do |t, args|

  args.with_defaults(:clear => '0', :family_offset => '0', :types => 'designers foundries families')
  family_offset = args[:family_offset].to_i
  types = args[:types].split(" ").map &:to_sym

  elastic = ElasticClient.new

  if (args[:clear] == '1')
    # clear index
    puts "Deleting index"
    elastic.delete_index
  end

  if not elastic.index_exists?
    puts "(Re)creating index"
    elastic.create_index(
        {
            settings: {
                analysis: {
                    filter: {
                        autocomplete_filter: {
                            type: 'edge_ngram',
                            min_gram: 1,
                            max_gram: 10
                        }
                    },
                    analyzer: {
                        autocomplete: {
                            type: 'custom',
                            tokenizer: 'standard',
                            filter: [
                                'lowercase',
                                'autocomplete_filter'
                            ]
                        }
                    }
                }
            },
            mappings: {
                families: {
                    properties: {
                        name: {
                            type: "multi_field",
                            fields: {
                                raw: {type: 'string', index: 'not_analyzed'},
                                plain: {type: 'string'},
                                autocomplete: {type: 'string', analyzer: 'autocomplete'}
                            }
                        },
                        bestseller_sortno: {type: 'integer'},
                        style_category: {type: 'string', index: 'not_analyzed'},
                        designers: {type: 'nested'},
                        foundry: {type: 'nested'},
                        typefaces: {type: 'nested'},
                    }},
                designers: {
                    properties: {
                        name: {
                            type: "multi_field",
                            fields: {
                                plain: {type: 'string'},
                                autocomplete: {type: 'string', analyzer: 'autocomplete'}
                            }
                        }
                    }},
                foundries: {
                    properties: {
                        name: {
                            type: "multi_field",
                            fields: {
                                plain: {type: 'string'},
                                autocomplete: {type: 'string', analyzer: 'autocomplete'}
                            }
                        }
                    }}
            }
        })
  end

  puts "Populating Indices"

  if (types.include? :designers)
    puts "Indexing designers …"
    cnt = 0
    Designer.find_each do |designer|
      cnt = cnt + 1
      puts "#{cnt} - Indexing #{designer.name}"
      elastic.index(designer.id, {
          id: designer.id,
          name: designer.name
      }, {type: 'designers'})
    end
    puts "#{cnt} designers indexed."
  end

  if (types.include? :foundries)
    puts "Indexing foundries …"
    cnt = 0
    Foundry.find_each do |foundry|
      cnt = cnt + 1
      puts "#{cnt} - Indexing #{foundry.name}"
      elastic.index(foundry.id, {
          id: foundry.id,
          name: foundry.name
      }, {type: 'foundries'})
    end
    puts "#{cnt} foundries indexed."
  end

  if (types.include? :families)
    puts "Indexing families …"
    cnt = 0
    ids = []
    Family.where(active: true).offset(family_offset).find_each do |family|
      cnt = cnt + 1
      puts "#{cnt} - Indexing #{family.name} ##{family.id}"
      typefaces = family.typefaces.where(active: true).order(sortno: :asc)
      wlf = WebLayoutfont.find_by_id(family.layoutfont_id)
      search_data = {
          id: family.id,
          name: family.name,
          slug: family.url_string,
          sort_name: family.sort_name,
          typeface_count: family.typeface_count,
          layoutfont_id: family.layoutfont_id,
          design_year: family.design_year || 0,
          bestseller_sortno: family.bestseller_sortno || 999999999,
          updated_at: family.updated_at,
          webfonts_available: family.webfonts_available ? 1 : 0,
          web_layoutfont_available: wlf ? 1 : 0,
          foundry: {
              id: family.foundry.id,
              name: family.foundry.name,
              slug: family.foundry.url_string
          },
          designers: family.family_designers.map { |family_designer|
            if family_designer.designer.nil?
              nil
            else
              {name: family_designer.designer.name}
            end
          },
          style_category: derive_style_category(family),
          typefaces: typefaces.map { |typeface| {
              id: typeface.id,
              name: typeface.name,
              weight_name: typeface.weight_name,
              layoutfont_id: typeface.layoutfont_id,
              slug: typeface.url_string,
              woff_md5: typeface.font_atoms.find { |atom|
                atom.font_type_id == 14 || atom.font_type_id == 15
              }.try(:md5_checksum)
          } },
          similar_families: family.similar_families.where("similar_family_id <> #{family.id}").limit(24).map{ |similar| { id: similar.similar_family_id }}
      }
      elastic.index(family.id, search_data, {type: 'families'})
      ids.push(family.id)
    end
    puts "#{cnt} families indexed."

    if family_offset == 0
      prune = Hashie::Mash.new elastic.search({filter: {not: {ids: {values: ids}}}})
      if prune.hits.total > 0
        ids = prune.hits.hits.map { |family| family._source.id }
        puts "Pruning #{ids.count} families from index"
        elastic.delete_ids ids
      end
    end

  end

end

def has_cat(family, style)
  family.style_categories.find { |c| c.name == style }
end

def derive_style_category(family)
  check_order = %w(Blackletter Script Sans\ Serif Serif Slab\ Serif Symbol Non\ Latin Display)
  for cat in check_order
    if has_cat(family, cat)
      puts "#{family.name} assigned to category #{cat}"
      return cat
    end
  end
  ''
end