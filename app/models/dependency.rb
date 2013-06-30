class Dependency

  # This Model describes the relationship between 2 products/packages
  # This Model describes 1 dependency of a package to another package

  include Mongoid::Document
  include Mongoid::Timestamps

  A_SCOPE_COMPILE = "compile"
  A_SCOPE_RUNTIME = "runtime"
  A_SCOPE_REQUIRE = "require"
  A_SCOPE_TEST    = "test"

  field :name        , type: String   # name of the dependency
  field :version     , type: String   # version of the dependency. This is the unfiltered version string. It is not parsed yet.
  field :group_id    , type: String   # groupd_id of the dependency
  field :artifact_id , type: String   # artifact_id of the dependency
  field :dep_prod_key, type: String   # prod_key of the dependency (Foreign Key)
  field :scope       , type: String   # scope of the dependency

  field :prod_key    , type: String   # This dependency belongs to this prod_key
  field :prod_version, type: String   # This dependency belongs to this version of prod_key

  field :prod_type   , type: String,  :default => Project::A_TYPE_RUBYGEMS
  field :language    , type: String,  :default => Product::A_LANGUAGE_RUBY
  field :known       , type: Boolean

  def self.find_by_lang_key_and_version( lang, prod_key, version)
    Dependency.all(conditions: { language: lang, prod_key: prod_key, prod_version: version } )
  end

  def self.find_by_lang_key_version_scope(lang, prod_key, version, scope)
    if scope
      return Dependency.where( language: lang, prod_key: prod_key, prod_version: version, scope: scope )
    else
      return Dependency.where( language: lang, prod_key: prod_key, prod_version: version )
    end
  end

  def self.find_by(language, prod_key, prod_version, name, version, dep_prod_key)
    dependencies = Dependency.where(language: language, prod_key: prod_key, prod_version: prod_version, name: name, version: version, dep_prod_key: dep_prod_key)
    return nil if dependencies.nil? || dependencies.empty?
    dependencies[0]
  end

  def product
    product = Product.fetch_product( language, dep_prod_key )
    if product.nil? && language.eql?(Product::A_LANGUAGE_PHP) && (dep_prod_key.eql?( "php/php" ) || dep_prod_key.eql?( "php" ) )
      product = Product.fetch_product( Product::A_LANGUAGE_C, dep_prod_key )
    end
    product
  end

  def parent_product
    Product.fetch_product( language, prod_key )
  end

  def language_escaped
    if self.language.eql? Product::A_LANGUAGE_NODEJS
      return "nodejs"
    end
    if language.eql?(Product::A_LANGUAGE_PHP) && (dep_prod_key.eql?( "php/php" ) || dep_prod_key.eql?( "php" ) )
      return Product::A_LANGUAGE_C.downcase
    end
    return language.downcase
  end

  def update_known
    product = self.product
    if product.nil?
      self.known = false
    else
      self.known = true
    end
    self.save()
  end

  def update_known_if_nil
    self.update_known() if self.known.nil?
  end

  def version_parsed
    return "0" if version.nil?
    abs_version = String.new(version)
    if prod_type.eql?( Project::A_TYPE_RUBYGEMS )
      abs_version = String.new( gem_version_parsed )
    elsif prod_type.eql?( Project::A_TYPE_COMPOSER )
      abs_version = String.new( packagist_version_parsed )
    elsif prod_type.eql?( Project::A_TYPE_NPM )
      abs_version = String.new( npm_version_parsed )
    end
    # TODO cases for java
    abs_version
  end

  def gem_version_parsed
    version_string = String.new(version)
    product        = Product.fetch_product( self.language, self.dep_prod_key )
    dependency     = Projectdependency.new
    parser         = GemfileParser.new
    parser.parse_requested_version(version_string, dependency, product)
    dependency.version_requested
  end

  def packagist_version_parsed
    lang = self.language
    if self.dep_prod_key.eql?("php/php") or self.dep_prod_key.eql?("php")
      lang = Product::A_LANGUAGE_C
    end
    version_string = String.new(version)
    product        = Product.fetch_product( lang, self.dep_prod_key )
    dependency     = Projectdependency.new
    parser         = ComposerParser.new
    parser.parse_requested_version(version_string, dependency, product)
    dependency.version_requested
  end

  def npm_version_parsed
    version_string = String.new( version )
    product        = Product.fetch_product( self.language, self.dep_prod_key )
    dependency     = Projectdependency.new
    parser         = PackageParser.new
    parser.parse_requested_version( version_string, dependency, product )
    dependency.version_requested
  end

  def dep_prod_key_for_url
    Product.encode_product_key dep_prod_key
  end

  def version_for_url
    url_param = version_parsed
    Version.encode_version( url_param )
  end

end
