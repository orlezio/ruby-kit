# encoding: utf-8
module Prismic
  # This is a simple cache class provided with the prismic.io Ruby kit.
  #
  # It is pretty dumb but effective:
  #
  # * everything is stored in memory,
  # * invalidation: not needed for prismic.io documents (they are eternally
  #   immutable), but we don't want the cache to expand indefinitely; therefore
  #   all cache but the new master ref is cleared when a new master ref gets
  #   published.
  #
  # If you need a smarter caching (for instance, caching in files), you can
  # extend this class and replace its methods, and when creating your API object
  # like this for instance: Prismic.api(url, options), pass the name of the
  # class you created as a :cache option. Therefore, to use this simple cache,
  # you can create your API object like this: `Prismic.api(url, cache:
  # Prismic::DefaultCache)`
  class LruCache

    # Based on http://stackoverflow.com/questions/1933866/efficient-ruby-lru-cache
    # The Hash are sorted, so the age is represented by the key order

    # Returns the cache object holding the responses to "results" queries (lists
    # of documents). The object that is stored as a cache_object is what is
    # returned by {Prismic::JsonParser.results_parser} (so that we don't have to
    # parse anything again, it's stored already parsed).
    #
    # @return [Hash<String,Object>]
    attr_reader :intern

    # Returns the maximum of keys to store
    #
    # @return [Fixum]
    attr_reader :max_size

    # @param max_size [Fixnum] (100) The default maximum of keys to store
    def initialize(max_size=100)
      @intern = {}
      @max_size = max_size
    end

    # Add a cache entry.
    #
    # @param key [String] The key
    # @param value [Object] The value to store
    #
    # @return [Object] The stored value
    def store(key, value)
      @intern.delete(key)
      @intern[key] = value
      if @intern.length > @max_size
        @intern.delete(@intern.first[0])
      end
      value
    end
    alias :[]= :store

    # Update the maximun number of keys to store
    #
    # Prune the cache old oldest keys if the new max_size is older than the keys
    # number.
    #
    # @param max_size [Fixnum] The new maximun number of keys to store
    def max_size=(max_size)
      raise ArgumentError.new(:max_size) if max_size < 1
      @max_size = max_size
      if @max_size < @intern.size
        @intern.keys[0 .. (@max_size-@intern.size)].each { |k|
          @intern.delete(k)
        }
      end
    end

    # Get a cache entry
    #
    # A block can be provided: it will be used to compute (and store) the value
    # if the key is missing.
    #
    # @param key [String] The key to fetch
    #
    # @return [Object] The cache object as was stored
    def get(key)
      found = true
      value = @intern.delete(key){ found = false }
      if found
        @intern[key] = value
      else
        self[key] = yield(key)
      end
    end
    alias :[] :get

    # Checks if a cache entry exists
    #
    # @param key [String] The key to test
    #
    # @return [Boolean]
    def include?(key)
      @intern.include?(key)
    end

    # Invalidates all entries
    def invalidate_all!
      @intern.clear
    end
    alias :clear! :invalidate_all!

    # Expose the Hash keys
    #
    # This is only for debugging purposes.
    #
    # @return [Array<String>]
    def keys
      @intern.keys
    end

    # Return the number of stored keys
    #
    # @return [Fixum]
    def size
      @intern.size
    end
    alias :length :size

  end

  # This default instance is used by the API to avoid creating a new instance
  # per request (which would make the cache useless).
  DefaultCache = LruCache.new
end
