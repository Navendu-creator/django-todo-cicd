module ApiHelper

  def format_response(search_response, params)
    response = {
        total: 0,
        page: params[:page],
        per_page: params[:limit]
    }
    results = []
    if not search_response.nil?
      data = Hashie::Mash.new search_response
      if params.has_key? 'autocomplete'
        if data.families.hits.key? 'hits'
          results = data.families.hits.hits.map { |hit|
            family = hit._source
            {
                id: family.id,
                type: 'family',
                name: family.name,
                layoutfont_id: family.layoutfont_id,
                # score: hit._score
            }
          }
          response[:total] += data.families.hits.total
        end
        if data.designers.hits.key? 'hits'
          results.concat data.designers.hits.hits.map { |hit|
                           designer = hit._source
                           {
                               id: designer.id,
                               type: 'designer',
                               name: designer.name,
                               score: hit._score

                           }
                         }
          response[:total] += data.designers.hits.total
        end
        if data.foundries.hits.key? 'hits'
          results.concat data.foundries.hits.hits.map { |hit|
                           foundry = hit._source
                           {
                               id: foundry.id,
                               type: 'foundry',
                               name: foundry.name
                           }
                         }
          response[:total] += data.foundries.hits.total
        end
      else
        if data.hits.key? 'hits'
          results = data.hits.hits.map { |hit|
            family = hit._source
            family.typefaces.each do |t|
              t.url = "http://www.fontshop.com/families/#{t.slug}/"
            end
            family.foundry.url = "http://www.fontshop.com/foundries/#{family.foundry.slug}/"
            {
                id: family.id,
                name: family.name,
                url: "http://www.fontshop.com/families/#{family.slug}",
                typeface_count: family.typeface_count,
                webfonts_available: family.webfonts_available,
                layoutfont_id: family.layoutfont_id,
                foundry: family.foundry,
                typefaces: family.typefaces,
#                score: hit._score
            }
          }
          response[:total] = data.hits.total
        end
      end
    end
    response[:results] = results
    response
  end

  def get_search_query(term)
    {bool: {
        should: [{
                     match: {'name.plain' => {query: term, boost: 3}},
                 }, {
                     nested: {
                         path: 'designers',
                         query: {
                             match: {'designers.name' => term}
                         }
                     }
                 }, {
                     nested: {
                         path: 'foundry',
                         query: {
                             match: {'foundry.name' => term}
                         }
                     }
                 }]
    }}
  end

  def get_filters(params, category_map)
    filters = []
    if params[:category] != 'any'
      filters.push(term: {style_category: category_map[params[:category]]})
    end
    if params[:type] == 'webfonts'
      filters.push(term: {webfonts_available: 1})
    end
    if params[:client] == 'webfonter'
      filters.push(term:   {web_layoutfont_available: 1})
    end
    filters
  end

  # a hash which by default creates a new hash when an unknown key is queried, allowing you to do things like hash[1][2][3] = 4
  # see http://stackoverflow.com/questions/1503671/ruby-hash-autovivification-facets
  def auto_vivifying_hash
    Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
  end

  #https://gist.github.com/bcoe/6505434
  def sanitize_search_string(str)
    # Escape special characters
    # http://lucene.apache.org/core/old_versioned_docs/versions/2_9_1/queryparsersyntax.html#Escaping Special Characters
    escaped_characters = Regexp.escape('\\+-&|!(){}[]^~*?:\/')
    str = str.gsub(/([#{escaped_characters}])/, '\\\\\1')

    # AND, OR and NOT are used by lucene as logical operators. We need
    # to escape them
    ['AND', 'OR', 'NOT'].each do |word|
      escaped_word = word.split('').map { |char| "\\#{char}" }.join('')
      str = str.gsub(/\s*\b(#{word.upcase})\b\s*/, " #{escaped_word} ")
    end

    # Escape odd quotes
    quote_count = str.count '"'
    str = str.gsub(/(.*)"(.*)/, '\1\"\3') if quote_count % 2 == 1
    return str
  end


end